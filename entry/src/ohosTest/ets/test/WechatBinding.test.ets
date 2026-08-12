import { describe, expect, it } from '@ohos/hypium';
import { WechatBindStatus, WechatBinding } from '../../../main/ets/core/WechatBinding';

export default function wechatBindingTest() {
  describe('WechatBinding', () => {
    it('parsesOnlyConnectedSuccessfulBindStatus', 0, () => {
      const connected = WechatBinding.bindStatus(200,
        '{"connected":true,"account_name":"VoiceDrop 测试号","authorizer_appid":"wx-authorizer","enabled":true}');
      expect(connected.connected).assertTrue();
      expect(connected.accountName).assertEqual('VoiceDrop 测试号');
      expect(connected.authorizerAppid).assertEqual('wx-authorizer');
      expect(connected.enabled).assertTrue();
      expect(WechatBinding.bindStatus(500, '{"connected":true}').connected).assertFalse();
      expect(WechatBinding.bindStatus(200, 'bad json').connected).assertFalse();
    });

    it('roundTripsTheAccountScopedWechatStatusJsonCache', 0, () => {
      const connected = WechatBinding.bindStatus(200,
        '{"connected":true,"account_name":"VoiceDrop 测试号","authorizer_appid":"wx-authorizer","enabled":true}');
      const cached = WechatBinding.bindStatusCache(WechatBinding.bindStatusCacheJson(connected, 1234));
      expect(cached?.connected).assertTrue();
      expect(cached?.accountName).assertEqual('VoiceDrop 测试号');
      expect(cached?.authorizerAppid).assertEqual('wx-authorizer');
      const disconnected = WechatBinding.bindStatusCache(
        WechatBinding.bindStatusCacheJson(new WechatBindStatus(), 1234));
      expect(disconnected?.connected).assertFalse();
      expect(WechatBinding.bindStatusCache('')).assertUndefined();
      expect(WechatBinding.bindStatusCache('{"connected":true}')).assertUndefined();
      expect(WechatBinding.bindStatusCache('bad json')).assertUndefined();
    });

    it('acceptsOnlySignedVoiceDropAuthorizationUrls', 0, () => {
      expect(WechatBinding.authorizationUrl(200,
        '{"scan_url":"https://voicedrop.cn/files/api/wechat/scan?state=signed.state_1"}'))
        .assertEqual('https://voicedrop.cn/files/api/wechat/scan?state=signed.state_1');
      expect(WechatBinding.authorizationUrl(200,
        '{"scan_url":"https://evil.example/wechat/scan?state=signed.state"}')).assertEqual('');
      expect(WechatBinding.authorizationUrl(500,
        '{"scan_url":"https://voicedrop.cn/files/api/wechat/scan?state=signed.state"}')).assertEqual('');
    });

    it('buildsOriginHandoffOnlyForTrustedWechatAuthorizationPage', 0, () => {
      const scanUrl = 'https://voicedrop.cn/files/api/wechat/scan?state=signed.state_1';
      const authorizationUrl = 'https://mp.weixin.qq.com/cgi-bin/componentloginpage' +
        '?component_appid=wx-test&pre_auth_code=pre-code' +
        '&redirect_uri=https%3A%2F%2Fvoicedrop.cn%2Ffiles%2Fapi%2Fwechat%2Fauth-callback';
      const page = WechatBinding.authorizationPage(scanUrl,
        `<script>window.location.replace(${JSON.stringify(authorizationUrl)});</script>`);
      expect(page.scanUrl).assertEqual(scanUrl);
      expect(page.html.includes('name="referrer" content="origin"')).assertTrue();
      expect(page.html.includes(JSON.stringify(authorizationUrl))).assertTrue();
      expect(WechatBinding.authorizationPage(scanUrl,
        '<script>window.location.replace("https://evil.example/steal")</script>').html).assertEqual('');
      expect(WechatBinding.authorizationPage('https://evil.example/wechat/scan?state=signed', page.html).html)
        .assertEqual('');
    });

    it('allowsOnlyTheVoiceDropCallbackAndSuccessRedirectsAfterWechatAuthorization', 0, () => {
      expect(WechatBinding.isTrustedAuthorizationNavigation(
        'https://voicedrop.cn/files/api/wechat/auth-callback?state=signed.state&auth_code=code')).assertTrue();
      expect(WechatBinding.isTrustedAuthorizationNavigation(
        'https://voicedrop.cn/files/api/wechat/auth-success')).assertTrue();
      expect(WechatBinding.isTrustedAuthorizationNavigation(
        'https://voicedrop.cn/files/api/wechat/unbind')).assertFalse();
      expect(WechatBinding.isTrustedAuthorizationNavigation(
        'https://evil.example/files/api/wechat/auth-success')).assertFalse();
    });

    it('mapsQrBoundsFromWebPageToSnapshotPixels', 0, () => {
      const crop = WechatBinding.qrCropRegion('"100,240,200,200,400,800"', 800, 1600);
      expect(crop.x).assertEqual(176);
      expect(crop.y).assertEqual(456);
      expect(crop.width).assertEqual(448);
      expect(crop.height).assertEqual(448);
      const clipped = WechatBinding.qrCropRegion('0,0,200,200,400,800', 800, 1600);
      expect(clipped.x).assertEqual(0);
      expect(clipped.y).assertEqual(0);
      expect(clipped.width).assertEqual(448);
      expect(clipped.height).assertEqual(448);
      expect(WechatBinding.qrCropRegion('bad', 800, 1600).width).assertEqual(0);
    });
  });
}
