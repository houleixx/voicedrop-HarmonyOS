export enum ShareImportKind {
  AUDIO = 'audio',
  IMAGE = 'image',
  DATASET = 'dataset'
}

export class ShareRecordValue {
  utd: string;
  content: string;
  uri: string;
  title: string;
  description: string;

  constructor(utd: string = '', content: string = '', uri: string = '', title: string = '',
    description: string = '') {
    this.utd = utd;
    this.content = content;
    this.uri = uri;
    this.title = title;
    this.description = description;
  }
}

export class ShareIncomingPayload {
  type: string;
  uris: string[];
  text: string;
  title: string;

  constructor(type: string = '', uris: string[] = [], text: string = '', title: string = '') {
    this.type = type;
    this.uris = uris;
    this.text = text;
    this.title = title;
  }
}

export class ShareDatasetItem {
  id: string;
  type: string;
  title: string;
  source: string;
  collectedAt: string;
  chars: number;

  constructor(id: string = '', type: string = '', title: string = '', source: string = '',
    collectedAt: string = '', chars: number = 0) {
    this.id = id;
    this.type = type;
    this.title = title;
    this.source = source;
    this.collectedAt = collectedAt;
    this.chars = Math.max(0, chars);
  }
}

export class ShareDatasetSnapshot {
  items: ShareDatasetItem[];
  count: number;
  totalChars: number;

  constructor(items: ShareDatasetItem[] = [], count: number = 0, totalChars: number = 0) {
    this.items = items;
    this.count = Math.max(0, count);
    this.totalChars = Math.max(0, totalChars);
  }
}

interface ShareDatasetWireItem {
  id?: string;
  type?: string;
  title?: string;
  source?: string;
  collectedAt?: string;
  chars?: number;
}

interface ShareDatasetWire {
  items?: ShareDatasetWireItem[];
  count?: number;
  totalChars?: number;
}

export class ShareImport {
  static readonly MIN_STYLE_CHARS: number = 300;

  static classify(mime: string, uris: string[]): ShareImportKind {
    const lower: string = (mime || '').toLowerCase();
    if (ShareImport.isAudioType(lower)) return ShareImportKind.AUDIO;
    if (ShareImport.isImageType(lower)) return ShareImportKind.IMAGE;
    if (uris.some((uri: string) => ShareImport.looksLikeAudio(uri))) return ShareImportKind.AUDIO;
    if (uris.length > 0 && uris.every((uri: string) => ShareImport.looksLikeImage(uri))) {
      return ShareImportKind.IMAGE;
    }
    return ShareImportKind.DATASET;
  }

  static payloadFromRecords(records: ShareRecordValue[]): ShareIncomingPayload {
    const uris: string[] = records.map((record: ShareRecordValue) => (record.uri ?? '').trim())
      .filter((uri: string) => uri.length > 0 && !ShareImport.isWebUrl(uri));
    const text: string = records.map((record: ShareRecordValue) => {
      const content: string = (record.content ?? '').trim();
      const description: string = (record.description ?? '').trim();
      const uri: string = (record.uri ?? '').trim();
      if (ShareImport.isWebUrl(content)) return content;
      if (ShareImport.isWebUrl(description)) return description;
      if (ShareImport.isWebUrl(uri)) return uri;
      return content.length > 0 ? content : description;
    }).filter((value: string) => value.length > 0).join('\n\n');
    const first: ShareRecordValue | undefined = records[0];
    return new ShareIncomingPayload(first?.utd ?? '', uris, text, first?.title?.trim() ?? '');
  }

  static mergePayload(shared: ShareIncomingPayload, fallback: ShareIncomingPayload): ShareIncomingPayload {
    const sharedText: string = shared.text.trim();
    const fallbackText: string = fallback.text.trim();
    let text: string = sharedText.length > 0 ? sharedText : fallbackText;
    if (!ShareImport.isWebUrl(text) && ShareImport.isWebUrl(fallbackText)) text = fallbackText;
    const uris: string[] = shared.uris.concat(fallback.uris)
      .filter((uri: string, index: number, values: string[]) => uri.length > 0 && values.indexOf(uri) === index);
    const useFallbackType: boolean = text === fallbackText && fallback.type.trim().length > 0;
    return new ShareIncomingPayload(
      useFallbackType ? fallback.type : (shared.type.trim() || fallback.type),
      uris, text, shared.title.trim() || fallback.title.trim());
  }

  static newestAddedDatasetItem(before: ShareDatasetSnapshot,
    after: ShareDatasetSnapshot): ShareDatasetItem | undefined {
    return after.items.find((candidate: ShareDatasetItem) =>
      !before.items.some((existing: ShareDatasetItem) => existing.id === candidate.id));
  }

  static canExtract(snapshot: ShareDatasetSnapshot): boolean {
    return snapshot.count > 0 && snapshot.totalChars >= ShareImport.MIN_STYLE_CHARS;
  }

  static formatChars(chars: number): string {
    const digits: string = `${Math.max(0, Math.floor(chars))}`;
    const groups: string[] = [];
    let end: number = digits.length;
    while (end > 3) {
      groups.unshift(digits.substring(end - 3, end));
      end -= 3;
    }
    groups.unshift(digits.substring(0, end));
    return `${groups.join(',')} 字`;
  }

  static formatTotalChars(chars: number): string {
    const safe: number = Math.max(0, Math.floor(chars));
    if (safe >= 10000) return `约 ${(safe / 10000).toFixed(1)} 万字`;
    return `约 ${ShareImport.formatChars(safe)}`;
  }

  static styleTaskTag(clearAfter: boolean): string {
    return clearAfter ? 'TaskStyleExtract' : 'TaskStyleExtract-Keep';
  }

  static parseDatasetResponse(raw: string): ShareDatasetSnapshot {
    let wire: ShareDatasetWire = {};
    try { wire = JSON.parse(raw) as ShareDatasetWire; } catch (_) { return new ShareDatasetSnapshot(); }
    const items: ShareDatasetItem[] = Array.isArray(wire.items) ? wire.items.map((item: ShareDatasetWireItem) =>
      new ShareDatasetItem(
        String(item.id ?? ''), String(item.type ?? ''), String(item.title ?? ''),
        String(item.source ?? ''), String(item.collectedAt ?? ''), Number(item.chars ?? 0)
      )) : [];
    const totalChars: number = Number.isFinite(Number(wire.totalChars)) ?
      Number(wire.totalChars) : items.reduce((sum: number, item: ShareDatasetItem) => sum + item.chars, 0);
    const count: number = Number.isFinite(Number(wire.count)) ? Number(wire.count) : items.length;
    return new ShareDatasetSnapshot(items, count, totalChars);
  }

  static firstLineTitle(text: string, fallback: string = '分享内容'): string {
    for (const line of text.split(/\r?\n/)) {
      if (line.trim().length > 0) return line.trim().substring(0, 40);
    }
    return (fallback.trim() || '分享内容').substring(0, 40);
  }

  static isWebUrl(value: string): boolean { return /^https?:\/\/\S+$/i.test(value.trim()); }

  static extractRtf(value: string): string {
    return value.replace(/\\par[d]?\s?/g, '\n')
      .replace(/\\'[0-9a-fA-F]{2}/g, '')
      .replace(/\\[a-zA-Z]+-?\d* ?/g, '')
      .replace(/[{}]/g, '')
      .replace(/\n\s*\n\s*\n+/g, '\n\n')
      .trim();
  }

  static extractDocxXml(xml: string): string {
    return ShareImport.decodeXmlEntities(xml
      .replace(/<w:tab\s*\/>/gi, '\t')
      .replace(/<w:br[^>]*\/>/gi, '\n')
      .replace(/<\/w:p>/gi, '\n')
      .replace(/<[^>]+>/g, ''))
      .replace(/\r/g, '')
      .replace(/\n\s*\n\s*\n+/g, '\n\n')
      .trim();
  }

  static extractHtml(html: string): string {
    let body: string = html;
    const article: RegExpMatchArray | null = html.match(/<article[^>]*>([\s\S]*)<\/article>/i);
    const wechat: RegExpMatchArray | null = html.match(/<div[^>]+id=[\"']js_content[\"'][^>]*>([\s\S]*)<\/div>/i);
    const generic: RegExpMatchArray | null = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    if (wechat) body = wechat[1]; else if (article) body = article[1]; else if (generic) body = generic[1];
    return ShareImport.decodeXmlEntities(body
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<\/?(?:p|div|section|article|h[1-6]|li|blockquote|br)[^>]*>/gi, '\n')
      .replace(/<[^>]+>/g, ' '))
      .replace(/[ \t]+/g, ' ')
      .replace(/\n\s*\n\s*\n+/g, '\n\n')
      .trim();
  }

  static htmlTitle(html: string, fallback: string): string {
    const og: RegExpMatchArray | null = html.match(/<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)/i) ??
      html.match(/<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:title[\"']/i);
    const title: RegExpMatchArray | null = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    return ShareImport.firstLineTitle(ShareImport.decodeXmlEntities(og?.[1] ?? title?.[1] ?? ''), fallback);
  }

  private static decodeXmlEntities(value: string): string {
    return value.replace(/&#x([0-9a-fA-F]+);/g, (_match: string, hex: string) =>
      String.fromCodePoint(parseInt(hex, 16)))
      .replace(/&#([0-9]+);/g, (_match: string, decimal: string) =>
        String.fromCodePoint(parseInt(decimal, 10)))
      .replace(/&nbsp;/gi, ' ')
      .replace(/&lt;/gi, '<')
      .replace(/&gt;/gi, '>')
      .replace(/&quot;/gi, '\"')
      .replace(/&apos;|&#39;/gi, "'")
      .replace(/&amp;/gi, '&');
  }

  private static looksLikeAudio(uri: string): boolean {
    return /\.(m4a|mp3|aac|wav|flac|ogg)(\?|$)/i.test(uri);
  }

  private static looksLikeImage(uri: string): boolean {
    return /\.(jpe?g|png|webp|heic|gif)(\?|$)/i.test(uri);
  }

  private static isAudioType(value: string): boolean {
    return value.startsWith('audio/') || value === 'general.audio' || value.endsWith('-audio') ||
      value.includes('.audio');
  }

  private static isImageType(value: string): boolean {
    return value.startsWith('image/') || value === 'general.image' || value === 'general.jpeg' ||
      value === 'general.png' || value.endsWith('-image');
  }
}
