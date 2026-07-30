/**
 * Preserve ASR response arrival semantics across asynchronous decompression.
 *
 * HarmonyOS parses gzip response bodies asynchronously, so an older response
 * can finish parsing after a newer one. Arrival order is authoritative because
 * ASR text snapshots are cumulative.
 */

export class AsrResponseReceipt {
  order: number;
  arrivedAfterLastFrame: boolean;

  constructor(order: number, arrivedAfterLastFrame: boolean) {
    this.order = order;
    this.arrivedAfterLastFrame = arrivedAfterLastFrame;
  }
}

export class AsrResponseGate {
  private nextOrder: number = 0;
  private latestAcceptedOrder: number = 0;

  begin(lastFrameSent: boolean): AsrResponseReceipt {
    this.nextOrder += 1;
    return new AsrResponseReceipt(this.nextOrder, lastFrameSent);
  }

  accept(receipt: AsrResponseReceipt): boolean {
    if (receipt.order <= this.latestAcceptedOrder) return false;
    this.latestAcceptedOrder = receipt.order;
    return true;
  }

  shouldFinish(receipt: AsrResponseReceipt, isFinal: boolean): boolean {
    return receipt.arrivedAfterLastFrame && isFinal;
  }

  reset(): void {
    this.nextOrder = 0;
    this.latestAcceptedOrder = 0;
  }
}
