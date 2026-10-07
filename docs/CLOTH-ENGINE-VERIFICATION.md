# Cloth Engine 验证记录

验证日期：2026-10-08。范围为最终厚重地毯参数下的 `Sources/RugEngine` CPU 布料模拟、网格输出及投影；实际 Metal 绘制、窗口鼠标交互与 Finder 桌面合成由集成验证另行记录。

## Release 测试结果

实际执行的最终验收命令：先构建并验收匹配应用实际 640 × 440pt 地毯的普通拖动测试，再跳过重复构建运行完整引擎测试。

```sh
swift test -c release \
  --scratch-path /private/tmp/desktop-mat-engine-build \
  --filter ordinaryCenterDragKeepsWoolCarpetSpreadAcrossDesktop
swift test -c release \
  --scratch-path /private/tmp/desktop-mat-engine-build \
  --skip-build --filter RugEngineTests
```

最终结果：**8 tests 全部通过**，完整 Swift Testing 运行耗时 **1.654 秒**；前置增量 Release 构建耗时 **1.53 秒**，普通拖动单项测试耗时 **0.222 秒**。独立 scratch path 避免与应用默认构建产物冲突。首次复现时可直接使用不带 `--skip-build` 的全引擎测试命令。

| 测试 | 实际验收条件 |
| --- | --- |
| `gridHasExpectedTopologyAndTextureCoverage` | 40 × 30 单元、1271 顶点、2400 三角形；索引有效、UV 完整、顶点有限。 |
| `trianglesFaceUpAndNormalsSurviveSurfaceDeformation` | 初始三角形朝上；倾斜平面的重算顶点法线与解析法线一致。 |
| `restingRugSleepsWithoutChangingShape` | 初始地毯平铺在 `z = 0`；120 次空闲更新后形状完全不变且保持休眠。 |
| `grabMovesNearbyClothFirstAndEventuallyPullsWholeRug` | 第一个 120 Hz 子步中抓点移动超过 5pt，响应大于远角的 3 倍；随后连续慢拖 120 帧，整体质心移动超过 180pt，结构边伸长小于 1.6 倍。 |
| `raisedCornerDeformsMeshAndFallsBackOntoDesktop` | 90 帧内将一角逐渐抬高到 190pt，实际最高点及抓角超过 180pt，对角高度小于 35pt，法线体现曲面弯折；释放后最终高度小于 1pt、无穿过桌面的顶点，并进入休眠。 |
| `ordinaryCenterDragKeepsWoolCarpetSpreadAcrossDesktop` | 匹配实际 640 × 440pt 网格，从中心一次设置指针目标 `(-180, +65)`、抬高 24pt，持续更新 66 帧/1100ms。逐帧要求有向投影面积大于初始面积的 85%、翻面三角形少于 1.5%、最高波小于 75pt；质心跟随到 x 为 -100 至 -235pt 之间。释放后 144 帧/2.4s 最高点小于 10pt、投影面积大于初始面积的 95%。 |
| `fastGrabsStayFiniteAndDoNotTearFabric` | 420 帧连续多向拖动和抬起；每 31 帧模拟一次 50ms 更新，其余为 60 Hz。所有投影位置、顶点高度、法线保持有限，顶点不穿过桌面，每帧结构边伸长小于 1.6 倍；释放后的 600 次更新内高度降至 50pt 以下并休眠，休眠形状不再变化。 |
| `projectionAgreesWithHeightOffsetAndInvalidInputIsIgnored` | 投影统一使用 `xy + (0.12, 0.42) × z`；无效指针位置、过远抓取及非有限时间输入不会破坏网格。 |

这些测试直接验证真实粒子与网格变形，没有通过整体图片的缩放或旋转来替代布料行为。

## 抗拉伸与释放行为

求解器使用 120 Hz 固定子步，包含结构、剪切和三点曲率弯曲约束。每个子步执行 10 轮交替方向的 XPBD 求解，再执行 4 轮结构/剪切边的抗拉伸投影。弯曲约束在各条水平和垂直织线上，用三个相邻粒子的 `a - 2 × middle + b` 曲率向量抵抗紧密折叠，静止曲率为零；compliance 为 `0.000002`。恢复力来自局部约束求解，不是整体平移或强制将整个网格归为平面。

抓取通过单个局部粒子传力，桌面摩擦和阻尼作用于各个粒子。水平空气阻尼为 6/s，桌面摩擦为 2.4/s，垂直速度阻尼为 20/s；较强垂直耗散保留手部局部抬起，同时抑制整毯持续飘动。粒子高度没有通过此阻尼进行上限裁剪。

抗拉伸投影的局部目标为静止边长的 1.28 倍；由于后续邻边修正会再次改变同一顶点，这不是最终所有边都不超过 1.28 倍的硬性保证。最终参数下上述 420 帧压力轨迹单独采样得到的最大结构边伸长为 **1.3318235 倍**，测试逐帧要求小于 **1.6 倍**。

鼠标目标的追踪速度限制为 800pt/s，避免单个跳跃事件向一小块布料注入无限能量；极快拖动时抓点可以短暂滞后，周围网格继续传递受力。每次更新最多补算 8 个子步，避免暂停后长时间追帧。

匹配实时验收的普通拖动轨迹中，实际 640 × 440pt 地毯的最高瞬态波为 **65.45pt**；1100ms 后最高点为 **24pt**，有向投影面积约 **99.7%**，没有翻面，主体保持铺展。释放后 650ms 的单独采样已回到 `z = 0` 并休眠。随后从真实当前角位置设置 `(-145, -100)` 指针偏移、抬高 180pt，1100ms 后仍保持约 **94.7%** 有向投影面积、实际角高度 180pt；释放后 2.4s 回到 `z = 0` 并休眠。

连续大幅多向拉扯压力测试允许惯性把其它粒子抬得比抓点更高，不强制将全部顶点瞬间重置为平面。最终压力采样中，释放后第一个更新最高点约 **247.89pt**，随后持续落下，约 4 秒模拟时间内恢复到 `z = 0` 并休眠。这是约 7.5 秒连续高速、抬起、多向轨迹的结果，与一次普通拖动逐帧小于 75pt 的质量门槛分别验收。休眠后不再运行求解器，再次抓取会唤醒。

## CPU 性能采样

使用 Swift `-O` 单独编译引擎与临时采样程序，在本机执行。编译命令为：

```sh
swiftc -O \
  -module-cache-path /private/tmp/desktop-mat-engine-modulecache \
  Sources/RugEngine/RugMesh.swift \
  Sources/RugEngine/RugCloth.swift \
  /private/tmp/MatClothTiming.swift \
  -o /private/tmp/MatClothTiming
/private/tmp/MatClothTiming
```

采样程序创建 640 × 440pt、1271 粒子的地毯并持续抓取中部。执行 720 次 `step(deltaTime: 1 / 60)`，每次包含两个 120 Hz 子步和一次网格法线重算，利用 `ContinuousClock` 单独计时每次 `step`。

指针及抬起轨迹为：

```swift
let time = Float(frame) / 60
cloth.updateGrab(
    target: SIMD2(180 * sin(time * 2), 110 * sin(time * 1.5)),
    lift: max(0, 90 * sin(time))
)
cloth.step(deltaTime: 1 / 60)
```

| 720 次更新耗时 | 实测结果 |
| --- | ---: |
| 平均 | 2.29ms |
| p50 | 2.26ms |
| p95 | 2.41ms |
| 最大 | 5.44ms |

这是 CPU 引擎的真实测量，包含位置约束、地面接触、速度更新、休眠判断、顶点发布和法线重算；不包含 Metal 编码、GPU 绘制、WindowServer 合成、鼠标事件处理或多个显示器同时运行。结果处于 60 Hz 的 CPU 帧预算内，**不能据此宣称完整应用稳定达到 60 FPS 或 120 FPS**。临时基准程序保存在 `/private/tmp`，不是随应用发布的资源。

## 与截图及实际交互验收的区别

本记录以数值测试和 CPU 时间采样为证据。普通拖动数值测试使用与实时 Metal 验收相同的尺寸、目标偏移、抬高和持续时间；它仍不等同于真实 `NSEvent` 鼠标拖动的输入递送。网格压力测试中的高速轨迹是确定性模拟输入，也不等同于用户连续拖动鼠标。实际截图结果在应用集成记录中验收，本记录不以截图替代上述数值门槛。

实际 Metal 截图可以检查弯折轮廓、纹理、法线光照、折叠阴影与透明区域；一张截图无法证明拖拽延迟、连续帧稳定性、松手回落过程、真实 Finder 文件可点击或桌面层级。集成验证需要使用同一变形网格进行绘制和鼠标命中，另行观察真实原生应用中的连续拖动、角掀起、鼠标穿透、释放和帧率。

## 当前物理边界

- 已有重力、桌面接触、水平摩擦、惯性、方向相关速度阻尼、低回弹、局部抓取、结构/剪切距离约束和三点曲率弯曲约束，地毯形状来自真实 mesh deformation。
- **尚未实现布料自碰撞**。折叠层之间没有厚度碰撞求解，复杂交叠可能互相穿透。渲染中的羊毛厚度、纤维和层间阴影不等于物理自碰撞已完成。
- 当前弯曲由三点离散曲率约束实现，尚未使用完整的二面角弯曲或有限元羊毛材料模型。
- 静止判据来自粒子速度，稳定低褶皱也可以休眠。已验收的普通拖动、角掀起与压力轨迹都能在释放后归地平铺；这不构成任意长时间、多次重叠拉扯都必然完全恢复初始矩形的保证。重置操作负责恢复初始形状。
- 本引擎不依赖 AppKit，不操作文件；它本身不证明真实 Finder 交互、多 Space 或多显示器输入已经通过。
