/**
 * Front-camera frame pipeline for the gaze page turn feature.
 *
 * Owns a Camera Kit preview session bound to an offscreen ImageReceiver,
 * converts each received NV21 frame into an RGBA_8888 PixelMap and feeds it
 * to the CoreVisionKit faceDetector. The largest detected face is reduced to
 * a GazeSample (head pitch + eye centers' normalized position) and handed to
 * the registered frame listener; frames without a usable face deliver null
 * so the engine can mark tracking lost.
 *
 * Frame processing is strictly serial: arrivals while a frame is still being
 * processed are dropped, which throttles the detector to a sustainable rate.
 */
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { faceDetector } from '@kit.CoreVisionKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { GazeSample } from './GazePageTurnEngine'

export type GazeFrameListener = (sample: GazeSample | null) => void
export type GazeCameraErrorListener = (message: string) => void
type GazeCameraAdmission = () => boolean

export class GazeCameraService {
  /** Candidate frame rotations probed at startup; front sensors may deliver
   * rotated content, which makes the detector miss upright faces. */
  private static readonly PROBE_ANGLES: number[] = [0, 90, 180, 270]
  private static readonly PROBE_FRAMES_PER_ANGLE: number = 5
  private frameListener: GazeFrameListener | null = null
  private errorListener: GazeCameraErrorListener | null = null
  private cameraInput: camera.CameraInput | null = null
  private captureSession: camera.CaptureSession | null = null
  private previewOutput: camera.PreviewOutput | null = null
  private receiver: image.ImageReceiver | null = null
  private frameWidth: number = 0
  private frameHeight: number = 0
  // CoreVisionKit's detector is shared. Finish old setup, frame work and
  // release before another activation can initialize it.
  private static pipelineTail: Promise<void> = Promise.resolve()
  private canDeliver: GazeCameraAdmission | null = null
  private frameTask: Promise<void> | null = null
  private firstFrameLogged: boolean = false
  private frameLayoutLogged: boolean = false
  private frameErrorLogged: boolean = false
  /** Remaining frames of the startup direction probe; locked once <= 0. */
  private probeRemaining: number = 0
  private probeHits: number[] = [0, 0, 0, 0]
  /** Locked clockwise rotation applied before detection; -1 while probing. */
  private rotationDegrees: number = -1

  onFrame(listener: GazeFrameListener): void {
    this.frameListener = listener
  }

  onError(listener: GazeCameraErrorListener): void {
    this.errorListener = listener
  }

  private static enqueue(action: () => Promise<boolean>): Promise<boolean> {
    const result = GazeCameraService.pipelineTail.then(action)
    GazeCameraService.pipelineTail = result.then((): void => {}, (): void => {})
    return result
  }

  static waitForPendingOperations(): Promise<void> {
    return GazeCameraService.pipelineTail
  }

  start(context: common.UIAbilityContext, admitted: GazeCameraAdmission): Promise<boolean> {
    return GazeCameraService.enqueue(async (): Promise<boolean> => {
      if (!admitted()) return false
      return await this.startInternal(context, admitted)
    })
  }

  async stop(): Promise<void> {
    this.canDeliver = null
    await GazeCameraService.enqueue(async (): Promise<boolean> => {
      if (this.receiver !== null) await this.releasePipeline()
      return true
    })
  }

  private reportError(message: string): void {
    if (this.errorListener !== null) {
      this.errorListener(message)
    }
  }

  private async startInternal(context: common.UIAbilityContext, admitted: GazeCameraAdmission): Promise<boolean> {
    let receiver: image.ImageReceiver | null = null
    let input: camera.CameraInput | null = null
    let session: camera.CaptureSession | null = null
    let preview: camera.PreviewOutput | null = null
    let detectorReady: boolean = false
    let published: boolean = false
    try {
      const manager: camera.CameraManager = camera.getCameraManager(context)
      const devices: Array<camera.CameraDevice> = manager.getSupportedCameras()
      let frontDevice: camera.CameraDevice | undefined = undefined
      for (const device of devices) {
        if (device.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
          frontDevice = device
          break
        }
      }
      if (frontDevice === undefined) {
        this.reportError('no_front_camera')
        return false
      }
      const front: camera.CameraDevice = frontDevice
      const capability: camera.CameraOutputCapability = manager.getSupportedOutputCapability(front)
      let profile: camera.Profile | undefined = undefined
      for (const candidate of capability.previewProfiles) {
        if (profile === undefined ||
          candidate.size.width * candidate.size.height < profile.size.width * profile.size.height) {
          profile = candidate
        }
      }
      if (profile === undefined) {
        this.reportError('no_preview_profile')
        return false
      }
      DiagnosticLogger.info('reader', 'gaze_camera_profile',
        `front=${front.cameraPosition} profile=${profile.size.width}x${profile.size.height} format=${profile.format}`)
      try {
        detectorReady = await faceDetector.init()
        if (!admitted()) return false
        if (!detectorReady) {
          DiagnosticLogger.warn('reader', 'gaze_detector_init_failed', 'faceDetector.init returned false')
          this.reportError('detector_init_failed')
          return false
        }
      } catch (error) {
        const err = error as BusinessError
        DiagnosticLogger.error('reader', 'gaze_detector_init_threw',
          `code=${err.code} name=${err.name} message=${err.message}`)
        if (admitted()) this.reportError(`detector_init_${err.code}`)
        return false
      }
      DiagnosticLogger.info('reader', 'gaze_camera_step', 'detector_ready')
      const width: number = profile.size.width
      const height: number = profile.size.height
      receiver = image.createImageReceiver(width, height, image.ImageFormat.JPEG, 2)
      const surfaceId: string = await receiver.getReceivingSurfaceId()
      if (!admitted()) return false
      DiagnosticLogger.info('reader', 'gaze_camera_step', `receiver_created surface=${surfaceId.length > 0}`)
      const frameReceiver = receiver
      receiver.on('imageArrival', () => {
        if (this.receiver === frameReceiver) this.scheduleProcessFrame()
      })
      input = manager.createCameraInput(front)
      await input.open()
      if (!admitted()) return false
      DiagnosticLogger.info('reader', 'gaze_camera_step', 'camera_opened')
      session = manager.createCaptureSession()
      session.beginConfig()
      session.addInput(input)
      preview = manager.createPreviewOutput(profile, surfaceId)
      DiagnosticLogger.info('reader', 'gaze_camera_step', 'preview_output_created')
      session.addOutput(preview)
      await session.commitConfig()
      if (!admitted()) return false
      DiagnosticLogger.info('reader', 'gaze_camera_step', 'config_committed')
      await session.start()
      if (!admitted()) return false
      DiagnosticLogger.info('reader', 'gaze_camera_step', 'session_started')
      this.cameraInput = input
      this.captureSession = session
      this.previewOutput = preview
      this.receiver = receiver
      this.frameWidth = width
      this.frameHeight = height
      this.firstFrameLogged = false
      this.frameLayoutLogged = false
      this.frameErrorLogged = false
      this.probeHits = [0, 0, 0, 0]
      this.probeRemaining =
        GazeCameraService.PROBE_ANGLES.length * GazeCameraService.PROBE_FRAMES_PER_ANGLE
      this.rotationDegrees = -1
      this.canDeliver = admitted
      published = true
      return true
    } catch (error) {
      const err = error as BusinessError
      DiagnosticLogger.error('reader', 'gaze_camera_start_failed',
        `code=${err.code} name=${err.name} message=${err.message}`)
      if (admitted()) this.reportError(`camera_start_${err.code}`)
      return false
    } finally {
      if (!published) {
        await GazeCameraService.releaseSessionPieces(session, preview, input, receiver, detectorReady, null)
      }
    }
  }

  private static async releaseSessionPieces(session: camera.CaptureSession | null,
    preview: camera.PreviewOutput | null, input: camera.CameraInput | null,
    receiver: image.ImageReceiver | null, detectorReady: boolean, frame: Promise<void> | null): Promise<void> {
    if (session !== null) {
      await session.stop().catch((): void => {})
    }
    if (frame !== null) await frame.catch((): void => {})
    if (preview !== null) {
      await preview.release().catch((): void => {})
    }
    if (session !== null) {
      await session.release().catch((): void => {})
    }
    if (input !== null) {
      await input.close().catch((): void => {})
    }
    if (receiver !== null) {
      await receiver.release().catch((): void => {})
    }
    if (detectorReady) await faceDetector.release().catch((): void => {})
  }

  private async releasePipeline(): Promise<void> {
    const session = this.captureSession
    const preview = this.previewOutput
    const input = this.cameraInput
    const receiver = this.receiver
    this.captureSession = null
    this.previewOutput = null
    this.cameraInput = null
    this.receiver = null
    await GazeCameraService.releaseSessionPieces(session, preview, input, receiver, true, this.frameTask)
  }

  private scheduleProcessFrame(): void {
    const receiver = this.receiver
    const admitted = this.canDeliver
    if (receiver === null || admitted === null || !admitted() || this.frameTask !== null) return
    this.frameTask = this.processLatestFrame(receiver, admitted).finally((): void => {
      this.frameTask = null
    }).catch((): void => {})
  }

  private async processLatestFrame(receiver: image.ImageReceiver, admitted: GazeCameraAdmission): Promise<void> {
    let frameImage: image.Image | null = null
    let pixelMap: image.PixelMap | null = null
    try {
      frameImage = await receiver.readLatestImage()
      if (!admitted()) return
      if (!this.firstFrameLogged) {
        this.firstFrameLogged = true
        DiagnosticLogger.info('reader', 'gaze_first_frame', `size=${this.frameWidth}x${this.frameHeight}`)
      }
      const comp: image.Component = await frameImage.getComponent(image.ComponentType.JPEG)
      if (!admitted()) return
      if (!this.frameLayoutLogged) {
        this.frameLayoutLogged = true
        const expected: number = this.frameWidth * this.frameHeight * 3 / 2
        DiagnosticLogger.info('reader', 'gaze_frame_layout',
          `len=${comp.byteBuffer.byteLength} rowStride=${comp.rowStride} expected=${expected}`)
      }
      const nv21: Uint8Array = GazeCameraService.extractNv21(comp, this.frameWidth, this.frameHeight)
      const options: image.InitializationOptions = {
        size: { width: this.frameWidth, height: this.frameHeight },
        srcPixelFormat: image.PixelMapFormat.NV21,
        pixelFormat: image.PixelMapFormat.RGBA_8888
      }
      pixelMap = await image.createPixelMap(nv21.buffer, options)
      if (!admitted()) return
      const probing: boolean = this.probeRemaining > 0
      let probeIndex: number = -1
      if (probing) {
        probeIndex = (GazeCameraService.PROBE_ANGLES.length * GazeCameraService.PROBE_FRAMES_PER_ANGLE
          - this.probeRemaining) % GazeCameraService.PROBE_ANGLES.length
        if (GazeCameraService.PROBE_ANGLES[probeIndex] > 0) {
          await pixelMap.rotate(GazeCameraService.PROBE_ANGLES[probeIndex])
        }
      } else if (this.rotationDegrees > 0) {
        await pixelMap.rotate(this.rotationDegrees)
      }
      if (!admitted()) return
      // The permission text promises in-memory analysis. Never pack a
      // camera frame into a file, including rotation probes.
      const visionInfo: faceDetector.VisionInfo = { pixelMap: pixelMap }
      const faces: Array<faceDetector.Face> = await faceDetector.detect(visionInfo)
      if (!admitted()) return
      if (probing) {
        if (faces.length > 0) {
          this.probeHits[probeIndex] += 1
        }
        this.probeRemaining -= 1
        if (this.probeRemaining <= 0) {
          let bestIndex: number = 0
          let bestHits: number = -1
          for (let i: number = 0; i < this.probeHits.length; i++) {
            if (this.probeHits[i] > bestHits) {
              bestHits = this.probeHits[i]
              bestIndex = i
            }
          }
          this.rotationDegrees = GazeCameraService.PROBE_ANGLES[bestIndex]
          DiagnosticLogger.info('reader', 'gaze_direction_locked',
            `angle=${this.rotationDegrees} hits=[${this.probeHits.join(',')}]`)
        }
        // Probe frames carry an unstable orientation; do not feed the engine.
        if (this.frameListener !== null) {
          this.frameListener(null)
        }
        return
      }
      const sample: GazeSample | null = GazeCameraService.pickFace(faces)
      if (this.frameListener !== null) {
        this.frameListener(sample)
      }
    } catch (error) {
      if (!admitted()) return
      this.frameListener?.(null)
      if (!this.frameErrorLogged) {
        this.frameErrorLogged = true
        const err = error as BusinessError
        DiagnosticLogger.error('reader', 'gaze_frame_process_failed',
          `code=${err.code} name=${err.name} message=${err.message}`)
      }
    } finally {
      if (pixelMap !== null) {
        await pixelMap.release().catch((): void => {})
      }
      if (frameImage !== null) {
        await frameImage.release().catch((): void => {})
      }
    }
  }

  /**
   * The 1003 preview stream delivers a compact NV21 frame (Y plane followed by
   * interleaved VU). The component buffer may carry trailing padding, and Y
   * rows may be padded when rowStride exceeds the frame width, so both cases
   * are normalized into one exact-size NV21 buffer.
   */
  private static extractNv21(comp: image.Component, width: number, height: number): Uint8Array {
    const src: Uint8Array = new Uint8Array(comp.byteBuffer)
    const ySize: number = width * height
    const total: number = ySize + (ySize >> 1)
    const yStride: number = comp.rowStride > 0 ? comp.rowStride : width
    if (yStride === width && src.length >= total) {
      const nv21: Uint8Array = new Uint8Array(total)
      nv21.set(src.subarray(0, total))
      return nv21
    }
    const nv21: Uint8Array = new Uint8Array(total)
    for (let row: number = 0; row < height; row++) {
      const srcStart: number = row * yStride
      nv21.set(src.subarray(srcStart, srcStart + width), row * width)
    }
    const chromaHeight: number = height >> 1
    for (let row: number = 0; row < chromaHeight; row++) {
      const srcStart: number = yStride * height + row * yStride
      nv21.set(src.subarray(srcStart, srcStart + width), ySize + row * width)
    }
    return nv21
  }

  /** Reduces the detection result to one sample built from the largest face. */
  private static pickFace(faces: Array<faceDetector.Face>): GazeSample | null {
    let best: faceDetector.Face | null = null
    let bestArea: number = 0
    for (const face of faces) {
      const area: number = face.rect.width * face.rect.height
      if (area > bestArea) {
        bestArea = area
        best = face
      }
    }
    if (best === null) {
      return null
    }
    const leftEyeY: number = best.points[0].y
    const rightEyeY: number = best.points[1].y
    const eyeCenterY: number =
      ((leftEyeY + rightEyeY) / 2 - best.rect.top) / Math.max(1, best.rect.height)
    return {
      pitch: best.pose.pitch,
      eyeCenterY: eyeCenterY,
      probability: best.probability,
      timestamp: Date.now()
    }
  }
}
