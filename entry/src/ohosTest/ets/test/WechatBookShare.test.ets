import { describe, expect, it } from '@ohos/hypium';
import { WechatBookShare } from '../../../main/ets/core/WechatBookShare';

export default function wechatBookShareTest() {
  describe('WechatBookShare', () => {
    it('buildsTheWechatBookCardTitle', 0, () => {
      expect(WechatBookShare.title(' 一本书 ', '短标题', ' 作者 ')).assertEqual('《一本书》 — 作者');
      expect(WechatBookShare.title('', '短标题', '')).assertEqual('《短标题》');
    });

    it('buildsTheMiniProgramReaderPathWithCoverMetadata', 0, () => {
      expect(WechatBookShare.miniProgramPath('sample-book', '一本书', '张 三', true))
        .assertEqual('pages/book-reader/index?slug=sample-book&title=%E4%B8%80%E6%9C%AC%E4%B9%A6' +
          '&author=%E5%BC%A0%20%E4%B8%89&cover=1');
      expect(WechatBookShare.miniProgramPath('sample-book', '一本书', '', false).endsWith('&cover=0'))
        .assertTrue();
    });

    it('mapsTheBookMenuTargetsToWechatScenes', 0, () => {
      expect(WechatBookShare.isTimeline('friend')).assertFalse();
      expect(WechatBookShare.isTimeline('timeline')).assertTrue();
    });
  });
}
