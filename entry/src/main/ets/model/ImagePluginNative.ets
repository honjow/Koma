import nativeRuntime from 'libkoma_source_runtime.so'
import { NativeImageProcessorResult } from './ImageProcessingPlugins'

interface ImagePluginNativeModule {
  inspectImageProcessor(module: Uint8Array, sourceOwned?: boolean): string
  runImageProcessor(module: Uint8Array, pixels: ArrayBuffer, width: number, height: number,
    configuration: string, sourceOwned?: boolean): NativeImageProcessorResult
}
export const imagePluginNative = nativeRuntime as ImagePluginNativeModule
