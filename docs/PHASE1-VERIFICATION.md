# Phase 1 验证记录

验证日期：2026-10-07。范围为项目架构与静态原生桌面地毯。

## 已通过

- Swift 6.4 / Xcode 27.0：Debug 与 Release 构建成功；部署目标为 macOS 15。
- RugEngine 的两项 Swift Testing 测试通过：网格完整性 / UV / 索引及朝向，变形后的法线重算。
- 生成 `build/一席 · Desktop Mat.app`，Info.plist 与开发签名检查通过；原生应用启动接口成功运行。
- 当前本机 macOS 27.0.1 / Apple M4 / 两个连接显示器分别创建真实地毯面板。
- 两个实际 Finder 桌面图标窗口的 WindowServer 层级为 `-2147483603`，两个地毯窗口为 `-2147483602`，重叠普通原生窗口为 `0`。实际窗口顺序符合桌面图标 < 地毯 < 普通窗口。
- 所有地毯面板无标题栏、不透明窗口背景或 AppKit 自带阴影，不可成为 key / main window，鼠标全部穿透。
- 40 × 30 个网格单元 / 1271 顶点 / 2400 三角形；两个显示器的离屏 Metal 图像输出成功。
- 每张 GPU 图像有 1,128,907 个完全不透明像素、266,804 个完全透明像素，中心不透明、外角透明；RGB 超过 alpha 的非法预乘像素为 0。
- renderer 实际从 `.app/Contents/Resources/DesktopMat_DesktopMat.bundle` 加载 shader，不依赖开发目录里的 `.build` 资源。
- 原生 UI 工具可读取地毯窗口并获取独立窗口截图；毛边、流苏、程序化织物纹样和透明阴影输出已检视。

运行证据：`artifacts/phase1-verification.json`，`artifacts/rug-1.png`，`artifacts/rug-3.png`。这些本机诊断文件默认被 Git 忽略，仍保存在工作目录。

## 尚未确认

当前 UI 工具给出的是单个窗口截图，不能作为整个桌面合成画面的证据。菜单栏系统进程的 UI 查询超时，因此下列项目仍需在实际桌面观察：

- 不透明地毯区域是否完整遮住真实 Finder 图标，隐藏后是否立即重现。
- 外部 App 窗口的实际遮挡画面、桌面框选/点击、菜单栏显隐和退出点击。
- 多 Space、Show Desktop、Mission Control、Stage Manager、全屏、睡眠唤醒、显示器热插拔。
- macOS 15 实机兼容性。当前机器的通过结果不代表这个版本已经通过。

这些边界没有被自动通过项替代。当前没有布料物理、可拖拽、缩放、旋转、掀角、扫地动画或主题图库；全部属于后续 Phase。

## 实现修正

NSPanel 的 `isFloatingPanel` 配置会重置窗口层级，已将桌面层级设置移到初始化末尾。使用带 `screen` 的 convenience super initializer 导致 subclass 初始化路径错误，已改为正确的 designated initializer。透明 Metal render target 改为与材质一致的非 sRGB 自动转换格式，避免预乘 RGB 被非线性编码后产生透明阴影光边，并加入实际 GPU 像素验收。

终端沙盒阻止 AppKit 向 LaunchServices 注册，因此实机运行验证在正常图形会话中执行；Release 的 dSYM 生成也在终端沙盒外完成。应用本身没有申请屏幕录制、辅助功能或 Finder Automation 权限。
