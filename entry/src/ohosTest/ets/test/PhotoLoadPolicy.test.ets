import { describe, expect, it } from '@ohos/hypium';
import { PhotoLoadPolicy } from '../../../main/ets/core/PhotoLoadPolicy';

export default function photoLoadPolicyTest() {
  describe('PhotoLoadPolicy', () => {
    it('reportsOrdinaryPhotoFailureWithoutGenerationPolling', 0, () => {
      expect(PhotoLoadPolicy.failureState('original')).assertEqual('loadFailed');
      expect(PhotoLoadPolicy.shouldPoll('original')).assertTrue();
      expect(PhotoLoadPolicy.timeoutMs('original')).assertEqual(15000);
    });

    it('pollsOnlyForAKeyIntroducedByImageGeneration', 0, () => {
      expect(PhotoLoadPolicy.failureState('generated')).assertEqual('making');
      expect(PhotoLoadPolicy.shouldPoll('generated')).assertTrue();
    });

    it('showsPendingImageEditWithoutLoadingTheOldPhoto', 0, () => {
      expect(PhotoLoadPolicy.failureState('pending')).assertEqual('making');
      expect(PhotoLoadPolicy.shouldLoad('pending')).assertFalse();
      expect(PhotoLoadPolicy.shouldLoad('original')).assertTrue();
      expect(PhotoLoadPolicy.shouldLoad('generated')).assertTrue();
      expect(PhotoLoadPolicy.startsMaking('pending')).assertTrue();
      expect(PhotoLoadPolicy.startsMaking('generatedPending')).assertTrue();
      expect(PhotoLoadPolicy.shouldLoad('generatedPending')).assertTrue();
      expect(PhotoLoadPolicy.startsMaking('generated')).assertFalse();
    });

    it('followsAndroidGeneratedPhotoTimingStates', 0, () => {
      expect(PhotoLoadPolicy.generatedState(0)).assertEqual('loading');
      expect(PhotoLoadPolicy.generatedState(899)).assertEqual('loading');
      expect(PhotoLoadPolicy.generatedState(900)).assertEqual('making');
      expect(PhotoLoadPolicy.generatedState(299999)).assertEqual('making');
      expect(PhotoLoadPolicy.generatedState(300000)).assertEqual('failed');
    });

    it('capsGeneratedPhotoPollingAtTheFiveMinuteDeadline', 0, () => {
      expect(PhotoLoadPolicy.generatedRetryDelay(0)).assertEqual(3000);
      expect(PhotoLoadPolicy.generatedRetryDelay(298500)).assertEqual(1500);
      expect(PhotoLoadPolicy.generatedRetryDelay(300000)).assertEqual(0);
    });

    it('restoresWaitWithoutResettingTheDeadline', 0, () => {
      expect(PhotoLoadPolicy.startedAt(1000, 100000, false)).assertEqual(1000);
      expect(PhotoLoadPolicy.startedAt(1000, 400000, false)).assertEqual(1000);
      expect(PhotoLoadPolicy.startedAt(1000, 400000, true)).assertEqual(400000);
      expect(PhotoLoadPolicy.restoredIntent(true, false)).assertEqual('generated');
      expect(PhotoLoadPolicy.restoredIntent(false, false)).assertEqual('unknown');
      expect(PhotoLoadPolicy.restoredIntent(true, true)).assertEqual('original');
      expect(PhotoLoadPolicy.timeoutMs('unknown')).assertEqual(300000);
    });

    it('marksOnlyPhotoKeysIntroducedByAnArticleEdit', 0, () => {
      expect(PhotoLoadPolicy.introducedKeys(
        ['photos/session/1-old.jpg'],
        ['photos/session/1-new.jpg', 'photos/session/8-added.jpg']
      )).assertDeepEquals(['photos/session/1-new.jpg', 'photos/session/8-added.jpg']);
    });

    it('neverMarksTheExistingSourceKeyAsGenerated', 0, () => {
      expect(PhotoLoadPolicy.introducedKeys(
        ['users/a/photos/session/source.jpg'],
        ['users/a/photos/session/source.jpg']
      )).assertDeepEquals([]);
    });
  });
}
