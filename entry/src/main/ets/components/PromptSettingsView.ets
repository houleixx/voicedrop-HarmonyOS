import { common } from '@kit.AbilityKit';
import { KeyboardAvoidMode, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
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
  @State private showGroupDialog: boolean = false;
  @State private groupName: string = '';
  @State private creatingGroup: boolean = false;
  @State private showImportSheet: boolean = false;
  @State private importPreviewLoading: boolean = false;
  @State private sorting: boolean = false;
  @State private savingSort: boolean = false;
  @State private sortDraft: PromptNode[] = [];
  @State private sortRenderRevision: number = 0;
  @State private moveNodeId: string = '';
  @State private showEditor: boolean = false;
  @State private editing: PromptNode = new PromptNode();
  @State private originalId: string = '';
  @State private targetGroup: string = '';
  @State private importInput: string = '';
  @State private preview?: PromptPreview = undefined;
  @State private shareEntries: PromptShareEntry[] = [];
  @State private shareState: PromptShareState = new PromptShareState();
  @State private editorShareLoading: boolean = false;
  @State private shareWorking: boolean = false;
  @State private draggingId: string = '';
  @State private dragTargetId: string = '';
  @State private swipeNodeId: string = '';
  @State private swipeOffsetX: number = 0;
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
  private swipeStartOffsetX: number = 0;
  private editorOriginal: PromptNode = new PromptNode();
  private importKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  private importKeyboardAvoidModeSaved: boolean = false;

  aboutToAppear(): void {
    if (/^[1-9][0-9]{6}$/.test(this.initialCode)) this.importInput = this.initialCode;
    this.load().then(() => {
      if (this.importInput.length > 0) {
        this.openImportSheet();
        this.previewImport();
      }
    });
    this.loadMarket();
  }

  aboutToDisappear(): void {
    this.restoreImportKeyboardAvoidMode();
  }

  private openImportSheet(): void {
    if (!this.showImportSheet) {
      this.importKeyboardAvoidMode = this.getUIContext().getKeyboardAvoidMode();
      this.importKeyboardAvoidModeSaved = true;
      this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    }
    this.showImportSheet = true;
  }

  private closeImportSheet(): void {
    this.showImportSheet = false;
    this.restoreImportKeyboardAvoidMode();
  }

  private restoreImportKeyboardAvoidMode(): void {
    if (!this.importKeyboardAvoidModeSaved) return;
    this.getUIContext().setKeyboardAvoidMode(this.importKeyboardAvoidMode);
    this.importKeyboardAvoidModeSaved = false;
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
    this.closePromptSwipe();
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
    this.closePromptSwipe();
    this.marketPreview = undefined; this.marketPreviewLoading = true;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => this.marketDetail = item);
    const preview: PromptPreview | undefined = await promptStore.preview(item.code);
    if (this.marketDetail?.code !== item.code) return;
    this.marketPreview = preview; this.marketPreviewLoading = false;
  }

  private closeMarketDetail(): void {
    animateTo({ duration: 200, curve: Curve.EaseIn }, () => this.marketDetail = undefined);
    this.marketPreview = undefined; this.marketPreviewLoading = false;
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
          LoadingProgress().width(24).height(24).color(Theme.ACCENT_STRONG)
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
              Row() {
                RemixIcon({
                  glyph: item.appliesTo.includes('image') && !item.appliesTo.includes('text') ?
                    RI.IMAGE : RI.FILE_TEXT,
                  iconSize: 17,
                  color: item.appliesTo.includes('image') && !item.appliesTo.includes('text') ?
                    Theme.ACCENT : Theme.SECONDARY
                })
              }
                .width(32).height(32).justifyContent(FlexAlign.Center)
                .backgroundColor(item.appliesTo.includes('image') ?
                  Theme.ACCENT_SOFT : '#F2EEE7')
                .borderRadius(8)
              Column({ space: 3 }) {
                Text(item.label).fontSize(15).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${item.author || '匿名'} · 导入 ${item.importCount}`).fontSize(12).fontColor(Theme.SECONDARY)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              if (this.importingMarketCode === item.code) {
                LoadingProgress().width(26).height(26).color(Theme.ACCENT_STRONG)
              }
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
    this.loading = false;
    const warning: string = await promptStore.refresh(); this.items = promptStore.items();
    this.loadWarning = warning;
    const states: Map<string, PromptShareState> = await promptStore.shareStates();
    const entries: PromptShareEntry[] = []; states.forEach((state: PromptShareState, id: string) => entries.push(new PromptShareEntry(id, state)));
    this.shareEntries = entries;
  }

  private beginNew(type: string, groupId: string = ''): void {
    this.closePromptSwipe();
    const node: PromptNode = new PromptNode(); node.id = PromptTree.newUserId(); node.type = type;
    node.origin = 'user';
    node.label = ''; node.appliesTo = type === 'action' ? ['text', 'image'] : [];
    this.editorOriginal = node.copy();
    this.editing = node; this.originalId = ''; this.targetGroup = groupId;
    this.shareState = new PromptShareState(); this.editorShareLoading = false;
    this.openEditorPage();
  }

  private beginEdit(node: PromptNode): void {
    this.closePromptSwipe();
    this.editorOriginal = node.copy();
    this.editing = node.isSystem() ? PromptTree.fork(node) : node.copy();
    this.originalId = node.id; this.targetGroup = '';
    this.openEditorPage();
    this.loadEditorShareState(node.id);
  }

  private openGroupDialog(): void {
    this.closePromptSwipe();
    this.groupName = '';
    this.creatingGroup = false;
    this.showGroupDialog = true;
  }

  private async createGroup(): Promise<void> {
    const label: string = this.groupName.trim();
    if (label.length === 0) {
      promptAction.showToast({ message: '请输入分组名字' });
      return;
    }
    if (this.creatingGroup) return;
    const group: PromptNode = new PromptNode();
    group.id = PromptTree.newUserId();
    group.type = 'group';
    group.label = label;
    group.origin = 'user';
    this.creatingGroup = true;
    const error: string = await promptStore.add(group);
    this.creatingGroup = false;
    if (error.length > 0) {
      promptAction.showToast({ message: error });
      return;
    }
    this.items = promptStore.items();
    this.showGroupDialog = false;
  }

  private openEditorPage(): void {
    animateTo({ duration: 240, curve: Curve.EaseOut }, () => this.showEditor = true);
  }

  private closeEditorPage(): void {
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => this.showEditor = false);
  }

  private async loadEditorShareState(id: string): Promise<void> {
    const cached: PromptShareEntry | undefined =
      this.shareEntries.find((value: PromptShareEntry) => value.id === id);
    this.shareState = cached?.state ?? new PromptShareState();
    this.editorShareLoading = true;
    const states: Map<string, PromptShareState> = await promptStore.shareStates();
    if (!this.showEditor || this.originalId !== id) return;
    const state: PromptShareState = states.get(id) ?? new PromptShareState();
    this.shareState = state;
    const entries: PromptShareEntry[] = [];
    states.forEach((value: PromptShareState, nodeId: string) =>
      entries.push(new PromptShareEntry(nodeId, value)));
    this.shareEntries = entries;
    this.editorShareLoading = false;
  }

  private async saveEditor(): Promise<void> {
    if (this.editing.label.trim().length === 0) { promptAction.showToast({ message: '请输入名称'}); return; }
    if (!this.editing.isGroup() && this.editing.prompt.trim().length === 0) { promptAction.showToast({ message: '请输入提示词内容'}); return; }
    let error: string = '';
    if (this.originalId.length > 0) error = await promptStore.replace(this.originalId, this.editing);
    else error = await promptStore.add(this.editing, this.targetGroup.length > 0 ? this.targetGroup : undefined);
    if (error.length > 0) promptAction.showToast({ message: error});
    else { this.items = promptStore.items(); this.closeEditorPage(); }
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

  private visibleItems(): PromptNode[] {
    return this.sorting ? this.sortDraft : this.items;
  }

  private beginSort(): void {
    if (this.sorting) return;
    this.closePromptSwipe();
    this.sortDraft = PromptTree.copy(this.items);
    this.sorting = true;
    this.showNewMenu = false;
  }

  private cancelSort(): void {
    if (this.savingSort) return;
    this.sorting = false;
    this.sortDraft = [];
    this.draggingId = '';
    this.dragTargetId = '';
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
    this.draggingId = '';
    this.dragTargetId = '';
  }

  private toggleGroup(id: string): void {
    this.closePromptSwipe();
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
    if (moved) {
      this.sortDraft = moved;
      this.sortRenderRevision++;
    }
    this.moveNodeId = '';
  }

  private beginDrag(node: PromptNode): void {
    if (!this.sorting) return;
    this.draggingId = node.id;
    this.dragTargetId = '';
  }

  private enterDragTarget(nodeId: string): void {
    if (!this.sorting || this.draggingId.length === 0 || this.draggingId === nodeId) return;
    this.dragTargetId = nodeId;
  }

  private leaveDragTarget(nodeId: string): void {
    if (this.dragTargetId === nodeId) this.dragTargetId = '';
  }

  private dropSortNode(target: PromptNode, targetGroupId: string): void {
    if (!this.sorting || this.draggingId.length === 0 || this.draggingId === target.id) return;
    const moving: PromptNode | undefined = this.sortNode(this.draggingId);
    if (!moving) return;
    let groupId: string = targetGroupId;
    let targetIndex: number = 0;
    if (target.isGroup() && !moving.isGroup()) {
      groupId = target.id;
      targetIndex = target.children.length;
    } else {
      if (moving.isGroup() && groupId.length > 0) return;
      const siblings: PromptNode[] = groupId.length > 0 ?
        (this.sortDraft.find((node: PromptNode) => node.id === groupId)?.children ?? []) :
        this.sortDraft;
      targetIndex = siblings.findIndex((node: PromptNode) => node.id === target.id);
      if (targetIndex < 0) return;
    }
    const moved: PromptNode[] | undefined = PromptTree.move(this.sortDraft, moving.id,
      groupId.length > 0 ? groupId : undefined, targetIndex);
    if (moved) {
      this.sortDraft = moved;
      if (groupId.length > 0 && !this.expandedGroups.includes(groupId)) {
        this.expandedGroups = this.expandedGroups.concat([groupId]);
      }
      this.sortRenderRevision++;
      this.draggingId = '';
    }
    this.dragTargetId = '';
  }

  private endDrag(): void {
    this.draggingId = '';
    this.dragTargetId = '';
  }

  private startPromptDrag(node: PromptNode): DragItemInfo {
    if (!this.sorting) this.beginSort();
    this.beginDrag(node);
    return {
      builder: () => { this.promptDragPreview(node) },
      extraInfo: node.id
    };
  }

  private beginPromptSwipe(nodeId: string): void {
    if (this.sorting) return;
    this.swipeStartOffsetX = this.swipeNodeId === nodeId ? this.swipeOffsetX : 0;
    this.swipeNodeId = nodeId;
    this.swipeOffsetX = this.swipeStartOffsetX;
  }

  private updatePromptSwipe(nodeId: string, offsetX: number): void {
    if (this.sorting || this.swipeNodeId !== nodeId) return;
    this.swipeOffsetX = Math.max(-88, Math.min(0, this.swipeStartOffsetX + offsetX));
  }

  private finishPromptSwipe(nodeId: string): void {
    if (this.swipeNodeId !== nodeId) return;
    const expanded: boolean = !this.sorting && this.swipeOffsetX <= -44;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.swipeOffsetX = expanded ? -88 : 0;
      if (!expanded) this.swipeNodeId = '';
    });
  }

  private closePromptSwipe(): void {
    if (this.swipeNodeId.length === 0) return;
    animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
      this.swipeOffsetX = 0;
      this.swipeNodeId = '';
    });
  }

  private promptSwipeOffset(nodeId: string): number {
    return this.swipeNodeId === nodeId ? this.swipeOffsetX : 0;
  }

  @Builder
  private promptDragPreview(node: PromptNode) {
    Row({ space: 10 }) {
      Row() {
        RemixIcon({
          glyph: node.isGroup() ? RI.FOLDER :
            (node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? RI.IMAGE : RI.FILE_TEXT),
          iconSize: 18,
          color: node.appliesTo.includes('image') && !node.appliesTo.includes('text') ? Theme.ACCENT : Theme.SECONDARY
        })
      }
        .width(34).height(34).justifyContent(FlexAlign.Center)
        .backgroundColor(node.appliesTo.includes('image') ? Theme.ACCENT_SOFT : '#F2EEE7')
        .borderRadius(9)
      Text(node.label).fontSize(15).fontColor(Theme.INK).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
    }
      .width(236)
      .height(54)
      .padding({ left: 12, right: 14 })
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.BORDER, radius: 12 })
      .borderRadius(12)
      .shadow({ radius: 12, color: '#28000000', offsetX: 0, offsetY: 5 })
  }

  @Builder
  private dragHandle(node: PromptNode) {
    Text('≡').fontSize(25).fontColor(this.draggingId === node.id ? '#111111' : '#8B8B87')
      .width(30).height(40).textAlign(TextAlign.Center)
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
      this.closeImportSheet(); promptAction.showToast({ message: '导入成功'});
    }
  }

  private async toggleSharing(): Promise<void> {
    if (this.originalId.length === 0 || this.shareWorking) return;
    this.shareWorking = true;
    const previous: PromptShareState = this.shareState;
    const state: PromptShareState = await promptStore.setSharing(this.originalId, !previous.sharing);
    this.shareWorking = false;
    if (state.error.length > 0) { promptAction.showToast({ message: state.error}); return; }
    this.shareState = state;
    this.shareEntries = this.shareEntries.filter((value: PromptShareEntry) => value.id !== this.originalId)
      .concat([new PromptShareEntry(this.originalId, state)]);
  }

  private copyShare(value: string): void {
    const data: pasteboard.PasteData = pasteboard.createPlainTextData(value);
    pasteboard.getSystemPasteboard().setData(data); promptAction.showToast({ message: '已复制'});
  }

  private async sharePrompt(code: string): Promise<void> {
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const record: systemShare.SharedRecord = {
        utd: 'general.plain-text',
        content: Api.sharePage(code),
        title: '分享提示词'
      };
      const data: systemShare.SharedData = new systemShare.SharedData(record);
      await new systemShare.ShareController(data).show(context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (_) {
      promptAction.showToast({ message: '无法打开系统分享面板' });
    }
  }

  private hasUnsavedEditorChanges(): boolean {
    return this.editing.label.trim() !== this.editorOriginal.label.trim() ||
      this.editing.prompt.trim() !== this.editorOriginal.prompt.trim() ||
      this.editing.appliesTo.includes('text') !== this.editorOriginal.appliesTo.includes('text') ||
      this.editing.appliesTo.includes('image') !== this.editorOriginal.appliesTo.includes('image');
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
  private originBadge(node: PromptNode) {
    Row() {
      Text(this.originLabel(node))
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.originColor(node))
    }
      .padding({ left: 2, right: 2, top: 2, bottom: 2 })
      .backgroundColor(this.originBackground(node))
      .borderRadius(4)
  }

  @Builder
  private promptDeleteAction(node: PromptNode) {
    Button('删除')
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor(Color.White)
      .width(88)
      .height(52)
      .padding(0)
      .backgroundColor('#D94B3D')
      .borderRadius(0)
      .onClick(async () => {
        this.closePromptSwipe();
        await this.remove(node);
      })
  }

  @Builder
  private actionRow(node: PromptNode, groupId: string) {
    Stack({ alignContent: Alignment.End }) {
      if (!this.sorting && this.swipeNodeId === node.id) {
        this.promptDeleteAction(node)
      }
      Row({ space: 10 }) {
        if (this.sorting) this.dragHandle(node)
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
              this.originBadge(node)
            }
          }.width('100%')
          if (this.appliesLabel(node).length > 0) {
            Text(this.appliesLabel(node)).fontSize(11)
              .fontColor(this.appliesLabel(node) === '仅图片' ? Theme.ACCENT :
                (this.appliesLabel(node) === '仅文字' ? Theme.GREEN : Theme.SECONDARY))
              .padding({ left: 2, right: 2, top: 2, bottom: 2 })
              .backgroundColor(this.appliesLabel(node) === '仅图片' ? Theme.ACCENT_SOFT :
                (this.appliesLabel(node) === '仅文字' ? Theme.GREEN_BG : '#F2EEE7'))
              .borderRadius(4)
          }
        }
          .layoutWeight(1)
          .constraintSize({ minWidth: 0 })
          .alignItems(HorizontalAlign.Start)
        if (this.sorting) {
          Button() {
            RemixIcon({ glyph: RI.FOLDER, iconSize: 16, color: Theme.SECONDARY })
          }.width(30).height(32).padding(0).backgroundColor(Color.Transparent)
            .onClick(() => this.moveNodeId = node.id)
        } else {
          RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
        }
      }
        .constraintSize({ minHeight: 52 })
        .padding({ left: groupId.length > 0 ? 31 : 15, right: 15, top: 9, bottom: 9 })
        .backgroundColor(this.draggingId === node.id || this.dragTargetId === node.id ?
          Theme.ACCENT_SOFT : Theme.CARD)
        .width('100%')
        .translate({ x: this.promptSwipeOffset(node.id) })
        .onClick(() => {
          if (this.sorting) return;
          if (this.swipeNodeId.length > 0) {
            this.closePromptSwipe();
          } else {
            this.beginEdit(node);
          }
        })
        .draggable(true)
        .onDragStart(() => this.startPromptDrag(node))
        .onDragEnd(() => this.endDrag())
        .onDragEnter(() => this.enterDragTarget(node.id))
        .onDragLeave(() => this.leaveDragTarget(node.id))
        .onDrop(() => this.dropSortNode(node, groupId))
        .priorityGesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
            .onActionStart(() => this.beginPromptSwipe(node.id))
            .onActionUpdate((event: GestureEvent) => this.updatePromptSwipe(node.id, event.offsetX))
            .onActionEnd(() => this.finishPromptSwipe(node.id))
            .onActionCancel(() => this.finishPromptSwipe(node.id))
        )
    }
      .width('100%')
      .clip(true)
  }

  @Builder
  private promptNode(node: PromptNode) {
    if (node.isGroup()) {
      Column() {
        Row({ space: 10 }) {
          if (this.sorting) this.dragHandle(node)
          Row() {
            RemixIcon({ glyph: RI.FOLDER, iconSize: 18, color: Theme.SECONDARY })
          }.width(32).height(32).justifyContent(FlexAlign.Center).backgroundColor('#F2EEE7').borderRadius(8)
          Row({ space: 6 }) {
            Text(node.label).fontSize(15).fontColor(Theme.INK).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (this.originLabel(node).length > 0) {
              this.originBadge(node)
            }
            Text(`分组 · ${node.children.length} 项`).fontSize(12).fontColor(Theme.SECONDARY)
          }.layoutWeight(1).constraintSize({ minWidth: 0 })
          if (!this.sorting) {
            RemixIcon({ glyph: RI.ARROW_RIGHT, iconSize: 17, color: Theme.FAINT })
              .rotate({ angle: this.expandedGroups.includes(node.id) ? 90 : 0 })
          }
        }
          .constraintSize({ minHeight: 52 })
          .padding({ left: 15, right: 15, top: 9, bottom: 9 })
          .backgroundColor(this.dragTargetId === node.id ? Theme.ACCENT_SOFT : Theme.CARD)
          .width('100%')
          .onClick(() => { if (!this.sorting) this.toggleGroup(node.id); })
          .draggable(true)
          .onDragStart(() => this.startPromptDrag(node))
          .onDragEnd(() => this.endDrag())
          .onDragEnter(() => this.enterDragTarget(node.id))
          .onDragLeave(() => this.leaveDragTarget(node.id))
          .onDrop(() => this.dropSortNode(node, ''))
        if (this.expandedGroups.includes(node.id)) {
          ForEach(node.children, (child: PromptNode) => {
            Divider().color(Theme.DIVIDER).margin({ left: 75 })
            this.actionRow(child, node.id)
          }, (child: PromptNode) => `${node.id}-${child.id}-${this.sortRenderRevision}`)
        }
      }.width('100%')
    } else {
      this.actionRow(node, '')
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
  private editorShareAction(label: string, glyph: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 4 }) {
        RemixIcon({ glyph: glyph, iconSize: 15, color: Theme.ACCENT })
        Text(label).fontSize(12).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
      }.justifyContent(FlexAlign.Center)
    }
      .height(40)
      .layoutWeight(1)
      .padding({ left: 5, right: 5 })
      .backgroundColor(Theme.ACCENT_SOFT)
      .borderRadius(8)
      .onClick(action)
  }

  @Builder
  private editorShareCard() {
    Column({ space: 10 }) {
      if (this.editorShareLoading) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color(Theme.ACCENT_STRONG)
          Text('正在加载分享状态…').fontSize(13).fontColor(Theme.FAINT)
        }.height(44).width('100%')
      } else {
        Row() {
          Column({ space: 3 }) {
            Text('分享这条提示词').fontSize(15).fontColor(Theme.INK)
            Text(this.shareState.sharing
              ? (this.shareState.borrowed ?
                '转发中：这是原作者的分享码，关闭只停止转发，码不会失效' :
                '分享中：社区可见，关闭后分享码失效、社区帖撤下') :
              '开启后发布到社区，并得到分享码短链')
              .fontSize(12).lineHeight(17).fontColor(Theme.FAINT)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.shareState.sharing })
            .enabled(!this.shareWorking)
            .onChange((enabled: boolean) => {
              if (enabled !== this.shareState.sharing) this.toggleSharing();
            })
        }.width('100%')
        if (this.shareState.sharing && this.shareState.code.length > 0) {
          Text(this.shareState.code)
            .fontSize(34).fontWeight(FontWeight.Bold).letterSpacing(5)
            .fontColor(Theme.INK).width('100%').textAlign(TextAlign.Center)
            .margin({ top: 2 })
          Text(`voicedrop.cn/${this.shareState.code}`)
            .fontSize(13).fontColor(Theme.SECONDARY).width('100%').textAlign(TextAlign.Center)
          Row({ space: 8 }) {
            this.editorShareAction('复制数字', RI.FILE_COPY, () => this.copyShare(this.shareState.code))
            this.editorShareAction('复制链接', RI.LINK,
              () => this.copyShare(Api.sharePage(this.shareState.code)))
            this.editorShareAction('分享…', RI.SHARE_FORWARD,
              () => this.sharePrompt(this.shareState.code))
          }.width('100%')
          if (this.shareState.borrowed || this.hasUnsavedEditorChanges()) {
            Text(this.shareState.borrowed ?
              '转发原作者的版本；改动正文保存后会自动停止转发' :
              '当前修改尚未保存，分享的仍是已保存版本')
              .fontSize(12).lineHeight(17).fontColor(Theme.FAINT)
              .width('100%').textAlign(TextAlign.Center)
          }
        }
      }
    }
      .padding(16)
      .margin({ top: 11 })
      .backgroundColor(Theme.CARD)
      .borderRadius(14)
      .width('100%')
  }

  @Builder
  private editorPage() {
    Column() {
      Stack({ alignContent: Alignment.End }) {
        PageHeader({
          title: this.originalId.length > 0 ? '编辑提示词' :
            (this.editing.isGroup() ? '新建分组' : '提示词'),
          onBack: () => this.closeEditorPage()
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
              this.editorShareCard()
            }
          }
          if (this.originalId.length > 0) {
            Button(this.editing.isGroup() ? '删除分组' : '删除提示词')
              .fontSize(14).fontColor('#B42318').backgroundColor('#FEECE8')
              .width('100%').height(46).margin({ top: 16 })
              .onClick(async () => {
                if (await this.remove(this.editing)) this.closeEditorPage();
              })
          }
        }
          .padding({ left: 18, right: 18, top: 8, bottom: 28 })
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(Theme.BG)
      .transition(TransitionEffect.move(TransitionEdge.END)
        .animation({ duration: 240, curve: Curve.EaseOut }))
  }

  private async restoreDefaults(): Promise<void> {
    this.closePromptSwipe();
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
          if (this.sorting) {
            Text('提示词')
              .fontSize(23).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .width('100%').height(56).textAlign(TextAlign.Center)
            Row() {
              Text('取消')
                .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Theme.ACCENT)
                .width(52).height(40).textAlign(TextAlign.Center)
                .onClick(() => this.cancelSort())
              Blank()
              Text(this.savingSort ? '保存中…' : '完成')
                .fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor(this.savingSort ? Theme.FAINT : Theme.ACCENT)
                .width(this.savingSort ? 72 : 52).height(40).textAlign(TextAlign.Center)
                .enabled(!this.savingSort)
                .onClick(() => this.finishSort())
            }.width('100%').height(56).padding({ left: 10, right: 12 })
          } else {
            PageHeader({ title: '提示词', onBack: () => this.onBack() })
            Button({ type: ButtonType.Normal }) {
              Stack({ alignContent: Alignment.Center }) {
                Row().width(18).height(2).backgroundColor(Color.White).borderRadius(1)
                Row().width(2).height(18).backgroundColor(Color.White).borderRadius(1)
              }.width(24).height(24)
            }
              .width(40).height(40).padding(0)
              .backgroundColor(Theme.ACCENT).borderRadius(12).margin({ right: 16 })
              .onClick(() => {
                this.closePromptSwipe();
                this.showNewMenu = true;
              })
          }
        }.height(56).width('100%')
        Scroll() {
          Column({ space: 12 }) {
            Text(this.sorting ? '长按提示词并拖动排序；拖到分组行可收进该组。' :
              '一套指令，长按文字或图片时按『适用于』自动筛选。改过的系统项标『已自定义』，自己建的标『自建』，收下别人分享的标『导入』。')
              .fontSize(13).lineHeight(19).fontColor(Theme.SECONDARY).width('100%')
            if (this.loadWarning.length > 0) {
              Text('加载失败，正在显示上次内容')
                .fontSize(13).fontColor('#A44C28').padding({ left: 12, right: 12, top: 9, bottom: 9 })
                .backgroundColor('#FFEADB').borderRadius(9).width('100%')
            }
            if (this.loading) {
              Column({ space: 8 }) {
                LoadingProgress().width(28).height(28).color(Theme.ACCENT_STRONG)
                Text('正在加载提示词…').fontSize(12).fontColor(Theme.FAINT)
              }.height(120).justifyContent(FlexAlign.Center).width('100%')
            } else if (this.visibleItems().length === 0) {
              Text('还没有提示词，可点击右上角新建')
                .fontSize(15).fontColor(Theme.FAINT).height(140).width('100%').textAlign(TextAlign.Center)
            } else {
              Column() {
                ForEach(this.visibleItems(), (node: PromptNode, index: number) => {
                  if (index > 0) Divider().color(Theme.DIVIDER).margin({ left: 59 })
                  this.promptNode(node)
                }, (node: PromptNode) => `${node.id}-${this.sortRenderRevision}`)
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
                .onClick(() => {
                  this.closePromptSwipe();
                  this.preview = undefined;
                  this.openImportSheet();
                })
              Text('也可以在录音时直接对 VoiceDrop 说出数字，或点开 voicedrop.cn 链接自动跳转到这里。')
                .fontSize(12).lineHeight(18).fontColor(Theme.FAINT)
                .padding({ left: 4, right: 4, top: 8 }).width('100%')
              Button('恢复默认提示词').fontSize(14).fontColor(Theme.ACCENT).height(52)
                .backgroundColor(Color.Transparent).width('100%').onClick(() => this.restoreDefaults())
            }
          }.padding({ left: 16, right: 16, top: 6, bottom: 40 }).width('100%')
        }
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .onScroll((_xOffset: number, yOffset: number) => {
            if (Math.abs(yOffset) > 0.5) this.closePromptSwipe();
          })
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
              .onClick(() => {
                this.showNewMenu = false;
                this.openGroupDialog();
              })
          }.padding({ left: 16, right: 16, top: 24, bottom: 30 }).backgroundColor('#FFFBF6')
            .borderRadius({ topLeft: 22, topRight: 22 }).width('100%')
        }.width('100%').height('100%').backgroundColor('#47000000')
      }
      if (this.showGroupDialog) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('#66000000')
            .onClick(() => {
              if (!this.creatingGroup) this.showGroupDialog = false;
            })
          Column({ space: 14 }) {
            Text('新建分组')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(Theme.INK)
              .width('100%').textAlign(TextAlign.Center)
            TextInput({ text: this.groupName, placeholder: '分组名字' })
              .height(54).fontSize(17).padding({ left: 14, right: 14 })
              .defaultFocus(true)
              .backgroundColor(Theme.CARD)
              .border({ width: 1, color: '#E0D8CC', radius: 12 })
              .borderRadius(12)
              .onChange((value: string) => this.groupName = value)
            Row({ space: 10 }) {
              Button('取消')
                .layoutWeight(1).height(44)
                .fontSize(15).fontColor(Theme.SECONDARY)
                .backgroundColor('#F2EEE7')
                .enabled(!this.creatingGroup)
                .onClick(() => this.showGroupDialog = false)
              Button(this.creatingGroup ? '创建中…' : '创建')
                .layoutWeight(1).height(44)
                .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .backgroundColor(Theme.ACCENT)
                .enabled(!this.creatingGroup)
                .onClick(() => this.createGroup())
            }.width('100%')
          }
            .padding({ left: 18, right: 18, top: 20, bottom: 18 })
            .width('84%')
            .constraintSize({ maxWidth: 360 })
            .backgroundColor('#FFFBF6')
            .borderRadius(18)
            .shadow({ radius: 18, color: '#33000000', offsetX: 0, offsetY: 8 })
        }.width('100%').height('100%')
      }
      if (this.showImportSheet) {
        Column() {
          Blank().layoutWeight(1).onClick(() => this.closeImportSheet())
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
      if (this.marketDetail) {
        Stack({ alignContent: Alignment.Bottom }) {
          Column()
            .width('100%').height('100%').backgroundColor('#66000000')
            .onClick(() => this.closeMarketDetail())
          Column() {
            Scroll() {
              Column({ space: 13 }) {
                Row() {
                  Text(this.marketType(this.marketDetail!))
                    .fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(this.marketDetail!.appliesTo.includes('image') ? Theme.ACCENT : Theme.GREEN)
                    .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                    .backgroundColor(this.marketDetail!.appliesTo.includes('image') ?
                      Theme.ACCENT_SOFT : '#EAF1EC')
                    .borderRadius(4)
                  Blank()
                  Button({ type: ButtonType.Normal }) {
                    RemixIcon({ glyph: RI.CLOSE, iconSize: 22, color: Theme.SECONDARY })
                  }
                    .width(40).height(40).padding(0).backgroundColor(Color.Transparent)
                    .onClick(() => this.closeMarketDetail())
                }.width('100%')
                Text(this.marketDetail!.label)
                  .fontSize(23).fontWeight(FontWeight.Bold).fontColor(Theme.INK).width('100%')
                Row({ space: 8 }) {
                  Text((this.marketDetail!.author || '友').substring(0, 1))
                    .fontSize(11).fontWeight(FontWeight.Bold).fontColor(Color.White)
                    .width(24).height(24).textAlign(TextAlign.Center)
                    .backgroundColor('#D8A25B').borderRadius(12)
                  Text(this.marketDetail!.author || '匿名分享者')
                    .fontSize(13).fontColor(Theme.SECONDARY)
                }.width('100%')
                Row() {
                  Column({ space: 2 }) {
                    Text(`${this.marketDetail!.importCount}`).fontSize(18).fontWeight(FontWeight.Bold)
                    Text('被导入').fontSize(11).fontColor(Theme.FAINT)
                  }.layoutWeight(1)
                  Divider().vertical(true).height(30).color(Theme.DIVIDER)
                  Column({ space: 2 }) {
                    Text(this.marketApplies(this.marketDetail!)).fontSize(18).fontWeight(FontWeight.Bold)
                    Text('适用于').fontSize(11).fontColor(Theme.FAINT)
                  }.layoutWeight(1)
                }
                  .height(78).backgroundColor(Theme.CARD)
                  .border({ width: 1, color: Theme.BORDER, radius: 5 })
                  .borderRadius(5).width('100%')
                Text('提示词全文')
                  .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY).width('100%')
                if (this.marketPreviewLoading) {
                  Row({ space: 8 }) {
                    LoadingProgress().width(22).height(22).color(Theme.ACCENT_STRONG)
                    Text('加载中…').fontSize(14).fontColor(Theme.SECONDARY)
                  }
                    .padding(14).backgroundColor(Theme.CARD)
                    .border({ width: 1, color: Theme.BORDER, radius: 5 })
                    .borderRadius(5).width('100%')
                } else {
                  Text(this.marketPreview?.prompt || '（全文加载失败）')
                    .fontSize(14).lineHeight(22).fontColor('#5B5349')
                    .padding(14).backgroundColor(Theme.CARD)
                    .border({ width: 1, color: Theme.BORDER, radius: 5 })
                    .borderRadius(5).width('100%')
                }
                if (this.marketDetail!.exampleInput.length > 0 ||
                  this.marketDetail!.exampleOutput.length > 0) {
                  Text('效果示例')
                    .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Theme.SECONDARY).width('100%')
                  if (this.marketDetail!.exampleInput.length > 0) {
                    Text(this.marketDetail!.exampleInput)
                      .fontSize(13).lineHeight(20).fontColor(Theme.FAINT).width('100%')
                  }
                  if (this.marketDetail!.exampleOutput.length > 0) {
                    Text(this.marketDetail!.exampleOutput)
                      .fontSize(14).lineHeight(21).fontColor(Theme.INK).width('100%')
                  }
                }
              }.padding({ left: 18, right: 18, top: 12, bottom: 18 }).width('100%')
            }.layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
            Column() {
              Button(PromptTree.containsImport(this.items, this.marketDetail!.code) ?
                '已在我的提示词里' :
                (this.importingMarketCode === this.marketDetail!.code ? '正在导入…' : '加入我的提示词'))
                .fontSize(17).fontWeight(FontWeight.Bold).fontColor(Color.White)
                .enabled(!PromptTree.containsImport(this.items, this.marketDetail!.code) &&
                  this.importingMarketCode.length === 0)
                .opacity(this.importingMarketCode === this.marketDetail!.code ? 0.55 : 1)
                .stateEffect(false)
                .width('100%').height(54)
                .backgroundColor(PromptTree.containsImport(this.items, this.marketDetail!.code) ?
                  '#C2B9A8' : Theme.ACCENT)
                .borderRadius(12)
                .onClick(() => this.importMarket(this.marketDetail!))
            }.padding({ left: 18, right: 18, top: 10, bottom: 12 }).backgroundColor(Theme.BG).width('100%')
          }
            .width('100%').height('75%').backgroundColor(Theme.BG)
            .borderRadius({ topLeft: 20, topRight: 20 }).clip(true)
            .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
              .animation({ duration: 220, curve: Curve.EaseOut }))
        }.width('100%').height('100%')
      }
    }
  }
}
