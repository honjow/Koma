import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { ToriiWholePageLiveEvaluationReport, ToriiWholePageLiveEvaluationPageReport } from '../readerTranslation/services/ToriiWholePageLiveEvaluationService'
import { KomaModalScaffold } from './KomaModalScaffold'

/** Same original/result comparison as NextE, presented in Koma's existing modal shell. */
@ComponentV2
export struct KomaTranslationEvaluationContent {
  @Require @Param report: ToriiWholePageLiveEvaluationReport
  @Event onClose: () => void = () => {}

  private originalImage(index: number): Resource {
    return index === 0 ? $rawfile('comic_translation_live_eval_page_01.jpg') : $rawfile('comic_translation_live_eval_page_02.jpg')
  }

  @Builder
  private EvaluationImage(title: string, source: ResourceStr) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(title).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor($r('sys.color.font_secondary')).width('100%')
      Image(source).width('100%').aspectRatio(2 / 3).objectFit(ImageFit.Contain)
        .backgroundColor(Color.Black).borderRadius(ThemeConstants.LIST_ROW_RADIUS)
    }.width('100%')
  }

  build() {
    KomaModalScaffold({ title: AppStrings.get('comic_torii_live_evaluation_result_title'), onClose: () => { this.onClose() } }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(AppStrings.format('comic_torii_live_evaluation_summary', this.report.modelId,
          `${(this.report.elapsedMs() / 1000).toFixed(1)} s`, `${(this.report.totalArtifactBytes / 1024).toFixed(0)} KB`))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor($r('sys.color.font_secondary')).width('100%')
        ForEach(this.report.pages, (page: ToriiWholePageLiveEvaluationPageReport) => {
          Column({ space: ThemeConstants.SPACE_MD }) {
            Text(AppStrings.get('comic_torii_live_evaluation_page').replace('%d', `${page.pageIndex + 1}`))
              .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM).fontWeight(FontWeight.Medium).width('100%')
            this.EvaluationImage(AppStrings.get('comic_torii_live_evaluation_original'), this.originalImage(page.pageIndex))
            this.EvaluationImage(AppStrings.get('comic_torii_live_evaluation_translated'), `file://${page.artifactPath}`)
          }.padding(ThemeConstants.SPACE_MD).width('100%')
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(ThemeConstants.LIST_ROW_RADIUS)
        }, (page: ToriiWholePageLiveEvaluationPageReport): string => `${page.pageIndex}:${page.artifactHash}`)
      }.padding(ThemeConstants.SPACE_LG).width('100%')
    }
  }
}
