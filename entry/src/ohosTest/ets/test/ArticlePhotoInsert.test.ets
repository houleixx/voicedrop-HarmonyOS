import { describe, expect, it } from '@ohos/hypium';
import { ArticlePhotoInsert } from '../../../main/ets/core/ArticlePhotoInsert';

export default function articlePhotoInsertTest() {
  describe('ArticlePhotoInsert', () => {
    it('buildsAndroidCompatibleInstructionAndImageKeys', 0, () => {
      const keys: string[] = [
        'photos/2026-07-29-200000/12-abc.jpg',
        'photos/2026-07-29-200000/18-def.jpg'
      ];
      const instruction: string = ArticlePhotoInsert.instructionForKeys(keys);
      expect(instruction.includes('这2张照片')).assertTrue();
      expect(instruction.includes(`[[photo:${keys[0]}]]、[[photo:${keys[1]}]]`)).assertTrue();
      expect(instruction.includes('所有照片必须全部插入，不能遗漏')).assertTrue();
      expect(ArticlePhotoInsert.imagesForKeys(keys).map((image) => image.key).join(','))
        .assertEqual(keys.join(','));
    });

    it('doesNotBuildAnInstructionWithoutPhotoKeys', 0, () => {
      expect(ArticlePhotoInsert.instructionForKeys([])).assertEqual('');
      expect(ArticlePhotoInsert.imagesForKeys(['  ']).length).assertEqual(0);
    });
  });
}
