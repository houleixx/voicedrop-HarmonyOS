import { promptAction } from '@kit.ArkUI';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';

export const SUPPORT_EMAIL: string = 'jianshuo@hotmail.com';
export const COMMUNITY_TERMS: string = `发布到 VD 社区，表示你同意以下社区公约：

• 你对自己发布的内容负责，并拥有发布它的权利。
• 严禁发布令人反感的内容，包括色情或露骨性内容、暴力血腥、仇恨或歧视、骚扰或欺凌、违法内容、自残等。VoiceDrop 对令人反感的内容和滥用行为零容忍。
• 违规内容一经举报将被立即下架，并在 24 小时内处理；屡次或严重违规的账号将被移除。
• 你可以随时举报不当内容、屏蔽不想看到的用户。

继续即表示你已阅读并同意本社区公约与最终用户许可协议（EULA）。如需联系或投诉内容，请发邮件至 ${SUPPORT_EMAIL}。`;

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
          Column({ space: 6 }) {
            Text('VoiceDrop').fontSize(28).fontWeight(FontWeight.Bold)
            Text(`动动嘴，把想法变成文章 · ${this.appVersion}`).fontSize(14).fontColor('#777777')
          }.padding({ top: 18, bottom: 18 }).width('100%')
          this.row('隐私政策', '查看个人信息与权限处理说明', this.onPrivacy)
          this.row('社区公约', '发布、举报与内容治理规则', () => {
            promptAction.showDialog({ title: '社区公约', message: COMMUNITY_TERMS, buttons: [{ text: '关闭', color: '#111111' }] });
          })
          this.row('已屏蔽用户', `${this.blockedAuthorCount} 人`, this.onBlockedAuthors)
          this.row('联系我们 / 内容投诉', SUPPORT_EMAIL, this.onContact)
        }.padding(16).width('100%')
      }.layoutWeight(1)
    }.height('100%')
  }
}
