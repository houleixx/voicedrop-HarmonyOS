import { describe, expect, it } from '@ohos/hypium';
import { ShareDatasetSnapshot, ShareImport, ShareImportKind } from '../../../main/ets/core/ShareImport';

export default function shareImportTest() {
  describe('ShareImport', () => {
    it('classifiesSystemSharesByMimeAndFileExtension', 0, () => {
      expect(ShareImport.classify('audio/mpeg', ['content://voice'])).assertEqual(ShareImportKind.AUDIO);
      expect(ShareImport.classify('*/*', ['file://one.jpg', 'file://two.png'])).assertEqual(ShareImportKind.IMAGE);
      expect(ShareImport.classify('application/pdf', ['file://article.pdf'])).assertEqual(ShareImportKind.DATASET);
      expect(ShareImport.classify('*/*', ['file://image.jpg', 'file://article.pdf']))
        .assertEqual(ShareImportKind.DATASET);
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
  });
}
