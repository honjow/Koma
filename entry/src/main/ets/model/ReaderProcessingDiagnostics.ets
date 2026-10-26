/** The NextE processing logs use bounded owner hashes, never page/work identities. */
export function readerProcessingOwnerHash(value: string): string {
  const clean = (value || '').trim()
  if (clean.length === 0) return ''
  let hash = 2166136261
  for (let index = 0; index < clean.length; index += 1) {
    hash ^= clean.charCodeAt(index)
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return `${clean.length}:${hash.toString(16)}`
}

// Native workers throw fixed contract errors. Publish only this finite category;
// the arbitrary message remains subject to the existing diagnostics redactor.
export function readerSuperResolutionFailureCode(message: string): string {
  if (message === 'invalid RGBA dimensions or stride') return 'invalid_rgba_stride'
  if (message === 'RGBA buffer is smaller than stride times height') return 'short_rgba_buffer'
  if (message === 'invalid super-resolution argument type' || message === 'invalid MindSpore NNRT upscale argument type') return 'native_argument_type'
  if (message === 'failed to load ncnn param file') return 'ncnn_param_load'
  if (message === 'failed to load ncnn model file') return 'ncnn_model_load'
  if (message.startsWith('failed to build MindSpore NNRT model, status=')) return 'nnrt_model_build'
  if (message === 'MindSpore NNRT model has an unexpected input contract') return 'nnrt_input_contract'
  if (message === 'NNRT accelerator is unavailable') return 'nnrt_accelerator_unavailable'
  if (message.includes('Vulkan') && (message.startsWith('failed to ') || message.startsWith('super-resolution '))) return 'vulkan_processing'
  if (message === 'waifu2x rejected the input tile' || message === 'waifu2x failed to infer the output tile' || message === 'waifu2x returned an unexpected output shape') return 'waifu2x_inference'
  return 'unclassified'
}
