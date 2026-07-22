export class Api {
  static readonly HOST: string = 'jianshuo.dev';
  static readonly PHOTO_HOST: string = 'voicedrop.cn';
  static readonly FILES: string = `https://${Api.HOST}/files/api`;
  static readonly AGENT: string = `https://${Api.HOST}/agent`;
  static readonly RECO: string = `https://${Api.HOST}/reco`;
  static readonly AGENT_WS: string = `wss://${Api.HOST}/agent`;

  static path(value: string): string {
    return value.split('/').map((part: string) => encodeURIComponent(part)).join('/');
  }

  static sharePage(id: string): string {
    return `https://voicedrop.cn/${Api.path(id)}`;
  }
}

