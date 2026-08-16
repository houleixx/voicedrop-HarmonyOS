import { describe, expect, it } from '@ohos/hypium';
import { BookReviseContract, BookThreadEntry } from '../../../main/ets/core/BookReviseContract';

export default function bookReviseContractTest() {
  describe('BookReviseContract', () => {
    it('decodesThePermanentConversationThread', 0, () => {
      const result = BookReviseContract.history(200,
        '{"slug":"the-book","author":"作者","running":false,"thread":[' +
        '{"ts":1000,"kind":"create","instruction":"开书","status":"done"},' +
        '{"ts":2000,"kind":"revise","instruction":"删掉第三章","status":"running","reply":null}]}');
      expect(result.loaded).assertTrue();
      expect(result.value?.slug).assertEqual('the-book');
      expect(result.value?.thread.length).assertEqual(2);
      expect(result.value?.running).assertTrue();
      expect(result.value?.thread[1].instruction).assertEqual('删掉第三章');
    });

    it('mapsOwnerAndLegacyBookHistoryFailures', 0, () => {
      const unauthorized = BookReviseContract.history(401, '{}');
      const forbidden = BookReviseContract.history(403, '{}');
      const legacy = BookReviseContract.history(404, '{}');
      expect(unauthorized.denied).assertTrue();
      expect(unauthorized.message).assertEqual('登录状态已失效，请重新登录后再试。');
      expect(forbidden.denied).assertTrue();
      expect(forbidden.message).assertEqual('只有这本书的主人能修改。');
      expect(legacy.denied).assertTrue();
      expect(legacy.message.includes('还没登记主人')).assertTrue();
    });

    it('mapsEveryRevisionResponseThatNeedsDedicatedCopy', 0, () => {
      const accepted = BookReviseContract.revise(202, '{"ts":1234,"suanli":88}');
      expect(accepted.accepted).assertTrue();
      expect(accepted.ts).assertEqual(1234);
      expect(BookReviseContract.revise(401, '{}').message).assertEqual('身份校验没过，请稍后重试。');
      expect(BookReviseContract.revise(402, '{"need_suanli":40,"suanli":12.5}').message)
        .assertEqual('算力不足：改一次要 40 算力，你现在有 12.5。');
      expect(BookReviseContract.revise(403, '{}').message).assertEqual('只有这本书的主人能修改。');
      expect(BookReviseContract.revise(404, '{}').message.includes('还没登记主人')).assertTrue();
      expect(BookReviseContract.revise(409, '{}').message).assertEqual('上一个修改还在进行，等它改完再提。');
    });

    it('blocksBlankConcurrentAndDuplicateSubmissions', 0, () => {
      const done: BookThreadEntry[] = [new BookThreadEntry(1, 'create', '种子', 'done')];
      const running: BookThreadEntry[] = done.concat([new BookThreadEntry(2, 'revise', '修改', 'running')]);
      expect(BookReviseContract.canSend('  改一下  ', false, false, done, '')).assertTrue();
      expect(BookReviseContract.canSend('   ', false, false, done, '')).assertFalse();
      expect(BookReviseContract.canSend('改一下', true, false, done, '')).assertFalse();
      expect(BookReviseContract.canSend('改一下', false, true, done, '')).assertFalse();
      expect(BookReviseContract.canSend('改一下', false, false, running, '')).assertFalse();
      expect(BookReviseContract.canSend('改一下', false, false, done, '没有权限')).assertFalse();
    });

    it('rendersStatusCopyAndCapsInstructionsAtTheServerLimit', 0, () => {
      expect(BookReviseContract.replyText(new BookThreadEntry(1, 'revise', '修改', 'running')).includes('正在修改'))
        .assertTrue();
      expect(BookReviseContract.replyText(new BookThreadEntry(1, 'revise', '修改', 'failed')).includes('没有完成'))
        .assertTrue();
      expect(BookReviseContract.replyText(new BookThreadEntry(1, 'revise', '修改', 'done', '改了两处')))
        .assertEqual('改了两处');
      expect(BookReviseContract.instruction(`  ${'甲'.repeat(4100)}  `).length).assertEqual(4000);
    });
  });
}
