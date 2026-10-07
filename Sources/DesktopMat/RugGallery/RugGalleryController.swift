import AppKit
import SwiftUI

@MainActor
final class RugGalleryController {
    private let desktop: DesktopManager
    private var window: NSWindow?
    private var model: RugGalleryModel?

    init(desktop: DesktopManager) { self.desktop = desktop }

    func show() {
        if let window {
            syncSelection()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = RugGalleryModel(selected: desktop.selectedStyle)
        self.model = model
        let content = RugGalleryView(model: model) { [weak self] in self?.apply($0) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 580),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "一席 · 地毯画廊"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func syncSelection() { model?.selected = desktop.selectedStyle }

    func apply(_ style: RugStyle) {
        do {
            try desktop.setStyle(style)
            syncSelection()
        } catch {
            let alert = NSAlert()
            alert.messageText = "这张地毯暂时无法铺开"
            alert.informativeText = "请稍后再试，当前地毯会继续保留。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            NSLog("Desktop Mat material change: %@", error.localizedDescription)
        }
    }
}

@MainActor
private final class RugGalleryModel: ObservableObject {
    @Published var selected: RugStyle
    let previews: [RugStyle: NSImage]

    init(selected: RugStyle) {
        self.selected = selected
        previews = Dictionary(uniqueKeysWithValues: RugStyle.allCases.map { ($0, RugTextureFactory.preview(style: $0)) })
    }
}

private struct RugGalleryView: View {
    @ObservedObject var model: RugGalleryModel
    let select: (RugStyle) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("挑一张，铺在桌面。")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text("六种纹样，同一份柔软。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(RugStyle.allCases) { style in
                    Button { select(style) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Image(nsImage: model.previews[style] ?? NSImage())
                                .resizable().scaledToFit()
                                .padding(7)
                                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(model.selected == style ? Color.accentColor : Color.primary.opacity(0.10),
                                                lineWidth: model.selected == style ? 2 : 1)
                                }
                            HStack {
                                Text(style.displayName).font(.headline)
                                Spacer(minLength: 4)
                                if model.selected == style {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                            Text(style.detail).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(2).frame(height: 30, alignment: .topLeading)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("应用地毯：\(style.displayName)")
                    .accessibilityValue(model.selected == style ? "已选中" : "")
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("应用到所有屏幕，下次打开也会记得。")
                Text("切换纹样会保留当前位置与褶皱。")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(width: 660, height: 580)
    }
}
