import { describe, expect, it } from '@ohos/hypium';
import { PhotoLoadPolicy } from '../../../main/ets/core/PhotoLoadPolicy';

export default function photoLoadPolicyTest() {
  describe('PhotoLoadPolicy', () => {
    it('reportsOrdinaryPhotoFailureWithoutGenerationPolling', 0, () => {
      expect(PhotoLoadPolicy.failureState('original')).assertEqual('loadFailed');
      expect(PhotoLoadPolicy.shouldPoll('original')).assertFalse();
    });

    it('pollsOnlyForAKeyIntroducedByImageGeneration', 0, () => {
      expect(PhotoLoadPolicy.failureState('generated')).assertEqual('making');
      expect(PhotoLoadPolicy.shouldPoll('generated')).assertTrue();
    });

    it('marksOnlyPhotoKeysIntroducedByAnArticleEdit', 0, () => {
      expect(PhotoLoadPolicy.introducedKeys(
        ['photos/session/1-old.jpg'],
        ['photos/session/1-new.jpg', 'photos/session/8-added.jpg']
      )).assertDeepEquals(['photos/session/1-new.jpg', 'photos/session/8-added.jpg']);
    });

    it('keepsSameKeyImageProcessingActiveUntilTheReplacementLoads', 0, () => {
      expect(PhotoLoadPolicy.processingKeys(
        ['users/a/photos/session/other.jpg'],
        ['users/a/photos/session/same-key.jpg']
      )).assertDeepEquals([
        'users/a/photos/session/other.jpg',
        'users/a/photos/session/same-key.jpg'
      ]);
    });
  });
}
