/**
 * Bottom overlay indicator for the gaze page turn feature.
 *
 * Renders a compact status pill above the reader's bottom edge while gaze
 * tracking runs: a calibration hint, an "armed" hint once the gaze reaches
 * the lower third of the page (one glance up turns the page), or a short
 * failure hint when the camera is unavailable. Purely informational - it
 * never intercepts touches and owns no state of its own.
 */
import { GazePhase } from './GazePageTurnEngine'
import { GazeTurnUiState } from './GazePageTurnController'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

const GAZE_HINT_BACKGROUND: ResourceColor = '#B311100F'

@ComponentV2
export struct GazePageTurnIndicator {
  @Param state: GazeTurnUiState = {
    tracking: false, phase: GazePhase.CALIBRATING, errorMessage: null
  }
  private hintKey(): string | null {
    if (!this.state.tracking) {
      return this.state.errorMessage !== null ? 'reader_eye_gaze_camera_unavailable' : null
    }
    if (this.state.phase === GazePhase.CALIBRATING || this.state.phase === GazePhase.LOST) {
      return 'reader_eye_gaze_calibrating'
    }
    if (this.state.phase === GazePhase.ARMED) {
      return 'reader_eye_gaze_armed_hint'
    }
    return null
  }

  build() {
    if (this.state.tracking || this.state.errorMessage !== null) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        if (this.hintKey() !== null) {
          Text(AppStrings.get(this.hintKey() ?? ''))
            .fontSize(11)
            .fontColor(this.state.phase === GazePhase.ARMED && this.state.tracking
              ? ThemeConstants.READER_ACCENT_LIGHT : Color.White)
            .maxLines(1)
        }
        if (this.state.tracking && this.hintKey() === null) {
          Row()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(ThemeConstants.READER_ACCENT)
        }
      }
      .alignItems(HorizontalAlign.Center)
      .padding({
        left: ThemeConstants.SPACE_MD,
        right: ThemeConstants.SPACE_MD,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS + 2
      })
      .borderRadius(14)
      .backgroundColor(GAZE_HINT_BACKGROUND)
      .id('koma-eye-gaze-status')
      .hitTestBehavior(HitTestMode.None)
    }
  }
}
