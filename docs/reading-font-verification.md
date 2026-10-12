# 阅读字号手动验证 · 2026-10-12

本轮实现社区、分享文章和书籍的全局五档阅读字号（0.9 / 1 / 1.15 / 1.3 / 1.5）。入口为设置 → 其他 → 阅读字号、社区文章 → ⋯ → 字号，分享文章右上角字号按钮，以及书籍右上角 ⋯ → 字号。正文及标题、行距一起变化，图片及工具栏不缩放。本机持久化，不改服务端契约，不随分享链接传播。录音/自己的文章编辑详情和提示词帖不接入。

按用户要求，本轮不运行任何自动测试。已补充纯字号模型测试文件但未执行，构建不等于这些测试通过。用户在模拟器手动确认：

1. 设置中依次选择五档，打开社区和分享文章查看标题、Markdown 标题、列表、引用、长段落的排版；最大档可纵向读完，无横向溢出。
2. 阅读页切档后即时变化；取消选择保留原档位。返回设置和已有阅读页时同步更新。
3. 重启应用后仍保留所选档位；清除可重建缓存后仍保留。语言切到 English 检查档位和设置说明。
4. 提示词正文、录音详情、自己的文章编辑器与行号光标保持原排版。照片尺寸、分享、投币、喜欢、回应和举报操作正常。

本轮仅构建、安装、启动确认，阅读交互及排版由用户手动测试；不声称完成真机或端到端验证。

## 本轮构建与安装记录

- 使用 DevEco 自带 JBR/SDK 执行 `hvigorw --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon`：BUILD SUCCESSFUL。
- 安装包：`entry/build/default/outputs/default/entry-default-signed.hap`，沿用本地已有 signingConfig，未修改签名配置。
- 模拟器：VoiceDrop_API22（HarmonyOS 6.0.2 / API22），目标 `127.0.0.1:5557`。`hdc install -r` 返回 install bundle successfully，保留已有数据。
- `aa start -a EntryAbility -b com.baixingai.voicedrop.hm` 成功；`aa dump -a` 确认 Ability 和 App 均为 FOREGROUND。
- 未执行 Hypium 或 UI 自动测试，新增测试文件未执行。

## 书籍阅读字号补齐

- Android 通过 WebSettings.setTextZoom；HarmonyOS 通过响应式 Web.textZoomRatio，仅调整文字，由网页重排，不使用整页 zoom。
- 五档对应 90/100/115/130/150%，与文章共用本地偏好；所有读者均可使用书页菜单入口。
- 手动补充：设置中改档后打开书，书页中切档即时生效；跳转下一章、返回章节、刷新、关闭后再打开仍保持。最大档检查封面、图片、正文、长链接和窄屏无额外横向溢出。切换字号不重载页面、不改分享链接。
- 已扩充百分比映射测试，但按用户要求未运行自动测试；网页重排仍由用户在模拟器实际书页确认。

书籍字号补齐后重新执行同一构建命令成功，并已覆盖安装至上述模拟器、启动应用；未运行自动测试。构建日志分别为 `/private/tmp/voicedrop-android-book-font-build.log` 和 `/private/tmp/voicedrop-harmony-book-font-build.log`。

## 字号选择底部弹窗

- 复用设置名字弹窗的底部 CustomDialogController 样式：白色圆角卡片、遮罩、关闭按钮和进出动画；适配底部安全区域。
- 设置、社区、分享文章、书籍共用 ReadingFontSheet，展示五档选项和当前选中标记；点击保存字号并关闭，关闭或点击遮罩不改字号。
- 手动检查上述四个入口的弹出位置、选中标记、切档后正文更新，以及关闭、遮罩、返回键取消行为。
- 本次 assembleHap 构建成功，未运行自动测试，未更新鸿蒙模拟器。安卓已完成 assembleDebug 并覆盖安装至 emulator-5554。
