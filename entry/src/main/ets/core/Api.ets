export class Api {
  static readonly HOST: string = 'voicedrop.cn';
  static readonly PHOTO_HOST: string = Api.HOST;
  static readonly WS_HOST: string = 'jianshuo.dev';
  static readonly DIRECT_API_ORIGIN: string = `https://${Api.WS_HOST}`;
  static readonly FILES: string = `https://${Api.HOST}/files/api`;
  static readonly AGENT: string = `https://${Api.HOST}/agent`;
  static readonly RECO: string = `https://${Api.HOST}/reco`;
  static readonly AGENT_WS: string = `wss://${Api.WS_HOST}/agent`;

  static path(value: string): string {
    return value.split('/').map((part: string) => encodeURIComponent(part)).join('/');
  }

  static directApiUrl(url: string): string {
    const domesticOrigin: string = `https://${Api.HOST}`;
    if (!url.startsWith(`${domesticOrigin}/`)) return url;
    return `${Api.DIRECT_API_ORIGIN}${url.substring(domesticOrigin.length)}`;
  }

  static sharePage(id: string): string {
    return `https://voicedrop.cn/${Api.path(id)}`;
  }
}
