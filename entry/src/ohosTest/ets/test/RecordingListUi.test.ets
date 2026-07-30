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

    it('prependsAFinalizedLocalTakeAsUploading', 0, () => {
      const pending: Recording = new Recording({ name: 'VoiceDrop-new.m4a' });
      pending.uploading = true;
      const remote: Recording = new Recording({ name: 'VoiceDrop-existing.m4a' });
      const refreshed: Recording[] = RecordingListUi.afterRefresh([pending], [remote], []);
      expect(refreshed.length).assertEqual(2);
      expect(refreshed[0].name).assertEqual(pending.name);
      expect(refreshed[0].statusLabel()).assertEqual('正在上传');
    });

    it('showsAStoppedTakeAsSavingBeforeTheFileIsFinalized', 0, () => {
      const existing: Recording = new Recording({ name: 'VoiceDrop-existing.m4a' });
      const saving: Recording = new Recording({ name: 'VoiceDrop-saving.m4a' });
      saving.saving = true;
      const updated: Recording[] = RecordingListUi.beginSaving([existing], saving);
      expect(updated.length).assertEqual(2);
      expect(updated[0].name).assertEqual(saving.name);
      expect(updated[0].statusLabel()).assertEqual('正在保存');
    });

    it('replacesTheSavingRowWithTheFinalizedUploadingTake', 0, () => {
      const saving: Recording = new Recording({ name: 'VoiceDrop-saving.m4a' });
      saving.saving = true;
      const existing: Recording = new Recording({ name: 'VoiceDrop-existing.m4a' });
      const pending: Recording = new Recording({ name: 'VoiceDrop-final.m4a' });
      pending.uploading = true;
      const updated: Recording[] = RecordingListUi.finishSaving([saving, existing], saving.name, pending);
      expect(updated.length).assertEqual(2);
      expect(updated[0].name).assertEqual(pending.name);
      expect(updated[0].statusLabel()).assertEqual('正在上传');
    });

    it('removesTheSavingRowWhenFinalizationFails', 0, () => {
      const saving: Recording = new Recording({ name: 'VoiceDrop-saving.m4a' });
      saving.saving = true;
      const existing: Recording = new Recording({ name: 'VoiceDrop-existing.m4a' });
      const updated: Recording[] = RecordingListUi.cancelSaving([saving, existing], saving.name);
      expect(updated.length).assertEqual(1);
      expect(updated[0].name).assertEqual(existing.name);
    });

    it('keepsTheSavingRowAtTheTopDuringARefresh', 0, () => {
      const saving: Recording = new Recording({ name: 'VoiceDrop-saving.m4a' });
      saving.saving = true;
      const staleRemote: Recording = new Recording({ name: saving.name });
      const remote: Recording = new Recording({ name: 'VoiceDrop-existing.m4a' });
      const refreshed: Recording[] = RecordingListUi.afterRefresh([], [staleRemote, remote], [], [saving]);
      expect(refreshed.length).assertEqual(2);
      expect(refreshed[0].statusLabel()).assertEqual('正在保存');
      expect(refreshed[1].name).assertEqual(remote.name);
    });

    it('keepsAnEnrichedTitleWhenTheLightweightServerRowHasNoTitle', 0, () => {
      const previous: Recording = new Recording({
        name: 'VoiceDrop-ready.m4a',
        hasArticles: true,
        title: '已经生成的标题',
        tags: ['随笔'],
        coverPhotoKey: 'photos/session/0-cover.jpg'
      });
      const lightweight: Recording = new Recording({
        name: previous.name,
        hasArticles: true
      });
      const refreshed: Recording[] = RecordingListUi.afterRefresh(
        [], [lightweight], [], [], [previous]);
      expect(refreshed[0].rowTitle()).assertEqual('已经生成的标题');
      expect(refreshed[0].tags.join(',')).assertEqual('随笔');
      expect(refreshed[0].coverPhotoKey).assertEqual('photos/session/0-cover.jpg');
    });

    it('doesNotDowngradeALiveWebSocketPhaseDuringPullRefresh', 0, () => {
      const previous: Recording = new Recording({
        name: 'VoiceDrop-processing.m4a',
        phase: 'mining'
      });
      const lightweight: Recording = new Recording({
        name: previous.name
      });
      const refreshed: Recording[] = RecordingListUi.afterRefresh(
        [], [lightweight], [], [], [previous]);
      expect(refreshed[0].statusLabel()).assertEqual('挖文章');
    });

    it('updatesOnlyTheMatchingRecordingForAnAsrPhase', 0, () => {
      const target: Recording = new Recording({
        name: 'VoiceDrop-2026-07-29-120000-0m10s-Wed-Noon.m4a'
      });
      target.uploading = true;
      const untouched: Recording = new Recording({
        name: 'VoiceDrop-2026-07-28-120000-0m10s-Tue-Noon.m4a'
      });
      untouched.hasArticles = true;
      const updated: Recording[] = RecordingListUi.applyStatus(
        [target, untouched], target.stem(), 'asr');
      expect(updated.length).assertEqual(2);
      expect(updated[0].statusLabel()).assertEqual('听录音');
      expect(updated[0].uploading).assertFalse();
      expect(updated[1].name).assertEqual(untouched.name);
      expect(updated[1].hasArticles).assertTrue();
    });

    it('marksOnlyTheMatchingRecordingReadyOrEmpty', 0, () => {
      const ready: Recording = new Recording({
        name: 'VoiceDrop-2026-07-29-120000-0m10s-Wed-Noon.m4a'
      });
      ready.phase = 'mining';
      const empty: Recording = new Recording({
        name: 'VoiceDrop-2026-07-29-121000-0m10s-Wed-Noon.m4a'
      });
      const readyRows: Recording[] = RecordingListUi.applyStatus(
        [ready, empty], ready.stem(), 'ready');
      expect(readyRows[0].statusLabel()).assertEqual('已成文');
      expect(readyRows[1].statusLabel()).assertEqual('待处理');

      const emptyRows: Recording[] = RecordingListUi.applyStatus(
        readyRows, empty.stem(), 'empty');
      expect(emptyRows[0].statusLabel()).assertEqual('已成文');
      expect(emptyRows[1].statusLabel()).assertEqual('无语音');
    });

    it('replacesTheDateFallbackWithTheGeneratedArticleTitle', 0, () => {
      const ready: Recording = new Recording({
        name: 'VoiceDrop-2026-07-29-120000-0m10s-Wed-Noon.m4a',
        hasArticles: true
      });
      const other: Recording = new Recording({ name: 'VoiceDrop-other.m4a' });
      const updated: Recording[] = RecordingListUi.applyArticleMetadata(
        [ready, other], ready.stem(), ' 正常的文章标题 ', ['随笔']);
      expect(updated[0].rowTitle()).assertEqual('正常的文章标题');
      expect(updated[0].tags.join(',')).assertEqual('随笔');
      expect(updated[1].title).assertEqual('');
    });

    it('rerendersOnlyTheRecordingChangedByAWebSocketUpdate', 0, () => {
      const target: Recording = new Recording({
        name: 'VoiceDrop-2026-07-29-120000-0m10s-Wed-Noon.m4a'
      });
      target.uploading = true;
      const untouched: Recording = new Recording({
        name: 'VoiceDrop-2026-07-28-120000-0m10s-Tue-Noon.m4a',
        hasArticles: true,
        title: '原有文章'
      });
      const targetUploadingKey: string = RecordingListUi.rowRenderKey(target);
      const untouchedKey: string = RecordingListUi.rowRenderKey(untouched);

      RecordingListUi.applyStatus([target, untouched], target.stem(), 'mining');
      const targetMiningKey: string = RecordingListUi.rowRenderKey(target);
      expect(targetMiningKey === targetUploadingKey).assertFalse();
      expect(RecordingListUi.rowRenderKey(untouched)).assertEqual(untouchedKey);

      RecordingListUi.applyStatus([target, untouched], target.stem(), 'ready');
      RecordingListUi.applyArticleMetadata([target, untouched], target.stem(), '新生成的标题', ['随笔']);
      expect(RecordingListUi.rowRenderKey(target) === targetMiningKey).assertFalse();
      expect(RecordingListUi.rowRenderKey(untouched)).assertEqual(untouchedKey);
    });
  });
}
