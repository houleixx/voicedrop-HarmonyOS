import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { settingsStore, StyleSettings } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@CustomDialog
struct NameEditorDialog {
  controller?: CustomDialogController;
  initialName: () => string = () => '';
  onSave: (name: string) => Promise<boolean> = async () => false;
  @State private name: string = '';
  @State private saving: boolean = false;

  aboutToAppear(): void {
    this.name = this.initialName();
  }

  private async submit(): Promise<void> {
    if (this.saving) return;
    this.saving = true;
    const nextName: string = this.name.trim().substring(0, 20);
    try {
      if (await this.onSave(nextName)) this.controller?.close();
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Blank().width(44)
        Text('名字')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        Button({ type: ButtonType.Normal }) {
          RemixIcon({ glyph: RI.CLOSE, iconSize: 24, color: Theme.SECONDARY })
        }
          .width(44)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .enabled(!this.saving)
          .onClick(() => this.controller?.close())
      }
        .height(56)
        .padding({ left: 8, right: 8 })
        .width('100%')
        .alignItems(VerticalAlign.Center)
      Divider().strokeWidth(1).color(Theme.DIVIDER)
      Column({ space: 10 }) {
        TextInput({ text: this.name, placeholder: '你的名字' })
          .height(54)
          .defaultFocus(true)
          .fontSize(17)
          .fontColor(Theme.INK)
          .placeholderColor(Theme.FAINT)
          .padding({ left: 14, right: 14 })
          .backgroundColor('#FFF7F2EC')
          .borderRadius(14)
          .enabled(!this.saving)
          .onChange((value: string) => this.name = value.substring(0, 20))
          .onSubmit(() => this.submit())
        Text('这个名字会出现在文章署名，以及挖文章时对你的称呼。随时可改。')
          .fontSize(13)
          .fontColor(Theme.SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Button(this.saving ? '保存中…' : '完成')
          .height(54)
          .width('100%')
          .margin({ top: 8 })
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.WHITE)
          .backgroundColor(this.saving ? '#C2B9A8' : Theme.ACCENT)
          .borderRadius(12)
          .enabled(!this.saving)
          .onClick(() => this.submit())
      }
        .padding({ left: 18, right: 18, top: 12, bottom: 16 })
        .width('100%')
        .alignItems(HorizontalAlign.Start)
    }
      .width('100%')
      .backgroundColor(Theme.CARD)
      .borderRadius({ topLeft: 26, topRight: 26 })
      .alignItems(HorizontalAlign.Start)
  }
}

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
  @State private currentName: string = '';
  private nameEditorDialog: CustomDialogController = new CustomDialogController({
    builder: NameEditorDialog({
      initialName: (): string => this.currentName,
      onSave: (name: string): Promise<boolean> => this.saveName(name)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Bottom,
    width: '100%',
    keyboardAvoidMode: KeyboardAvoidMode.DEFAULT,
    keyboardAvoidDistance: LengthMetrics.vp(0),
    maskColor: '#66000000',
    openAnimation: { duration: 240, curve: Curve.EaseOut },
    closeAnimation: { duration: 180, curve: Curve.EaseIn }
  });

  aboutToAppear(): void {
    this.loadName();
  }

  private async loadName(): Promise<void> {
    try {
      const settings: StyleSettings = await settingsStore.loadStyle();
      this.currentName = settings.name ?? '';
    } catch (_) {}
  }

  private async openNameEditor(): Promise<void> {
    await this.loadName();
    this.nameEditorDialog.open();
  }

  private async saveName(name: string): Promise<boolean> {
    try {
      if (!await settingsStore.saveName(name)) {
        promptAction.showToast({ message: '名字保存失败，请重试' });
        return false;
      }
      this.currentName = name;
      promptAction.showToast({ message: '名字已保存' });
      return true;
    } catch (_) {
      promptAction.showToast({ message: '名字保存失败，请重试' });
      return false;
    }
  }

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
  private nameRow() {
    Row({ space: 12 }) {
      Row() { RemixIcon({ glyph: RI.USER, iconSize: 20, color: Theme.ACCENT }) }
        .width(38).height(38).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(10)
      Column({ space: 4 }) {
        Text('名字').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
        Text('署名和挖文章时对你的称呼').fontSize(12).fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.currentName.length > 0) {
        Text(this.currentName)
          .fontSize(15)
          .fontColor(Theme.SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 96 })
      }
      RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 23, color: Theme.FAINT })
    }
      .padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .width('100%')
      .onClick(() => this.openNameEditor())
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
            this.nameRow()
            this.divider()
            this.row('写作风格', '成文时模仿这套语气', 'style', RI.QUILL_PEN)
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
        }.padding({ left: 16, right: 16, top: 6, bottom: 28 }).width('100%')
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.height('100%').backgroundColor(Theme.BG)
  }
}
