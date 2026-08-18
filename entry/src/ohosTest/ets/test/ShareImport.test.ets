import { describe, expect, it } from '@ohos/hypium';
import {
  ShareDatasetItem,
  ShareDatasetSnapshot,
  ShareImport,
  ShareImportKind,
  ShareIncomingPayload,
  ShareRecordValue
} from '../../../main/ets/core/ShareImport';

export default function shareImportTest() {
  describe('ShareImport', () => {
    it('classifiesSystemSharesByMimeAndFileExtension', 0, () => {
      expect(ShareImport.classify('audio/mpeg', ['content://voice'])).assertEqual(ShareImportKind.AUDIO);
      expect(ShareImport.classify('*/*', ['file://one.jpg', 'file://two.png'])).assertEqual(ShareImportKind.IMAGE);
      expect(ShareImport.classify('application/pdf', ['file://article.pdf'])).assertEqual(ShareImportKind.DATASET);
      expect(ShareImport.classify('*/*', ['file://image.jpg', 'file://article.pdf']))
        .assertEqual(ShareImportKind.DATASET);
      expect(ShareImport.classify('general.jpeg', ['file://shared'])).assertEqual(ShareImportKind.IMAGE);
      expect(ShareImport.classify('general.mpeg-4-audio', ['file://shared'])).assertEqual(ShareImportKind.AUDIO);
    });

    it('combinesSystemShareRecordsIntoOneIncomingPayload', 0, () => {
      const payload: ShareIncomingPayload = ShareImport.payloadFromRecords([
        new ShareRecordValue('general.plain-text', '第一段', '', '自己的文章'),
        new ShareRecordValue('general.plain-text', '第二段')
      ]);
      expect(payload.type).assertEqual('general.plain-text');
      expect(payload.title).assertEqual('自己的文章');
      expect(payload.text).assertEqual('第一段\n\n第二段');
    });

    it('usesDescriptionWhenHarmonyRecordContentIsPresentButEmpty', 0, () => {
      const payload: ShareIncomingPayload = ShareImport.payloadFromRecords([
        new ShareRecordValue('general.plain-text', '', '', '网页标题', 'https://voicedrop.cn/article')
      ]);
      expect(payload.text).assertEqual('https://voicedrop.cn/article');
    });

    it('parsesDatasetAndAppliesTheSharedExtractionThreshold', 0, () => {
      const snapshot: ShareDatasetSnapshot = ShareImport.parseDatasetResponse(
        '{"items":[{"id":"a","type":"doc","title":"文章","source":"a.pdf","chars":301}],"count":1,"totalChars":301}');
      expect(snapshot.items[0].title).assertEqual('文章');
      expect(snapshot.totalChars).assertEqual(301);
      expect(ShareImport.canExtract(snapshot)).assertTrue();
      expect(ShareImport.canExtract(new ShareDatasetSnapshot(snapshot.items, 1, 299))).assertFalse();
    });

    it('extractsDocxParagraphsAndDecodesEntities', 0, () => {
      const xml: string = '<w:document><w:p><w:r><w:t>第一段&amp;内容</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>第二段</w:t></w:r><w:tab/><w:r><w:t>尾部</w:t></w:r></w:p></w:document>';
      expect(ShareImport.extractDocxXml(xml)).assertEqual('第一段&内容\n第二段\t尾部');
    });

    it('extractsReadableHtmlInsteadOfSavingOnlyTheLink', 0, () => {
      const html: string = '<html><head><title>示例文章</title><style>hide</style></head>' +
        '<body><article><p>第一段正文</p><p>第二段&nbsp;正文</p></article></body></html>';
      expect(ShareImport.htmlTitle(html, 'example.com')).assertEqual('示例文章');
      expect(ShareImport.extractHtml(html)).assertEqual('第一段正文\n\n第二段 正文');
    });

    it('usesBackendRecognizedTaskTags', 0, () => {
      expect(ShareImport.styleTaskTag(true)).assertEqual('TaskStyleExtract');
      expect(ShareImport.styleTaskTag(false)).assertEqual('TaskStyleExtract-Keep');
    });

    it('formatsDatasetCountsLikeTheIosDatasetHeaderAndRows', 0, () => {
      expect(ShareImport.formatChars(1116)).assertEqual('1,116 字');
      expect(ShareImport.formatTotalChars(1116)).assertEqual('约 1,116 字');
      expect(ShareImport.formatTotalChars(12345)).assertEqual('约 1.2 万字');
    });

    it('findsTheBackendDatasetItemAddedByTheCurrentShare', 0, () => {
      const before: ShareDatasetSnapshot = new ShareDatasetSnapshot([
        new ShareDatasetItem('old', 'text', '旧文章', '分享文本', '2026-08-18T01:00:00Z', 300)
      ], 1, 300);
      const after: ShareDatasetSnapshot = new ShareDatasetSnapshot([
        new ShareDatasetItem('new', 'web', '后端解析后的标题', 'voicedrop.cn', '2026-08-18T02:00:00Z', 1116),
        new ShareDatasetItem('old', 'text', '旧文章', '分享文本', '2026-08-18T01:00:00Z', 300)
      ], 2, 1416);
      const added: ShareDatasetItem | undefined = ShareImport.newestAddedDatasetItem(before, after);
      expect(added?.id).assertEqual('new');
      expect(added?.title).assertEqual('后端解析后的标题');
    });
  });
}
