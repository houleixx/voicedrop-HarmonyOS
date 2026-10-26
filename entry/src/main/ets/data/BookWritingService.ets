import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';
import { AppLocale } from '../core/AppLocale';
import { Api } from '../core/Api';
import { BookWritingOptions } from '../core/BookWritingOptions';

export class BookSeedBody {
  seed: string;
  hidden: boolean;
  author?: string;
  constructor(seed: string, author: string = '', hidden: boolean = false) {
    this.seed = seed.trim().substring(0, 20000);
    this.hidden = hidden;
    if (author.trim().length > 0) this.author = author.trim();
  }
}

interface BookAuthorWire { name?: string; }
class BookNameBody {
  name: string;
  constructor(name: string) { this.name = name; }
}

interface BookChargeWire {
  need_suanli?: number;
  suanli?: number;
}

export class BookWritingResult {
  code: number;
  accepted: boolean;
  message: string;
  balance?: number;

  constructor(code: number, accepted: boolean, message: string, balance?: number) {
    this.code = code;
    this.accepted = accepted;
    this.message = message;
    this.balance = balance;
  }
}

export class BookWritingService {
  static readonly API: string = 'https://lab.jianshuo.dev/api/book';
  static readonly SHELF: string = 'https://voicedrop.cn/books/';
  static readonly FALLBACK_BOOK_SUANLI: number = 160;

  static shouldLoadInvite(balance: number | undefined, price: number = BookWritingService.FALLBACK_BOOK_SUANLI): boolean {
    return balance !== undefined && balance < price;
  }

  static shortfall(balance: number | undefined, price: number = BookWritingService.FALLBACK_BOOK_SUANLI): number {
    if (balance === undefined || !Number.isFinite(balance)) return 0;
    const amount: number = Math.max(0, price - balance);
    return Math.ceil(amount);
  }

  async loadAuthor(): Promise<string> {
    const identity: string = authStore.storageScope();
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/style`, authStore.bearer());
    if (!response.ok() || identity !== authStore.storageScope()) throw new Error('author unavailable');
    const wire: BookAuthorWire = JSON.parse(response.text) as BookAuthorWire;
    if (!wire || typeof wire !== 'object' || Array.isArray(wire) ||
      (wire.name !== undefined && typeof wire.name !== 'string')) throw new Error('invalid author');
    return wire.name ?? '';
  }

  async start(seed: string, draft: string = '', loadedAuthor: string | undefined = undefined,
    hidden: boolean = false, edited: boolean = false): Promise<BookWritingResult> {
    if (seed.trim().length === 0) return BookWritingService.result(400, '');
    const identity: string = authStore.storageScope();
    const bearer: string = authStore.bearer();
    let author: string = draft.trim();
    let loaded: string | undefined = loadedAuthor;
    if (loaded === undefined && author.length === 0) {
      try {
        loaded = await this.loadAuthor();
        author = BookWritingOptions.loadedDraft(author, edited, loaded).trim();
      } catch (_) {
        return new BookWritingResult(0, false, '作者名字读取失败，请检查网络后重试。');
      }
    }
    if (identity !== authStore.storageScope()) return new BookWritingResult(0, false, '身份已变化，请返回后重试。');
    const name: string | undefined = BookWritingOptions.nameToSave(author, loaded);
    if (name !== undefined) {
      try {
        const saved: HttpResponse = await httpClient.putJson(`${Api.FILES}/style`, bearer, new BookNameBody(name));
        if (!saved.ok()) return new BookWritingResult(saved.code, false, '名字保存失败，请重试');
      } catch (_) {
        return new BookWritingResult(0, false, '名字保存失败，请重试');
      }
    }
    if (identity !== authStore.storageScope()) return new BookWritingResult(0, false, '身份已变化，请返回后重试。');
    const body: BookSeedBody = new BookSeedBody(seed, author, hidden);
    const response: HttpResponse = await httpClient.postJson(BookWritingService.API, bearer, body, 30000);
    return BookWritingService.result(response.code, response.text);
  }

  static result(code: number, responseText: string): BookWritingResult {
    if (code === 202) {
      return new BookWritingResult(code, true, '开始写了！现在可以关闭 App，稍后下拉刷新「写书」书架查看。');
    }
    if (code === 402) {
      let body: BookChargeWire = {};
      try { body = JSON.parse(responseText.length > 0 ? responseText : '{}') as BookChargeWire; } catch (_) {}
      // The 402 payload is authoritative even if our cached display price is stale.
      const need: string = BookWritingService.formatSuanli(body.need_suanli, BookWritingService.FALLBACK_BOOK_SUANLI);
      const have: string = BookWritingService.formatSuanli(body.suanli, 0);
      return new BookWritingResult(code, false,
        AppLocale.bookWritingCreditsInsufficient(need, have), body.suanli);
    }
    if (code === 401) return new BookWritingResult(code, false, '身份校验没过，请稍后重试。');
    return new BookWritingResult(code, false, code > 0
      ? `服务器返回 ${code}，请稍后重试。` : '没连上服务器，请检查网络后重试。');
  }

  static message(code: number, responseText: string = ''): string {
    return BookWritingService.result(code, responseText).message;
  }

  private static formatSuanli(value: number | undefined, fallback: number): string {
    const amount: number = value !== undefined && Number.isFinite(value) ? value : fallback;
    const rounded: number = Math.round(amount * 10) / 10;
    return rounded === Math.round(rounded) ? `${Math.round(rounded)}` : rounded.toFixed(1);
  }
}

export const bookWritingService: BookWritingService = new BookWritingService();
