# Contributing to Desktop Mat

欢迎一起让这张桌面地毯变得更有触感、更稳定。Desktop Mat 首先是一个数字玩具：保持原生、小巧、非破坏性，避免复杂 Dashboard 和任务管理界面。

Contributions should support a small, tactile native macOS desktop object. Keep interactions direct and file operations non-destructive.

## Development

- macOS 15+ and Swift 6; open `Package.swift` in Xcode or use the command line.
- Build: `bash scripts/build-app.sh release`.
- Engine tests: `swift test -c release --disable-sandbox`.
- Local GUI integration: `bash scripts/verify-cloth.sh` in an active desktop session.
- CI runs tests and packages an ad-hoc signed app. It does not establish GUI behavior or notarization.

The renderer and interaction hit testing must use the same projected mesh. Preserve single-owner mouse grabs, release ownership on cancellation, and keep ordinary application windows above the rug. Do not add desktop file mutations as an incidental part of visual interactions.

## Pull requests

Describe the user-visible change, why it is needed, and what you verified. Keep changes focused. Add meaningful engine tests for physics behavior or regressions; describe manual steps for window and mouse behavior that automated checks cannot prove.

For interaction changes, check first click, dragging beyond the initial rug outline, release, hide/show, reset, Finder selection outside the rug, and ordinary foreground windows. Include display count, macOS version and relevant Space / Stage Manager setup when reporting a problem. Please remove personal file names and paths from screenshots and logs.

## Rugs and assets

Prefer original procedural patterns that remain coherent as the mesh folds. Rug themes should work with the existing wool and textile material details, not just paste an unrelated image onto a plane.

- Submit only work you created or material with a license that clearly permits redistribution in this project.
- Document third-party assets, author, source URL and license; include required attribution and license files.
- Do not include the reference videos, screenshots of another app, or unlicensed textile scans as repository assets.
- Be clear about historical inspiration. Do not claim an original contemporary pattern is an authentic historical reproduction.
- Preserve the restrained palettes and small native control surface; theme changes should not require a new dashboard.

## Issues and ideas

Use the issue templates for bugs and feature proposals. For bugs, include steps, expected and actual behavior, environment, and any safe-to-share evidence. For ideas, explain the interaction and why it belongs on the desktop. Existing proposals are collected in [feature ideas](docs/FEATURE-IDEAS.md).

Contributions are covered by the repository's [MIT license](LICENSE). Do not submit code or assets you do not have permission to license.
