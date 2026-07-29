import { describe, expect, it } from '@ohos/hypium';
import {
  MIN_RECORDING_DURATION_SECONDS,
  isRecordingTooShort
} from '../../../main/ets/core/RecordingPolicy';

export default function recordingPolicyTest() {
  describe('RecordingPolicy', () => {
    it('usesFourSecondsAsTheSharedMinimum', 0, () => {
      expect(MIN_RECORDING_DURATION_SECONDS).assertEqual(4);
    });

    it('rejectsDurationsBelowFourSeconds', 0, () => {
      expect(isRecordingTooShort(0)).assertTrue();
      expect(isRecordingTooShort(3.999)).assertTrue();
    });

    it('acceptsFourSecondsAndLonger', 0, () => {
      expect(isRecordingTooShort(4)).assertFalse();
      expect(isRecordingTooShort(30)).assertFalse();
    });
  });
}
