import { Api } from '../core/Api';
import { authStore } from './AuthStore';
import { httpClient, HttpResponse } from '../net/HttpClient';

interface UsageBalanceWire { suanli?: number; spent_suanli?: number; }
interface UsageSummaryRowWire { reason_code?: string; reason?: string; suanli?: number; count?: number; }
interface UsageSummaryWire { granted?: UsageSummaryRowWire[]; spent?: UsageSummaryRowWire[]; }
interface UsageEntryWire {
  id?: number;
  ts?: number;
  kind?: string;
  reason?: string;
  suanli?: number;
  balance_suanli?: number;
}
interface UsageLedgerWire { entries?: UsageEntryWire[]; has_more?: boolean; next?: string; }

export class UsageBalance {
  suanli: number;
  spentSuanli: number;
  constructor(suanli: number = 0, spentSuanli: number = 0) {
    this.suanli = suanli;
    this.spentSuanli = spentSuanli;
  }
}

export class UsageSummaryRow {
  reasonCode: string;
  reason: string;
  suanli: number;
  count: number;
  constructor(reasonCode: string = '', reason: string = '', suanli: number = 0, count: number = 1) {
    this.reasonCode = reasonCode;
    this.reason = reason;
    this.suanli = suanli;
    this.count = count;
  }
}

export class UsageSummary {
  granted: UsageSummaryRow[];
  spent: UsageSummaryRow[];
  constructor(granted: UsageSummaryRow[] = [], spent: UsageSummaryRow[] = []) {
    this.granted = granted;
    this.spent = spent;
  }
}

export class UsageEntry {
  id: number;
  ts: number;
  kind: string;
  reason: string;
  suanli: number;
  balanceSuanli: number;
  constructor(id: number = 0, ts: number = 0, kind: string = '', reason: string = '', suanli: number = 0,
    balanceSuanli: number = 0) {
    this.id = id;
    this.ts = ts;
    this.kind = kind;
    this.reason = reason;
    this.suanli = suanli;
    this.balanceSuanli = balanceSuanli;
  }
}

export class UsageLedgerPage {
  entries: UsageEntry[];
  nextCursor: string;
  constructor(entries: UsageEntry[] = [], nextCursor: string = '') {
    this.entries = entries;
    this.nextCursor = nextCursor;
  }
}

export class UsageStore {
  static readonly SUANLI_PER_ARTICLE: number = 9;

  articleCapacity(balance: number): number {
    return Math.max(0, Math.floor(balance / UsageStore.SUANLI_PER_ARTICLE));
  }

  async balance(): Promise<UsageBalance> {
    const response: HttpResponse = await httpClient.get(`${Api.AGENT}/usage/balance`, authStore.bearer());
    if (!response.ok()) throw new Error(`算力余额加载失败 HTTP ${response.code}`);
    const wire: UsageBalanceWire = JSON.parse(response.text) as UsageBalanceWire;
    return new UsageBalance(wire.suanli ?? 0, wire.spent_suanli ?? 0);
  }

  async summary(): Promise<UsageSummary> {
    const response: HttpResponse = await httpClient.get(`${Api.AGENT}/usage/summary`, authStore.bearer());
    if (!response.ok()) throw new Error(`算力汇总加载失败 HTTP ${response.code}`);
    const wire: UsageSummaryWire = JSON.parse(response.text) as UsageSummaryWire;
    return new UsageSummary(this.summaryRows(wire.granted ?? []), this.summaryRows(wire.spent ?? []));
  }

  async ledger(before: string = ''): Promise<UsageLedgerPage> {
    let url: string = `${Api.AGENT}/usage/ledger?limit=50`;
    if (before.length > 0) url += `&before=${encodeURIComponent(before)}`;
    const response: HttpResponse = await httpClient.get(url, authStore.bearer());
    if (!response.ok()) throw new Error(`算力明细加载失败 HTTP ${response.code}`);
    const wire: UsageLedgerWire = JSON.parse(response.text) as UsageLedgerWire;
    const entries: UsageEntry[] = (wire.entries ?? []).map((entry: UsageEntryWire) => new UsageEntry(
      entry.id ?? 0, entry.ts ?? 0, entry.kind ?? '', entry.reason ?? '', entry.suanli ?? 0,
      entry.balance_suanli ?? 0));
    return new UsageLedgerPage(entries, wire.has_more === true ? wire.next ?? '' : '');
  }

  private summaryRows(rows: UsageSummaryRowWire[]): UsageSummaryRow[] {
    return rows.map((row: UsageSummaryRowWire) => new UsageSummaryRow(
      row.reason_code ?? '', row.reason ?? '', row.suanli ?? 0, row.count ?? 1));
  }
}

export const usageStore: UsageStore = new UsageStore();
