import { describe, expect, it } from '@ohos/hypium';
import { XhsCardLayout, XhsCardPage } from '../../../main/ets/core/XhsCardLayout';

export default function xhsCardLayoutTest() {
  describe('XhsCardLayout', () => {
    it('matchesAndroidCardGeometryAndImageLimit', 0, () => {
      expect(XhsCardLayout.WIDTH).assertEqual(1080);
      expect(XhsCardLayout.HEIGHT).assertEqual(1440);
      expect(XhsCardLayout.BODY_FONT_SIZE).assertEqual(42);
      expect(XhsCardLayout.PARAGRAPH_SPACING).assertEqual(36);
      expect(XhsCardLayout.generatedCardSlots(0)).assertEqual(9);
      expect(XhsCardLayout.generatedCardSlots(3)).assertEqual(6);
      expect(XhsCardLayout.generatedCardSlots(9)).assertEqual(0);
    });

    it('keepsClosingPunctuationWithThePreviousMeasuredLine', 0, () => {
      const lines: string[] = XhsCardLayout.wrapParagraph(
        '我来测试一下，现在录音是不是正常呢？现在用的是鸿蒙的录音功能。',
        17,
        (value: string): number => Array.from(value).length
      );
      expect(lines.join('|')).assertEqual(
        '我来测试一下，现在录音是不是正常呢？|现在用的是鸿蒙的录音功能。');
    });

    it('addsAndroidAndIosParagraphSpacingWhilePaginating', 0, () => {
      const pages: XhsCardPage[] = XhsCardLayout.paginateBody(
        '第一段。\n第二段。',
        (value: string): number => Array.from(value).length * 42
      );
      expect(pages.length).assertEqual(1);
      expect(pages[0].lines.length).assertEqual(2);
      expect(pages[0].lines[0].y).assertEqual(150);
      expect(pages[0].lines[1].y).assertEqual(254);
    });
  });
}
