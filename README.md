# VoiceDrop HarmonyOS

**随手录下口述，自动整理成可编辑、可分享的文章。**

这是 VoiceDrop 的 HarmonyOS 原生客户端，使用 ArkTS、ArkUI、Stage 模型和 HarmonyOS 系统 Kit 实现。应用包名为 `com.baixingai.voicedrop.hm`，支持手机、平板和 2in1 设备。

---

## HarmonyOS App（本仓库）

### 核心行为

- 首次启动先展示隐私政策；同意前不创建身份、不联网，也不初始化录音或 WebSocket。
- 轻点首页麦克风开始录音，再次点击停止。录音保存为 AAC/M4A，并在停止后自动上传、转写和生成文章。
- 上传失败或应用中断时保留本地录音；下次启动或回到前台继续上传，避免录音丢失。
- 长按首页麦克风可说出图库指令；松开发送、上滑取消，可按当前列表编号操作录音。
- 录音时可添加标签和照片，也可开启实时 AI 采访。
- 生成后的文章支持播放原录音、编辑、重新生成、历史版本、撤销/重做、图片、公开分享和公众号草稿发布。
- “VD社区”支持推荐、最新、回应、点赞、举报、回复、算力投币和提示词分享。
- 默认使用本机生成的匿名身份；也支持微信登录、匿名 Token 导入和跨设备安全配对。
- 支持系统分享接收、`voicedrop://` 深链、静态快捷方式“记一条”和 ZIP 数据导出。

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

---

## 代码结构

| 路径 | 作用 |
|---|---|
| `AppScope/` | 应用级名称、图标、版本和 bundle 配置 |
| `entry/src/main/ets/entryability/` | Stage 模型入口，处理冷启动、深链和系统分享 Want |
| `entry/src/main/ets/pages/` | 首页、录音列表、文章、社区、设置及二级页面 |
| `entry/src/main/ets/components/` | 可复用 ArkUI 组件 |
| `entry/src/main/ets/ui/` | 主题、统一标题栏和 Remix Icon 封装 |
| `entry/src/main/ets/audio/` | M4A 录音、播放、上传、ASR 听写和实时采访 |
| `entry/src/main/ets/net/` | HTTP、WebSocket 和火山 ASR 二进制协议 |
| `entry/src/main/ets/data/` | 身份、设置、录音库、社区、提示词、用量和导出 |
| `entry/src/main/ets/core/` | 录音命名、文章解析、提示词树及可单测业务逻辑 |
| `entry/src/main/ets/share/` | 系统分享内容收集、预览和导入 |
| `entry/src/main/ets/model/` | 跨页面共享的数据模型 |
| `entry/src/main/module.json5` | Ability、权限、深链、分享和快捷方式声明 |
| `entry/src/ohosTest/` | Hypium 单元测试与测试运行器 |
| `docs/android-parity-coverage.md` | Android 功能迁移覆盖情况和待真机验证项 |

---

## 技术与产品文档

- [Android → HarmonyOS 功能迁移清单](docs/android-parity-coverage.md)
- [第三方组件声明](THIRD_PARTY_NOTICES.md)

相关实现分布在多个仓库：

- `voicedrop-android`：当前主要功能、交互和跨端契约参考。
- `voicedrop`：iOS 客户端及早期产品行为参考。
- `voicedrop-mini`：微信小程序实现和受限平台行为参考。
- `jianshuo.dev`：Files、Agent、Reco、WebSocket、分享页及服务端业务逻辑。

---

## 给未来开发者和 Agent 的指引

- 修改功能前先阅读根目录 `AGENTS.md` 和 `docs/android-parity-coverage.md`。
- 用户可见行为优先对照 Android；Android 未覆盖或语义不清时继续核对 iOS。
- API、WebSocket、认证、上传、状态值和错误处理必须以服务端当前实现为准，不凭客户端代码猜测。
- 不要随意改变 API path、JSON 字段、录音命名、文章 schema、图片 marker 或 `X-VD-Platform`。
- 不在源码、README、日志或测试数据中记录真实 Token、AppSecret、证书密码或私钥。
- 修改权限、Ability、深链、分享或快捷方式时，同时检查 `module.json5`、`EntryAbility` 和目标页面。
- 新功能和缺陷修复应补充可行的测试；无法自动化的平台行为应写明模拟器或真机验证步骤。
- 提交前至少确保主 HAP 构建成功，并运行与修改范围相关的单元测试。
