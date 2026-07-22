# VoiceDrop HarmonyOS

**随手录下口述，自动整理成可编辑、可分享的文章。**

这是 VoiceDrop 的 HarmonyOS 原生客户端，使用 ArkTS、ArkUI、Stage 模型和 HarmonyOS 系统 Kit 实现。应用包名为 `com.baixingai.voicedrop.hm`，支持手机、平板和 2in1 设备。

---

## HarmonyOS App（本仓库）

### 功能

- **轻点即录音**：在“我的录音”中轻点麦克风开始录音，再次点击停止。音频以单声道 AAC/M4A 保存，并立即进入上传和文章生成流程。
- **失败不丢录音**：断网或上传失败时，录音保留在本地待传队列；下次启动或回到前台会继续上传。
- **自动生成文章**：录音上传后自动转写并生成文章，列表会实时显示待处理、听录音、挖文章、已成文和无语音等状态。
- **语音管理图库**：长按首页麦克风说出指令，松开发送、上滑取消；可以按当前列表编号删除录音、修改标签或执行其他图库操作。
- **录音增强**：录音时可添加标签、拍照或选择相册图片，也可开启实时 AI 采访。
- **阅读与编辑**：文章详情支持阅读、播放原录音、修改标题和正文、自然语言改写、重新生成、历史版本、撤销与重做。
- **语音修改文章**：长按说出修改要求，AI 会根据指令改写文章并实时刷新结果。
- **文章配图**：从相册选择图片或拍照上传，让 AI 将图片插入文章正文；公开分享、社区和公众号沿用相同图片规则。
- **分享与发布**：支持公开链接、系统分享、小红书文案以及微信公众号草稿创建和更新。
- **VD社区**：浏览推荐、最新和回应内容，支持点赞、举报、回复、作者屏蔽、算力投币和提示词分享。
- **文风与提示词**：保存个人写作文风，管理快捷提示词，并可通过分享码浏览和导入社区提示词。
- **账号与迁移**：默认使用本机生成的匿名身份，也支持微信登录、匿名 Token 导入和跨设备安全配对。
- **导入与导出**：支持系统分享接收、`voicedrop://` 深链、静态快捷方式“记一条”，并可导出文章、音频、字幕、图片和索引。
- **隐私启动门禁**：首次启动先展示隐私政策；同意前不创建身份、不联网，也不初始化录音或 WebSocket。

跨端接口、文章结构、图片 marker、录音状态和用户可见结果主要与 VoiceDrop Android/iOS 客户端保持一致；HarmonyOS 请求统一携带 `X-VD-Platform: harmonyos`。

### 录音文件名

录音停止后生成自描述文件名，例如：

```text
VoiceDrop-2026-07-22-143052-0m33s-Wed-Afternoon.m4a
└─前缀──┘ └──时间戳───┘ └时长┘ └星期┘└─时段──┘
```

- `VoiceDrop-` 前缀和 `.m4a` 后缀是跨端及服务端识别约定，不应修改。
- 时长按秒四舍五入，日期、星期和时段与 Android/iOS 使用同一语义。
- 上传前会检查文件大小及 M4A `moov` 数据，防止上传未完成或损坏的录音。
- 标签以 sidecar 数据随录音上传；上传失败时录音和标签都会保留在本地等待重试。

文章中的图片使用以下 marker：

```text
[[photo:photos/<sessionTs>/<offset>-<rand>.jpg]]
```

修改录音命名或图片 marker 前，需要同步检查其他客户端、公开分享页、社区和公众号链路。

---

## 开发环境

- macOS
- DevEco Studio 6.0.2 或更高版本
- HarmonyOS SDK 6.0.2（API 22）
- OHPM
- Hvigor

用 DevEco Studio 打开仓库根目录，等待 SDK 和依赖同步完成。首次构建可手动安装依赖：

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
```

项目不需要手工填写上传 Token：首次同意隐私政策后会创建匿名身份。微信登录依赖腾讯官方 `@tencent/wechat_open_sdk`，正式发布前仍需在微信开放平台登记 HarmonyOS bundle、identifier 和发布证书签名。

### 构建 Debug HAP

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module \
  -p product=default \
  -p module=entry@default \
  -p buildMode=debug \
  assembleHap --no-daemon
```

未配置签名时，构建产物位于：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

日常开发建议直接在 DevEco Studio 中选择模拟器或真机后运行，由 IDE 使用调试签名完成安装。

### 单元测试

测试使用 Hypium，测试源码位于 `entry/src/ohosTest/`。

构建测试 HAP：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module \
  -p product=default \
  -p module=entry@ohosTest \
  -p buildMode=debug \
  assembleHap --no-daemon
```

安装主 HAP 和测试 HAP 后，可通过 HDC 执行：

```bash
hdc shell aa test \
  -b com.baixingai.voicedrop.hm \
  -m entry_test \
  -s unittest OpenHarmonyTestRunner \
  -s timeout 15000
```

纯业务逻辑应优先补充单元测试；录音、相机、相册、微信、系统分享和 WebSocket 等系统集成仍需在模拟器或真机验证。

### 模拟器与真机

- 模拟器适合验证编译、导航、布局、普通交互和不依赖厂商应用的网络流程。
- 麦克风、相机、系统 Picker、微信授权、设备配对、安装升级及后台恢复应在 HarmonyOS 真机补充验收。
- 实时 AI 采访会同时使用主录音与 PCM 音频采集；需在目标机型确认系统是否允许双路采集。
- 未配置正式签名的 HAP 不能作为发布包；证书、私钥、密码和真实凭据不得提交到仓库。

## 相关项目

- [VoiceDrop Android](https://github.com/houleixx/voicedrop-android)
- [VoiceDrop iOS](https://github.com/houleixx/voicedrop)
- [VoiceDrop 微信小程序](https://github.com/houleixx/voicedrop-mini)

各客户端共享后端 API、文章格式、录音命名、图片 marker 和分享链路，并根据各自平台的权限及交互习惯进行适配。
