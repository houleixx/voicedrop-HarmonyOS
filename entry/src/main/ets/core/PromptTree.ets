import { util } from '@kit.ArkTS';

export class PromptNode {
  id: string = '';
  type: string = 'action';
  label: string = '';
  origin: string = 'user';
  prompt: string = '';
  kind?: string;
  forkedFrom?: string;
  importedFrom?: string;
  appliesTo: string[] = [];
  children: PromptNode[] = [];

  isGroup(): boolean { return this.type === 'group'; }
  isSystem(): boolean { return this.origin === 'system'; }
  copy(): PromptNode {
    const node: PromptNode = new PromptNode();
    node.id = this.id; node.type = this.type; node.label = this.label; node.origin = this.origin;
    node.prompt = this.prompt; node.kind = this.kind; node.forkedFrom = this.forkedFrom;
    node.importedFrom = this.importedFrom; node.appliesTo = this.appliesTo.slice();
    node.children = this.children.map((child: PromptNode) => child.copy());
    return node;
  }
}

interface PromptWire {
  id?: string;
  type?: string;
  label?: string;
  origin?: string;
  prompt?: string;
  kind?: string;
  forkedFrom?: string;
  importedFrom?: string;
  appliesTo?: string[];
  children?: PromptWire[];
}

interface PromptRootWire { schema?: number; items: PromptWire[]; }

class PromptRawItem {
  ref?: string;
  id?: string;
  type?: string;
  label?: string;
  prompt?: string;
  kind?: string;
  forkedFrom?: string;
  importedFrom?: string;
  appliesTo?: string[];
  children?: PromptRawItem[];
}

class PromptRawRoot { items: PromptRawItem[] = []; }
class PromptResolvedRoot { schema: number = 1; items: PromptNode[] = []; }

export class PromptMutation {
  items: PromptNode[];
  changed: boolean;
  removed?: PromptNode;
  constructor(items: PromptNode[], changed: boolean, removed?: PromptNode) {
    this.items = items; this.changed = changed; this.removed = removed;
  }
}

export class PromptTree {
  static copy(nodes: PromptNode[]): PromptNode[] { return nodes.map((node: PromptNode) => node.copy()); }

  static decode(raw: string): PromptNode[] {
    const root: PromptRootWire = JSON.parse(raw) as PromptRootWire;
    if ((root.schema ?? 1) > 1 || !root.items) throw new Error('unsupported prompt schema');
    return root.items.map((item: PromptWire) => PromptTree.fromWire(item));
  }

  static encodeRaw(nodes: PromptNode[]): string {
    const root: PromptRawRoot = new PromptRawRoot();
    root.items = nodes.map((node: PromptNode) => PromptTree.rawItem(node));
    return JSON.stringify(root);
  }

  static encodeResolved(nodes: PromptNode[]): string {
    const root: PromptResolvedRoot = new PromptResolvedRoot();
    root.items = PromptTree.copy(nodes);
    return JSON.stringify(root);
  }

  static newUserId(): string { return `p_${util.generateRandomUUID(true).replace(/-/g, '').substring(0, 8)}`; }

  static fork(node: PromptNode): PromptNode {
    const copy: PromptNode = node.copy();
    copy.forkedFrom = node.id; copy.id = PromptTree.newUserId(); copy.origin = 'custom';
    return copy;
  }

  static replace(source: PromptNode[], id: string, replacement: PromptNode): PromptMutation {
    const out: PromptNode[] = [];
    let changed: boolean = false;
    for (const node of source) {
      if (node.id === id) { out.push(replacement.copy()); changed = true; continue; }
      const copy: PromptNode = node.copy();
      if (node.isGroup()) {
        const nested: PromptMutation = PromptTree.replace(node.children, id, replacement);
        copy.children = nested.items; changed = changed || nested.changed;
      }
      out.push(copy);
    }
    return new PromptMutation(out, changed);
  }

  static remove(source: PromptNode[], id: string): PromptMutation {
    const out: PromptNode[] = [];
    let changed: boolean = false;
    let removed: PromptNode | undefined = undefined;
    for (const node of source) {
      if (!removed && node.id === id) { removed = node.copy(); changed = true; continue; }
      const copy: PromptNode = node.copy();
      if (!removed && node.isGroup()) {
        const nested: PromptMutation = PromptTree.remove(node.children, id);
        copy.children = nested.items;
        if (nested.changed) { changed = true; removed = nested.removed; }
      }
      out.push(copy);
    }
    return new PromptMutation(out, changed, removed);
  }

  static append(source: PromptNode[], node: PromptNode, groupId?: string): PromptNode[] {
    const out: PromptNode[] = PromptTree.copy(source);
    if (!groupId) { out.push(node.copy()); return out; }
    for (const candidate of out) {
      if (candidate.isGroup() && candidate.id === groupId && !node.isGroup()) {
        candidate.children.push(node.copy()); return out;
      }
    }
    return PromptTree.copy(source);
  }

  static move(source: PromptNode[], id: string, groupId: string | undefined, index: number): PromptNode[] | undefined {
    if (id === groupId) return undefined;
    const result: PromptMutation = PromptTree.remove(source, id);
    if (!result.changed || !result.removed || (groupId && result.removed.isGroup())) return undefined;
    const out: PromptNode[] = result.items;
    if (!groupId) { out.splice(Math.max(0, Math.min(index, out.length)), 0, result.removed); return out; }
    for (const node of out) {
      if (node.isGroup() && node.id === groupId) {
        node.children.splice(Math.max(0, Math.min(index, node.children.length)), 0, result.removed); return out;
      }
    }
    return undefined;
  }

  static flattenIds(source: PromptNode[]): string[] {
    const result: string[] = [];
    for (const node of source) { result.push(node.id); result.push(...PromptTree.flattenIds(node.children)); }
    return result;
  }

  static containsImport(source: PromptNode[], code: string): boolean {
    for (const node of source) if (node.importedFrom === code || PromptTree.containsImport(node.children, code)) return true;
    return false;
  }

  static extractShareCode(text: string): string {
    const match: RegExpMatchArray | null = text.match(/(^|[^0-9])([1-9][0-9]{6})(?![0-9])/);
    return match ? match[2] : '';
  }

  static actions(source: PromptNode[], anchor: string): PromptNode[] {
    const result: PromptNode[] = [];
    for (const node of source) {
      if (node.isGroup()) result.push(...PromptTree.actions(node.children, anchor));
      else if (node.appliesTo.includes(anchor)) result.push(node.copy());
    }
    return result;
  }

  /** Keep configured groups while removing actions that do not apply to the selected anchor. */
  static menu(source: PromptNode[], anchor: string): PromptNode[] {
    const result: PromptNode[] = [];
    for (const node of source) {
      if (node.isGroup()) {
        const children: PromptNode[] = PromptTree.menu(node.children, anchor);
        if (children.length > 0) {
          const group: PromptNode = node.copy(); group.children = children; result.push(group);
        }
      } else if (node.appliesTo.includes(anchor)) result.push(node.copy());
    }
    return result;
  }

  private static fromWire(item: PromptWire): PromptNode {
    const node: PromptNode = new PromptNode();
    node.id = item.id ?? ''; node.type = item.type ?? 'action'; node.label = item.label ?? '';
    node.origin = item.origin ?? ((item.id ?? '').startsWith('sys_') ? 'system' : 'user');
    node.prompt = item.prompt ?? ''; node.kind = item.kind;
    node.forkedFrom = item.forkedFrom; node.importedFrom = item.importedFrom;
    node.appliesTo = item.appliesTo ? item.appliesTo.slice() : [];
    node.children = item.children ? item.children.map((child: PromptWire) => PromptTree.fromWire(child)) : [];
    return node;
  }

  private static rawItem(node: PromptNode): PromptRawItem {
    const item: PromptRawItem = new PromptRawItem();
    if (node.isSystem()) {
      item.ref = node.id;
      if (node.isGroup()) item.children = node.children.map((child: PromptNode) => PromptTree.rawItem(child));
      return item;
    }
    item.id = node.id; item.type = node.type; item.label = node.label;
    item.forkedFrom = node.forkedFrom;
    if (node.isGroup()) item.children = node.children.map((child: PromptNode) => PromptTree.rawItem(child));
    else {
      item.prompt = node.prompt; item.appliesTo = node.appliesTo.slice(); item.kind = node.kind;
      item.importedFrom = node.importedFrom;
    }
    return item;
  }
}

function group(id: string, label: string): PromptNode {
  const node: PromptNode = new PromptNode(); node.id = id; node.type = 'group'; node.label = label; node.origin = 'system'; return node;
}
function action(id: string, label: string, prompt: string, anchor: string, kind?: string): PromptNode {
  const node: PromptNode = new PromptNode(); node.id = id; node.label = label; node.origin = 'system';
  node.prompt = prompt; node.appliesTo = [anchor]; node.kind = kind; return node;
}

export function defaultPrompts(): PromptNode[] {
  const style: PromptNode = group('sys_style', '图片风格');
  style.children = [
    action('sys_cartoon', '卡通', '把这张图（[[photo:{{KEY}}]]）重画成宫崎骏动画的手绘卡通风格，构图和主体不变，正文其他内容都不要动。', 'image', 'image'),
    action('sys_ad', '广告', '把这张图（[[photo:{{KEY}}]]）重新设计成一则现代、极简、精致的商品广告，不使用文字，正文其他内容都不要动。', 'image', 'image'),
    action('sys_watercolor', '水彩', '把这张图（[[photo:{{KEY}}]]）重画成通透的水彩画风格，构图和主体不变，正文其他内容都不要动。', 'image', 'image'),
    action('sys_sketch', '素描', '把这张图（[[photo:{{KEY}}]]）重画成铅笔素描风格，构图和主体不变，正文其他内容都不要动。', 'image', 'image'),
    action('sys_oil', '油画', '把这张图（[[photo:{{KEY}}]]）重画成古典油画风格，构图和主体不变，正文其他内容都不要动。', 'image', 'image'),
    action('sys_film', '胶片', '把这张图（[[photo:{{KEY}}]]）调成胶片摄影的质感和色调，构图和主体不变，正文其他内容都不要动。', 'image', 'image')
  ];
  const rewrite: PromptNode = group('sys_rewrite', '改写这段');
  rewrite.children = [
    action('sys_concise', '更简洁', '把第{{LINE}}行（开头是“{{QUOTE}}”）改写得更简洁，意思不变，正文其他行都不要动。', 'text'),
    action('sys_casual', '更口语', '把第{{LINE}}行（开头是“{{QUOTE}}”）改写得更口语、像平时说话，意思不变，正文其他行都不要动。', 'text'),
    action('sys_formal', '更书面', '把第{{LINE}}行（开头是“{{QUOTE}}”）改写得更书面、更正式，意思不变，正文其他行都不要动。', 'text'),
    action('sys_expand', '扩写一点', '把第{{LINE}}行（开头是“{{QUOTE}}”）扩写一点，补充细节但别啰嗦，正文其他行都不要动。', 'text')
  ];
  const insert: PromptNode = group('sys_insert', '插入图片');
  insert.children = [
    action('sys_wechat_cover', '公众号题图', '给这篇文章画一张微信公众号题图，放在文章最前面。画面为 2.45:1 横幅，主标题清晰可读，风格干净、精致、实用，正文其他内容都不要动。', 'text', 'image'),
    action('sys_cartoon_explainer', '卡通解释图', '读懂全文后画一张扁平卡通解释图，插入到正文最能帮助理解的位置；用清晰的分区、箭头和少量中文标签表达核心结构，正文其他内容都不要动。', 'text', 'image')
  ];
  return [style, rewrite, insert];
}
