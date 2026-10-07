# 一席 · Desktop Mat 架构

目标是 Swift 6、macOS 15+ 的原生菜单栏应用。AppKit 管理真实桌面覆盖窗口，MetalKit 承载 GPU 绘制；SwiftUI 用于设置与少量原生辅助界面。地毯是桌面上的视觉对象，应用不读取、移动、删除、重命名桌面文件，也不修改壁纸。

当前代码为 0.3：在原生桌面覆盖与真实布料交互基础上，加入六款原创程序化地毯、原生 SwiftUI 画廊、菜单主题选择及全局主题记忆。实现覆盖了多个 Phase 的部分内容，不代表 Phase 2–6 全部完成；真实 OS 鼠标派发、缩放、旋转、自碰撞、独立显示器配置和完整性能目标仍需继续验证或开发。历史布料验证见 `INTERACTION-VERIFICATION.md`，本次预设验证见 `PRESETS-VERIFICATION.md`。

## 模块边界

| 模块 | 责任 | 阶段 |
| --- | --- | --- |
| App | 进程生命周期、依赖装配、菜单栏入口；不创建普通主窗口 | 已实现，0.2 集成待验收 |
| DesktopOverlay | 每个显示器一个覆盖 `NSScreen.frame` 的无边框非激活透明 NSPanel；桌面窗口层级、显隐、销毁 | 已实现，0.2 集成待验收 |
| RugRenderer | MTKView、动态 mesh buffer、法线光照、织物背面、跟随变形的流苏与投影软阴影 | 已实现基础效果，视觉待验收 |
| RugEngine | 不依赖 AppKit/SwiftUI/Metal 的 Swift 模块；simd 粒子、XPBD 约束、局部抓取、重力/阻尼/桌面接触、休眠 | 已实现，验证边界见引擎记录 |
| RugMesh | 40 × 30 单元拓扑、UV、三角索引与变形后的表面法线 | 已实现 |
| RugTexture | 六款原创程序化织物纹样、GPU albedo 与同源画廊预览 | 已实现六主题 |
| RugGallery | 紧凑原生 SwiftUI 主题选择窗口，显示当前选择 | 已实现 |
| DesktopManager | 显示器与坐标系、各自地毯生命周期、重置与显隐；不操作 Finder 文件 | 基础已实现；跨屏传递未实现 |
| RugInteraction | 原生 mouseDown/dragged/up；中部局部拖动、四角提升、释放；保持单个输入 owner | 已实现；缩放/旋转未实现 |
| MouseTracking | 使用当前布料投影三角形命中，动态切换 NSPanel 鼠标穿透；被动 event monitor 与轮询 | 已实现；真实 OS 路由待验收 |
| MenuBar | 显隐、主题子菜单、画廊、重置、层级检查、关于、退出 | 已实现；物理手感菜单未实现 |
| Preferences | UserDefaults 保存显隐与全局主题，未知主题回退宁夏 | 独立显示器配置和位置记忆未实现 |

目录以 `Sources/DesktopMat` 和 `Sources/RugEngine` 分离应用与引擎。待开发功能只列在路线图中，菜单不提供空按钮或假动画。Phase 1 历史验证保存在 `PHASE1-VERIFICATION.md`；独立引擎的已执行测试和 CPU 采样保存在 `CLOTH-ENGINE-VERIFICATION.md`，两者均不能代替 0.2 真实桌面交互验证。

## 桌面覆盖窗口

地毯窗口使用 `NSPanel`，初始化 style mask 为 `[.borderless, .nonactivatingPanel]`，`isFloatingPanel = false`、`hidesOnDeactivate = false`、`isOpaque = false`、`backgroundColor = .clear`。覆写 `canBecomeKey` 和 `canBecomeMain` 返回 `false`，显示时不调用 `activate` 或 `makeKeyAndOrderFront`。菜单栏身份通过 accessory activation policy/应用 bundle 配置建立。

层级取运行时 `CGWindowLevelForKey(.desktopIconWindow) + 1`，并检查严格小于 `CGWindowLevelForKey(.normalWindow)`。这样表达“高于桌面图标、低于普通应用窗口”的目标，避免写死某一 macOS 的数值。Apple 对 `CGWindowLevelForKey` 的文档说明它面向框架且不推荐应用直接使用；本项目因需要精确桌面层级而采用这一公开 API，但 Finder、Show Desktop、Space 等真实行为仍需在目标系统上验收，不能仅由层级数值推断成功。

collection behavior 当前组合为 `[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]`：允许在桌面 Space 出现、保持桌面对象性质、不参与窗口轮换；当前不加入其他 App 的全屏 Space。`stationary` 不能与 `managed` 或 `transient` 同时配置。全屏兼容在 Phase 6 独立验证；`fullScreenAuxiliary` 只是请求加入全屏 Space 的行为，不是跨所有第三方应用的保证。Stage Manager 的 `primary`、`auxiliary`、`canJoinAllApplications` 也互斥。

实机发现 NSPanel 的浮动属性配置会将窗口层级重置，因此 `level` 在面板和 collection behavior 配置结束后赋值。Metal 使用 `.bgra8Unorm` 与显式 sRGB layer，保持透明区域的 RGB/alpha 预乘关系；后续采用线性物理光照时需要独立输出色彩转换。

Phase 1 历史版本令整个地毯窗口 `ignoresMouseEvents = true`。0.2 的窗口覆盖整块显示器，透明区域为地毯提供拖动与掀角空间；`MouseTrackingManager` 根据鼠标所在位置和当前布料投影三角形动态切换 `ignoresMouseEvents`。主体布料以外、揭露区域和阴影区域保持穿透，抓取期间原面板持有完整 drag sequence，其他面板保持穿透。屏幕重配置、隐藏和退出会释放抓取。

输入从实际派发到 `RugInputView` 的 `mouseDown` 开始。它接受第一次点击，并处理 `mouseDragged` / `mouseUp`；`NSView.hitTest` 只选择当前窗口内的 responder，不承担跨应用点击转发。局部/全局 monitor 仅观察鼠标移动和释放，不合成或重新派发 Finder 点击。120 Hz 的 common-mode timer 补充指针命中更新；按键已经按下时不因鼠标进入地毯而获得一个新的抓取，以保留 Finder 和其他 App 已开始的拖动。

这是窗口级动态穿透的实现策略。真实 OS 中露出 Finder 图标后的直接点击、快速进入并点击、前景窗口鼠标所有权仍待验收；异步 monitor 与轮询不能证明第一击一定无延迟命中。

透明背景必须由窗口和 Metal render target 同时实现：clear alpha 为 0，地毯实体表面 alpha 为 1，阴影单独混合。Finder 图标消失应来自实体地毯遮挡，而不是截屏/复制桌面或修改图标。

## 引擎数据与坐标约定

独立 `RugEngine` 包含 `SIMD3<Float>` 粒子位置、上一子步位置与速度，mesh 顶点法线、`SIMD2<Float>` UV 和三角索引。普通粒子使用统一的逆质量权重，当前抓取粒子作为运动学约束处理。桌面平面为 x/y，z 表示离开桌面的高度；长度单位为逻辑屏幕 points。应用使用 `NSWindow.convertPoint(fromScreen:)` 和 `NSView.convert` 转换 AppKit 屏幕坐标，保留负显示器原点；Retina backing scale 仅用于 drawable 像素转换。引擎不读取 `NSScreen` 或 `NSEvent`。

0.2 的 `RugCloth` 使用 120 Hz 固定子步。每步包含重力、水平/垂直阻尼与近桌面摩擦，10 轮交替顺序的 structural / shear 距离约束与三点织线曲率弯曲约束 XPBD 求解，以及 4 轮 structural / shear 抗拉伸修正。弯曲约束抵抗局部曲率，使普通拖动保持地毯主体铺展，角点仍可抬起；没有对整张地毯执行刚体平移或强制平铺。桌面接触限制 `z >= 0`，落地采用低回弹；当前没有自碰撞、有限体积厚度或布料之间的接触求解，折叠可能相互穿过。

中部抓取选择距离鼠标最近的局部粒子，周围节点通过约束受牵引，拖动速度产生少量局部高度变化。四角附近的抓取选择真实角节点，鼠标相对起点的移动距离决定提升高度。目标追踪速度受限，快速跳跃时抓点可以暂时滞后；松手释放抓取约束，让重力、阻尼和桌面接触继续求解。慢速与快速操作的视觉手感、厚重羊毛观感以及四角自然回落仍需集成观察。

渲染与命中使用统一斜投影 `screenPoint = xy + (0.12, 0.42) × z`。角落提升改变实际 3D mesh 与投影轮廓，下方像素露出来自真实几何形变；当前没有对整体图片执行缩放、旋转或裁切来替代布料。

模拟在 CPU 运行，GPU 绘制。`RugSurfaceView` 的渲染、抓取和命中查询均读取当前 `renderer.cloth.mesh`，使用同一投影和三角拓扑；MainActor 串行执行这些操作，避免交互读取一个独立旧网格。每个 Metal command 使用新分配的不可变 vertex buffer，CPU 不改写 GPU 上一帧仍在读取的数据。只有实测性能需要时才考虑 compute shader 或异步模拟；后者必须引入明确 snapshot 交换。

## 渲染与性能

0.2 的 MetalKit draw loop 请求显示器支持范围内的 60–120 FPS，模拟保持 120 Hz 固定步长并限制长暂停后的补算。solver 安静后进入休眠，renderer 连续确认稳定后暂停绘制，保留当前桌面图像；再次抓取/重置唤醒，隐藏时暂停。鼠标穿透轮询仍持续运行，因此“空闲暂停”指布料求解与持续绘制，没有宣称应用空闲 CPU 为零。

基础动态阴影由变形 mesh 的九次投影样本形成，随高度变软；折皱暗部使用邻节点高度与局部法线计算的遮蔽近似。织物背面与毛边/流苏跟随顶点变形，Metal depth buffer 处理视觉前后关系。当前没有通用 ambient occlusion、完整厚度或自碰撞求解。

120 Hz 模拟频率与 `preferredFramesPerSecond` 是实现参数。引擎 CPU 采样不等于完整应用达到 60/120 FPS；多个全显示器 drawable 的 GPU 成本、低鼠标延迟、ProMotion 120 FPS、热插拔/睡眠唤醒和长时间稳定性仍待实机验收。

六款预设包括宁夏、宋锦、水墨山河、海水江崖、中国红和隐山熊猫；各自有独立原创矢量构图，叠加确定性纤维颗粒，非历史织物复原。GPU 2048×1408 纹理与画廊 600×412 预览复用同一绘制流程。albedo 仅承载颜色/织物图案，实际形变仍由网格求解器完成；Metal 采样对 CoreGraphics 图像方向作显式转换。

主题切换先为所有显示器准备 texture，再一次性提交材质及 UserDefaults；任何分配失败均保留原有主题。切换保留粒子位置、速度、UV、当前抓取与褶皱；已提交 Metal command 保留其引用的旧 texture，CPU 不会改写其像素。当前选项应用到所有屏幕，下次启动恢复全局主题，独立显示器主题与位置配置尚未实现。

## 安全与权限

- 默认模式不需要桌面文件读取权限、Finder Automation、Accessibility 或 Screen Recording。
- 不获取或保存桌面截图，不改写 Finder 图标位置。
- 隐藏/退出/崩溃时窗口消失，下方桌面对象自然重新可见。
- 当前每个显示器各有独立地毯；一次抓取只属于起始显示器。跨显示器传递地毯未实现，全局主题已持久化，每屏位置/主题与手感尚未持久化。
- Sweep Mode 不在当前六个 Phase 内实现；未来先明确“视觉扫地”原型的数据来源与权限，再单独推进。任何真实文件操作必须成为后续独立、明确授权的功能。

## 官方 API 依据

- [desktopIconWindow](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey/desktopiconwindow)：桌面图标层级。
- [CGWindowLevelForKey](https://developer.apple.com/documentation/coregraphics/cgwindowlevelforkey(_:))：运行时查询标准窗口层级及其使用提示。
- [nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)：面板不激活所属应用。
- [isFloatingPanel](https://developer.apple.com/documentation/appkit/nspanel/isfloatingpanel)：面板是否浮动。
- [becomesKeyOnlyIfNeeded](https://developer.apple.com/documentation/appkit/nspanel/becomeskeyonlyifneeded)：面板键盘焦点行为。
- [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)：Space、Mission Control、全屏、Stage Manager 行为及互斥配置。
- [ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)：窗口整体鼠标透明。

这些是实现依据；目标行为是否可靠仍以 `ROADMAP.md` 的实机验收为准。
