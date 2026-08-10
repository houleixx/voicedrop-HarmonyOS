import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

export class StyleSettings {
  style?: string;
  name?: string;
}
export class WechatSettings {
  appid?: string;
  secret?: string;
  enabled?: boolean;
}
export class AppConfig {
  autoShareCommunity?: boolean;
}
export class StyleVersion {
  v: number = 0;
  style: string = '';
  source?: string;
  savedAt?: string | number;
  createdAt?: string | number;
}
export class StyleHistory {
  head: number = 0;
  versions: StyleVersion[] = [];
}
class StyleBody {
  style: string;
  constructor(style: string) { this.style = style; }
}
class NameBody {
  name: string;
  constructor(name: string) { this.name = name; }
}
export class FeedbackBody {
  text: string;
  name: string;
  version: string;
  constructor(text: string, name: string, version: string) {
    this.text = text.trim().substring(0, 2000);
    this.name = name.trim();
    this.version = version.trim();
  }
}
class StyleHeadBody {
  head: number;
  constructor(head: number) { this.head = head; }
}
class AppConfigBody {
  autoShareCommunity: boolean;
  constructor(autoShareCommunity: boolean) { this.autoShareCommunity = autoShareCommunity; }
}
class WechatCredentialBody {
  appid: string;
  secret: string;
  constructor(appid: string, secret: string) { this.appid = appid; this.secret = secret; }
}
interface WechatValidationWire { ok?: boolean; errcode?: number; errmsg?: string; }

export class SettingsStore {
  async loadStyle(): Promise<StyleSettings> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/style`, authStore.bearer());
    return response.ok() ? JSON.parse(response.text) as StyleSettings : new StyleSettings();
  }

  async saveStyle(style: string): Promise<boolean> {
    return (await httpClient.putJson(`${Api.FILES}/style`, authStore.bearer(), new StyleBody(style.trim()))).ok();
  }

  async saveName(name: string): Promise<boolean> {
    return (await httpClient.putJson(`${Api.FILES}/style`, authStore.bearer(), new NameBody(name.trim()))).ok();
  }

  async sendFeedback(text: string, name: string = '', version: string = ''): Promise<boolean> {
    const body: FeedbackBody = new FeedbackBody(text, name, version);
    if (body.text.length === 0) return false;
    return (await httpClient.postJson(`${Api.AGENT}/feedback`, authStore.bearer(), body)).ok();
  }

  async loadStyleHistory(): Promise<StyleHistory> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/style/history`, authStore.bearer());
    if (!response.ok()) return new StyleHistory();
    const history: StyleHistory = JSON.parse(response.text) as StyleHistory;
    history.versions = Array.isArray(history.versions) ? history.versions : [];
    return history;
  }

  async saveStyleHead(head: number): Promise<boolean> {
    return (await httpClient.patchJson(`${Api.FILES}/style/head`, authStore.bearer(), new StyleHeadBody(head))).ok();
  }

  async loadWechat(): Promise<WechatSettings> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/download/WECHAT.json`, authStore.bearer());
    return response.ok() ? JSON.parse(response.text) as WechatSettings : new WechatSettings();
  }

  async saveWechat(settings: WechatSettings): Promise<boolean> {
    return (await httpClient.putJson(`${Api.FILES}/upload/WECHAT.json`, authStore.bearer(), settings)).ok();
  }

  async loadConfig(): Promise<AppConfig> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/download/CONFIG.json`, authStore.bearer());
    return response.ok() ? JSON.parse(response.text) as AppConfig : new AppConfig();
  }

  async saveConfig(autoShareCommunity: boolean): Promise<boolean> {
    return (await httpClient.putJson(`${Api.FILES}/upload/CONFIG.json`, authStore.bearer(),
      new AppConfigBody(autoShareCommunity))).ok();
  }

  wechatCredentialError(appid: string, secret: string): string {
    if (!/^wx[0-9A-Za-z]{16}$/.test(appid.trim())) return 'AppID 格式不对（应以 wx 开头，共 18 位）';
    if (!/^[0-9a-f]{32}$/.test(secret.trim())) return 'AppSecret 格式不对（应为 32 位小写十六进制）';
    return '';
  }

  async validateWechat(appid: string, secret: string): Promise<string> {
    try {
      const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/wechat-validate`, authStore.bearer(),
        new WechatCredentialBody(appid.trim(), secret.trim()));
      if (!response.ok()) return '暂时连不上验证服务，请稍后再试（配置未保存）';
      const result: WechatValidationWire = JSON.parse(response.text) as WechatValidationWire;
      if (result.ok === true) return '';
      if (result.errcode === 40164) return '服务器 IP 还没生效：请把服务端 IP 加入公众号后台的 IP 白名单，保存后等一两分钟再试';
      if (result.errcode === 40013) return 'AppID 无效，找不到这个公众号';
      if (result.errcode === 40125) return 'AppSecret 无效';
      if (result.errcode === 41002) return '缺少 AppID';
      if (result.errcode === 41004) return '缺少 AppSecret';
      return `验证失败：${result.errmsg ?? '未知错误'}`;
    } catch (_) { return '暂时连不上验证服务，请稍后再试（配置未保存）'; }
  }
}

export const settingsStore: SettingsStore = new SettingsStore();
