import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { appPreferences } from '../data/AppPreferences';
import { authStore } from '../data/AuthStore';
import { DeviceLinkCrypto } from '../data/DeviceLinkCrypto';
import { DeviceLinkStore } from '../data/DeviceLinkStore';
import { libraryStore } from '../data/LibraryStore';
import { PageHeader } from '../ui/PageHeader';

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
  @State private token: string = '';
  @State private ownCode: string = '------';
  @State private accountId: string = '';
  @State private linkPrefix: string = '';
  @State private linkCode: string = '';
  @State private linkPhase: string = 'prefix';
  @State private linkMessage: string = '';
  @State private deletingAccount: boolean = false;
  private linker?: DeviceLinkStore;

  aboutToAppear(): void {
    this.linker = new DeviceLinkStore((phase: string, message: string) => {
      this.linkPhase = phase; this.linkMessage = message;
      if (phase === 'done') { promptAction.showToast({ message: '账号迁移成功' }); this.onAccountChanged(); }
    });
    DeviceLinkCrypto.accountCode(authStore.anonymousBearer()).then((value: string) => this.ownCode = value).catch(() => {});
    DeviceLinkCrypto.accountId(authStore.anonymousBearer()).then((value: string) => this.accountId = value).catch(() => {});
  }

  private maskedToken(): string {
    const token: string = authStore.anonymousBearer();
    return token.length <= 16 ? token : `${token.substring(0, 10)}••••••${token.substring(token.length - 4)}`;
  }

  private async copyAccountValue(value: string, message: string): Promise<void> {
    if (value.length === 0) { promptAction.showToast({ message: '账户信息尚未加载' }); return; }
    await pasteboard.getSystemPasteboard().setData(pasteboard.createPlainTextData(value));
    promptAction.showToast({ message: message });
  }

  aboutToDisappear(): void { this.linker?.cancel(false); }

  build() {
    Column() {
      PageHeader({ title: '账号与设备', onBack: this.onBack })
      Scroll() {
        Column({ space: 16 }) {
          Text(this.loggedIn ? '已登录微信账号' : '当前使用匿名账号').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          Column({ space: 8 }) {
            Text('账户').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
            Text('在这台设备上自动生成，不需要用户名或密码。').fontSize(13).fontColor('#777777').width('100%')
            Row() {
              Column({ space: 3 }) { Text('你的 ID').fontSize(12).fontColor('#888888'); Text(this.accountId || '加载中…').fontSize(14).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Button('复制').fontSize(13).onClick(() => this.copyAccountValue(this.accountId, '账户 ID 已复制'))
            }.padding(12).backgroundColor('#F7F7F5').borderRadius(10).width('100%')
            Row() {
              Column({ space: 3 }) { Text('访问令牌').fontSize(12).fontColor('#888888'); Text(this.maskedToken()).fontSize(14) }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Button('复制').fontSize(13).onClick(() => this.copyAccountValue(authStore.anonymousBearer(), '访问令牌已复制'))
            }.padding(12).backgroundColor('#F7F7F5').borderRadius(10).width('100%')
          }.padding(16).backgroundColor(Color.White).borderRadius(12).width('100%').alignItems(HorizontalAlign.Start)
          Column() {
            Row() { Text('录音').fontSize(16).layoutWeight(1); Text(`${this.recordingCount} 条`).fontSize(14).fontColor('#777777') }.padding(14).width('100%')
            Row() { Text('成文').fontSize(16).layoutWeight(1); Text(`${this.articleCount} 篇`).fontSize(14).fontColor('#777777') }.padding(14).width('100%')
          }.backgroundColor(Color.White).borderRadius(12).width('100%')
          Text('匿名 Token 可在多台设备之间迁移全部录音和文章。请像密码一样妥善保管。').fontSize(14).lineHeight(22).fontColor('#666666').width('100%')
          Column({ space: 8 }) {
            Text('本机账号代码').fontSize(13).fontColor('#888888').width('100%')
            Text(this.ownCode).fontSize(28).fontWeight(FontWeight.Bold).letterSpacing(5).width('100%')
            Text('在新设备输入此代码；本机会显示一次性 4 位验证码。').fontSize(13).fontColor('#666666').width('100%')
          }.padding(16).backgroundColor(Color.White).borderRadius(12).width('100%').alignItems(HorizontalAlign.Start)
          Text('从另一台设备迁移账号').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
          if (this.linkPhase === 'prefix' || this.linkPhase === 'error') {
            TextInput({ text: this.linkPrefix, placeholder: '老设备上的 6 位账号代码' }).maxLength(6)
              .onChange((value: string) => this.linkPrefix = value.toUpperCase()).backgroundColor(Color.White)
            Button('查找账号').width('100%').onClick(async () => {
              try { await this.linker?.start(this.linkPrefix); } catch (error) { this.linkPhase = 'error'; this.linkMessage = String(error); }
            })
          } else if (this.linkPhase === 'code') {
            TextInput({ text: this.linkCode, placeholder: '老设备显示的 4 位验证码' }).type(InputType.Number).maxLength(4)
              .onChange((value: string) => this.linkCode = value).backgroundColor(Color.White)
            Button('验证并迁移').width('100%').onClick(async () => {
              try { await this.linker?.verify(this.linkCode); } catch (error) { this.linkPhase = 'error'; this.linkMessage = String(error); }
            })
          } else if (this.linkPhase === 'working') { LoadingProgress(); Text('正在进行端到端加密迁移…').fontColor('#666666') }
          else if (this.linkPhase === 'done') { Text('✓ 账号迁移成功').fontSize(17).fontColor('#16825D') }
          if (this.linkMessage.length > 0) Text(this.linkMessage).fontSize(13).fontColor(this.linkPhase === 'error' ? '#D92D20' : '#666666').width('100%')
          TextInput({ text: this.token, placeholder: '粘贴 anon_ 开头的 Token' }).onChange((value: string) => this.token = value).backgroundColor(Color.White)
          Button('导入 Token').width('100%').onClick(async () => {
            const ok: boolean = await authStore.adoptAnonymousToken(this.token.trim());
            promptAction.showToast({ message: ok ? '导入成功' : 'Token 格式不正确' });
            if (ok) this.onAccountChanged();
          })
          if (this.loggedIn) Button('退出微信账号').width('100%').backgroundColor('#D92D20').onClick(this.onWechatSignOut)
          else Button('用微信登录（同步设备 · 参与社区）').width('100%').backgroundColor('#16825D').onClick(this.onWechatLogin)
          Button(this.deletingAccount ? '正在永久删除…' : '永久删除账户').width('100%').enabled(!this.deletingAccount)
            .fontColor('#B42318').backgroundColor('#FEE4E2').onClick(async () => {
              const result = await promptAction.showDialog({
                title: '永久删除账户？',
                message: '将永久删除你的全部数据：云端录音、文章、照片、设置、社区分享和微信登录绑定。本操作不可恢复。',
                buttons: [{ text: '取消', color: '#666666' }, { text: '永久删除', color: '#D92D20' }]
              });
              if (result.index !== 1) return;
              this.deletingAccount = true;
              try {
                const deleted: boolean = await libraryStore.deleteAccount();
                if (!deleted) { promptAction.showToast({ message: '删除失败，请稍后再试' }); return; }
                await appPreferences.clearAccountQueues(this.recordingNames);
                await authStore.resetAnonymous();
                this.token = '';
                promptAction.showToast({ message: '账户已删除，已创建新的匿名空间' });
                this.onDeleted();
              } catch (error) { promptAction.showToast({ message: `删除失败：${String(error)}` }); }
              finally { this.deletingAccount = false; }
            })
          Text('永久删除云端与本机的账户关联数据，不可恢复。').fontSize(12).fontColor('#888888').width('100%')
        }.padding({ left: 16, right: 16, top: 6, bottom: 30 })
      }.layoutWeight(1).width('100%')
    }.height('100%')
  }
}
