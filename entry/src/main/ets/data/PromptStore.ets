import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Api } from '../core/Api';
import { PromptNode, PromptTree, PromptMutation, defaultPrompts } from '../core/PromptTree';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';
import { ClientReliability } from '../core/ClientReliability';

class CodeBody { code: string; constructor(code: string) { this.code = code; } }
class IdBody { id: string; constructor(id: string) { this.id = id; } }
export class PromptPreview {
  label: string = ''; prompt: string = ''; author: string = ''; kind?: string;
  importCount: number = 0; appliesTo: string[] = [];
}
export class PromptShareState {
  code: string = ''; sharing: boolean = false; error: string = '';
  /// 溯源转发（2026-07-22）：true = 未修改的导入件在转发【原作者的】码——不是
  /// 自有码，关闭只是停止转发，码本身不会失效。老服务端响应无此字段 → false。
  borrowed: boolean = false;
}
interface PromptMarketExampleWire { input?: string; output?: string; imageKey?: string; }
interface PromptMarketItemWire {
  code?: string; label?: string; author?: string; kind?: string; importCount?: number; createdAt?: string;
  appliesTo?: string[]; example?: PromptMarketExampleWire;
}
interface PromptMarketWire { items?: PromptMarketItemWire[]; }
export class PromptMarketItem {
  code: string = '';
  label: string = '分享提示词';
  author: string = '';
  kind: string = '';
  importCount: number = 0;
  createdAt: string = '';
  appliesTo: string[] = [];
  exampleInput: string = '';
  exampleOutput: string = '';
  exampleImageKey: string = '';
}
interface ImportedWire { item?: Object; }
interface ShareWire { code?: string; sharing?: boolean; borrowed?: boolean; }
interface ShareStatesWire { byItem?: Record<string, ShareWire>; }
interface ErrorWire { error?: string; }

export class PromptStore {
  private prefs?: preferences.Preferences;
  private promptItems: PromptNode[] = defaultPrompts();
  private mutating: boolean = false;
  private cacheIdentity: string = '';

  async initialize(context: common.Context): Promise<void> {
    this.prefs = await preferences.getPreferences(context, { name: 'voicedrop.prompts' });
    this.cacheIdentity = authStore.bearer();
    const cached: string = String(this.prefs.getSync(ClientReliability.promptCacheKey(this.cacheIdentity), '') ?? '');
    if (cached.length > 0) try { this.promptItems = PromptTree.decode(cached); } catch (_) {}
  }

  items(): PromptNode[] { this.ensureAccount(); return PromptTree.copy(this.promptItems); }
  textActions(): PromptNode[] { this.ensureAccount(); return PromptTree.actions(this.promptItems, 'text'); }
  imageActions(): PromptNode[] { this.ensureAccount(); return PromptTree.actions(this.promptItems, 'image'); }

  async refresh(): Promise<string> {
    this.ensureAccount();
    try {
      const response: HttpResponse = await httpClient.get(`${Api.AGENT}/prompts`, authStore.bearer());
      if (!response.ok()) return '刷新失败，正在显示上次内容';
      this.promptItems = PromptTree.decode(response.text); await this.cache(response.text); return '';
    } catch (_) { return '刷新失败，正在显示上次内容'; }
  }

  async clearLocalCache(): Promise<void> {
    this.prefs?.clearSync();
    await this.prefs?.flush();
    this.cacheIdentity = '';
    this.promptItems = defaultPrompts();
  }

  async saveDraft(draft: PromptNode[]): Promise<string> {
    if (this.mutating) return '正在保存，请稍候';
    this.mutating = true;
    const snapshot: PromptNode[] = this.items(); this.promptItems = PromptTree.copy(draft);
    try {
      const response: HttpResponse = await httpClient.putJson(`${Api.AGENT}/prompts`, authStore.bearer(), JSON.parse(PromptTree.encodeRaw(draft)) as Object);
      if (!response.ok()) throw new Error('save failed');
      this.promptItems = PromptTree.decode(response.text); await this.cache(response.text); return '';
    } catch (_) { this.promptItems = snapshot; return '保存失败，请重试'; }
    finally { this.mutating = false; }
  }

  async add(node: PromptNode, groupId?: string): Promise<string> {
    const before: PromptNode[] = this.items(); const after: PromptNode[] = PromptTree.append(before, node, groupId);
    return PromptTree.flattenIds(before).join(',') === PromptTree.flattenIds(after).join(',') ? '分组不存在' : this.saveDraft(after);
  }
  async replace(id: string, node: PromptNode): Promise<string> {
    const result: PromptMutation = PromptTree.replace(this.items(), id, node);
    return result.changed ? this.saveDraft(result.items) : '提示词不存在';
  }
  async remove(id: string): Promise<string> {
    const result: PromptMutation = PromptTree.remove(this.items(), id);
    return result.changed ? this.saveDraft(result.items) : '提示词不存在';
  }
  async move(id: string, groupId: string | undefined, index: number): Promise<string> {
    const moved: PromptNode[] | undefined = PromptTree.move(this.items(), id, groupId, index);
    return moved ? this.saveDraft(moved) : '无法移动这个提示词';
  }

  async restoreDefaults(): Promise<string> { return this.responseMutation('/prompts/restore-defaults'); }

  async preview(input: string): Promise<PromptPreview | undefined> {
    const code: string = PromptTree.extractShareCode(input); if (!code) return undefined;
    try {
      const response: HttpResponse = await httpClient.get(`${Api.AGENT}/prompt-share/${code}`);
      return response.ok() ? JSON.parse(response.text) as PromptPreview : undefined;
    } catch (_) { return undefined; }
  }

  async importCode(input: string): Promise<string> {
    this.ensureAccount();
    const code: string = PromptTree.extractShareCode(input);
    if (!code) return '请输入有效的 7 位分享码';
    if (PromptTree.containsImport(this.promptItems, code)) return '这个提示词已经导入过了';
    return this.responseMutation('/prompts/import', new CodeBody(code), true);
  }

  async market(sort: string = 'hot', scope: string = '', limit: number = 30): Promise<PromptMarketItem[] | undefined> {
    const safeSort: string = sort === 'new' ? 'new' : 'hot';
    let url: string = `${Api.AGENT}/prompt-market?sort=${safeSort}&limit=${Math.max(1, Math.min(limit, 100))}`;
    if (scope === 'text' || scope === 'image') url += `&scope=${scope}`;
    try {
      const response: HttpResponse = await httpClient.get(url, authStore.bearer());
      if (!response.ok()) return undefined;
      const values: PromptMarketItemWire[] = (JSON.parse(response.text) as PromptMarketWire).items ?? [];
      return values.filter((wire: PromptMarketItemWire) => (wire.code ?? '').trim().length > 0)
        .map((wire: PromptMarketItemWire) => {
          const item: PromptMarketItem = new PromptMarketItem();
          item.code = (wire.code ?? '').trim(); item.label = wire.label ?? '分享提示词';
          item.author = wire.author ?? ''; item.kind = wire.kind ?? ''; item.importCount = Math.max(0, wire.importCount ?? 0);
          item.createdAt = wire.createdAt ?? ''; item.appliesTo = wire.appliesTo ?? [];
          item.exampleInput = wire.example?.input ?? ''; item.exampleOutput = wire.example?.output ?? '';
          item.exampleImageKey = wire.example?.imageKey ?? '';
          return item;
        });
    } catch (_) { return undefined; }
  }

  async setSharing(id: string, sharing: boolean): Promise<PromptShareState> {
    const state: PromptShareState = new PromptShareState();
    if (!authStore.isWechatAuthenticated()) { state.error = '请先登录微信后分享提示词'; return state; }
    try {
      const response: HttpResponse = sharing
        ? await httpClient.postJson(`${Api.AGENT}/prompt-share`, authStore.session(), new IdBody(id))
        : await httpClient.delete(`${Api.AGENT}/prompt-share/${encodeURIComponent(id)}`, authStore.session());
      if (!response.ok()) {
        let remote: string = '';
        try { remote = (JSON.parse(response.text) as ErrorWire).error ?? ''; } catch (_) {}
        if (response.code === 429) remote = '今天生成分享码的次数已达上限，明天再试';
        else if (remote === 'needs_apple_signin' || remote === 'needs_wechat_signin') remote = '请先登录微信后分享提示词';
        else if (remote === 'content_flagged') remote = '提示词未通过社区审核，暂时不能分享';
        state.error = remote || '提示词分享操作失败'; return state;
      }
      const wire: ShareWire = JSON.parse(response.text) as ShareWire;
      state.code = wire.code ?? ''; state.sharing = wire.sharing ?? sharing; state.borrowed = wire.borrowed ?? false; return state;
    } catch (_) { state.error = '提示词分享操作失败'; return state; }
  }

  async shareStates(): Promise<Map<string, PromptShareState>> {
    const states: Map<string, PromptShareState> = new Map<string, PromptShareState>();
    try {
      const response: HttpResponse = await httpClient.get(`${Api.AGENT}/prompt-shares`, authStore.bearer());
      if (!response.ok()) return states;
      const values: Record<string, ShareWire> = (JSON.parse(response.text) as ShareStatesWire).byItem ?? {};
      Object.keys(values).forEach((id: string) => {
        const wire: ShareWire = values[id]; const state: PromptShareState = new PromptShareState();
        state.code = wire.code ?? ''; state.sharing = wire.sharing ?? false; state.borrowed = wire.borrowed ?? false; states.set(id, state);
      });
    } catch (_) {}
    return states;
  }

  private async responseMutation(path: string, body: Object = new Object(), importing: boolean = false): Promise<string> {
    if (this.mutating) return '正在保存，请稍候'; this.mutating = true;
    try {
      const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}${path}`, authStore.bearer(), body);
      if (!response.ok()) throw new Error('mutation failed');
      if (importing) {
        const imported: ImportedWire = JSON.parse(response.text) as ImportedWire;
        if (!imported.item) throw new Error('missing item');
        const wrapper: string = `{"schema":1,"items":[${JSON.stringify(imported.item)}]}`;
        const node: PromptNode = PromptTree.decode(wrapper)[0];
        if (!PromptTree.flattenIds(this.promptItems).includes(node.id)) this.promptItems.push(node);
        await this.cache(PromptTree.encodeResolved(this.promptItems));
      } else { this.promptItems = PromptTree.decode(response.text); await this.cache(response.text); }
      return '';
    } catch (_) { return '操作失败，请重试'; }
    finally { this.mutating = false; }
  }

  private ensureAccount(): void {
    const next: string = authStore.bearer();
    if (next === this.cacheIdentity) return;
    this.cacheIdentity = next;
    this.promptItems = defaultPrompts();
    const cached: string = String(this.prefs?.getSync(ClientReliability.promptCacheKey(next), '') ?? '');
    if (cached.length > 0) try { this.promptItems = PromptTree.decode(cached); } catch (_) {}
  }

  private async cache(raw: string): Promise<void> {
    this.ensureAccount();
    this.prefs?.putSync(ClientReliability.promptCacheKey(this.cacheIdentity), raw);
    await this.prefs?.flush();
  }
}

export const promptStore: PromptStore = new PromptStore();
