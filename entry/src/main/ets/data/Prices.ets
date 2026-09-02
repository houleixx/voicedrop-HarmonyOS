import { Api } from '../core/Api';
import { httpClient } from '../net/HttpClient';
import { appPreferences } from './AppPreferences';

interface PricesWire { book?: number; book_revise?: number; }

/** Display prices are cached for a day; the server remains the billing authority. */
export class PriceTable {
  book: number;
  bookRevise: number;
  fetchedAt: number;
  constructor(book: number = 160, bookRevise: number = 40, fetchedAt: number = 0) {
    this.book = book; this.bookRevise = bookRevise; this.fetchedAt = fetchedAt;
  }
}

export class Prices {
  static readonly FALLBACK: PriceTable = new PriceTable(160, 40, 0);
  static readonly TTL_MS: number = 24 * 60 * 60 * 1000;

  static isStale(table: PriceTable | undefined, now: number): boolean {
    return table === undefined || now - table.fetchedAt > Prices.TTL_MS;
  }

  /** A valid book price is required; an absent or invalid revise price retains the last known valid value. */
  static merge(remote: PricesWire | undefined, previous: PriceTable, now: number): PriceTable | undefined {
    if (remote === undefined || !Prices.positive(remote.book)) return undefined;
    const revise: number = Prices.positive(remote.book_revise) ? remote.book_revise as number : previous.bookRevise;
    return new PriceTable(remote.book as number, revise, now);
  }

  static load(raw: string): PriceTable | undefined {
    try {
      const stored: PriceTable = JSON.parse(raw) as PriceTable;
      return Prices.positive(stored.book) && Prices.positive(stored.bookRevise) && Number.isFinite(stored.fetchedAt)
        ? new PriceTable(stored.book, stored.bookRevise, stored.fetchedAt) : undefined;
    } catch (_) { return undefined; }
  }

  static current(): PriceTable { return Prices.load(appPreferences.pricesCache()) ?? Prices.FALLBACK; }

  /** This request is deliberately public: /agent/usage/prices does not use a bearer token. */
  async refreshIfNeeded(now: number = Date.now()): Promise<PriceTable> {
    const cached: PriceTable | undefined = Prices.load(appPreferences.pricesCache());
    const previous: PriceTable = cached ?? Prices.FALLBACK;
    if (!Prices.isStale(cached, now)) return previous;
    try {
      const response = await httpClient.get(`${Api.AGENT}/usage/prices`);
      if (!response.ok()) return previous;
      const next: PriceTable | undefined = Prices.merge(JSON.parse(response.text) as PricesWire, previous, now);
      if (next === undefined) return previous;
      await appPreferences.savePricesCache(JSON.stringify(next));
      return next;
    } catch (_) { return previous; }
  }

  private static positive(value: number | undefined): boolean {
    return value !== undefined && Number.isFinite(value) && value > 0;
  }
}

export const prices: Prices = new Prices();
