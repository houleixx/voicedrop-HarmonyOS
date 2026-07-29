import { CapturedPhoto } from '../data/PhotoService';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import {
  formatRecordingTime, waveBarFrac, waveBarHeight, waveBarColor, WAVEFORM_PATTERN
} from '../core/RecordingUi';

@Component
export struct RecordingSession {
  @Prop recordingSeconds: number = 0;
  @Prop activeLevel: number = 0;
  @Prop interviewActive: boolean = false;
  @Prop interviewStatus: string = '';
  @Prop capturedPhotos: CapturedPhoto[] = [];
  @Prop transitioning: boolean = false;
  @Prop showInterview: boolean = true;
  @Prop safeAreaTop: number = 0;
  @Prop safeAreaBottom: number = 0;

  onStop: () => void = () => {};
  onAddPhoto: () => void = () => {};
  onToggleInterview: () => void = () => {};
  onRemovePhoto: (photo: CapturedPhoto) => void = (_photo: CapturedPhoto) => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Circle().width(9).height(9).fill(Theme.ACCENT_STRONG)
            Text(this.interviewActive ? 'AI 采访中' : '正在录音')
              .fontSize(14).fontColor(Theme.SECONDARY).letterSpacing(2)
          }
          if (this.interviewActive && this.interviewStatus.length > 0) {
            Text(this.interviewStatus).fontSize(11).fontColor(Theme.FAINT).letterSpacing(1)
          }
        }
        .width('100%')
        .height(72)
        .padding({ top: 18 })
        .alignItems(HorizontalAlign.Center)

        Blank().layoutWeight(1)

        Column({ space: 30 }) {
          Text(formatRecordingTime(this.recordingSeconds))
            .fontSize(76).fontWeight(FontWeight.Lighter)
            .fontColor(Theme.INK)
            .fontFamily('monospace')
            .letterSpacing(1)

          Row({ space: 3 }) {
            ForEach(WAVEFORM_PATTERN, (base: number, i: number) => {
              Column()
                .width(3).height(waveBarHeight(waveBarFrac(base, this.activeLevel)))
                .backgroundColor(waveBarColor(waveBarFrac(base, this.activeLevel)))
                .borderRadius(2)
            }, (base: number, i: number) => `${i}`)
          }
          .height(46).alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Center)

        if (this.capturedPhotos.length > 0) {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.capturedPhotos, (photo: CapturedPhoto) => {
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(`file://${photo.localPath}`)
                    .width(74).height(74)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(12)
                  Button() {
                    RemixIcon({ glyph: RI.CLOSE, iconSize: 14, color: Theme.WHITE })
                  }
                  .width(25).height(25)
                  .padding(0)
                  .borderRadius(13)
                  .backgroundColor('#B82A2521')
                  .enabled(!this.transitioning)
                  .onClick(() => this.onRemovePhoto(photo))
                }
                .width(74).height(74)
              }, (photo: CapturedPhoto) => photo.key)
            }
            .padding({ left: 22, right: 22 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .height(74)
          .width('100%')
          .margin({ top: 24 })
        }

        Blank().layoutWeight(1)

        Row() {
          Column({ space: 7 }) {
            Stack({ alignContent: Alignment.Center }) {
              RemixIcon({
                glyph: RI.MIC,
                iconSize: 23,
                color: this.interviewActive ? '#B54708' : Theme.SECONDARY
              })
            }
            .width(54).height(54)
            .borderRadius(27)
            .backgroundColor(this.interviewActive ? Theme.AMBER_BG : Theme.CARD)
            .border({ width: 1, color: this.interviewActive ? '#F1D09A' : Theme.BORDER })
            Text('采访')
              .fontSize(11).letterSpacing(1.5)
              .fontColor(this.interviewActive ? '#B54708' : Theme.SECONDARY)
          }
          .width(92)
          .alignItems(HorizontalAlign.Center)
          .opacity(this.showInterview ? 1 : 0)
          .enabled(this.showInterview && !this.transitioning)
          .onClick(() => this.onToggleInterview())

          Column({ space: 7 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column()
                .width(66).height(66)
                .borderRadius(33)
                .backgroundColor(Theme.WHITE)
                .shadow({ radius: 8, color: '#33000000', offsetX: 0, offsetY: 0 })

              Column() {
                Blank().width(20).height(20).backgroundColor(Theme.WHITE).borderRadius(5)
              }
              .width(60).height(60).borderRadius(30)
              .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
              .backgroundColor(Theme.ACCENT_STRONG)
            }
            .width(82).height(82)
            .alignContent(Alignment.Center)
            Text('点击停止')
              .fontSize(11).letterSpacing(1)
              .fontColor(Theme.SECONDARY)
          }
          .width(112)
          .alignItems(HorizontalAlign.Center)
          .enabled(!this.transitioning)
          .onClick(() => this.onStop())

          Column({ space: 7 }) {
            Stack({ alignContent: Alignment.Center }) {
              RemixIcon({
                glyph: RI.IMAGE,
                iconSize: 23,
                color: Theme.SECONDARY
              })
            }
            .width(54).height(54)
            .borderRadius(27)
            .backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER })
            Text('拍照')
              .fontSize(11).letterSpacing(1.5)
              .fontColor(Theme.SECONDARY)
          }
          .width(92)
          .alignItems(HorizontalAlign.Center)
          .enabled(!this.transitioning)
          .onClick(() => this.onAddPhoto())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Top)
        .height(126)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.safeAreaTop, bottom: this.safeAreaBottom + 12 })
      .backgroundColor(Theme.BG)

      if (this.transitioning) {
        Column({ space: 18 }) {
          LoadingProgress()
            .width(52).height(52)
            .color(Theme.ACCENT_STRONG)
          Text('正在保存录音…')
            .fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(Theme.INK)
          Text('请稍候，不要退出应用')
            .fontSize(13)
            .fontColor(Theme.SECONDARY)
        }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#F5FAF6EF')
          .hitTestBehavior(HitTestMode.Block)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
