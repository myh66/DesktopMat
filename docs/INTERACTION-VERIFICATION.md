# 0.2 布料交互集成验证

验证日期：2026-10-08（Asia/Shanghai）。本机 Apple M4、macOS 27.0.1，两个显示器；部署目标 macOS 15，未在 macOS 15 实机测试。

## 最终应用

`bash scripts/build-app.sh release` 成功生成 `build/一席 · Desktop Mat.app`（0.2.0 / build 2），Info.plist 校验与开发签名验证通过。Metal shader 在真实 GPU 上成功编译并绘制。已通过 LaunchServices 启动最终应用，`--replace --show` 仅替换本应用实例并显示地毯。

启动链路修复包含：显式、幂等的 AppKit 依赖装配；抛错的 Metal 设置放在 NSView / NSPanel 完成初始化之后；修复 shader 保留字。否则 build 成功也不能保证运行时 Metal 可用。

## 实时集成检查

实际执行：

```sh
"build/一席 · Desktop Mat.app/Contents/MacOS/DesktopMat" \
  --replace --verify "$PWD/artifacts"
```

退出码 0，**12 项全部通过**。完整报告为 `artifacts/cloth-verification.json`，实际 GPU 输出为 `cloth-drag.png`、`cloth-lift.png`、`cloth-rest.png`。

| 检查 | 最终实测 |
| --- | --- |
| WindowServer 层级 | 两个真实面板均为 -2147483602；Finder 桌面图标 -2147483603，普通检查窗口 0。 |
| 原生面板配置 | 两个整显示器透明面板，不成为 key / main window。 |
| 当前 mesh 命中 | 主体内部命中，透明显示器角落不命中。 |
| Responder 抓取所有权 | 本进程原生 down/up fixture 建立一个抓取者，其他显示器保持穿透；up 释放所有权。 |
| 局部拖动 | 中部目标位移 (-180, +65)pt、lift 24pt，持续 1100ms；质心跟随 190pt。 |
| 普通拖动保留主体 | 投影三角形面积约初始的 99%，0 个向下法线顶点，避免一拖即整体揉团。 |
| 拖动 GPU 像素 | 282763 个不透明像素，1104841 个透明像素，0 个预乘颜色违规像素。 |
| 三维掀角 | 真实角节点高度 180pt，最大法线倾斜约 1；材质背面与局部折叠可见。 |
| 掀角 GPU 像素 | 269606 个不透明像素，1121483 个透明像素，0 个预乘颜色违规像素。 |
| 揭露区域变化 | 165 个原来被覆盖的 mesh 采样点处于变形后的三角形之外。 |
| 重力释放 | 松手后 2400ms，高度从 180pt 降到 0pt，无非有限顶点。 |
| 回落 GPU 像素 | 283464 个不透明像素，1104175 个透明像素，0 个预乘颜色违规像素。 |

截图已目视检查：正常拖动保留铺展的羊毛地毯，掀角出现局部翻折与背面；形状与命中均来自同一 3D cloth mesh。透明 PNG 在黑色查看器中显示黑底，不代表应用修改了壁纸。截图来自本应用离屏 GPU target，不包含 Finder 或用户桌面合成。

## 实际 UI 验证边界

原生 UI 工具成功识别运行中的地毯面板，并截取其窗口画面。坐标点击该桌面层级、非激活面板返回 `noWindowsAvailable`，无法用此工具完成真正的 OS 鼠标拖动验收。未使用合成系统事件或将 Finder 点击重新投递给应用绕过该限制。

上面的 responder fixture 是本进程调用；实时布料检查调用实际 view/renderer 的抓取接口并等待真实 draw loop。两者均不能证明 OS 第一击、连续鼠标派发或 Finder 图标点击穿透已通过。普通前景窗口遮挡层级已用 WindowServer 元数据确认，完整桌面合成画面未由隔离窗口截图证明。

仍待真实鼠标检查：快速首次进入并点击、四个角连续拉扯、拖出原轮廓、掀开后的 Finder 直接点击、前景窗口所有权、菜单显隐/重置、跨 Space 和显示器边缘行为。完整应用 60 / 120 FPS 也未作保证。

当前不读取、修改或移动桌面文件。没有布料自碰撞和实体厚度求解，极端折叠仍可能穿叠；跨显示器转移地毯、缩放、旋转和 Sweep Mode 未实现。
