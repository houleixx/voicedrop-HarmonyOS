import { PageHeader } from '../ui/PageHeader';
import { AppLocale } from '../core/AppLocale';

export const PRIVACY_TEXT_ZH: string = 'VoiceDrop 隐私政策\n\n' +
  '更新日期：2026年7月31日\n生效日期：2026年7月31日\n\n' +
  '欢迎使用 VoiceDrop。本应用由百姓网股份有限公司提供。我们重视你的个人信息和隐私安全。本政策说明我们在提供录音转写、文章生成、社区、设备配对等功能时如何处理信息。你可以只使用匿名身份；拒绝非必要权限不会影响浏览和已生成内容的基本功能。\n\n' +
  '一、我们处理的信息\n\n' +
  '1. 录音与语音。只有你主动点击录音、听写、语音修改、语音回复或实时采访时，我们才会使用麦克风。音频会上传至 VoiceDrop 服务，用于语音识别、文章生成、修改和播放。\n\n' +
  '2. 文章与操作数据。我们处理转写文本、生成文章、标题、标签、编辑指令、提示词、版本历史、追问回答和发布状态，以提供写作、同步、恢复及导出功能。\n\n' +
  '3. 图片与文件。只有你主动拍摄、从相册选择、插图或从其他应用分享文件时，我们才读取相应内容。所选图片可能上传并嵌入文章；导入的文字或文档内容可能用于提取你的写作文风。\n\n' +
  '4. 账号信息。首次使用会生成匿名 Token，用于区分你的云端空间。若你主动使用微信登录，我们会保存服务端签发的登录会话及必要的微信公开身份信息。若你主动授权微信公众号，微信会向 VoiceDrop 服务端提供完成草稿发布所需的公众号标识和授权令牌；应用不会要求你填写公众号 AppSecret。\n\n' +
  '5. 社区与互动。文章和提示词只有在你主动分享或开启“自动分享到 VD 社区”后才会公开。公开内容可能包含作者名、标题、正文、图片、回复关系、点赞和投币状态。你可以取消分享、举报内容或屏蔽作者。\n\n' +
  '6. 设备与运行信息。为完成应用使用统计、深链、设备配对、故障排查和安全防护，我们可能处理应用版本、系统类型、设备品牌与型号、屏幕和网络信息、请求时间、网络错误、匿名设备标识及随机设备配对标识。我们不以本应用能力读取通讯录、短信或精确位置。\n\n' +
  '二、权限说明\n\n' +
  '麦克风权限用于录音和语音交互；相机权限用于你主动拍照插图；相册/媒体访问用于你主动选择图片或文件；网络权限用于上传、同步、生成、社区和使用统计。相关权限均在对应功能触发时申请，你可以在系统设置中撤回。撤回后只会影响依赖该权限的功能。\n\n' +
  '三、信息的使用、共享与委托处理\n\n' +
  '我们仅为实现上述功能、保障服务安全、响应你的请求和履行法律义务而处理信息。语音识别、云存储、内容生成或消息分发可能由受约束的云服务供应商提供技术处理。除非取得你的单独同意、为完成你主动发起的共享/发布、依据法律要求或保护人身财产安全，我们不会向无关第三方出售或披露你的个人信息。\n\n' +
  '为统计应用启动、活跃、留存和使用事件，我们接入友盟同欣（北京）科技有限公司提供的友盟移动统计 SDK。该 SDK 可能处理 OAID、匿名设备标识、设备品牌与型号、系统版本、屏幕及运营商/网络信息、IP 地址、应用版本、渠道和使用事件；仅在你同意本政策后初始化。友盟隐私政策：https://www.umeng.com/page/policy/。\n\n' +
  '当你主动点击“用微信登录”时，应用会调用腾讯微信 OpenSDK 拉起微信授权，向微信传递 VoiceDrop 的 AppID、授权范围和随机请求标识，并接收一次性授权 code；微信账号信息由 VoiceDrop 服务端依据该 code 完成登录绑定。未点击微信登录时不会发起该流程。微信隐私政策：https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_agreement&s=privacy。\n\n' +
  '四、保存与安全\n\n' +
  '本地会保存必要的偏好、匿名 Token、登录会话、待上传任务和缓存；云端会保存你上传的录音、文章及关联数据，直至你删除内容、删除账户或超过业务所需期限。设备配对迁移使用 X25519、HKDF-SHA256 和 AES-256-GCM 端到端加密。我们采取访问控制、传输加密和最小权限等措施，但互联网服务无法保证绝对安全。\n\n' +
  '五、你的权利\n\n' +
  '你可以在应用内查看、修改、导出和删除录音、文章、文风、提示词及社区分享；可以退出登录、撤回权限、解除屏蔽，并在“设置 → 账号”永久删除账户。账户删除成功后，应用会清理本机身份和待发送队列并创建新的匿名空间。若你无法自行完成请求，可通过下方邮箱联系我们。\n\n' +
  '六、未成年人保护\n\n' +
  '本服务主要面向成年人。未成年人应在监护人阅读并同意本政策后使用，不应录入不必要的本人或他人敏感信息。若我们发现未经适当同意收集了未成年人信息，将依法尽快删除。\n\n' +
  '七、政策更新与联系我们\n\n' +
  '功能或法律要求变化时，我们可能更新本政策，并通过应用内提示或页面公示重要变更。对隐私政策、个人信息权利或安全问题有疑问，请联系：hello@voicedrop.cn。\n\n' +
  '在线版本：https://voicedrop.cn/privacy/';

export const PRIVACY_TEXT_EN: string = 'VoiceDrop Privacy Policy\n\n' +
  'Updated: July 31, 2026\nEffective: July 31, 2026\n\n' +
  'Welcome to VoiceDrop. This app is provided by Baixing.com Co., Ltd. We value your personal information and privacy. This policy explains how we handle information when providing recording transcription, article creation, Community, device pairing, and related features. You may use an anonymous identity only; declining non-essential permissions does not affect browsing or basic use of content already created.\n\n' +
  '1. Information we process\n\n' +
  '1) Recordings and voice. We use the microphone only when you actively record, dictate, revise by voice, reply by voice, or start a live interview. Audio is uploaded to VoiceDrop services for speech recognition, article creation, revision, and playback.\n\n' +
  '2) Articles and activity data. We process transcripts, generated articles, titles, tags, editing instructions, prompts, version history, follow-up answers, and publishing status to provide writing, sync, recovery, and export features.\n\n' +
  '3) Images and files. We read content only when you actively take a photo, select from your album, insert an illustration, or share a file from another app. Selected images may be uploaded and embedded in articles; imported text or documents may be used to extract your writing style.\n\n' +
  '4) Account information. On first use, an anonymous token is created to distinguish your cloud space. If you sign in with WeChat, we retain the server-issued sign-in session and necessary public WeChat identity information. If you authorize a WeChat Official Account, WeChat provides VoiceDrop services with the identifier and authorization token required to publish drafts; the app does not ask you to enter an Official Account AppSecret.\n\n' +
  '5) Community and interaction. Articles and prompts are public only when you actively share them or enable Auto-share to VD Community. Public content may include the author name, title, body, images, reply relationships, likes, and credit-sending status. You may unshare, report content, or block authors.\n\n' +
  '6) Device and operation information. To complete app analytics, deep links, device pairing, troubleshooting, and security protection, we may process app version, system type, device brand and model, screen and network information, request time, network errors, anonymous device identifiers, and random device-pairing identifiers. The app does not read contacts, SMS, or precise location.\n\n' +
  '2. Permissions\n\n' +
  'Microphone permission is used for recording and voice interaction; camera permission is used when you actively take an illustration photo; album/media access is used when you actively choose images or files; network permission is used for upload, sync, creation, Community, and analytics. Permissions are requested when the relevant feature is used and can be withdrawn in system settings. Withdrawal affects only features that depend on that permission.\n\n' +
  '3. Use, sharing, and entrusted processing\n\n' +
  'We process information only to provide the features above, keep services secure, respond to your requests, and fulfill legal obligations. Speech recognition, cloud storage, content generation, or message delivery may be technically processed by bound cloud-service providers. Unless we obtain your separate consent, complete sharing or publishing initiated by you, comply with law, or protect personal and property safety, we do not sell or disclose your personal information to unrelated third parties.\n\n' +
  'For launch, activity, retention, and feature analytics, we integrate the Umeng Mobile Analytics SDK provided by Umeng Tongxin (Beijing) Technology Co., Ltd. The SDK may process OAID, anonymous device identifiers, device brand and model, OS version, screen and carrier/network information, IP address, app version, channel, and usage events. It initializes only after you agree to this policy. Umeng privacy policy: https://www.umeng.com/page/policy/.\n\n' +
  'When you actively tap Sign in with WeChat, the app uses Tencent WeChat OpenSDK to start authorization, passes VoiceDrop\'s AppID, authorization scope, and a random request identifier to WeChat, and receives a one-time authorization code. VoiceDrop services complete sign-in binding using that code. This process is not started unless you tap WeChat sign-in. WeChat privacy policy: https://weixin.qq.com/cgi-bin/readtemplate?lang=zh_CN&t=weixin_agreement&s=privacy.\n\n' +
  '4. Storage and security\n\n' +
  'The app stores necessary preferences, anonymous tokens, sign-in sessions, pending uploads, and cache locally. The cloud stores recordings, articles, and associated data you upload until you delete content, delete your account, or the business retention period expires. Device-pairing migration uses X25519, HKDF-SHA256, and AES-256-GCM end-to-end encryption. We use access controls, encryption in transit, and least-privilege measures, but internet services cannot guarantee absolute security.\n\n' +
  '5. Your rights\n\n' +
  'You can view, revise, export, and delete recordings, articles, writing styles, prompts, and Community shares in the app; sign out, withdraw permissions, unblock authors, and permanently delete your account in Settings → Account. After account deletion succeeds, the app clears local identity and pending queues and creates a new anonymous space. If you cannot complete a request yourself, contact us by email below.\n\n' +
  '6. Children\'s privacy\n\n' +
  'This service is mainly for adults. Minors should use it only after a guardian has read and agreed to this policy, and should not enter unnecessary sensitive information about themselves or others. If we discover that minor information was collected without suitable consent, we will delete it as soon as required by law.\n\n' +
  '7. Policy updates and contact\n\n' +
  'We may update this policy when features or legal requirements change, and will notify you of material changes through in-app notices or publication on this page. For privacy, personal-information rights, or security questions, contact hello@voicedrop.cn.\n\n' +
  'Online version: https://voicedrop.cn/privacy/';

export function privacyText(): string {
  return AppLocale.isEnglish() ? PRIVACY_TEXT_EN : PRIVACY_TEXT_ZH;
}

@Component
export struct PrivacyPolicyPage {
  onBack: () => void = () => {};

  build() {
    Column() {
      PageHeader({ title: AppLocale.text('隐私政策'), onBack: this.onBack })
      Scroll() {
        Text(privacyText()).fontSize(16).lineHeight(28)
          .padding({ left: 16, right: 16, top: 6, bottom: 16 }).width('100%')
      }
        .layoutWeight(1).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
  }
}
