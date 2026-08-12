import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

export class BookSeedBody {
  seed: string;
  constructor(seed: string) { this.seed = seed.trim().substring(0, 20000); }
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
  static readonly BOOK_SUANLI: number = 320;

  static shouldLoadInvite(balance: number | undefined): boolean {
    return balance !== undefined && balance < BookWritingService.BOOK_SUANLI;
  }

  static shortfall(balance: number | undefined): number {
    if (balance === undefined || !Number.isFinite(balance)) return 0;
    const amount: number = Math.max(0, BookWritingService.BOOK_SUANLI - balance);
    return Math.ceil(amount);
  }

  async start(seed: string): Promise<BookWritingResult> {
    const body: BookSeedBody = new BookSeedBody(seed);
    if (body.seed.length === 0) return BookWritingService.result(400, '');
    const response: HttpResponse = await httpClient.postJson(BookWritingService.API, authStore.bearer(), body, 30000);
    return BookWritingService.result(response.code, response.text);
  }

  static result(code: number, responseText: string): BookWritingResult {
    if (code === 202) {
      return new BookWritingResult(code, true, '开始写了！现在可以关闭 App，稍后下拉刷新「写书」书架查看。');
    }
    if (code === 402) {
      let body: BookChargeWire = {};
      try { body = JSON.parse(responseText.length > 0 ? responseText : '{}') as BookChargeWire; } catch (_) {}
      const need: string = BookWritingService.formatSuanli(body.need_suanli, BookWritingService.BOOK_SUANLI);
      const have: string = BookWritingService.formatSuanli(body.suanli, 0);
      return new BookWritingResult(code, false,
        `算力不足：写一本书要 ${need} 算力，你现在有 ${have}。`, body.suanli);
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
