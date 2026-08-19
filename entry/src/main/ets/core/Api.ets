import { apiRoute } from './ApiRoute';

export class Api {
  static readonly CN_HOST: string = 'voicedrop.cn';
  static readonly CF_HOST: string = 'jianshuo.dev';
  static get HOST(): string { return apiRoute.host(); }
  static get PHOTO_HOST(): string { return apiRoute.host(); }
  static readonly WS_HOST: string = Api.CF_HOST;
  static readonly DIRECT_API_ORIGIN: string = `https://${Api.CF_HOST}`;
  static get FILES(): string { return `https://${Api.HOST}/files/api`; }
  static get AGENT(): string { return `https://${Api.HOST}/agent`; }
  static get RECO(): string { return `https://${Api.HOST}/reco`; }
  static readonly AGENT_WS: string = `wss://${Api.CF_HOST}/agent`;
  static get PUBLIC_WEB_BASE(): string { return apiRoute.publicWebBase(); }
  static get PHOTO_BASE(): string { return `https://${Api.PHOTO_HOST}/files/api`; }

  static path(value: string): string {
    return value.split('/').map((part: string) => encodeURIComponent(part)).join('/');
  }

  static directApiUrl(url: string): string {
    const domesticOrigin: string = `https://${Api.CN_HOST}`;
    if (!url.startsWith(`${domesticOrigin}/`)) return url;
    return `${Api.DIRECT_API_ORIGIN}${url.substring(domesticOrigin.length)}`;
  }

  static restyleUrl(): string {
    return `${Api.AGENT}/restyle`;
  }

  static sharePage(id: string): string {
    return `https://voicedrop.cn/${Api.path(id)}`;
  }
}
