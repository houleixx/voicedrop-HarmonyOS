import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

export class BookSeedBody {
  seed: string;
  constructor(seed: string) { this.seed = seed.trim().substring(0, 20000); }
}

export class BookWritingService {
  static readonly API: string = 'https://lab.jianshuo.dev/api/book';
  static readonly SHELF: string = 'https://voicedrop.cn/books/';

  async start(seed: string): Promise<number> {
    const body: BookSeedBody = new BookSeedBody(seed);
    if (body.seed.length === 0) return 400;
    const response: HttpResponse = await httpClient.postJson(BookWritingService.API, authStore.bearer(), body, 30000);
    return response.code;
  }

  static message(code: number): string {
    if (code === 202) return '开始写了！现在可以关闭 App，稍后去公开书架查看。';
    if (code === 409) return '服务器正在写另一本书，等它写完再来。';
    if (code === 401) return '还不能写书：请先用 VoiceDrop 录音并生成至少一篇文章。';
    if (code === 429) return '今天的写书额度用完了，明天再来。';
    return code > 0 ? `服务器返回 ${code}，请稍后重试。` : '没连上服务器，请检查网络后重试。';
  }
}

export const bookWritingService: BookWritingService = new BookWritingService();
