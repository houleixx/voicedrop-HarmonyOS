import { describe, expect, it } from '@ohos/hypium';
import { RecordingStopPolicy } from '../../../main/ets/core/RecordingStopPolicy';

function containerBytes(complete: boolean): Uint8Array {
  const bytes: Uint8Array = new Uint8Array(1200);
  if (complete) {
    bytes[1100] = 109;
    bytes[1101] = 111;
    bytes[1102] = 111;
    bytes[1103] = 118;
  }
  return bytes;
}

export default function recordingStopPolicyTest() {
  describe('RecordingStopPolicy', () => {
    it('finalizesACompleteM4aEvenWhenStopReportedIoError', 0, () => {
      expect(RecordingStopPolicy.canFinalize(false, true)).assertEqual(true);
    });

    it('doesNotFinalizeAnIncompleteFileAfterStopFailure', 0, () => {
      expect(RecordingStopPolicy.canFinalize(false, false)).assertEqual(false);
    });

    it('doesNotFinalizeAnIncompleteFileEvenWhenStopReturned', 0, () => {
      expect(RecordingStopPolicy.canFinalize(true, false)).assertEqual(false);
    });

    it('recognizesOnlyNonTrivialM4aContainersWithMoov', 0, () => {
      expect(RecordingStopPolicy.hasCompleteM4a(containerBytes(true))).assertEqual(true);
      expect(RecordingStopPolicy.hasCompleteM4a(containerBytes(false))).assertEqual(false);
      expect(RecordingStopPolicy.hasCompleteM4a(new Uint8Array(10))).assertEqual(false);
    });
  });
}
