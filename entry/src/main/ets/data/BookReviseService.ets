import { BookHistoryResult, BookReviseContract, BookReviseResult } from '../core/BookReviseContract';
import { httpClient, HttpResponse } from '../net/HttpClient';
import { authStore } from './AuthStore';

class BookReviseBody {
  slug: string;
  instruction: string;
  constructor(slug: string, instruction: string) { this.slug = slug; this.instruction = instruction; }
}

export class BookReviseService {
  static readonly HISTORY_API: string = 'https://lab.jianshuo.dev/api/book/history';
  static readonly REVISE_API: string = 'https://lab.jianshuo.dev/api/book/revise';

  async history(slug: string): Promise<BookHistoryResult> {
    const url: string = `${BookReviseService.HISTORY_API}?slug=${encodeURIComponent(slug)}`;
    const response: HttpResponse = await httpClient.get(url, authStore.bearer());
    return BookReviseContract.history(response.code, response.text);
  }

  async revise(slug: string, instruction: string): Promise<BookReviseResult> {
    const body: BookReviseBody = new BookReviseBody(slug, BookReviseContract.instruction(instruction));
    const response: HttpResponse = await httpClient.postJson(
      BookReviseService.REVISE_API, authStore.bearer(), body, 30000);
    return BookReviseContract.revise(response.code, response.text);
  }
}

export const bookReviseService: BookReviseService = new BookReviseService();
