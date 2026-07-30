import { describe, expect, it } from '@ohos/hypium';
import { ArticleEditEvent, ArticleEditQueueItem, ArticleEditUi } from '../../../main/ets/core/ArticleEditUi';

export default function articleEditUiTest() {
  describe('ArticleEditUi', () => {
    it('keepsTheCurrentRequestFirstAndAppendsWaitingRequests', 0, () => {
      let queue: ArticleEditQueueItem[] = [];
      queue = ArticleEditUi.enqueue(queue, 'one', '改写第一段');
      queue = ArticleEditUi.enqueue(queue, 'two', '把图片改成插画');
      expect(queue.map((item: ArticleEditQueueItem): string => item.id).join(',')).assertEqual('one,two');
    });

    it('resolvesRequestsFromUpdatedErrorAndSnapshotEvents', 0, () => {
      const queue: ArticleEditQueueItem[] = [
        new ArticleEditQueueItem('one', '第一条'),
        new ArticleEditQueueItem('two', '第二条')
      ];
      expect(ArticleEditUi.reconcile(queue, new ArticleEditEvent('updated', 'one')).length).assertEqual(1);
      expect(ArticleEditUi.reconcile(queue, new ArticleEditEvent('error', 'one')).length).assertEqual(1);
      const snapshot: ArticleEditEvent = new ArticleEditEvent('snapshot');
      snapshot.queue = [{ id: 'two', status: 'done' }];
      expect(ArticleEditUi.reconcile(queue, snapshot)
        .map((item: ArticleEditQueueItem): string => item.id).join(','))
        .assertEqual('one');
    });

    it('mapsServerRepliesAndErrorsToAndroidStyleFeedback', 0, () => {
      const reply: ArticleEditEvent = new ArticleEditEvent('reply');
      reply.text = '改好了';
      expect(ArticleEditUi.feedback(reply)?.text).assertEqual('改好了');
      expect(ArticleEditUi.feedback(reply)?.ok).assertTrue();

      const error: ArticleEditEvent = new ArticleEditEvent('error');
      error.message = '修改失败';
      expect(ArticleEditUi.feedback(error)?.text).assertEqual('修改失败');
      expect(ArticleEditUi.feedback(error)?.ok).assertFalse();
    });
  });
}
