import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { PromptNode, PromptTree } from '../core/PromptTree';
import { promptStore, PromptPreview, PromptShareState, PromptMarketItem } from '../data/PromptStore';
import { Api } from '../core/Api';
import { VoiceDropTheme as Theme } from '../ui/VoiceDropTheme';
import { RemixIcon, RemixIconGlyph as RI } from '../ui/RemixIcon';
import { PageHeader } from '../ui/PageHeader';
import { PromptMarketFilter, PromptMarketFilters } from '../core/PromptMarketFilter';

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
  @State private loadWarning: string = '';
  @State private expandedGroups: string[] = [];
  @State private showNewMenu: boolean = false;
  @State private showImportSheet: boolean = false;
  @State private importPreviewLoading: boolean = false;
  @State private sorting: boolean = false;
  @State private savingSort: boolean = false;
  @State private sortDraft: PromptNode[] = [];
  @State private moveNodeId: string = '';
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
  @State private marketFilter: string = 'hot';
  @State private marketLoading: boolean = false;
  @State private marketFailed: boolean = false;
  @State private importingMarketCode: string = '';
  @State private marketDetail?: PromptMarketItem = undefined;
  @State private marketPreview?: PromptPreview = undefined;
  @State private marketPreviewLoading: boolean = false;
  private marketFilters: PromptMarketFilter[] = PromptMarketFilters.all();
  private marketRequestGeneration: number = 0;
  private dragReferenceY: number = 0;
  private dragMoveBusy: boolean = false;

  aboutToAppear(): void {
    if (/^[1-9][0-9]{6}$/.test(this.initialCode)) this.importInput = this.initialCode;
    this.load().then(() => {
      if (this.importInput.length > 0) {
        this.showImportSheet = true;
        this.previewImport();
      }
    });
    this.loadMarket();
  }

  private async loadMarket(): Promise<void> {
    if (this.marketLoading) return;
    const filter: PromptMarketFilter = PromptMarketFilters.resolve(this.marketFilter);
    const requestGeneration: number = ++this.marketRequestGeneration;
    this.marketLoading = true; this.marketFailed = false;
    const items: PromptMarketItem[] | undefined = await promptStore.market(filter.sort, filter.scope, 30);
    if (requestGeneration !== this.marketRequestGeneration) return;
    this.marketLoading = false; this.marketFailed = items === undefined; this.marketItems = items ?? [];
  }

  private selectMarketFilter(key: string): void {
    if (key === this.marketFilter) return;
    this.marketFilter = PromptMarketFilters.resolve(key).key;
    this.marketItems = [];
    this.marketFailed = false;
    this.marketLoading = false;
    this.loadMarket();
  }

  private async importMarket(item: PromptMarketItem): Promise<void> {
    if (this.importingMarketCode.length > 0 || PromptTree.containsImport(this.items, item.code)) return;
    this.importingMarketCode = item.code;
    const error: string = await promptStore.importCode(item.code);
    this.importingMarketCode = ''; this.items = promptStore.items();
    if (error.length > 0) promptAction.showToast({ message: error});
    else { this.closeMarketDetail(); promptAction.showToast({ message: '已加入提示词'}); }
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
  private marketFilterChip(filter: PromptMarketFilter) {
    Button(filter.label)
      .fontSize(13)
      .fontWeight(this.marketFilter === filter.key ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.marketFilter === filter.key ? Color.White : '#5B5349')
      .height(32)
      .layoutWeight(1)
      .backgroundColor(this.marketFilter === filter.key ? '#2B2823' : Color.White)
      .borderRadius(16)
      .border({ width: this.marketFilter === filter.key ? 0 : 1, color: '#E5DCCB' })
      .onClick(() => this.selectMarketFilter(filter.key))
  }

  @Builder
  private marketSection() {
    Column({ space: 10 }) {
      Text('社区提示词').fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY)
        .padding({ left: 2 }).width('100%')
      Row({ space: 8 }) {
        ForEach(this.marketFilters, (filter: PromptMarketFilter) => {
          this.marketFilterChip(filter)
        }, (filter: PromptMarketFilter) => filter.key)
      }.width('100%')
      if (this.marketLoading && this.marketItems.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(24).height(24).color(Theme.ACCENT)
          Text('正在加载社区提示词…').fontSize(13).fontColor(Theme.FAINT)
        }.height(88).justifyContent(FlexAlign.Center).width('100%')
      } else if (this.marketFailed && this.marketItems.length === 0) {
        Button('社区提示词加载失败，点此重试').height(88).backgroundColor(Color.Transparent)
          .fontColor(Theme.ACCENT).onClick(() => this.loadMarket())
      } else if (this.marketItems.length === 0) {
        Text('暂无公开提示词').fontSize(13).fontColor(Theme.FAINT).height(88)
          .width('100%').textAlign(TextAlign.Center)
      } else {
        Column() {
          ForEach(this.marketItems, (item: PromptMarketItem, index: number) => {
            if (index > 0) Divider().color(Theme.DIVIDER).margin({ left: 59 })
            Row({ space: 10 }) {
              Text(item.appliesTo.includes('image') && !item.appliesTo.includes('text') ? '图' : '文')
                .fontSize(13).fontWeight(FontWeight.Bold)
                .fontColor(item.appliesTo.includes('image') ? '#B55D38' : '#2F765B')
                .width(34).height(34).textAlign(TextAlign.Center)
                .backgroundColor(item.appliesTo.includes('image') ? '#FFF0E8' : '#EAF1EC').borderRadius(8)
              Column({ space: 3 }) {
                Text(item.label).fontSize(15).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${item.author || '匿名'} · 导入 ${item.importCount}`).fontSize(12).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.importingMarketCode === item.code) LoadingProgress().width(26)
              else if (PromptTree.containsImport(this.items, item.code)) {
                Row({ space: 3 }) {
                  Text('已导入').fontSize(12).fontColor(Theme.FAINT)
                  RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 14, color: Theme.FAINT })
                }
              } else {
                Button('导入').fontSize(13).height(32).fontColor(Theme.ACCENT)
                  .backgroundColor(Color.White).border({ width: 1, color: '#EBC4B7', radius: 16 })
                  .onClick(() => this.importMarket(item))
              }
            }.height(52).padding({ left: 15, right: 15, top: 9, bottom: 9 }).width('100%')
              .onClick(() => this.openMarketDetail(item))
          }, (item: PromptMarketItem) => item.code)
        }.backgroundColor(Theme.CARD).border({ width: 1, color: Theme.BORDER, radius: 12 })
          .borderRadius(12).clip(true).width('100%')
      }
    }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 10 })
  }

  private async load(): Promise<void> {
    this.items = promptStore.items();
    const warning: string = await promptStore.refresh(); this.items = promptStore.items(); this.loading = false;
    this.loadWarning = warning;
    const states: Map<string, PromptShareState> = await promptStore.shareStates();
    const entries: PromptShareEntry[] = []; states.forEach((state: PromptShareState, id: string) => entries.push(new PromptShareEntry(id, state)));
    this.shareEntries = entries;
  }

  private beginNew(type: string, groupId: string = ''): void {
    const node: PromptNode = new PromptNode(); node.id = PromptTree.newUserId(); node.type = type;
    node.origin = 'user';
    node.label = ''; node.appliesTo = type === 'action' ? ['text', 'image'] : [];
    this.editing = node; this.originalId = ''; this.targetGroup = groupId; this.showEditor = true;
  }

  private beginEdit(node: PromptNode): void {
    this.editing = node.isSystem() ? PromptTree.fork(node) : node.copy();
    this.originalId = node.id; this.targetGroup = ''; this.showEditor = true;
  }

  private async saveEditor(): Promise<void> {
    if (this.editing.label.trim().length === 0) { promptAction.showToast({ message: '请输入名称'}); return; }
    if (!this.editing.isGroup() && this.editing.prompt.trim().length === 0) { promptAction.showToast({ message: '请输入提示词内容'}); return; }
    let error: string = '';
    if (this.originalId.length > 0) error = await promptStore.replace(this.originalId, this.editing);
    else error = await promptStore.add(this.editing, this.targetGroup.length > 0 ? this.targetGroup : undefined);
    if (error.length > 0) promptAction.showToast({ message: error});
    else { this.items = promptStore.items(); this.showEditor = false; }
  }

  private async remove(node: PromptNode): Promise<boolean> {
    const result = await promptAction.showDialog({
      title: `删除“${node.label}”？`, message: node.isGroup() ? '分组内的提示词也会一起删除。' : '删除后可以通过恢复默认值找回系统提示词。',
      buttons: [{ text: '取消', color: '#666666' }, { text: '删除', color: '#D92D20' }]
    });
    if (result.index !== 1) return false;
    const error: string = await promptStore.remove(node.id); this.items = promptStore.items();
    promptAction.showToast({ message: error.length > 0 ? error : '已删除'});
    return error.length === 0;
  }

  private async move(node: PromptNode, groupId: string | undefined, index: number): Promise<void> {
    if (this.sorting) {
      const moved: PromptNode[] | undefined = PromptTree.move(this.sortDraft, node.id, groupId, index);
      if (moved) this.sortDraft = moved;
      return;
    }
    const error: string = await promptStore.move(node.id, groupId, index); this.items = promptStore.items();
    if (error.length > 0) promptAction.showToast({ message: error});
  }

  private visibleItems(): PromptNode[] {
    return this.sorting ? this.sortDraft : this.items;
  }

  private beginSort(): void {
    if (this.sorting) return;
    this.sortDraft = PromptTree.copy(this.items);
    this.sorting = true;
    this.showNewMenu = false;
  }

  private cancelSort(): void {
    if (this.savingSort) return;
    this.sorting = false;
    this.sortDraft = [];
    this.draggingId = '';
  }

  private async finishSort(): Promise<void> {
    if (this.savingSort) return;
    this.savingSort = true;
    const error: string = await promptStore.saveDraft(this.sortDraft);
    this.savingSort = false;
    if (error.length > 0) {
      promptAction.showToast({ message: error });
      return;
    }
    this.items = promptStore.items();
    this.sorting = false;
    this.sortDraft = [];
  }

  private toggleGroup(id: string): void {
    if (this.expandedGroups.includes(id)) {
      this.expandedGroups = this.expandedGroups.filter((value: string) => value !== id);
    } else {
      this.expandedGroups = this.expandedGroups.concat([id]);
    }
  }

  private sortNode(id: string): PromptNode | undefined {
    for (const node of this.sortDraft) {
      if (node.id === id) return node;
      const child: PromptNode | undefined = node.children.find((value: PromptNode) => value.id === id);
      if (child) return child;
    }
    return undefined;
  }

  private moveSortNode(groupId: string): void {
    const node: PromptNode | undefined = this.sortNode(this.moveNodeId);
    if (!node || node.isGroup()) { this.moveNodeId = ''; return; }
    let targetIndex: number = this.sortDraft.length;
    if (groupId.length > 0) {
      const group: PromptNode | undefined = this.sortDraft.find((value: PromptNode) => value.id === groupId);
      if (!group) return;
      targetIndex = group.children.length;
      if (!this.expandedGroups.includes(groupId)) this.expandedGroups = this.expandedGroups.concat([groupId]);
    }
    const moved: PromptNode[] | undefined = PromptTree.move(this.sortDraft, node.id,
      groupId.length > 0 ? groupId : undefined, targetIndex);
    if (moved) this.sortDraft = moved;
    this.moveNodeId = '';
  }

  private beginDrag(node: PromptNode): void {
    this.draggingId = node.id;
    this.dragReferenceY = 0;
    this.dragMoveBusy = false;
  }

  private siblings(groupId: string): PromptNode[] {
    const source: PromptNode[] = this.visibleItems();
    if (groupId.length === 0) return source;
    const group: PromptNode | undefined = source.find((node: PromptNode) => node.id === groupId);
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
    if (!code) { promptAction.showToast({ message: '请输入分享链接或 7 位分享码'}); return; }
    this.importInput = code; this.importPreviewLoading = true;
    const result: PromptPreview | undefined = await promptStore.preview(code);
    if (PromptTree.extractShareCode(this.importInput) !== code) return;
    this.preview = result;
    this.importPreviewLoading = false;
    if (!this.preview) promptAction.showToast({ message: '没有找到这个分享码'});
  }

  private updateImportInput(value: string): void {
    this.importInput = value;
    this.preview = undefined;
    const code: string = PromptTree.extractShareCode(value);
    if (code.length === 7) this.previewImport();
  }

  private async importPrompt(): Promise<void> {
    const error: string = await promptStore.importCode(this.importInput);
    if (error.length > 0) promptAction.showToast({ message: error});
    else {
      this.items = promptStore.items(); this.preview = undefined; this.importInput = '';
      this.showImportSheet = false; promptAction.showToast({ message: '导入成功'});
    }
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
    if (state.error.length > 0) { promptAction.showToast({ message: state.error}); return; }
    this.shareState = state;
    this.shareEntries = this.shareEntries.filter((value: PromptShareEntry) => value.id !== this.shareNode!.id)
      .concat([new PromptShareEntry(this.shareNode.id, state)]);
  }

  private copyShare(value: string): void {
    const data: pasteboard.PasteData = pasteboard.createPlainTextData(value);
    pasteboard.getSystemPasteboard().setData(data); promptAction.showToast({ message: '已复制'});
  }

  private toggleAnchor(anchor: string, enabled: boolean): void {
    const next: PromptNode = this.editing.copy();
    if (enabled && !next.appliesTo.includes(anchor)) next.appliesTo.push(anchor);
    if (!enabled) next.appliesTo = next.appliesTo.filter((value: string) => value !== anchor);
    this.editing = next;
  }

  private appliesLabel(node: PromptNode): string {
    const text: boolean = node.appliesTo.includes('text');
    const image: boolean = node.appliesTo.includes('image');
    if (text && image) return '文字与图片';
    if (image) return '仅图片';
    if (text) return '仅文字';
    return '';
  }

  private originLabel(node: PromptNode): string {
    if (node.importedFrom) return '导入';
    if (node.origin === 'custom') return '已自定义';
    if (node.origin !== 'system') return '自建';
    return '';
  }

  private originColor(node: PromptNode): string {
    if (node.importedFrom) return '#4978A8';
    if (node.origin === 'custom') return Theme.AMBER;
    return Theme.GREEN;
  }

  private originBackground(node: PromptNode): string {
    if (node.importedFrom) return '#E8F0F8';
    if (node.origin === 'custom') return Theme.AMBER_BG;
    return Theme.GREEN_BG;
  }

  @Builder
  private actionRow(node: PromptNode, groupId: string, index: number, count: number) {
    Row({ space: 10 }) {
      if (this.sorting) this.dragHandle(node, groupId)
      Row() {
        RemixIcon({
          glyph: node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? RI.IMAGE : RI.FILE_TEXT,
          iconSize: 17,
          color: node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? Theme.ACCENT : Theme.SECONDARY
        })
      }.width(32).height(32).justifyContent(FlexAlign.Center)
        .backgroundColor(node.appliesTo.includes('image') ? Theme.ACCENT_SOFT : '#F2EEE7').borderRadius(8)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(node.label).fontSize(15).fontColor(Theme.INK).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          if (this.originLabel(node).length > 0) {
            Text(this.originLabel(node)).fontSize(11).fontWeight(FontWeight.Bold)
              .fontColor(this.originColor(node)).padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(this.originBackground(node)).borderRadius(4)
          }
        }.width('100%')
        if (this.appliesLabel(node).length > 0) {
          Text(this.appliesLabel(node)).fontSize(11)
            .fontColor(this.appliesLabel(node) === '仅图片' ? Theme.ACCENT :
              (this.appliesLabel(node) === '仅文字' ? Theme.GREEN : Theme.SECONDARY))
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor(this.appliesLabel(node) === '仅图片' ? Theme.ACCENT_SOFT :
              (this.appliesLabel(node) === '仅文字' ? Theme.GREEN_BG : '#F2EEE7'))
            .borderRadius(4)
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      if (this.sorting) {
        Button() {
          RemixIcon({ glyph: RI.FOLDER, iconSize: 16, color: Theme.SECONDARY })
        }.width(30).height(32).padding(0).backgroundColor(Color.Transparent)
          .onClick(() => this.moveNodeId = node.id)
        Button('↑').width(32).height(32).enabled(index > 0)
          .backgroundColor(Color.Transparent).fontColor(Theme.SECONDARY)
          .onClick(() => this.move(node, groupId || undefined, index - 1))
        Button('↓').width(32).height(32).enabled(index < count - 1)
          .backgroundColor(Color.Transparent).fontColor(Theme.SECONDARY)
          .onClick(() => this.move(node, groupId || undefined, index + 1))
      } else {
        RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
      }
    }
      .constraintSize({ minHeight: 52 })
      .padding({ left: groupId.length > 0 ? 31 : 15, right: 15, top: 9, bottom: 9 })
      .backgroundColor(this.draggingId === node.id ? Theme.ACCENT_SOFT : Theme.CARD)
      .width('100%')
      .onClick(() => { if (!this.sorting) this.beginEdit(node); })
      .gesture(LongPressGesture().onAction(() => this.beginSort()))
  }

  @Builder
  private promptNode(node: PromptNode, index: number) {
    if (node.isGroup()) {
      Column() {
        Row({ space: 10 }) {
          if (this.sorting) this.dragHandle(node, '')
          Row() {
            RemixIcon({ glyph: RI.FOLDER, iconSize: 18, color: Theme.SECONDARY })
          }.width(32).height(32).justifyContent(FlexAlign.Center).backgroundColor('#F2EEE7').borderRadius(8)
          Row({ space: 6 }) {
            Text(node.label).fontSize(15).fontColor(Theme.INK).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.originLabel(node).length > 0) {
              Text(this.originLabel(node)).fontSize(11).fontWeight(FontWeight.Bold)
                .fontColor(this.originColor(node)).padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .backgroundColor(this.originBackground(node)).borderRadius(4)
            }
            Text(`分组 · ${node.children.length} 项`).fontSize(12).fontColor(Theme.SECONDARY)
          }.layoutWeight(1)
          if (this.sorting) {
            Button('↑').width(32).height(32).enabled(index > 0).backgroundColor(Color.Transparent)
              .fontColor(Theme.SECONDARY).onClick(() => this.move(node, undefined, index - 1))
            Button('↓').width(32).height(32).enabled(index < this.visibleItems().length - 1).backgroundColor(Color.Transparent)
              .fontColor(Theme.SECONDARY).onClick(() => this.move(node, undefined, index + 1))
          } else {
            RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
              .rotate({ angle: this.expandedGroups.includes(node.id) ? 90 : 0 })
          }
        }
          .constraintSize({ minHeight: 52 })
          .padding({ left: 15, right: 15, top: 9, bottom: 9 })
          .backgroundColor(Theme.CARD)
          .width('100%')
          .onClick(() => { if (!this.sorting) this.toggleGroup(node.id); })
          .gesture(LongPressGesture().onAction(() => this.beginSort()))
        if (this.expandedGroups.includes(node.id)) {
          ForEach(node.children, (child: PromptNode, childIndex: number) => {
            Divider().color(Theme.DIVIDER).margin({ left: 75 })
            this.actionRow(child, node.id, childIndex, node.children.length)
          }, (child: PromptNode) => child.id)
        }
      }.width('100%')
    } else {
      this.actionRow(node, '', index, this.visibleItems().length)
    }
  }

  @Builder
  private appliesCard(label: string, anchor: string, icon: string) {
    Column({ space: 6 }) {
      RemixIcon({
        glyph: icon,
        iconSize: 28,
        color: this.editing.appliesTo.includes(anchor) ? Theme.ACCENT : Theme.FAINT
      })
      Text(label).fontSize(14)
        .fontColor(this.editing.appliesTo.includes(anchor) ? Theme.ACCENT : Theme.SECONDARY)
      Row() {
        if (this.editing.appliesTo.includes(anchor)) {
          RemixIcon({ glyph: RI.CHECK, iconSize: 17, color: Color.White })
        }
      }.width(24).height(24).justifyContent(FlexAlign.Center)
        .backgroundColor(this.editing.appliesTo.includes(anchor) ? Theme.ACCENT : Color.Transparent)
        .border({
          width: this.editing.appliesTo.includes(anchor) ? 0 : 1,
          color: '#C9C1B5',
          radius: 6
        }).borderRadius(6)
    }
      .height(112)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Theme.CARD)
      .border({
        width: this.editing.appliesTo.includes(anchor) ? 2 : 1,
        color: this.editing.appliesTo.includes(anchor) ? Theme.ACCENT : '#E5DED2',
        radius: 14
      })
      .borderRadius(14)
      .onClick(() => this.toggleAnchor(anchor, !this.editing.appliesTo.includes(anchor)))
  }

  @Builder
  private editorPage() {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        PageHeader({
          title: this.originalId.length > 0 ? '编辑提示词' :
            (this.editing.isGroup() ? '新建分组' : '提示词'),
          onBack: () => this.showEditor = false
        })
        Button('保存')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
          .height(40).padding({ left: 19, right: 19 }).backgroundColor(Theme.ACCENT).borderRadius(11)
          .margin({ right: 16 }).onClick(() => this.saveEditor())
      }.height(56).width('100%')
      Scroll() {
        Column({ space: 7 }) {
          Text(this.editing.isGroup() ? '分组名字' : '菜单里的名字')
            .fontSize(14).fontColor(Theme.SECONDARY).width('100%')
          TextInput({ text: this.editing.label, placeholder: this.editing.isGroup() ? '分组名字' : '菜单名称' })
            .height(54).fontSize(16).padding({ left: 14, right: 14 })
            .backgroundColor(Theme.CARD).border({ width: 1, color: '#E5DED2', radius: 12 }).borderRadius(12)
            .onChange((value: string) => {
              const next: PromptNode = this.editing.copy(); next.label = value; this.editing = next;
            })
          if (!this.editing.isGroup()) {
            Text('提示词').fontSize(14).fontColor(Theme.SECONDARY).width('100%').margin({ top: 7 })
            TextArea({ text: this.editing.prompt, placeholder: '写下长按后要执行的指令' })
              .height(160).fontSize(16).lineHeight(23).padding(14)
              .backgroundColor(Theme.CARD).border({ width: 1, color: '#E5DED2', radius: 12 }).borderRadius(12)
              .onChange((value: string) => {
                const next: PromptNode = this.editing.copy(); next.prompt = value; this.editing = next;
              })
            Row() {
              Text('适用于').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.INK).layoutWeight(1)
              Text('决定在哪种长按里出现').fontSize(12).fontColor(Theme.FAINT)
            }.width('100%').margin({ top: 7 })
            Row({ space: 16 }) {
              this.appliesCard('文字', 'text', RI.QUILL_PEN)
              this.appliesCard('图片', 'image', RI.IMAGE)
            }.width('100%')
            if (this.originalId.length > 0 && !this.editing.isSystem()) {
              Row() {
                Column({ space: 3 }) {
                  Text('分享这条提示词').fontSize(15).fontColor(Theme.INK)
                  Text(this.shareEntries.some((entry: PromptShareEntry) =>
                    entry.id === this.originalId && entry.state.sharing) ? '正在分享，可查看分享码' : '发布到社区，并得到分享码短链')
                    .fontSize(12).fontColor(Theme.FAINT)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
              }
                .padding(16).margin({ top: 11 }).backgroundColor(Theme.CARD).borderRadius(14).width('100%')
                .onClick(() => this.openShare(this.editing))
            }
          }
          if (this.originalId.length > 0) {
            Button(this.editing.isGroup() ? '删除分组' : '删除提示词')
              .fontSize(14).fontColor('#B42318').backgroundColor('#FEECE8')
              .width('100%').height(46).margin({ top: 16 })
              .onClick(async () => {
                if (await this.remove(this.editing)) this.showEditor = false;
              })
          }
        }.padding({ left: 18, right: 18, top: 8, bottom: 28 }).width('100%')
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }.width('100%').height('100%').backgroundColor(Theme.BG)
  }

  private async restoreDefaults(): Promise<void> {
    const result = await promptAction.showDialog({
      title: '恢复默认提示词',
      message: '会补回缺少的系统提示词，不会删除自建内容。',
      buttons: [{ text: '取消', color: '#666666' }, { text: '恢复', color: Theme.ACCENT }]
    });
    if (result.index !== 1) return;
    const error: string = await promptStore.restoreDefaults();
    this.items = promptStore.items();
    promptAction.showToast({ message: error.length > 0 ? error : '已恢复默认提示词' });
  }

  build() {
    Stack() {
      Column() {
        Stack({ alignContent: Alignment.End }) {
          PageHeader({ title: '提示词', onBack: () => { if (this.sorting) this.cancelSort(); else this.onBack(); } })
          if (this.sorting) {
            Button('取消').fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
              .width(54).height(40).backgroundColor(Theme.BG)
              .position({ x: 10, y: 8 }).onClick(() => this.cancelSort())
            Button(this.savingSort ? '保存中…' : '完成')
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
              .height(40).padding({ left: 10, right: 10 }).backgroundColor(Color.Transparent)
              .enabled(!this.savingSort).margin({ right: 12 }).onClick(() => this.finishSort())
          } else {
            Button('+').fontSize(27).fontColor(Color.White).width(40).height(40)
              .backgroundColor(Theme.ACCENT).borderRadius(12).margin({ right: 16 })
              .onClick(() => this.showNewMenu = true)
          }
        }.height(56).width('100%')
        Scroll() {
          Column({ space: 12 }) {
            Text(this.sorting ? '长按提示词并拖动排序；也可使用右侧按钮精确调整。' :
              '一套指令，长按文字或图片时按『适用于』自动筛选。改过的系统项标『已自定义』，自己建的标『自建』，收下别人分享的标『导入』。')
              .fontSize(13).lineHeight(19).fontColor(Theme.SECONDARY).width('100%')
            if (this.loadWarning.length > 0) {
              Text('加载失败，正在显示上次内容')
                .fontSize(13).fontColor('#A44C28').padding({ left: 12, right: 12, top: 9, bottom: 9 })
                .backgroundColor('#FFEADB').borderRadius(9).width('100%')
            }
            if (this.loading) {
              Column({ space: 8 }) {
                LoadingProgress().width(28).height(28).color(Theme.ACCENT)
                Text('正在加载提示词…').fontSize(12).fontColor(Theme.FAINT)
              }.height(120).justifyContent(FlexAlign.Center).width('100%')
            } else if (this.visibleItems().length === 0) {
              Text('还没有提示词，可点击右上角新建')
                .fontSize(15).fontColor(Theme.FAINT).height(140).width('100%').textAlign(TextAlign.Center)
            } else {
              Column() {
                ForEach(this.visibleItems(), (node: PromptNode, index: number) => {
                  if (index > 0) Divider().color(Theme.DIVIDER).margin({ left: 59 })
                  this.promptNode(node, index)
                }, (node: PromptNode) => node.id)
              }
                .backgroundColor(Theme.CARD).border({ width: 1, color: Theme.BORDER, radius: 12 })
                .borderRadius(12).clip(true).width('100%')
            }
            if (!this.sorting) {
              this.marketSection()
              Row({ space: 12 }) {
                Row() { RemixIcon({ glyph: RI.DOWNLOAD, iconSize: 21, color: Theme.ACCENT }) }
                  .width(44).height(44).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(10)
                Column({ space: 3 }) {
                  Text('输入魔法数字导入').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                  Text('把别人分享的提示词存进你的菜单').fontSize(13).fontColor(Theme.SECONDARY)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
              }
                .padding({ left: 16, right: 14, top: 14, bottom: 14 }).backgroundColor('#FBF3E9')
                .border({ width: 1, color: '#D8B08A', radius: 12, style: BorderStyle.Dashed })
                .borderRadius(12).width('100%')
                .onClick(() => { this.preview = undefined; this.showImportSheet = true; })
              Text('也可以在录音时直接对 VoiceDrop 说出数字，或点开 voicedrop.cn 链接自动跳转到这里。')
                .fontSize(12).lineHeight(18).fontColor(Theme.FAINT)
                .padding({ left: 4, right: 4, top: 8 }).width('100%')
              Button('恢复默认提示词').fontSize(14).fontColor(Theme.ACCENT).height(52)
                .backgroundColor(Color.Transparent).width('100%').onClick(() => this.restoreDefaults())
            }
          }.padding({ left: 16, right: 16, top: 6, bottom: 40 }).width('100%')
        }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }.height('100%').backgroundColor(Theme.BG)
      if (this.showEditor) {
        this.editorPage()
      }
      if (this.showNewMenu) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.showNewMenu = false)
          Column({ space: 12 }) {
            Text('新建').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .width('100%').textAlign(TextAlign.Center).margin({ bottom: 2 })
            Row({ space: 12 }) {
              Row() { RemixIcon({ glyph: RI.EDIT, iconSize: 22, color: Theme.ACCENT }) }
                .width(48).height(48).justifyContent(FlexAlign.Center).backgroundColor(Theme.ACCENT_SOFT).borderRadius(10)
              Column({ space: 3 }) {
                Text('新建动作').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                Text('一条提示词指令').fontSize(13).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
            }.height(82).padding({ left: 14, right: 12 }).backgroundColor(Theme.CARD)
              .border({ width: 1, color: '#E6DDD1', radius: 14 }).borderRadius(14)
              .onClick(() => { this.showNewMenu = false; this.beginNew('action'); })
            Row({ space: 12 }) {
              Row() { RemixIcon({ glyph: RI.FOLDER, iconSize: 22, color: Theme.SECONDARY }) }
                .width(48).height(48).justifyContent(FlexAlign.Center).backgroundColor('#F2EEE7').borderRadius(10)
              Column({ space: 3 }) {
                Text('新建分组').fontSize(17).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
                Text('收纳几个动作，菜单里成为二级子菜单').fontSize(13).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
            }.height(82).padding({ left: 14, right: 12 }).backgroundColor(Theme.CARD)
              .border({ width: 1, color: '#E6DDD1', radius: 14 }).borderRadius(14)
              .onClick(() => { this.showNewMenu = false; this.beginNew('group'); })
          }.padding({ left: 16, right: 16, top: 24, bottom: 30 }).backgroundColor('#FFFBF6')
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#47000000')
      }
      if (this.showImportSheet) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.showImportSheet = false)
          Column({ space: 13 }) {
            Text('导入提示词').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .width('100%').textAlign(TextAlign.Center)
            Text('输入 7 位魔法数字，或粘贴分享链接').fontSize(14).fontColor(Theme.FAINT)
              .width('100%').textAlign(TextAlign.Center)
            TextInput({ text: this.importInput, placeholder: '7 位魔法数字' })
              .height(58).fontSize(18).textAlign(TextAlign.Center).backgroundColor(Theme.CARD)
              .border({ width: 1, color: '#E6DDD1', radius: 12 }).borderRadius(12)
              .onChange((value: string) => this.updateImportInput(value))
            Button(this.importPreviewLoading ? '正在读取…' : (this.preview ? '加入我的提示词' : '读取提示词'))
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
              .height(54).width('100%').backgroundColor(Theme.ACCENT).borderRadius(12)
              .enabled(!this.importPreviewLoading)
              .onClick(() => { if (this.preview) this.importPrompt(); else this.previewImport(); })
            if (this.preview) {
              Text(`将导入「${this.preview!.label}」`).fontSize(13).fontColor(Theme.SECONDARY)
                .width('100%').textAlign(TextAlign.Center)
            }
            Text('导入后是你自己的副本，可改名、改内容、随时删除；原作者之后的修改不影响你。')
              .fontSize(13).lineHeight(19).fontColor(Theme.FAINT).width('100%').textAlign(TextAlign.Center)
          }.padding({ left: 16, right: 16, top: 22, bottom: 26 }).backgroundColor('#FFFBF6')
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#47000000')
      }
      if (this.moveNodeId.length > 0) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.moveNodeId = '')
          Column({ space: 8 }) {
            Text('移动到').fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .width('100%').textAlign(TextAlign.Center).margin({ bottom: 4 })
            Row({ space: 12 }) {
              RemixIcon({ glyph: RI.FILE_TEXT, iconSize: 20, color: Theme.SECONDARY })
              Text('顶层菜单').fontSize(16).fontColor(Theme.INK).layoutWeight(1)
              RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
            }.height(54).padding({ left: 14, right: 14 }).backgroundColor(Theme.CARD).borderRadius(12)
              .onClick(() => this.moveSortNode(''))
            ForEach(this.sortDraft.filter((node: PromptNode) => node.isGroup()), (group: PromptNode) => {
              Row({ space: 12 }) {
                RemixIcon({ glyph: RI.FOLDER, iconSize: 20, color: Theme.SECONDARY })
                Text(group.label).fontSize(16).fontColor(Theme.INK).layoutWeight(1)
                Text(`${group.children.length} 项`).fontSize(12).fontColor(Theme.FAINT)
                RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
              }.height(54).padding({ left: 14, right: 14 }).backgroundColor(Theme.CARD).borderRadius(12)
                .onClick(() => this.moveSortNode(group.id))
            }, (group: PromptNode) => group.id)
          }.padding({ left: 16, right: 16, top: 22, bottom: 26 }).backgroundColor('#FFFBF6')
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#47000000')
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
                // 溯源转发：未修改的导入件分享的是原作者的码——文案不能说「关闭后码失效」
                Text(this.shareState.sharing
                  ? (this.shareState.borrowed ? '转发中：这是原作者的分享码，关闭只停止转发，码不会失效' : '分享中：社区可见，关闭后分享码失效、社区帖撤下')
                  : '开启后发布到社区，并得到分享码短链').fontSize(12).fontColor('#777777')
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
              // 溯源转发：未修改的导入件分享的是原作者的码，改动正文保存后会自动停止转发
              Text(this.shareState.borrowed ? '转发原作者的版本；改动正文保存后会自动停止转发' : '分享的始终是已保存的版本').fontSize(12).fontColor('#888888').width('100%').textAlign(TextAlign.Center)
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
