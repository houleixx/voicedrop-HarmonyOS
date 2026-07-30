class RestyleRequestBody {
  stem: string;
  styleV?: number;

  constructor(stem: string, styleVersion?: number) {
    this.stem = stem;
    this.styleV = styleVersion;
  }
}

interface RestyleResponseWire {
  ok?: boolean;
  reason?: string;
  error?: string;
  head?: number;
}

export class RestyleResult {
  ok: boolean;
  reason: string;
  statusCode: number;
  head?: number;

  constructor(ok: boolean, reason: string = '', statusCode: number = 0, head?: number) {
    this.ok = ok;
    this.reason = reason;
    this.statusCode = statusCode;
    this.head = head;
  }

  message(): string {
    if (this.reason === 'no-style') return '所选文风不可用，请重新选择';
    if (this.reason === 'no-transcript') return '当前文章没有可重写的内容';
    if (this.reason === 'not-found') return '原文章不存在或尚未同步';
    if (this.reason === 'corrupt') return '文章数据异常，暂时无法重写';
    if (this.reason === 'no-article') return '未能生成新文章，请稍后重试';
    if (this.reason === 'unauthorized' || this.statusCode === 401) return '登录状态已失效，请重新登录';
    if (this.statusCode === 502 || this.statusCode === 503 || this.statusCode === 504 ||
      (this.statusCode >= 521 && this.statusCode <= 524)) {
      return `重写服务暂时不可用（HTTP ${this.statusCode}），请稍后重试`;
    }
    if (this.statusCode > 0) return `换文风请求失败（HTTP ${this.statusCode}）`;
    return '换文风请求失败';
  }
}

export class RestyleRequest {
  static body(stem: string, styleVersion?: number): string {
    return JSON.stringify(new RestyleRequestBody(stem, styleVersion));
  }

  static result(statusCode: number, responseText: string): RestyleResult {
    let body: RestyleResponseWire = {};
    try {
      body = JSON.parse(responseText) as RestyleResponseWire;
    } catch (_) {}
    const httpOk: boolean = statusCode >= 200 && statusCode < 300;
    const ok: boolean = httpOk && body.ok !== false;
    const reason: string = String(body.reason ?? body.error ?? '');
    return new RestyleResult(ok, reason, statusCode, body.head);
  }
}
