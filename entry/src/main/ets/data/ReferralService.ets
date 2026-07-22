import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

interface InviteLinkWire {
  url?: string;
  name?: string;
  suanliInviter?: number;
  suanliFriend?: number;
}
interface ClaimWire { attributed?: boolean; reason?: string; }
class ClaimBody {
  source: string;
  token?: string;
  constructor(source: string, token: string = '') { this.source = source; if (token.length > 0) this.token = token; }
}

export class InviteLink {
  url: string;
  name: string;
  suanliInviter: number;
  suanliFriend: number;
  constructor(url: string, name: string, suanliInviter: number, suanliFriend: number) {
    this.url = url; this.name = name; this.suanliInviter = suanliInviter; this.suanliFriend = suanliFriend;
  }
}

export class ReferralService {
  async inviteLink(): Promise<InviteLink | undefined> {
    const response: HttpResponse = await httpClient.get(`${Api.AGENT}/referral/link`, authStore.bearer());
    if (!response.ok()) return undefined;
    try {
      const wire: InviteLinkWire = JSON.parse(response.text) as InviteLinkWire;
      const url: string = (wire.url ?? '').trim();
      return url.length > 0 ? new InviteLink(url, (wire.name ?? '').trim(),
        wire.suanliInviter ?? 0, wire.suanliFriend ?? 0) : undefined;
    } catch (_) { return undefined; }
  }

  async claim(source: string, token: string = ''): Promise<string> {
    try {
      const response: HttpResponse = await httpClient.postJson(`${Api.AGENT}/referral/claim`, authStore.bearer(),
        new ClaimBody(source, token.trim()));
      if (!response.ok()) return '';
      const wire: ClaimWire = JSON.parse(response.text) as ClaimWire;
      if (wire.attributed) return 'attributed';
      return wire.reason ?? '';
    } catch (_) { return ''; }
  }

  shareToken(text: string): string {
    const match: RegExpMatchArray | null = text.match(/(?:https?:\/\/)?(?:www\.)?(?:voicedrop\.cn\/|jianshuo\.dev\/voicedrop\/)(?:i\/)?([A-Za-z0-9_-]{6,16})/i);
    if (!match) return '';
    const value: string = match[1];
    return ['privacy', 'welcome', 'help'].includes(value.toLowerCase()) ? '' : value;
  }
}

export const referralService: ReferralService = new ReferralService();
