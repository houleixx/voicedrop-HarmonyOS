import { http } from '@kit.NetworkKit';

export class HttpResponse {
  code: number;
  text: string;
  headers: Object;

  constructor(code: number, text: string, headers: Object) {
    this.code = code;
    this.text = text;
    this.headers = headers;
  }

  ok(): boolean { return this.code >= 200 && this.code < 300; }
}

export class BinaryResponse {
  code: number;
  data: ArrayBuffer;
  constructor(code: number, data: ArrayBuffer) { this.code = code; this.data = data; }
  ok(): boolean { return this.code >= 200 && this.code < 300; }
}

export class HttpClient {
  async get(url: string, bearer: string = ''): Promise<HttpResponse> {
    return this.request(url, http.RequestMethod.GET, bearer);
  }

  async postJson(url: string, bearer: string, body: Object | string = '', timeout: number = 30000): Promise<HttpResponse> {
    return this.request(url, http.RequestMethod.POST, bearer, body, 'application/json', timeout);
  }

  async putJson(url: string, bearer: string, body: Object): Promise<HttpResponse> {
    return this.request(url, http.RequestMethod.PUT, bearer, body, 'application/json');
  }

  async patchJson(url: string, bearer: string, body: Object): Promise<HttpResponse> {
    return this.request(url, 'PATCH' as http.RequestMethod, bearer, body, 'application/json');
  }

  async getBytes(url: string, bearer: string = ''): Promise<BinaryResponse> {
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = { 'Accept': '*/*', 'X-VD-Platform': 'harmonyos' };
    if (bearer.length > 0) headers['Authorization'] = `Bearer ${bearer}`;
    try {
      const result: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 120000
      });
      return new BinaryResponse(result.responseCode, result.result as ArrayBuffer);
    } finally {
      request.destroy();
    }
  }

  async putBytes(url: string, bearer: string, body: ArrayBuffer, contentType: string): Promise<HttpResponse> {
    return this.request(url, http.RequestMethod.PUT, bearer, body, contentType, 120000);
  }

  async delete(url: string, bearer: string): Promise<HttpResponse> {
    return this.request(url, http.RequestMethod.DELETE, bearer);
  }

  private async request(url: string, method: http.RequestMethod, bearer: string,
    body?: Object | string | ArrayBuffer, contentType: string = 'application/json', timeout: number = 30000): Promise<HttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = {
      'Accept': 'application/json', 'Content-Type': contentType, 'X-VD-Platform': 'harmonyos'
    };
    if (bearer.length > 0) headers['Authorization'] = `Bearer ${bearer}`;
    try {
      const result: http.HttpResponse = await request.request(url, {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: timeout,
        readTimeout: timeout
      });
      return new HttpResponse(result.responseCode, String(result.result ?? ''), result.header ?? {});
    } finally {
      request.destroy();
    }
  }
}

export const httpClient: HttpClient = new HttpClient();
