import { AppStrings } from '../i18n/AppStrings'

/** NextE's model names, shared by selection and current-model feedback. */
export function readerSuperResolutionModelLabel(model: string): string {
  if (model === 'systemCoreVision') return AppStrings.get('settings_reader_super_resolution_system')
  if (model === 'espcn2x') return AppStrings.get('settings_reader_super_resolution_espcn_2x')
  if (model === 'waifu2xPhotoNoise0_2x') return AppStrings.get('settings_reader_super_resolution_waifu2x_photo_noise0_2x')
  if (model === 'waifu2xArtNoise0_2x') return AppStrings.get('settings_reader_super_resolution_waifu2x_art_noise0_2x')
  if (model === 'waifu2xCunetNoise0_2x') return AppStrings.get('settings_reader_super_resolution_waifu2x_cunet_noise0_2x')
  if (model === 'realCuganSe2xConservative') return AppStrings.get('settings_reader_super_resolution_realcugan_se_2x_conservative')
  if (model === 'realEsrganX2plus') return AppStrings.get('settings_reader_super_resolution_realesrgan_x2plus')
  if (model === 'realEsrganAnimeVideoV3_2x') return AppStrings.get('settings_reader_super_resolution_realesrgan_animevideov3_2x')
  return AppStrings.get('settings_reader_super_resolution_model_not_selected')
}
