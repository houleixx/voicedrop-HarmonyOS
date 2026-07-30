import { formatRecordingTime, waveBarFrac, waveBarHeight, waveBarColor, WAVEFORM_PATTERN } from '../core/RecordingUi';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct CommunityReplyRecordingDock {
  @Prop recordingSeconds: number = 0;
  @Prop activeLevel: number = 0;
  @Prop transitioning: boolean = false;
  @Prop safeAreaBottom: number = 0;

  onStop: () => void = () => {};

  build() {
    Column() {
      Divider().color('#E8DECF')
      Row() {
        Row({ space: 10 }) {
          Circle().width(8).height(8).fill('#FFB8B8')
          Text(formatRecordingTime(this.recordingSeconds))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.INK)
            .fontFamily('monospace')
        }

        Row({ space: 4 }) {
          ForEach(WAVEFORM_PATTERN.slice(0, 8), (base: number, index: number) => {
            Column()
              .width(3)
              .height(waveBarHeight(waveBarFrac(base, this.activeLevel)))
              .backgroundColor(waveBarColor(waveBarFrac(base, this.activeLevel)))
              .borderRadius(2)
          }, (_base: number, index: number) => `${index}`)
        }
          .height(38)
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.Center }) {
          Circle().width(68).height(68).fill('#18E5392E')
          Stack({ alignContent: Alignment.Center }) {
            Circle().width(56).height(56).fill(Theme.CARD)
              .stroke(Theme.BORDER).strokeWidth(1)
            if (this.transitioning) {
              LoadingProgress().width(26).height(26).color(Theme.ACCENT_STRONG)
            } else {
              Column().width(24).height(24).backgroundColor(Theme.ACCENT_STRONG).borderRadius(7)
            }
          }.width(56).height(56)
        }
          .width(68)
          .height(68)
          .enabled(!this.transitioning)
          .onClick(() => this.onStop())
      }
        .height(112 + this.safeAreaBottom)
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 + this.safeAreaBottom })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(Theme.CARD)
    }.width('100%')
  }
}
