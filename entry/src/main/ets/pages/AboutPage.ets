import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import {
  COMMUNITY_TERMS,
  SUPPORT_EMAIL
} from '../core/CommunityTerms';

@Component
export struct AboutPage {
  onBack: () => void = () => {};
  onPrivacy: () => void = () => {};
  onBlockedAuthors: () => void = () => {};
  onContact: () => void = () => {};
  appVersion: string = '';
  @Link blockedAuthorCount: number;

  @Builder
  private row(title: string, subtitle: string, glyph: string, onClick: () => void) {
    Row({ space: 12 }) {
      Row() {
        RemixIcon({ glyph: glyph, iconSize: 21, color: Theme.ACCENT })
      }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Theme.ACCENT_SOFT)
        .borderRadius(11)
      Column({ space: 2 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .lineHeight(24)
          .letterSpacing(0)
          .fontColor(Theme.INK)
        Text(subtitle)
          .fontSize(13)
          .lineHeight(19)
          .letterSpacing(0)
          .fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 20, color: Theme.FAINT })
    }
      .constraintSize({ minHeight: 68 })
      .padding({ left: 16, right: 16, top: 11, bottom: 11 })
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(onClick)
  }

  @Builder
  private divider() {
    Divider()
      .strokeWidth(0.5)
      .color(Theme.BORDER)
      .margin({ left: 68, right: 16 })
  }

  build() {
    Column() {
      PageHeader({ title: '关于', onBack: this.onBack })
      Scroll() {
        Column() {
          Column() {
            this.row('隐私政策', '查看个人信息与权限处理说明', RI.FILE_TEXT, this.onPrivacy)
            this.divider()
            this.row('社区公约', '发布、举报与内容治理规则', RI.FLAG, () => {
              promptAction.showDialog({
                title: '社区公约',
                message: COMMUNITY_TERMS,
                buttons: [{ text: '好', color: '#D8593B' }]
              });
            })
            this.divider()
            this.row('已屏蔽用户', `${this.blockedAuthorCount} 人`, RI.USER, this.onBlockedAuthors)
            this.divider()
            this.row('联系我们 / 内容投诉', SUPPORT_EMAIL, RI.CHAT, this.onContact)
          }
            .backgroundColor(Theme.CARD)
            .borderRadius(14)
            .border({ width: 0.5, color: Theme.BORDER })
            .width('100%')
        }
          .padding({ left: 16, right: 16, top: 10, bottom: 32 })
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.BG)
  }
}
