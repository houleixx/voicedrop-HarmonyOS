import { describe, expect, it } from '@ohos/hypium';
import { RecordingName } from '../../../main/ets/core/RecordingName';

export default function recordingNameTest() {
  describe('RecordingName', () => {
    it('createsIosCompatibleRecordingPhotoKeys', 0, () => {
      expect(RecordingName.photoKey('2026-07-26-102030', 42, 'A9z'))
        .assertEqual('photos/2026-07-26-102030/42-a9z.jpg');
    });

    it('clampsNegativePhotoOffsets', 0, () => {
      expect(RecordingName.photoKey('2026-07-26-102030', -5, 'abc'))
        .assertEqual('photos/2026-07-26-102030/0-abc.jpg');
    });

    it('formatsRecordingDateAndTimeForLibraryRows', 0, () => {
      expect(RecordingName.dateTimeLabel(
        'VoiceDrop-2026-07-30-094812-1m05s-Thu-Morning.m4a'))
        .assertEqual('7月30日 09:48');
    });

    it('returnsEmptyDateAndTimeForUnknownNames', 0, () => {
      expect(RecordingName.dateTimeLabel('other-recording.m4a')).assertEqual('');
    });
  });
}
