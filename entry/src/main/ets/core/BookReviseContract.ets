export class BookThreadEntry {
  ts: number;
  kind: string;
  instruction: string;
  status: string;
  reply?: string;
  error?: string;

  constructor(ts: number = 0, kind: string = '', instruction: string = '', status: string = '',
    reply?: string, error?: string) {
    this.ts = ts;
    this.kind = kind;
    this.instruction = instruction;
    this.status = status;
    this.reply = reply;
    this.error = error;
  }
}

export class BookThread {
  slug: string;
  author?: string;
  running: boolean;
  thread: BookThreadEntry[];

  constructor(slug: string = '', author?: string, running: boolean = false, thread: BookThreadEntry[] = []) {
    this.slug = slug;
    this.author = author;
    this.running = running;
    this.thread = thread;
  }
}

export class BookHistoryResult {
  code: number;
  loaded: boolean;
  denied: boolean;
  message: string;
  value?: BookThread;

  constructor(code: number, loaded: boolean, denied: boolean, message: string, value?: BookThread) {
    this.code = code;
    this.loaded = loaded;
    this.denied = denied;
    this.message = message;
    this.value = value;
  }
}

export class BookReviseResult {
  code: number;
  accepted: boolean;
  message: string;
  ts: number;
  balance?: number;

  constructor(code: number, accepted: boolean, message: string, ts: number = 0, balance?: number) {
    this.code = code;
    this.accepted = accepted;
    this.message = message;
    this.ts = ts;
    this.balance = balance;
  }
}

interface BookThreadEntryWire {
  ts?: number;
  kind?: string;
  instruction?: string;
  status?: string;
  reply?: string;
  error?: string;
}

interface BookThreadWire {
  slug?: string;
  author?: string;
  running?: boolean;
  thread?: BookThreadEntryWire[];
}

interface BookReviseResponseWire {
  ts?: number;
  suanli?: number;
  need_suanli?: number;
}

/** Pure parsing and UI-state rules for the server book-revision contract. */
export class BookReviseContract {
  static readonly PRICE: number = 40;

  static history(code: number, responseText: string): BookHistoryResult {
    if (code === 200) {
      try {
        const wire: BookThreadWire = JSON.parse(responseText || '{}') as BookThreadWire;
        const entries: BookThreadEntry[] = (wire.thread ?? []).map((item: BookThreadEntryWire) =>
          new BookThreadEntry(
            BookReviseContract.number(item.ts), String(item.kind ?? ''), String(item.instruction ?? ''),
            String(item.status ?? ''), item.reply, item.error));
        const slug: string = String(wire.slug ?? '');
        if (slug.length === 0) return new BookHistoryResult(code, false, false, '服务器数据不完整，请稍后重试。');
        const running: boolean = wire.running === true || entries.some((entry: BookThreadEntry) => entry.status === 'running');
        return new BookHistoryResult(code, true, false, '', new BookThread(slug, wire.author, running, entries));
      } catch (_) {
        return new BookHistoryResult(code, false, false, '服务器数据不完整，请稍后重试。');
      }
    }
    if (code === 403) return new BookHistoryResult(code, false, true, '只有这本书的主人能修改。');
    if (code === 404) return new BookHistoryResult(code, false, true, '这本书是早期写的，还没登记主人，暂时不能在线修改。');
    if (code === 401) return new BookHistoryResult(code, false, true, '登录状态已失效，请重新登录后再试。');
    return new BookHistoryResult(code, false, false,
      code > 0 ? `服务器返回 ${code}，请稍后重试。` : '没连上服务器，请检查网络后重试。');
  }

  static revise(code: number, responseText: string): BookReviseResult {
    let wire: BookReviseResponseWire = {};
    try { wire = JSON.parse(responseText || '{}') as BookReviseResponseWire; } catch (_) {}
    if (code === 202) return new BookReviseResult(code, true, '', BookReviseContract.number(wire.ts), wire.suanli);
    if (code === 402) {
      const need: string = BookReviseContract.formatSuanli(wire.need_suanli, BookReviseContract.PRICE);
      const have: string = BookReviseContract.formatSuanli(wire.suanli, 0);
      return new BookReviseResult(code, false, `算力不足：改一次要 ${need} 算力，你现在有 ${have}。`, 0, wire.suanli);
    }
    if (code === 403) return new BookReviseResult(code, false, '只有这本书的主人能修改。');
    if (code === 404) return new BookReviseResult(code, false, '这本书是早期写的，还没登记主人，暂时不能在线修改。');
    if (code === 409) return new BookReviseResult(code, false, '上一个修改还在进行，等它改完再提。');
    if (code === 401) return new BookReviseResult(code, false, '身份校验没过，请稍后重试。');
    return new BookReviseResult(code, false,
      code > 0 ? `服务器返回 ${code}，请稍后重试。` : '没连上服务器，请检查网络后重试。');
  }

  static isRunning(entries: BookThreadEntry[]): boolean {
    return entries.some((entry: BookThreadEntry) => entry.status === 'running');
  }

  static canSend(input: string, sending: boolean, loading: boolean,
    entries: BookThreadEntry[], denied: string): boolean {
    return input.trim().length > 0 && !sending && !loading &&
      !BookReviseContract.isRunning(entries) && denied.length === 0;
  }

  static replyText(entry: BookThreadEntry): string {
    if (entry.status === 'running') {
      return entry.kind === 'create' ? '正在写这本书…' : '正在修改…（改完这里会出现修改说明）';
    }
    if (entry.status === 'failed') {
      return entry.kind === 'create' ? '这本书当时没写完就中断了' : '这次修改没有完成（没扣的算力不会少），可以再试一次';
    }
    const reply: string = (entry.reply ?? '').trim();
    if (reply.length > 0) return reply;
    return entry.kind === 'create' ? '书写好了，上架在「写书」书架。' : '改好了。';
  }

  static instruction(seed: string): string { return seed.trim().substring(0, 4000); }

  private static number(value: number | undefined): number {
    return value !== undefined && Number.isFinite(value) ? value : 0;
  }

  private static formatSuanli(value: number | undefined, fallback: number): string {
    const amount: number = value !== undefined && Number.isFinite(value) ? value : fallback;
    const rounded: number = Math.round(amount * 10) / 10;
    return rounded === Math.round(rounded) ? `${Math.round(rounded)}` : rounded.toFixed(1);
  }
}
