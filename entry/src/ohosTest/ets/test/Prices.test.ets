import { describe, expect, it } from '@ohos/hypium';
import { PriceTable, Prices } from '../../../main/ets/data/Prices';

export default function pricesTest() {
  describe('Prices', () => {
    it('mergesAValidBookAndPreservesTheLastValidRevisePrice', 0, () => {
      const previous = new PriceTable(160, 40, 0);
      const next = Prices.merge({ book: 123, book_revise: 45 }, previous, 1000);
      expect(next?.book).assertEqual(123);
      expect(next?.bookRevise).assertEqual(45);
      expect(Prices.merge({ book: 123 }, previous, 1000)?.bookRevise).assertEqual(40);
      expect(Prices.merge({ book: 123, book_revise: 0 }, previous, 1000)?.bookRevise).assertEqual(40);
      expect(Prices.merge({ book: 0, book_revise: 40 }, previous, 1000) === undefined).assertTrue();
    });

    it('expiresPriceTablesAfterTwentyFourHours', 0, () => {
      const now = 100000000;
      expect(Prices.isStale(new PriceTable(160, 40, now - Prices.TTL_MS), now)).assertFalse();
      expect(Prices.isStale(new PriceTable(160, 40, now - Prices.TTL_MS - 1), now)).assertTrue();
      expect(Prices.load('{"book":160,"bookRevise":40,"fetchedAt":7}')?.bookRevise).assertEqual(40);
      expect(Prices.load('{"book":160,"bookRevise":0,"fetchedAt":7}') === undefined).assertTrue();
    });
  });
}
