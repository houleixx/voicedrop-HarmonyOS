import { Api } from './Api';

interface WechatBindStatusWire {
  connected?: boolean;
  account_name?: string;
  authorizer_appid?: string;
  enabled?: boolean;
}

interface WechatAuthorizationWire {
  scan_url?: string;
}

interface WechatBindStatusCacheWire {
  connected?: boolean;
  accountName?: string;
  authorizerAppid?: string;
  enabled?: boolean;
  updatedAt?: number;
}

export class WechatBindStatus {
  connected: boolean;
  accountName: string;
  authorizerAppid: string;
  enabled: boolean;

  constructor(connected: boolean = false, accountName: string = '', authorizerAppid: string = '',
    enabled: boolean = false) {
    this.connected = connected;
    this.accountName = accountName;
    this.authorizerAppid = authorizerAppid;
    this.enabled = enabled;
  }
}

export class WechatAuthorizationPage {
  scanUrl: string;
  html: string;

  constructor(scanUrl: string = '', html: string = '') {
    this.scanUrl = scanUrl;
    this.html = html;
  }
}

export class WechatQrCropRegion {
  x: number;
  y: number;
  width: number;
  height: number;

  constructor(x: number = 0, y: number = 0, width: number = 0, height: number = 0) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

export class WechatBinding {
  static bindStatusCache(raw: string): WechatBindStatus | undefined {
    if (raw.length === 0) return undefined;
    try {
      const wire: WechatBindStatusCacheWire = JSON.parse(raw) as WechatBindStatusCacheWire;
      if (typeof wire.connected !== 'boolean' || typeof wire.updatedAt !== 'number' ||
        !Number.isFinite(wire.updatedAt) || wire.updatedAt <= 0) return undefined;
      return new WechatBindStatus(wire.connected, wire.accountName ?? '', wire.authorizerAppid ?? '',
        wire.connected && wire.enabled !== false);
    } catch (_) {
      return undefined;
    }
  }

  static bindStatusCacheJson(status: WechatBindStatus, updatedAt: number = Date.now()): string {
    const wire: WechatBindStatusCacheWire = {
      connected: status.connected,
      accountName: status.accountName,
      authorizerAppid: status.authorizerAppid,
      enabled: status.enabled,
      updatedAt: updatedAt
    };
    return JSON.stringify(wire);
  }

  static qrCropRegion(value: string, imageWidth: number, imageHeight: number): WechatQrCropRegion {
    const fields: number[] = value.replace(/^"|"$/g, '').split(',').map((field: string): number => Number(field));
    if (fields.length !== 6 || fields.some((field: number): boolean => !Number.isFinite(field)) ||
      fields[2] <= 0 || fields[3] <= 0 || fields[4] <= 0 || fields[5] <= 0 ||
      imageWidth <= 0 || imageHeight <= 0) return new WechatQrCropRegion();
    const padding: number = Math.max(12, Math.min(fields[2], fields[3]) * 0.06);
    const side: number = Math.max(fields[2], fields[3]) + padding * 2;
    const documentX: number = Math.max(0, Math.min(fields[4] - side, fields[0] + fields[2] / 2 - side / 2));
    const documentY: number = Math.max(0, Math.min(fields[5] - side, fields[1] + fields[3] / 2 - side / 2));
    const x: number = Math.max(0, Math.floor(documentX * imageWidth / fields[4]));
    const y: number = Math.max(0, Math.floor(documentY * imageHeight / fields[5]));
    const width: number = Math.min(imageWidth - x, Math.ceil(side * imageWidth / fields[4]));
    const height: number = Math.min(imageHeight - y, Math.ceil(side * imageHeight / fields[5]));
    return new WechatQrCropRegion(x, y, width, height);
  }

  static bindStatus(statusCode: number, responseBody: string): WechatBindStatus {
    if (statusCode < 200 || statusCode >= 300) return new WechatBindStatus();
    try {
      const wire: WechatBindStatusWire = JSON.parse(responseBody) as WechatBindStatusWire;
      if (wire.connected !== true) return new WechatBindStatus();
      return new WechatBindStatus(true, wire.account_name ?? '', wire.authorizer_appid ?? '', wire.enabled !== false);
    } catch (_) {
      return new WechatBindStatus();
    }
  }

  static authorizationUrl(statusCode: number, responseBody: string): string {
    if (statusCode < 200 || statusCode >= 300) return '';
    try {
      const wire: WechatAuthorizationWire = JSON.parse(responseBody) as WechatAuthorizationWire;
      const value: string = wire.scan_url?.trim() ?? '';
      const prefix: string = `${Api.FILES}/wechat/scan?state=`;
      if (!value.startsWith(prefix)) return '';
      const state: string = value.substring(prefix.length);
      return /^[A-Za-z0-9._~-]+$/.test(state) ? value : '';
    } catch (_) {
      return '';
    }
  }

  static authorizationPage(scanUrl: string, scanHtml: string): WechatAuthorizationPage {
    const scanPrefix: string = `${Api.FILES}/wechat/scan?state=`;
    if (!scanUrl.startsWith(scanPrefix) || !/^[A-Za-z0-9._~-]+$/.test(scanUrl.substring(scanPrefix.length))) {
      return new WechatAuthorizationPage();
    }
    const match: RegExpMatchArray | null = scanHtml.match(
      /window\.location\.replace\s*\(\s*("(?:\\.|[^"\\])*")\s*\)/);
    if (!match) return new WechatAuthorizationPage();
    try {
      const authorizationUrl: string = JSON.parse(match[1]) as string;
      if (!WechatBinding.isTrustedAuthorizationUrl(authorizationUrl)) return new WechatAuthorizationPage();
      const html: string = '<!doctype html><meta charset="utf-8">' +
        '<meta name="referrer" content="origin">' +
        '<meta name="viewport" content="width=device-width,initial-scale=1">' +
        '<title>正在打开微信授权</title><p>正在打开微信授权二维码页…</p>' +
        `<script>window.location.replace(${JSON.stringify(authorizationUrl)});</script>`;
      return new WechatAuthorizationPage(scanUrl, html);
    } catch (_) {
      return new WechatAuthorizationPage();
    }
  }

  static isTrustedAuthorizationNavigation(value: string): boolean {
    return value.startsWith(`${Api.FILES}/wechat/scan?state=`) ||
      WechatBinding.isTrustedAuthorizationUrl(value) || WechatBinding.isTrustedVoiceDropAuthorizationRedirect(value);
  }

  private static isTrustedVoiceDropAuthorizationRedirect(value: string): boolean {
    const successUrl: string = `${Api.FILES}/wechat/auth-success`;
    if (value === successUrl || value.startsWith(`${successUrl}#`)) return true;
    const callbackPrefix: string = `${Api.FILES}/wechat/auth-callback?`;
    if (!value.startsWith(callbackPrefix)) return false;
    const fields: string[] = value.substring(callbackPrefix.length).split('#')[0].split('&');
    return WechatBinding.hasQueryValue(fields, 'state') && WechatBinding.hasQueryValue(fields, 'auth_code');
  }

  private static isTrustedAuthorizationUrl(value: string): boolean {
    const prefix: string = 'https://mp.weixin.qq.com/cgi-bin/componentloginpage?';
    if (!value.startsWith(prefix)) return false;
    const query: string = value.substring(prefix.length).split('#')[0];
    const fields: string[] = query.split('&');
    return WechatBinding.hasQueryValue(fields, 'component_appid') &&
      WechatBinding.hasQueryValue(fields, 'pre_auth_code') &&
      WechatBinding.hasQueryValue(fields, 'redirect_uri');
  }

  private static hasQueryValue(fields: string[], name: string): boolean {
    const prefix: string = `${name}=`;
    return fields.some((field: string): boolean => field.startsWith(prefix) && field.length > prefix.length);
  }
}
