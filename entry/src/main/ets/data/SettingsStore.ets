import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';
import { WechatAuthorizationPage, WechatBindStatus, WechatBinding } from '../core/WechatBinding';

export class StyleSettings {
  style?: string;
  name?: string;
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
class EmptyWechatBody {}

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

  async wechatBindStatus(): Promise<WechatBindStatus> {
    const requestScope: string = authStore.storageScope();
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/wechat/bind-status`, authStore.bearer());
    if (!response.ok()) throw new Error(`wechat bind status HTTP ${response.code}`);
    if (requestScope !== authStore.storageScope()) throw new Error('wechat bind status account changed');
    const status: WechatBindStatus = WechatBinding.bindStatus(response.code, response.text);
    authStore.storeWechatBindStatusCache(WechatBinding.bindStatusCacheJson(status));
    return status;
  }

  cachedWechatBindStatus(): WechatBindStatus | undefined {
    return WechatBinding.bindStatusCache(authStore.wechatBindStatusCache());
  }

  async createWechatAuthorization(): Promise<string> {
    const response: HttpResponse = await httpClient.postJson(`${Api.FILES}/wechat/authorization`, authStore.bearer(),
      new EmptyWechatBody());
    return WechatBinding.authorizationUrl(response.code, response.text);
  }

  async createWechatAuthorizationPage(): Promise<WechatAuthorizationPage> {
    const scanUrl: string = await this.createWechatAuthorization();
    if (scanUrl.length === 0) return new WechatAuthorizationPage();
    const response: HttpResponse = await httpClient.get(scanUrl);
    if (!response.ok()) return new WechatAuthorizationPage();
    return WechatBinding.authorizationPage(scanUrl, response.text);
  }

  async unbindWechat(): Promise<boolean> {
    const success: boolean =
      (await httpClient.postJson(`${Api.FILES}/wechat/unbind`, authStore.bearer(), new EmptyWechatBody())).ok();
    if (success) authStore.storeWechatBindStatusCache(WechatBinding.bindStatusCacheJson(new WechatBindStatus()));
    return success;
  }

  async loadConfig(): Promise<AppConfig> {
    const response: HttpResponse = await httpClient.get(`${Api.FILES}/download/CONFIG.json`, authStore.bearer());
    return response.ok() ? JSON.parse(response.text) as AppConfig : new AppConfig();
  }

  async saveConfig(autoShareCommunity: boolean): Promise<boolean> {
    return (await httpClient.putJson(`${Api.FILES}/upload/CONFIG.json`, authStore.bearer(),
      new AppConfigBody(autoShareCommunity))).ok();
  }

}

export const settingsStore: SettingsStore = new SettingsStore();
