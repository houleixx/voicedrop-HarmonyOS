import libraryCommandUiTest from './LibraryCommandUi.test';
import communityTermsTest from './CommunityTerms.test';
import accountIdentityTest from './AccountIdentity.test';
import recordingListUiTest from './RecordingListUi.test';

export default function testsuite() {
  libraryCommandUiTest();
  communityTermsTest();
  accountIdentityTest();
  recordingListUiTest();
}
