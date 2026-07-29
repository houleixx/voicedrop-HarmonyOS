import { describe, expect, it } from '@ohos/hypium';
import { RecordingUploadPolicy } from '../../../main/ets/core/RecordingUploadPolicy';

export default function recordingUploadPolicyTest() {
  describe('RecordingUploadPolicy', () => {
    it('keepsAStoredAudioUploadSuccessfulWhenTheExtraMineTriggerFails', 0, () => {
      expect(RecordingUploadPolicy.uploadCompleted(true, false)).assertTrue();
    });

    it('doesNotCompleteWhenTheAudioPutFailed', 0, () => {
      expect(RecordingUploadPolicy.uploadCompleted(false, true)).assertFalse();
    });
  });
}
