import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
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
        Text(title).fontSize(17)
        Text(subtitle).fontSize(13).fontColor('#888888')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: '#AAA59D' })
    }.padding(17).backgroundColor(Color.White).borderRadius(14).width('100%').onClick(onClick)
  }

  build() {
    Column() {
      PageHeader({ title: '关于', onBack: this.onBack })
      Scroll() {
        Column({ space: 10 }) {
          this.row('隐私政策', '查看个人信息与权限处理说明', this.onPrivacy)
          this.row('社区公约', '发布、举报与内容治理规则', () => {
            promptAction.showDialog({
              title: '社区公约',
              message: COMMUNITY_TERMS,
              buttons: [{ text: '好', color: '#D8593B' }]
            });
          })
          this.row('已屏蔽用户', `${this.blockedAuthorCount} 人`, this.onBlockedAuthors)
          this.row('联系我们 / 内容投诉', SUPPORT_EMAIL, this.onContact)
        }
          .padding({ left: 16, right: 16, top: 6, bottom: 16 })
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: false })
    }.height('100%')
  }
}
