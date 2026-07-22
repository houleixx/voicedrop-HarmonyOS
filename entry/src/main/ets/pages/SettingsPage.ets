import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

export type SettingsTarget = 'account' | 'usage' | 'style' | 'prompts' | 'wechat' | 'about';

@Component
export struct SettingsPage {
  onBack: () => void = () => {};
  onNavigate: (target: SettingsTarget) => void = () => {};
  onInvite: () => void = () => {};
  onAutoShareChange: (value: boolean) => void = () => {};
  onExport: () => void = () => {};
  wechatAuthenticated: boolean = false;
  autoShareCommunity: boolean = false;
  savingAutoShare: boolean = false;
  preparingInvite: boolean = false;
  exporting: boolean = false;

  @Builder
  private row(title: string, subtitle: string, target: SettingsTarget, glyph: string) {
    Row({ space: 12 }) {
      Row() { RemixIcon({ glyph: glyph, iconSize: 20, color: Theme.ACCENT }) }
        .width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(10)
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        Text(subtitle).fontSize(12).fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: Theme.FAINT })
    }.padding({ left: 16, right: 16, top: 13, bottom: 13 }).width('100%').onClick(() => this.onNavigate(target))
  }

  @Builder
  private divider() { Divider().strokeWidth(1).color(Theme.BORDER).margin({ left: 66 }) }

  @Builder
  private section(label: string) {
    Text(label).fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.FAINT)
      .width('100%').padding({ left: 4, bottom: 8 }).margin({ top: 10 })
  }

  build() {
    Column() {
      PageHeader({ title: '设置', onBack: this.onBack })
      Scroll() {
        Column({ space: 10 }) {
          Column() {
            this.row('账户', this.wechatAuthenticated ? '已登录微信账号' : '无需登录 · 匿名 ID 已保存在本机', 'account', RI.USER)
            this.divider()
            this.row('算力', '余额与消耗明细', 'usage', RI.FLASHLIGHT)
          }.backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER }).width('100%')
          Row({ space: 12 }) {
            Row() { RemixIcon({ glyph: RI.TEAM, iconSize: 20, color: Theme.AMBER }) }
              .width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor(Theme.AMBER_BG).borderRadius(10)
            Column({ space: 4 }) {
              Text('邀请好友').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              Text('生成专属邀请链接并通过系统分享').fontSize(12).fontColor(Theme.SECONDARY)
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: Theme.FAINT })
          }.padding({ left: 16, right: 16, top: 13, bottom: 13 }).backgroundColor(Theme.CARD).borderRadius(12)
            .border({ width: 1, color: Theme.BORDER }).width('100%')
            .enabled(!this.preparingInvite).onClick(this.onInvite)
          this.section('写作')
          Column() {
            this.row('名字与写作风格', '署名、称呼和成文时模仿的语气', 'style', RI.QUILL_PEN)
            this.divider()
            this.row('提示词', '自定义长按菜单里的每个动作', 'prompts', RI.MAGIC)
          }.backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER }).width('100%')
          this.section('发布')
          Column() {
            this.row('微信公众号', '成文一键推送到草稿箱', 'wechat', RI.WECHAT)
            this.divider()
            Row({ space: 12 }) {
              Row() { RemixIcon({ glyph: RI.TEAM, iconSize: 20, color: Theme.GREEN }) }
                .width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor(Theme.GREEN_BG).borderRadius(10)
              Column({ space: 4 }) {
                Text('自动分享到 VD 社区').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                Text('挖出新文章后自动发到社区').fontSize(12).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.autoShareCommunity }).enabled(!this.savingAutoShare)
                .selectedColor(Theme.ACCENT).onChange(this.onAutoShareChange)
            }.padding({ left: 16, right: 16, top: 13, bottom: 13 }).width('100%')
          }.backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER }).width('100%')
          this.section('其他')
          Column() {
            Row({ space: 12 }) {
              Row() { RemixIcon({ glyph: RI.DOWNLOAD, iconSize: 20, color: Theme.ACCENT }) }
                .width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(10)
              Column({ space: 4 }) {
                Text('导出数据').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                Text('所有录音、文章、字幕和图片打包下载').fontSize(12).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: Theme.FAINT })
            }.padding({ left: 16, right: 16, top: 13, bottom: 13 }).width('100%')
              .enabled(!this.exporting).onClick(this.onExport)
            this.divider()
            this.row('关于', '隐私 · 公约 · 屏蔽 · 联系', 'about', RI.INFORMATION)
          }.backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER }).width('100%')
        }.padding({ left: 16, right: 16, top: 0, bottom: 28 }).width('100%')
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.height('100%').backgroundColor(Theme.BG)
  }
}
