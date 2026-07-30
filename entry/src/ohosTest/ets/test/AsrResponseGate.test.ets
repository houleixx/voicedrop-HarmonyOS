import { describe, expect, it } from '@ohos/hypium';
import { AsrResponseGate, AsrResponseReceipt } from '../../../main/ets/core/AsrResponseGate';

export default function asrResponseGateTest() {
  describe('AsrResponseGate', () => {
    it('doesNotLetAnOldFinalParsedLateCloseTheTailResponseWindow', 0, () => {
      const gate: AsrResponseGate = new AsrResponseGate();
      const beforeLastFrame: AsrResponseReceipt = gate.begin(false);
      const afterLastFrame: AsrResponseReceipt = gate.begin(true);

      // HarmonyOS gzip parsing is asynchronous. Model the newer response
      // completing first, followed by the stale pre-tail response.
      expect(gate.accept(afterLastFrame)).assertTrue();
      expect(gate.shouldFinish(afterLastFrame, true)).assertTrue();
      expect(gate.accept(beforeLastFrame)).assertFalse();
      expect(gate.shouldFinish(beforeLastFrame, true)).assertFalse();
    });

    it('requiresTheFinalResponseToArriveAfterTheLastAudioFrame', 0, () => {
      const gate: AsrResponseGate = new AsrResponseGate();
      const staleFinal: AsrResponseReceipt = gate.begin(false);
      expect(gate.accept(staleFinal)).assertTrue();
      expect(gate.shouldFinish(staleFinal, true)).assertFalse();
    });
  });
}
