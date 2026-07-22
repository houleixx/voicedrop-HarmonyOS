import { promptAction } from '@kit.ArkUI';
import { settingsStore, StyleHistory, StyleSettings, StyleVersion } from '../data/SettingsStore';
import { PageHeader } from '../ui/PageHeader';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';

@Component
export struct StyleSettingsPage {
  onBack: () => void = () => {};
  @State private name: string = '';
  @State private style: string = '';
  @State private saving: boolean = false;
  @State private history: StyleHistory = new StyleHistory();
  @State private selectedStyles: number[] = [];

  aboutToAppear(): void {
    Promise.all([settingsStore.loadStyle(), settingsStore.loadStyleHistory()])
      .then((values: [StyleSettings, StyleHistory]) => {
        this.name = values[0].name ?? '';
        this.style = values[0].style ?? '';
        this.selectedStyles = values[0].styles ?? [];
        this.history = values[1];
      });
  }

  private toggleStyleVersion(version: number): void {
    const index: number = this.selectedStyles.indexOf(version);
    if (index >= 0) this.selectedStyles.splice(index, 1);
    else if (this.selectedStyles.length < 3) this.selectedStyles.push(version);
    else promptAction.showToast({ message: '最多同时选择 3 个文风版本' });
    this.selectedStyles = this.selectedStyles.slice();
  }

  build() {
    Column() {
      PageHeader({ title: '写作文风', onBack: this.onBack })
      Scroll() {
        Column({ space: 16 }) {
          Text('你的名字').fontSize(15).fontColor(Theme.SECONDARY).width('100%')
          TextInput({ text: this.name, placeholder: '文章署名' }).onChange((value: string) => this.name = value)
            .backgroundColor(Theme.CARD).border({ width: 1, color: Theme.BORDER })
          Text('个人文风').fontSize(15).fontColor(Theme.SECONDARY).width('100%')
          TextArea({ text: this.style, placeholder: '描述你希望文章使用的语气、结构和表达习惯' })
            .onChange((value: string) => this.style = value).height(260).backgroundColor(Theme.CARD)
            .border({ width: 1, color: Theme.BORDER })
          Button(this.saving ? '保存中…' : '保存').width('100%').height(50).backgroundColor(Theme.ACCENT)
            .enabled(!this.saving).onClick(async () => {
            this.saving = true;
            const ok: boolean = await settingsStore.saveName(this.name) && await settingsStore.saveStyle(this.style);
            this.saving = false;
            promptAction.showToast({ message: ok ? '已保存' : '保存失败' });
          })
          if (this.history.versions.length > 0) {
            Text('历史文风').fontSize(18).fontWeight(FontWeight.Bold).margin({ top: 18 }).width('100%')
            Text('可切换当前版本；勾选 2–3 个版本可让新录音并行生成多种文风。').fontSize(13).lineHeight(20).fontColor('#777777').width('100%')
            ForEach(this.history.versions.slice().reverse(), (version: StyleVersion) => {
              Row({ space: 10 }) {
                Toggle({ type: ToggleType.Checkbox, isOn: this.selectedStyles.includes(version.v) })
                  .onChange(() => this.toggleStyleVersion(version.v))
                Column({ space: 4 }) {
                  Text(`v${version.v}${this.history.head === version.v ? ' · 当前' : ''}`).fontSize(15).fontWeight(FontWeight.Bold)
                  Text(version.style).fontSize(13).fontColor('#666666').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button('切换').fontSize(12).enabled(this.history.head !== version.v).onClick(async () => {
                  if (await settingsStore.saveStyleHead(version.v)) {
                    this.history.head = version.v; this.history = this.history;
                    this.style = version.style; promptAction.showToast({ message: `已切换到 v${version.v}` });
                  }
                })
              }.padding(12).backgroundColor(Theme.CARD).borderRadius(12).border({ width: 1, color: Theme.BORDER }).width('100%')
            }, (version: StyleVersion) => `${version.v}`)
            Button('保存多文风选择').width('100%').enabled(this.selectedStyles.length !== 1)
              .onClick(async () => promptAction.showToast({
                message: await settingsStore.saveStyleSelection(this.selectedStyles) ? '多文风选择已保存' : '保存失败'
              }))
          }
        }.padding({ left: 16, right: 16, top: 6, bottom: 30 })
      }.layoutWeight(1)
    }.height('100%').backgroundColor(Theme.BG)
  }
}
