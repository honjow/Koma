import nativeRuntime from 'libkoma_source_runtime.so'
import { NativeImageProcessorResult } from './ImageProcessingPlugins'

interface ImagePluginNativeModule {
  inspectImageProcessor(module: Uint8Array): string
  runImageProcessor(module: Uint8Array, pixels: ArrayBuffer, width: number, height: number,
    configuration: string): NativeImageProcessorResult
}
export const imagePluginNative = nativeRuntime as ImagePluginNativeModule
