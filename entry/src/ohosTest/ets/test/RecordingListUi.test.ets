import { describe, expect, it } from '@ohos/hypium';
import { RecordingListUi } from '../../../main/ets/core/RecordingListUi';
import { Recording } from '../../../main/ets/model/Models';

export default function recordingListUiTest() {
  describe('RecordingListUi', () => {
    it('removesOnlyTheSuccessfullyDeletedRecording', 0, () => {
      const first: Recording = new Recording({ name: 'VoiceDrop-first.m4a' });
      const second: Recording = new Recording({ name: 'VoiceDrop-second.m4a' });
      const remaining: Recording[] = RecordingListUi.afterSuccessfulDelete([first, second], first.name);
      expect(remaining.length).assertEqual(1);
      expect(remaining[0].name).assertEqual(second.name);
    });

    it('keepsTheListUnchangedWhenTheRecordingIsAbsent', 0, () => {
      const recording: Recording = new Recording({ name: 'VoiceDrop-kept.m4a' });
      const remaining: Recording[] = RecordingListUi.afterSuccessfulDelete([recording], 'missing.m4a');
      expect(remaining.length).assertEqual(1);
      expect(remaining[0].name).assertEqual(recording.name);
    });

    it('doesNotRestoreDeletedRowsFromPendingFilesOrAStaleServerIndex', 0, () => {
      const deletedPending: Recording = new Recording({ name: 'VoiceDrop-deleted.m4a' });
      deletedPending.uploading = true;
      const deletedRemote: Recording = new Recording({ name: 'VoiceDrop-deleted.m4a' });
      const keptRemote: Recording = new Recording({ name: 'VoiceDrop-kept.m4a' });
      const refreshed: Recording[] = RecordingListUi.afterRefresh(
        [deletedPending], [deletedRemote, keptRemote], [deletedRemote.name]);
      expect(refreshed.length).assertEqual(1);
      expect(refreshed[0].name).assertEqual(keptRemote.name);
    });
  });
}
