import SwiftUI

@MainActor
final class LayerVerificationView: NSHostingView<LayerVerificationContent> {
    init(frame: NSRect) {
        super.init(rootView: LayerVerificationContent())
        self.frame = frame
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    required init(rootView: LayerVerificationContent) {
        super.init(rootView: rootView)
    }
}

struct LayerVerificationContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text("窗在上，毯在下。")
                .font(.system(size: 23, weight: .medium))
            Text("这是一个普通层级的原生窗口。它应完整覆盖地毯；关闭后，地毯仍铺在桌面图标上方。")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("布料网格 · 局部拖拽 · 动态鼠标穿透")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
