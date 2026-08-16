import { RemixIcon } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

const SHARE_SHEET_ENTER_MS: number = 260;
const SHARE_SHEET_EXIT_MS: number = 200;
const SHARE_SHEET_OFFSCREEN_Y: number = 520;

export class ShareSheetTarget {
  id: string;
  label: string;
  glyph: string;
  backgroundColor: string;
  iconColor: string;
  iconSize: number;
  xiaohongshu: boolean;

  constructor(id: string, label: string, glyph: string, backgroundColor: string,
    iconColor: string, iconSize: number = 27, xiaohongshu: boolean = false) {
    this.id = id;
    this.label = label;
    this.glyph = glyph;
    this.backgroundColor = backgroundColor;
    this.iconColor = iconColor;
    this.iconSize = iconSize;
    this.xiaohongshu = xiaohongshu;
  }
}

@Component
export struct ShareBottomSheet {
  @Prop targets: ShareSheetTarget[] = [];
  @Prop safeAreaBottom: number = 0;
  onDismiss: () => void = () => {};
  onSelect: (id: string) => void = () => {};
  @State private presented: boolean = false;
  private closing: boolean = false;
  private enterTimer: number = -1;
  private exitTimer: number = -1;

  aboutToAppear(): void {
    this.enterTimer = setTimeout(() => {
      this.enterTimer = -1;
      if (this.closing) return;
      animateTo({ duration: SHARE_SHEET_ENTER_MS, curve: Curve.EaseOut }, () => {
        this.presented = true;
      });
    }, 0);
  }

  aboutToDisappear(): void {
    if (this.enterTimer >= 0) clearTimeout(this.enterTimer);
    if (this.exitTimer >= 0) clearTimeout(this.exitTimer);
  }

  private close(afterClose: () => void): void {
    if (this.closing) return;
    this.closing = true;
    if (this.enterTimer >= 0) {
      clearTimeout(this.enterTimer);
      this.enterTimer = -1;
    }
    animateTo({ duration: SHARE_SHEET_EXIT_MS, curve: Curve.EaseIn }, () => {
      this.presented = false;
    });
    this.exitTimer = setTimeout(() => afterClose(), SHARE_SHEET_EXIT_MS);
  }

  @Builder
  private shareTarget(target: ShareSheetTarget) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (target.xiaohongshu) {
          Image($r('app.media.xiaohongshu_white'))
            .width(32)
            .height(32)
            .objectFit(ImageFit.Contain)
        } else {
          RemixIcon({ glyph: target.glyph, iconSize: target.iconSize, color: target.iconColor })
        }
      }
        .width(56)
        .height(56)
        .backgroundColor(target.backgroundColor)
        .borderRadius(28)
      Text(target.label)
        .fontSize(14)
        .fontColor(Theme.SECONDARY)
        .fontWeight(FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(22)
        .margin({ top: 7 })
    }
      .height(85)
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start)
      .onClick(() => this.close(() => this.onSelect(target.id)))
  }

  @Builder
  private targetRow(targets: ShareSheetTarget[]) {
    Grid() {
      ForEach(targets, (target: ShareSheetTarget) => {
        GridItem() { this.shareTarget(target) }
      }, (target: ShareSheetTarget) => target.id)
    }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(0)
      .rowsGap(0)
      .width('100%')
      .height(85)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#61000000')
        .opacity(this.presented ? 1 : 0)
        .onClick(() => this.close(() => this.onDismiss()))
      Column() {
        this.targetRow(this.targets.slice(0, 4))
        if (this.targets.length > 4) {
          Divider()
            .strokeWidth(1)
            .color('#14000000')
            // Three column intervals plus one 56vp icon diameter aligns the
            // divider with the outer edges of the first and fourth icons.
            .width('calc(75% + 56vp)')
            .margin({ top: 16, bottom: 16 })
          this.targetRow(this.targets.slice(4))
        }
      }
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 12 + Math.max(0, this.safeAreaBottom) })
        .backgroundColor(Color.White)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .clip(true)
        .translate({ y: this.presented ? 0 : SHARE_SHEET_OFFSCREEN_Y })
    }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
