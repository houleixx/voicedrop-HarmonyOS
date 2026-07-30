import { describe, expect, it } from '@ohos/hypium';
import { ArticleBody, ArticleBlock } from '../../../main/ets/core/ArticleBody';

export default function articleBodyTest() {
  describe('ArticleBody', () => {
    it('numbersParagraphsAndPhotosInOneSequence', 0, () => {
      const body: string = '第一段\n\n第二段\n[[photo:photos/a.jpg]]\n第三段\n[[photo:2]]';
      const blocks: ArticleBlock[] = ArticleBody.locatedBlocks(body);

      expect(blocks.length).assertEqual(5);
      expect(blocks.map((block: ArticleBlock) => block.lineNumber).join(',')).assertEqual('1,2,3,4,5');
      expect(blocks.map((block: ArticleBlock) => block.kind).join(','))
        .assertEqual('text,text,photo,text,photo');
      expect(blocks[2].imageNumber).assertEqual(1);
      expect(blocks[4].imageNumber).assertEqual(2);
    });

    it('doesNotNumberBlankParagraphs', 0, () => {
      const blocks: ArticleBlock[] = ArticleBody.locatedBlocks('第一段\n   \n第二段');
      expect(blocks.length).assertEqual(2);
      expect(blocks[1].lineNumber).assertEqual(2);
    });

    it('findsTheFirstPhotoAcrossArticlesLikeAndroidRecordingRows', 0, () => {
      const key: string | undefined = ArticleBody.firstArticlePhotoKey([
        { title: '没有图片', body: '只有正文' },
        { title: '有图片', body: '正文\n\n[[photo:2]]' }
      ], ['photos/session/first.jpg', 'photos/session/cover.jpg']);
      expect(key).assertEqual('photos/session/cover.jpg');
    });

    it('materializesLegacyPhotoMarkerBeforeImageEditing', 0, () => {
      const body: string = '第一段\n\n[[photo:1]]\n\n第二段';
      expect(ArticleBody.materializePhotoMarker(body, '1', ['photos/session/original.jpg']))
        .assertEqual('第一段\n\n[[photo:photos/session/original.jpg]]\n\n第二段');
    });

    it('doesNotRewriteCurrentOrUnresolvablePhotoMarkers', 0, () => {
      const current: string = '[[photo:photos/session/current.jpg]]';
      expect(ArticleBody.materializePhotoMarker(current, 'photos/session/current.jpg', ['photos/session/current.jpg']))
        .assertEqual(current);
      expect(ArticleBody.materializePhotoMarker('[[photo:2]]', '2', ['photos/session/only.jpg']))
        .assertEqual('[[photo:2]]');
    });

    it('replacesOnlyTheSelectedVisibleParagraph', 0, () => {
      const body: string =
        '<!-- style: 风格 v3 -->\n  第一段  \n\n[[photo:photos/s/1-a.jpg]]\n\n第三段';
      expect(ArticleBody.replacingLine(3, '第三段（已修改）', body))
        .assertEqual('<!-- style: 风格 v3 -->\n  第一段  \n\n[[photo:photos/s/1-a.jpg]]\n\n第三段（已修改）');
    });

    it('doesNotReplacePhotoRowsOrRowsOutsideTheArticle', 0, () => {
      const body: string = '第一段\n[[photo:photos/s/1-a.jpg]]\n第三段';
      expect(ArticleBody.replacingLine(2, '不能替换图片', body)).assertEqual(body);
      expect(ArticleBody.replacingLine(9, '越界', body)).assertEqual(body);
    });

    it('mapsAVisibleParagraphBackIntoTheStoredArticle', 0, () => {
      const original: string =
        '<!-- style: 风格 v2 -->\n标题\n\n第一段\n[[photo:photos/s/1-a.jpg]]\n第二段';
      const rendered: string = '第一段\n[[photo:photos/s/1-a.jpg]]\n第二段';
      expect(ArticleBody.replacingRenderedLine(1, '第一段（已修改）', rendered, original))
        .assertEqual('<!-- style: 风格 v2 -->\n标题\n\n第一段（已修改）\n[[photo:photos/s/1-a.jpg]]\n第二段');
    });
  });
}
