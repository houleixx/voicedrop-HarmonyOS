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
  blockedAuthorCount: number = 0;

  @Builder
  private row(title: string, subtitle: string, onClick: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        Text(subtitle).fontSize(12).fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: Theme.FAINT })
    }
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .width('100%')
      .onClick(onClick)
  }

  @Builder
  private divider() {
    Divider()
      .strokeWidth(1)
      .color(Theme.BORDER)
      .margin({ left: 16, right: 16 })
  }

  build() {
    Column() {
      PageHeader({ title: '关于', onBack: this.onBack })
      Scroll() {
        Column() {
          Column() {
            this.row('隐私政策', '查看个人信息与权限处理说明', this.onPrivacy)
            this.divider()
            this.row('社区公约', '发布、举报与内容治理规则', () => {
              promptAction.showDialog({
                title: '社区公约',
                message: COMMUNITY_TERMS,
                buttons: [{ text: '好', color: '#D8593B' }]
              });
            })
            this.divider()
            this.row('已屏蔽用户', `${this.blockedAuthorCount} 人`, this.onBlockedAuthors)
            this.divider()
            this.row('联系我们 / 内容投诉', SUPPORT_EMAIL, this.onContact)
          }
            .backgroundColor(Theme.CARD)
            .borderRadius(12)
            .border({ width: 1, color: Theme.BORDER })
            .width('100%')
        }
          .padding({ left: 16, right: 16, top: 6, bottom: 28 })
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
