import { describe, expect, it } from '@ohos/hypium';
import {
  LibraryCommandEvent,
  LibraryCommandFeedback,
  LibraryCommandGestureAction,
  LibraryCommandTarget,
  LibraryCommandTone,
  LibraryCommandUi
} from '../../../main/ets/core/LibraryCommandUi';

export default function libraryCommandUiTest() {
  describe('LibraryCommandUi', () => {
    it('hidesConnectionLifecycleMessages', 0, () => {
      expect(LibraryCommandUi.isQuietMessage('已连接图库指令')).assertTrue();
      expect(LibraryCommandUi.isQuietMessage('正在恢复图库指令…')).assertTrue();
      expect(LibraryCommandUi.isQuietMessage('图库指令连接断开，稍后重试')).assertTrue();
      expect(LibraryCommandUi.feedbackForEvent(new LibraryCommandEvent('status', 'idle')).visible()).assertFalse();
    });

    it('showsWorkingStateOnlyWhileCommandRuns', 0, () => {
      const feedback = LibraryCommandUi.feedbackForEvent(new LibraryCommandEvent('status', 'working'));
      expect(feedback.text).assertEqual('正在执行图库指令…');
      expect(feedback.tone).assertEqual(LibraryCommandTone.Active);
      expect(feedback.visible()).assertTrue();
    });

    it('mapsCompletionReplyAndErrorFeedback', 0, () => {
      const completed = LibraryCommandUi.feedbackForEvent(new LibraryCommandEvent('updated'));
      const reply = LibraryCommandUi.feedbackForEvent(new LibraryCommandEvent('reply', undefined, '已为第 2 条添加标签'));
      const error = LibraryCommandUi.feedbackForEvent(new LibraryCommandEvent('error', undefined, undefined, '没有找到第 8 条录音'));
      expect(completed.text).assertEqual('图库指令已完成');
      expect(reply.text).assertEqual('已为第 2 条添加标签');
      expect(reply.tone).assertEqual(LibraryCommandTone.Normal);
      expect(error.text).assertEqual('没有找到第 8 条录音');
      expect(error.tone).assertEqual(LibraryCommandTone.Error);
    });

    it('hidesQuietRepliesFromFeedbackBubble', 0, () => {
      const feedback = LibraryCommandUi.feedbackForEvent(
        new LibraryCommandEvent('reply', undefined, '图库指令已完成'));
      expect(feedback.visible()).assertFalse();
    });

    it('matchesAndroidRecordButtonLabels', 0, () => {
      expect(LibraryCommandUi.recordButtonLabel(false, false)).assertEqual('轻点录音 · 长按说话');
      expect(LibraryCommandUi.recordButtonLabel(true, false)).assertEqual('松开发送 · 上滑取消');
      expect(LibraryCommandUi.recordButtonLabel(true, true)).assertEqual('上滑取消 · 松开放弃');
    });

    it('showsLiveTranscriptAndCancelWarning', 0, () => {
      expect(LibraryCommandUi.dictationFeedback('', false).text).assertEqual('在听…');
      expect(LibraryCommandUi.dictationFeedback('删除第二条', false).text).assertEqual('删除第二条');
      const canceled = LibraryCommandUi.dictationFeedback('删除第二条', true);
      expect(canceled.text).assertEqual('松手取消图库指令');
      expect(canceled.tone).assertEqual(LibraryCommandTone.Error);
    });

    it('keepsFinalTranscriptBeforeSwitchingToWorkingStatus', 0, () => {
      const working = new LibraryCommandFeedback('正在执行图库指令…', LibraryCommandTone.Active);
      const held = LibraryCommandUi.displayedFeedback(working, '删除第二条录音', true);
      const released = LibraryCommandUi.displayedFeedback(working, '删除第二条录音', false);
      expect(held.text).assertEqual('删除第二条录音');
      expect(held.tone).assertEqual(LibraryCommandTone.Active);
      expect(released.text).assertEqual('正在执行图库指令…');
      expect(LibraryCommandUi.transcriptConfirmationMs() >= 1500).assertTrue();
    });

    it('separatesTapSendAndCancelGestures', 0, () => {
      expect(LibraryCommandUi.gestureAction(false, false, false)).assertEqual(LibraryCommandGestureAction.Record);
      expect(LibraryCommandUi.gestureAction(false, false, true)).assertEqual(LibraryCommandGestureAction.None);
      expect(LibraryCommandUi.gestureAction(true, false, false)).assertEqual(LibraryCommandGestureAction.Send);
      expect(LibraryCommandUi.gestureAction(true, true, false)).assertEqual(LibraryCommandGestureAction.Cancel);
      expect(LibraryCommandUi.gestureAction(true, false, true)).assertEqual(LibraryCommandGestureAction.Cancel);
    });

    it('numbersOnlyActionableRecordings', 0, () => {
      const targets: LibraryCommandTarget[] = [
        new LibraryCommandTarget('first', '第一条', false),
        new LibraryCommandTarget('uploading', '上传中', true),
        new LibraryCommandTarget('third', '第三条', false)
      ];
      const refs = LibraryCommandUi.commandRefs(targets);
      expect(refs.length).assertEqual(2);
      expect(refs[0].number).assertEqual(1);
      expect(refs[0].stem).assertEqual('first');
      expect(refs[1].number).assertEqual(2);
      expect(refs[1].stem).assertEqual('third');
    });
  });
}
