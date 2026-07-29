import libraryCommandUiTest from './LibraryCommandUi.test';
import communityTermsTest from './CommunityTerms.test';
import accountIdentityTest from './AccountIdentity.test';
import recordingListUiTest from './RecordingListUi.test';
import recordingUiTest from './RecordingUi.test';
import recordingNameTest from './RecordingName.test';
import clientReliabilityTest from './ClientReliability.test';
import photoLoadPolicyTest from './PhotoLoadPolicy.test';
import recordingPolicyTest from './RecordingPolicy.test';
import recordingStopPolicyTest from './RecordingStopPolicy.test';
import communityLikeStateTest from './CommunityLikeState.test';
import recordingUploadPolicyTest from './RecordingUploadPolicy.test';
import appPageTest from './AppPage.test';

export default function testsuite() {
  libraryCommandUiTest();
  communityTermsTest();
  accountIdentityTest();
  recordingListUiTest();
  recordingUiTest();
  recordingNameTest();
  clientReliabilityTest();
  photoLoadPolicyTest();
  recordingPolicyTest();
  recordingStopPolicyTest();
  communityLikeStateTest();
  recordingUploadPolicyTest();
  appPageTest();
}
