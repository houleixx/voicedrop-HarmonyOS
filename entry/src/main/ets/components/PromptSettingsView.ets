import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { PromptNode, PromptTree } from '../core/PromptTree';
import { promptStore, PromptPreview, PromptShareState, PromptMarketItem } from '../data/PromptStore';
import { Api } from '../core/Api';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { PageHeader } from '../ui/PageHeader';

class PromptShareEntry {
  id: string; state: PromptShareState;
  constructor(id: string, state: PromptShareState) { this.id = id; this.state = state; }
}

@Component
export struct PromptSettingsView {
  onBack: () => void = () => {};
  initialCode: string = '';
  @State private items: PromptNode[] = [];
  @State private loading: boolean = true;
  @State private showEditor: boolean = false;
  @State private editing: PromptNode = new PromptNode();
  @State private originalId: string = '';
  @State private targetGroup: string = '';
  @State private importInput: string = '';
  @State private preview?: PromptPreview = undefined;
  @State private shareEntries: PromptShareEntry[] = [];
  @State private shareNode?: PromptNode = undefined;
  @State private shareState: PromptShareState = new PromptShareState();
  @State private shareWorking: boolean = false;
  @State private draggingId: string = '';
  @State private marketItems: PromptMarketItem[] = [];
  @State private marketSort: string = 'hot';
  @State private marketScope: string = '';
  @State private marketLoading: boolean = false;
  @State private marketFailed: boolean = false;
  @State private importingMarketCode: string = '';
  @State private marketDetail?: PromptMarketItem = undefined;
  @State private marketPreview?: PromptPreview = undefined;
  @State private marketPreviewLoading: boolean = false;
  private dragReferenceY: number = 0;
  private dragMoveBusy: boolean = false;

  aboutToAppear(): void {
    if (/^[1-9][0-9]{6}$/.test(this.initialCode)) this.importInput = this.initialCode;
    this.load().then(() => { if (this.importInput.length > 0) this.previewImport(); });
    this.loadMarket();
  }

  private async loadMarket(): Promise<void> {
    if (this.marketLoading) return;
    const sort: string = this.marketSort; const scope: string = this.marketScope;
    this.marketLoading = true; this.marketFailed = false;
    const items: PromptMarketItem[] | undefined = await promptStore.market(sort, scope, 30);
    if (sort !== this.marketSort || scope !== this.marketScope) return;
    this.marketLoading = false; this.marketFailed = items === undefined; this.marketItems = items ?? [];
  }

  private selectMarket(sort: string, scope: string): void {
    if (sort === this.marketSort && scope === this.marketScope) return;
    this.marketSort = sort; this.marketScope = scope; this.marketItems = []; this.marketLoading = false; this.loadMarket();
  }

  private async importMarket(item: PromptMarketItem): Promise<void> {
    if (this.importingMarketCode.length > 0 || PromptTree.containsImport(this.items, item.code)) return;
    this.importingMarketCode = item.code;
    const error: string = await promptStore.importCode(item.code);
    this.importingMarketCode = ''; this.items = promptStore.items();
    if (error.length > 0) promptAction.showToast({ message: error });
    else { this.closeMarketDetail(); promptAction.showToast({ message: '已加入提示词' }); }
  }

  private async openMarketDetail(item: PromptMarketItem): Promise<void> {
    this.marketDetail = item; this.marketPreview = undefined; this.marketPreviewLoading = true;
    const preview: PromptPreview | undefined = await promptStore.preview(item.code);
    if (this.marketDetail?.code !== item.code) return;
    this.marketPreview = preview; this.marketPreviewLoading = false;
  }

  private closeMarketDetail(): void {
    this.marketDetail = undefined; this.marketPreview = undefined; this.marketPreviewLoading = false;
  }

  private marketType(item: PromptMarketItem): string {
    const text: boolean = item.appliesTo.includes('text'); const image: boolean = item.appliesTo.includes('image');
    return text && image ? '文字与配图' : (image ? '配图' : '文字');
  }

  private marketApplies(item: PromptMarketItem): string {
    const text: boolean = item.appliesTo.includes('text'); const image: boolean = item.appliesTo.includes('image');
    return text && image ? '文字和图片' : (image ? '图片' : (text ? '文字' : '全部'));
  }

  @Builder
  private marketFilter(label: string, sort: string, scope: string) {
    Button(label).fontSize(13).height(32)
      .fontColor(this.marketSort === sort && this.marketScope === scope ? Color.White : '#555555')
      .backgroundColor(this.marketSort === sort && this.marketScope === scope ? '#111111' : '#ECECE8')
      .onClick(() => this.selectMarket(sort, scope))
  }

  @Builder
  private marketSection() {
    Column({ space: 10 }) {
      Text('社区提示词').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
      Row({ space: 7 }) {
        this.marketFilter('热门', 'hot', '')
        this.marketFilter('最新', 'new', '')
        this.marketFilter('文字', 'hot', 'text')
        this.marketFilter('配图', 'hot', 'image')
      }.width('100%')
      if (this.marketLoading && this.marketItems.length === 0) LoadingProgress().width(30)
      else if (this.marketFailed && this.marketItems.length === 0) Button('加载失败，点此重试').backgroundColor(Color.Transparent).fontColor('#777777').onClick(() => this.loadMarket())
      else if (this.marketItems.length === 0) Text('暂无公开提示词').fontSize(13).fontColor('#888888').padding(10)
      ForEach(this.marketItems, (item: PromptMarketItem) => {
        Row({ space: 10 }) {
          Text(item.appliesTo.includes('image') && !item.appliesTo.includes('text') ? '图' : '文').fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor(item.appliesTo.includes('image') ? '#B55D38' : '#2F765B').width(34).height(34).textAlign(TextAlign.Center)
            .backgroundColor(item.appliesTo.includes('image') ? '#FFF0E8' : '#EAF1EC').borderRadius(8)
          Column({ space: 3 }) {
            Text(item.label).fontSize(15).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${item.author || '匿名'} · 导入 ${item.importCount}`).fontSize(12).fontColor('#888888')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(() => this.openMarketDetail(item))
          if (this.importingMarketCode === item.code) LoadingProgress().width(26)
          else if (PromptTree.containsImport(this.items, item.code)) Text('已导入').fontSize(12).fontColor('#999999')
          else Button('导入').fontSize(13).height(32).onClick(() => this.importMarket(item))
        }.padding({ top: 8, bottom: 8 }).width('100%')
      }, (item: PromptMarketItem) => item.code)
    }.padding(14).backgroundColor(Color.White).borderRadius(14).width('100%').alignItems(HorizontalAlign.Start)
  }

  private async load(): Promise<void> {
    this.items = promptStore.items(); this.loading = false;
    const warning: string = await promptStore.refresh(); this.items = promptStore.items();
    const states: Map<string, PromptShareState> = await promptStore.shareStates();
    const entries: PromptShareEntry[] = []; states.forEach((state: PromptShareState, id: string) => entries.push(new PromptShareEntry(id, state)));
    this.shareEntries = entries;
    if (warning.length > 0) promptAction.showToast({ message: warning });
  }

  private beginNew(type: string, groupId: string = ''): void {
    const node: PromptNode = new PromptNode(); node.id = PromptTree.newUserId(); node.type = type;
    node.origin = 'user';
    node.label = type === 'group' ? '新分组' : '新提示词'; node.appliesTo = type === 'action' ? ['text'] : [];
    this.editing = node; this.originalId = ''; this.targetGroup = groupId; this.showEditor = true;
  }

  private beginEdit(node: PromptNode): void {
    this.editing = node.isSystem() ? PromptTree.fork(node) : node.copy();
    this.originalId = node.id; this.targetGroup = ''; this.showEditor = true;
  }

  private async saveEditor(): Promise<void> {
    if (this.editing.label.trim().length === 0) { promptAction.showToast({ message: '请输入名称' }); return; }
    if (!this.editing.isGroup() && this.editing.prompt.trim().length === 0) { promptAction.showToast({ message: '请输入提示词内容' }); return; }
    let error: string = '';
    if (this.originalId.length > 0) error = await promptStore.replace(this.originalId, this.editing);
    else error = await promptStore.add(this.editing, this.targetGroup.length > 0 ? this.targetGroup : undefined);
    if (error.length > 0) promptAction.showToast({ message: error });
    else { this.items = promptStore.items(); this.showEditor = false; }
  }

  private async remove(node: PromptNode): Promise<void> {
    const result = await promptAction.showDialog({
      title: `删除“${node.label}”？`, message: node.isGroup() ? '分组内的提示词也会一起删除。' : '删除后可以通过恢复默认值找回系统提示词。',
      buttons: [{ text: '取消', color: '#666666' }, { text: '删除', color: '#D92D20' }]
    });
    if (result.index !== 1) return;
    const error: string = await promptStore.remove(node.id); this.items = promptStore.items();
    promptAction.showToast({ message: error.length > 0 ? error : '已删除' });
  }

  private async move(node: PromptNode, groupId: string | undefined, index: number): Promise<void> {
    const error: string = await promptStore.move(node.id, groupId, index); this.items = promptStore.items();
    if (error.length > 0) promptAction.showToast({ message: error });
  }

  private beginDrag(node: PromptNode): void {
    this.draggingId = node.id;
    this.dragReferenceY = 0;
    this.dragMoveBusy = false;
  }

  private siblings(groupId: string): PromptNode[] {
    if (groupId.length === 0) return this.items;
    const group: PromptNode | undefined = this.items.find((node: PromptNode) => node.id === groupId);
    return group?.children ?? [];
  }

  private async updateDrag(node: PromptNode, groupId: string, offsetY: number): Promise<void> {
    if (this.dragMoveBusy) return;
    const distance: number = offsetY - this.dragReferenceY;
    if (Math.abs(distance) < 40) return;
    const siblings: PromptNode[] = this.siblings(groupId);
    const index: number = siblings.findIndex((value: PromptNode) => value.id === node.id);
    const target: number = index + (distance > 0 ? 1 : -1);
    if (index < 0 || target < 0 || target >= siblings.length) {
      this.dragReferenceY = offsetY;
      return;
    }
    this.dragReferenceY = offsetY;
    this.dragMoveBusy = true;
    await this.move(node, groupId.length > 0 ? groupId : undefined, target);
    this.dragMoveBusy = false;
  }

  private endDrag(): void {
    this.draggingId = '';
    this.dragReferenceY = 0;
  }

  @Builder
  private dragHandle(node: PromptNode, groupId: string) {
    Text('≡').fontSize(25).fontColor(this.draggingId === node.id ? '#111111' : '#8B8B87')
      .width(30).height(40).textAlign(TextAlign.Center)
      .gesture(
        PanGesture({ direction: PanDirection.Vertical, distance: 3 })
          .onActionStart(() => this.beginDrag(node))
          .onActionUpdate((event: GestureEvent) => this.updateDrag(node, groupId, event.offsetY))
          .onActionEnd(() => this.endDrag())
          .onActionCancel(() => this.endDrag())
      )
  }

  private async previewImport(): Promise<void> {
    const code: string = PromptTree.extractShareCode(this.importInput);
    if (!code) { promptAction.showToast({ message: '请输入分享链接或 7 位分享码' }); return; }
    this.importInput = code; this.preview = await promptStore.preview(code);
    if (!this.preview) promptAction.showToast({ message: '没有找到这个分享码' });
  }

  private async importPrompt(): Promise<void> {
    const error: string = await promptStore.importCode(this.importInput);
    if (error.length > 0) promptAction.showToast({ message: error });
    else { this.items = promptStore.items(); this.preview = undefined; this.importInput = ''; promptAction.showToast({ message: '导入成功' }); }
  }

  private openShare(node: PromptNode): void {
    const entry: PromptShareEntry | undefined = this.shareEntries.find((value: PromptShareEntry) => value.id === node.id);
    this.shareNode = node.copy(); this.shareState = entry?.state ?? new PromptShareState();
  }

  private async toggleSharing(): Promise<void> {
    if (!this.shareNode || this.shareWorking) return;
    this.shareWorking = true;
    const previous: PromptShareState = this.shareState;
    const state: PromptShareState = await promptStore.setSharing(this.shareNode.id, !previous.sharing);
    this.shareWorking = false;
    if (state.error.length > 0) { promptAction.showToast({ message: state.error }); return; }
    this.shareState = state;
    this.shareEntries = this.shareEntries.filter((value: PromptShareEntry) => value.id !== this.shareNode!.id)
      .concat([new PromptShareEntry(this.shareNode.id, state)]);
  }

  private copyShare(value: string): void {
    const data: pasteboard.PasteData = pasteboard.createPlainTextData(value);
    pasteboard.getSystemPasteboard().setData(data); promptAction.showToast({ message: '已复制' });
  }

  private toggleAnchor(anchor: string, enabled: boolean): void {
    const next: PromptNode = this.editing.copy();
    if (enabled && !next.appliesTo.includes(anchor)) next.appliesTo.push(anchor);
    if (!enabled) next.appliesTo = next.appliesTo.filter((value: string) => value !== anchor);
    this.editing = next;
  }

  @Builder
  private actionRow(node: PromptNode, groupId: string, index: number, count: number) {
    Row({ space: 6 }) {
      this.dragHandle(node, groupId)
      Row() {
        RemixIcon({
          glyph: node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? RI.IMAGE : RI.FILE_TEXT,
          iconSize: 17,
          color: node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? Theme.ACCENT : Theme.SECONDARY
        })
      }.width(32).height(32).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(8)
      Column({ space: 3 }) {
        Text(node.label).fontSize(16).fontWeight(FontWeight.Medium)
        Text(`${node.origin === 'system' ? '系统' : '自定义'} · ${node.appliesTo.includes('text') ? '文字' : ''}${node.appliesTo.includes('image') ? ' 图片' : ''}`)
          .fontSize(12).fontColor(Theme.SECONDARY)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start).onClick(() => this.beginEdit(node))
      Button('↑').width(36).height(34).enabled(index > 0).onClick(() => this.move(node, groupId || undefined, index - 1))
      Button('↓').width(36).height(34).enabled(index < count - 1).onClick(() => this.move(node, groupId || undefined, index + 1))
      if (!node.isSystem()) Button(this.shareEntries.some((value: PromptShareEntry) => value.id === node.id && value.state.sharing) ? '分享中' : '分享')
        .fontSize(12).height(34).onClick(() => this.openShare(node))
      Button('删').fontSize(12).height(34).fontColor('#B42318').backgroundColor('#FEE4E2').onClick(() => this.remove(node))
    }.padding(12).backgroundColor(this.draggingId === node.id ? Theme.ACCENT_SOFT : Theme.CARD)
      .borderRadius(10).border({ width: 1, color: Theme.BORDER }).width('100%')
  }

  @Builder
  private promptNode(node: PromptNode, index: number) {
    if (node.isGroup()) {
      Column({ space: 8 }) {
        Row() {
          this.dragHandle(node, '')
          RemixIcon({ glyph: RI.FOLDER, iconSize: 19, color: Theme.SECONDARY })
          Text(node.label).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1).onClick(() => this.beginEdit(node))
          Button('＋').fontSize(18).width(38).height(34).onClick(() => this.beginNew('action', node.id))
          Button('↑').width(36).height(34).enabled(index > 0).onClick(() => this.move(node, undefined, index - 1))
          Button('↓').width(36).height(34).enabled(index < this.items.length - 1).onClick(() => this.move(node, undefined, index + 1))
          Button('删').fontSize(12).height(34).fontColor('#B42318').backgroundColor('#FEE4E2').onClick(() => this.remove(node))
        }
        ForEach(node.children, (child: PromptNode, childIndex: number) => this.actionRow(child, node.id, childIndex, node.children.length),
          (child: PromptNode) => child.id)
      }.padding(14).backgroundColor(Theme.CARD).borderRadius(14).border({ width: 1, color: Theme.BORDER })
        .width('100%').alignItems(HorizontalAlign.Start)
    } else {
      this.actionRow(node, '', index, this.items.length)
    }
  }

  @Builder
  private editor() {
    Column({ space: 12 }) {
      Text(this.originalId.length > 0 ? '编辑提示词' : '新建提示词').fontSize(22).fontWeight(FontWeight.Bold).width('100%')
      TextInput({ text: this.editing.label, placeholder: '菜单名称' }).onChange((value: string) => {
        const next: PromptNode = this.editing.copy(); next.label = value; this.editing = next;
      }).backgroundColor('#F1F1EF')
      if (!this.editing.isGroup()) {
        TextArea({ text: this.editing.prompt, placeholder: '例如：把第{{LINE}}行改得更简洁；图片可使用 {{KEY}}' })
          .height(190).onChange((value: string) => { const next: PromptNode = this.editing.copy(); next.prompt = value; this.editing = next; })
          .backgroundColor('#F1F1EF')
        Row() {
          Text('用于文字').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.editing.appliesTo.includes('text') }).onChange((value: boolean) => this.toggleAnchor('text', value))
        }.width('100%')
        Row() {
          Text('用于图片').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.editing.appliesTo.includes('image') }).onChange((value: boolean) => this.toggleAnchor('image', value))
        }.width('100%')
      }
      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).backgroundColor('#E8E8E5').fontColor('#333333').onClick(() => this.showEditor = false)
        Button('保存').layoutWeight(1).backgroundColor(Theme.ACCENT).onClick(() => this.saveEditor())
      }.width('100%')
    }.padding(20).backgroundColor(Theme.CARD).borderRadius(18).margin(18).width('90%')
  }

  build() {
    Stack() {
      Column() {
        Stack({ alignContent: Alignment.End }) {
          PageHeader({ title: '提示词', onBack: () => this.onBack() })
          Row({ space: 6 }) {
            Button() { RemixIcon({ glyph: RI.FOLDER, iconSize: 18, color: Theme.ACCENT }) }
              .width(42).height(40).backgroundColor(Theme.ACCENT_SOFT).onClick(() => this.beginNew('group'))
            Button() { RemixIcon({ glyph: RI.EDIT, iconSize: 18, color: Theme.WHITE }) }
              .width(42).height(40).backgroundColor(Theme.ACCENT).onClick(() => this.beginNew('action'))
          }.margin({ right: 12 })
        }.height(56).width('100%')
        Scroll() {
          Column({ space: 12 }) {
            this.marketSection()
            Column({ space: 10 }) {
              Text('导入分享提示词').fontSize(17).fontWeight(FontWeight.Bold).width('100%')
              Row({ space: 8 }) {
                TextInput({ text: this.importInput, placeholder: '7 位分享码或链接' }).layoutWeight(1)
                  .onChange((value: string) => this.importInput = value)
                Button('预览').onClick(() => this.previewImport())
              }
              if (this.preview) {
                Column({ space: 5 }) {
                  Text(this.preview!.label).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
                  Text(`作者：${this.preview!.author || 'VoiceDrop 用户'} · 已导入 ${this.preview!.importCount} 次`).fontSize(12).fontColor('#888888').width('100%')
                  Text(this.preview!.prompt).fontSize(13).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                  Button('确认导入').onClick(() => this.importPrompt())
                }.padding(12).backgroundColor('#F5F5F2').borderRadius(10).alignItems(HorizontalAlign.Start)
              }
            }.padding(14).backgroundColor(Theme.CARD).borderRadius(14).border({ width: 1, color: Theme.BORDER })
              .width('100%').alignItems(HorizontalAlign.Start)
            Text('拖动 ≡ 调整顺序，也可使用上下按钮').fontSize(12).fontColor(Theme.SECONDARY).width('100%')
            if (this.loading) LoadingProgress().width(34)
            ForEach(this.items, (node: PromptNode, index: number) => this.promptNode(node, index), (node: PromptNode) => node.id)
            Button('恢复系统默认提示词').fontColor('#8A4B08').backgroundColor('#FFF4E5').onClick(async () => {
              const error: string = await promptStore.restoreDefaults(); this.items = promptStore.items();
              promptAction.showToast({ message: error.length > 0 ? error : '已恢复默认值' });
            })
          }.padding({ left: 16, right: 16, top: 6, bottom: 40 }).width('100%')
        }.layoutWeight(1)
      }.height('100%').backgroundColor(Theme.BG)
      if (this.showEditor) {
        Column() { this.editor() }.width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor('#66000000')
      }
      if (this.shareNode) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.shareNode = undefined)
          Column({ space: 14 }) {
            Row() { Text('分享这条提示词').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1); Button('关闭').onClick(() => this.shareNode = undefined) }
            Text(this.shareNode!.label).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
            Row() {
              Column({ space: 3 }) {
                Text(this.shareState.sharing ? '正在分享' : '未分享').fontSize(15).fontWeight(FontWeight.Medium)
                Text(this.shareState.sharing ? '关闭后分享码立即失效' : '开启后其他人可用 7 位码导入已保存的版本').fontSize(12).fontColor('#777777')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Toggle({ type: ToggleType.Switch, isOn: this.shareState.sharing }).enabled(!this.shareWorking).onChange(() => this.toggleSharing())
            }.width('100%')
            if (this.shareState.sharing && this.shareState.code.length > 0) {
              Text(this.shareState.code).fontSize(34).fontWeight(FontWeight.Bold).letterSpacing(5).width('100%').textAlign(TextAlign.Center)
              Text(`voicedrop.cn/${this.shareState.code}`).fontSize(13).fontColor('#666666').width('100%').textAlign(TextAlign.Center)
              Row({ space: 10 }) {
                Button('复制数字').layoutWeight(1).onClick(() => this.copyShare(this.shareState.code))
                Button('复制链接').layoutWeight(1).onClick(() => this.copyShare(Api.sharePage(this.shareState.code)))
              }.width('100%')
              Text('分享的始终是已保存的版本').fontSize(12).fontColor('#888888').width('100%').textAlign(TextAlign.Center)
            }
          }.padding({ left: 20, right: 20, top: 20, bottom: 30 }).backgroundColor(Color.White)
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#66000000')
      }
      if (this.marketDetail) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.closeMarketDetail())
          Column({ space: 13 }) {
            Row() { Text(this.marketType(this.marketDetail!)).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#B55D38').layoutWeight(1); Button('关闭').onClick(() => this.closeMarketDetail()) }
            Text(this.marketDetail!.label).fontSize(23).fontWeight(FontWeight.Bold).width('100%')
            Text(this.marketDetail!.author || '匿名分享者').fontSize(13).fontColor('#777777').width('100%')
            Row() {
              Column({ space: 2 }) {
                Text(`${this.marketDetail!.importCount}`).fontSize(18).fontWeight(FontWeight.Bold)
                Text('被导入').fontSize(11).fontColor('#888888')
              }.layoutWeight(1)
              Column({ space: 2 }) {
                Text(this.marketApplies(this.marketDetail!)).fontSize(18).fontWeight(FontWeight.Bold)
                Text('适用于').fontSize(11).fontColor('#888888')
              }.layoutWeight(1)
            }.padding(12).backgroundColor('#F5F5F2').borderRadius(10).width('100%')
            Text('提示词全文').fontSize(13).fontWeight(FontWeight.Bold).width('100%')
            if (this.marketPreviewLoading) {
              LoadingProgress().width(28)
            } else {
              Text(this.marketPreview?.prompt || '（全文加载失败）').fontSize(14).lineHeight(22)
                .padding(12).backgroundColor('#F5F5F2').borderRadius(10).width('100%')
            }
            if (this.marketDetail!.exampleInput.length > 0) {
              Text('示例输入').fontSize(13).fontWeight(FontWeight.Bold).width('100%')
              Text(this.marketDetail!.exampleInput).fontSize(14).lineHeight(21).padding(12).backgroundColor('#F5F5F2').borderRadius(10).width('100%')
            }
            if (this.marketDetail!.exampleOutput.length > 0) {
              Text('示例效果').fontSize(13).fontWeight(FontWeight.Bold).width('100%')
              Text(this.marketDetail!.exampleOutput).fontSize(14).lineHeight(21).padding(12).backgroundColor('#F5F5F2').borderRadius(10).width('100%')
            }
            Button(PromptTree.containsImport(this.items, this.marketDetail!.code) ? '已加入提示词' :
              (this.importingMarketCode === this.marketDetail!.code ? '正在导入…' : '加入提示词'))
              .enabled(!PromptTree.containsImport(this.items, this.marketDetail!.code) && this.importingMarketCode.length === 0)
              .width('100%').height(48).backgroundColor(Theme.ACCENT).onClick(() => this.importMarket(this.marketDetail!))
          }.padding({ left: 20, right: 20, top: 20, bottom: 30 }).backgroundColor(Color.White)
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#66000000')
      }
    }
  }
}
