import { LengthMetrics, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { AccountIdentity } from '../core/AccountIdentity';
import { ClientReliability } from '../core/ClientReliability';
import { uploader } from '../audio/Uploader';
import { appPreferences } from '../data/AppPreferences';
import { authStore } from '../data/AuthStore';
import { libraryStore } from '../data/LibraryStore';
import { promptStore } from '../data/PromptStore';
import { PageHeader } from '../ui/PageHeader';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@CustomDialog
struct TokenImportDialog {
  controller?: CustomDialogController;
  onImport: (token: string) => Promise<boolean> = async () => false;
  onImported: () => void = () => {};
  @State private token: string = '';
  @State private importing: boolean = false;
  @State private closing: boolean = false;
  @State private sheetOffsetY: string = '0%';
  @State private sheetOpacity: number = 1;

  private async submit(): Promise<void> {
    if (this.importing || this.closing) return;
    this.importing = true;
    try {
      if (await this.onImport(this.token)) this.closeDownward(this.onImported);
    } finally {
      this.importing = false;
    }
  }

  private closeDownward(afterClose: () => void = () => {}): void {
    if (this.closing) return;
    this.closing = true;
    animateTo({
      duration: 200,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.controller?.close();
        afterClose();
      }
    }, () => {
      this.sheetOffsetY = '100%';
      this.sheetOpacity = 0.96;
    });
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('登录已有账号')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.INK)
          .layoutWeight(1)
        Row() {
          RemixIcon({ glyph: RI.CLOSE, iconSize: 24, color: Theme.INK })
        }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .enabled(!this.closing)
          .onClick(() => this.closeDownward())
      }.width('100%').alignItems(VerticalAlign.Center)
      Text('在另一台设备的「账户」页面复制“访问令牌”，粘贴到这里。访问令牌以 anon_ 开头；页面上显示的账户 ID 只用于识别，不能用来登录。')
        .fontSize(14).fontColor(Theme.SECONDARY).lineHeight(20).width('100%')
      Text('访问令牌')
        .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.FAINT).letterSpacing(1).width('100%')
      TextArea({ text: this.token, placeholder: 'anon_...' })
        .height(72)
        .defaultFocus(true)
        .fontSize(15)
        .fontColor(Theme.INK)
        .placeholderColor('#C9C6C1')
        .backgroundColor(Theme.BG)
        .border({ width: 1, color: '#E5DED2', radius: 9 })
        .borderRadius(9)
        .onChange((value: string) => this.token = value)
      Text('导入后，本机会切换到该令牌对应的云端空间。原本机令牌不会删除，请保存后再操作。')
        .fontSize(12).fontColor(Theme.FAINT).lineHeight(17).width('100%')
      Button(this.importing ? '正在导入…' : '导入')
        .height(44)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.WHITE)
        .backgroundColor(Theme.ACCENT_STRONG)
        .enabled(!this.importing)
        .onClick(() => this.submit())
    }
      .padding({ left: 18, right: 18, top: 4, bottom: 12 })
      .width('100%')
      .backgroundColor(Theme.CARD)
      .borderRadius({ topLeft: 28, topRight: 28 })
      .translate({ y: this.sheetOffsetY })
      .opacity(this.sheetOpacity)
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .combine(TransitionEffect.opacity(0.92))
        .animation({ duration: 260, curve: Curve.EaseOut }))
      .alignItems(HorizontalAlign.Start)
  }
}

@Component
export struct AccountPage {
  onBack: () => void = () => {};
  onDeleted: () => void = () => {};
  onWechatLogin: () => void = () => {};
  onWechatSignOut: () => void = () => {};
  onAccountChanged: () => void = () => {};
  @Prop loggedIn: boolean = false;
  recordingNames: string[] = [];
  recordingCount: number = 0;
  articleCount: number = 0;
  @State private accountId: string = '';
  @State private deletingAccount: boolean = false;
  private tokenImportDialog: CustomDialogController = new CustomDialogController({
    builder: TokenImportDialog({
      onImport: (token: string): Promise<boolean> => this.importToken(token),
      onImported: this.onAccountChanged
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Bottom,
    width: '100%',
    keyboardAvoidMode: KeyboardAvoidMode.DEFAULT,
    keyboardAvoidDistance: LengthMetrics.vp(0),
    maskColor: '#66000000',
    openAnimation: { duration: 260, curve: Curve.EaseOut },
    closeAnimation: { duration: 0 }
  });

  aboutToAppear(): void {
    this.refreshAccountIdentity();
  }

  private refreshAccountIdentity(): void {
    this.accountId = AccountIdentity.accountIdFromScope(authStore.storageScope());
  }

  private maskedToken(): string {
    return AccountIdentity.maskedToken(authStore.anonymousBearer());
  }

  private async copyAccountValue(value: string, message: string): Promise<void> {
    if (value.length === 0) {
      promptAction.showToast({ message: '账户信息尚未加载'});
      return;
    }
    await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(value));
    promptAction.showToast({ message: message});
  }

  private async importToken(token: string): Promise<boolean> {
    const previousBearer: string = authStore.bearer();
    const ok: boolean = await authStore.adoptAnonymousToken(token.trim());
    if (!ok) {
      promptAction.showToast({ message: '请粘贴以 anon_ 开头的访问令牌'});
      return false;
    }
    if (ClientReliability.accountIdentityChanged(previousBearer, authStore.bearer())) {
      await appPreferences.clearAccountQueues(this.recordingNames);
    }
    this.refreshAccountIdentity();
    promptAction.showToast({ message: '已切换到已有账号'});
    return true;
  }

  private async deleteAccount(): Promise<void> {
    const result = await promptAction.showDialog({
      title: '永久删除账户？',
      message: '将永久删除你的全部数据：云端录音、文章、照片、设置、社区分享和微信登录绑定，本机数据也会清空。此操作不可恢复。',
      buttons: [{ text: '取消', color: Theme.SECONDARY }, { text: '永久删除', color: Theme.ACCENT_STRONG }]
    });
    if (result.index !== 1) return;
    this.deletingAccount = true;
    try {
      const deleted: boolean = await libraryStore.deleteAccount();
      if (!deleted) {
        promptAction.showToast({ message: '删除失败，请稍后再试'});
        return;
      }
      uploader.clearLocalAccountFiles();
      await appPreferences.clearDeletedAccountState();
      await promptStore.clearLocalCache();
      await authStore.resetAnonymous();
      promptAction.showToast({ message: '账户已删除'});
      this.onDeleted();
    } catch (error) {
      promptAction.showToast({ message: `删除失败：${String(error)}`});
    } finally {
      this.deletingAccount = false;
    }
  }

  @Builder
  private section(label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.FAINT)
      .letterSpacing(1)
      .width('100%')
      .padding({ left: 4, bottom: 8 })
  }

  @Builder
  private cardDivider(top: number = 0, bottom: number = 0) {
    Divider()
      .strokeWidth(1)
      .color(Theme.DIVIDER)
      .margin({ top: top, bottom: bottom })
  }

  @Builder
  private keyField(label: string, value: string, copyValue: string, masked: boolean = false) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.FAINT)
        .letterSpacing(1)
        .width('100%')
      Row() {
        Text(value)
          .fontSize(masked ? 14 : 15)
          .fontColor(Theme.INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(AccountIdentity.valueEllipsisMode)
          .layoutWeight(1)
        Row() {
          RemixIcon({ glyph: RI.FILE_COPY, iconSize: 20, color: Theme.ACCENT_STRONG })
        }.width(46).height('100%').justifyContent(FlexAlign.Center)
      }
        .height(48)
        .width('100%')
        .padding({ left: 13, right: 4 })
        .backgroundColor(Theme.BG)
        .border({ width: 1, color: '#E5DED2', radius: 9 })
        .borderRadius(9)
        .margin({ top: 7, bottom: 16 })
        .onClick(() => this.copyAccountValue(copyValue, `${label}已复制`))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private identityCard() {
    Column() {
      Column({ space: 3 }) {
        Text('账户').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.INK).width('100%')
        Text('在这台设备上自动生成，不需要用户名或密码。')
          .fontSize(13).fontColor(Theme.SECONDARY).width('100%')
      }.alignItems(HorizontalAlign.Start)
      this.cardDivider(16, 16)
      this.keyField('你的 ID', this.accountId || '加载中…', this.accountId)
      this.keyField('访问令牌', this.maskedToken(), authStore.anonymousBearer(), true)
      this.cardDivider(0, 10)
      if (this.loggedIn) {
        Row() {
          RemixIcon({ glyph: RI.WECHAT, iconSize: 18, color: Theme.SECONDARY })
          Text('已用微信登录').fontSize(15).fontColor(Theme.SECONDARY).margin({ left: 9 }).layoutWeight(1)
          Text('退出登录').fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG)
            .height(28).onClick(this.onWechatSignOut)
        }.height(28).width('100%').alignItems(VerticalAlign.Center)
      } else {
        Row() {
          RemixIcon({ glyph: RI.WECHAT, iconSize: 18, color: Theme.ACCENT_STRONG })
          Text('用微信登录（同步设备 · 参与社区）')
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG).margin({ left: 9 })
        }.height(28).width('100%').alignItems(VerticalAlign.Center).onClick(this.onWechatLogin)
      }
      Row() {
        RemixIcon({ glyph: RI.LINK, iconSize: 18, color: Theme.ACCENT_STRONG })
        Text('登录已有账号')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT_STRONG).margin({ left: 10 })
      }.height(28).width('100%').alignItems(VerticalAlign.Center).margin({ top: 3 })
        .onClick(() => this.tokenImportDialog.open())
    }
      .padding(18)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: '#E5DED2', radius: 12 })
      .borderRadius(12)
  }

  @Builder
  private dataCard() {
    Column() {
      Row() {
        Text('录音').fontSize(16).fontColor(Theme.INK).layoutWeight(1)
        Text(`${this.recordingCount} 条`).fontSize(14).fontColor(Theme.SECONDARY)
      }.padding({ left: 15, right: 15, top: 14, bottom: 14 }).width('100%')
      this.cardDivider()
      Row() {
        Text('成文').fontSize(16).fontColor(Theme.INK).layoutWeight(1)
        Text(`${this.articleCount} 篇`).fontSize(14).fontColor(Theme.SECONDARY)
      }.padding({ left: 15, right: 15, top: 14, bottom: 14 }).width('100%')
    }
      .width('100%')
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: '#E5DED2', radius: 12 })
      .borderRadius(12)
  }

  @Builder
  private transferCard() {
    Column() {
      Row() {
        Text('云端空间').fontSize(16).fontColor(Theme.INK).layoutWeight(1)
        Text('已启用').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#2F9B68')
      }
        .padding({ left: 15, right: 15, top: 14, bottom: 14 })
        .width('100%')
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: '#E5DED2', radius: 12 })
        .borderRadius(12)
      Text('云端空间由访问令牌决定。换设备时导入同一个访问令牌，就会看到同一套录音、文章、写作风格和配置。')
        .fontSize(13)
        .fontColor(Theme.FAINT)
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .width('100%')
        .padding({ left: 4, right: 4, top: 10 })
    }.width('100%')
  }

  @Builder
  private deleteCard() {
    Column() {
      Row() {
        RemixIcon({ glyph: RI.DELETE, iconSize: 20, color: Theme.ACCENT_STRONG })
        Text(this.deletingAccount ? '正在永久删除…' : '删除账户')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ACCENT_STRONG)
          .margin({ left: 10 })
          .layoutWeight(1)
      }
        .padding({ left: 15, right: 15, top: 14, bottom: 14 })
        .width('100%')
        .enabled(!this.deletingAccount)
        .backgroundColor(Theme.CARD)
        .border({ width: 1, color: '#E5DED2', radius: 12 })
        .borderRadius(12)
        .onClick(() => this.deleteAccount())
      Text('永久删除云端与本机的全部数据（录音、文章、照片、设置、社区分享、微信登录绑定），不可恢复。')
        .fontSize(12)
        .fontColor(Theme.FAINT)
        .lineHeight(18)
        .width('100%')
        .padding({ left: 4, right: 4, top: 10 })
    }.width('100%')
  }

  build() {
    Column() {
      PageHeader({ title: '账户', onBack: this.onBack })
      Scroll() {
        Column() {
          this.identityCard()
          Blank().height(22)
          this.section('数据')
          this.dataCard()
          Blank().height(22)
          this.section('转移与同步')
          this.transferCard()
          Blank().height(22)
          this.section('账户管理')
          this.deleteCard()
        }.padding({ left: 16, right: 16, top: 6, bottom: 40 }).width('100%')
      }.layoutWeight(1).width('100%').scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
      .height('100%')
      .backgroundColor(Theme.BG)
  }
}
