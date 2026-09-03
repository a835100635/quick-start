import AppKit
import SwiftUI

private final class FirstLaunchGuidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FirstLaunchGuideController {
    private let panel: FirstLaunchGuidePanel

    init() {
        panel = FirstLaunchGuidePanel(
            contentRect: NSRect(x: 0, y: 0, width: 286, height: 156),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = LauncherSettings.showOverFullScreen ? .statusBar : .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
    }

    func show(anchorFrame: NSRect, on screen: NSScreen, edge: LauncherEdge,
              triggerMode: LauncherTriggerMode) {
        let guideSize = NSSize(width: 286, height: 156)
        let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let preferredX = edge == .left
            ? anchorFrame.maxX + 10
            : anchorFrame.minX - guideSize.width - 10
        let preferredY = anchorFrame.midY - guideSize.height / 2
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - guideSize.width)
        let y = min(max(preferredY, visibleFrame.minY), visibleFrame.maxY - guideSize.height)

        panel.contentView = NSHostingView(
            rootView: FirstLaunchGuideView(
                edge: edge,
                triggerMode: triggerMode,
                onDismiss: { [weak self] in self?.dismiss() }
            )
        )
        panel.setFrame(
            NSRect(origin: NSPoint(x: x, y: y), size: guideSize),
            display: true,
            animate: false
        )
        panel.orderFrontRegardless()
        LauncherSettings.hasShownFirstLaunchGuide = true
    }

    func dismiss() {
        panel.orderOut(nil)
        LauncherSettings.hasShownFirstLaunchGuide = true
    }
}

private struct FirstLaunchGuideView: View {
    let edge: LauncherEdge
    let triggerMode: LauncherTriggerMode
    let onDismiss: () -> Void

    private var edgeTitle: String {
        edge == .left ? "左侧" : "右侧"
    }

    private var instruction: String {
        triggerMode == .hover
            ? "将鼠标移到胶囊上即可展开快捷菜单。"
            : "点击胶囊即可展开快捷菜单。"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                Text("Quick Start 已启动")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭引导")
            }

            HStack(alignment: .top, spacing: 10) {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 12, height: 42)
                    .shadow(color: Color.accentColor.opacity(0.45), radius: 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text("触发器在屏幕\(edgeTitle)边缘")
                        .font(.subheadline.weight(.semibold))
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Spacer()
                Button("知道了", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.leading, edge == .left ? 20 : 10)
        .padding(.trailing, edge == .left ? 10 : 20)
        .padding(.vertical, 14)
        .frame(width: 286, height: 156)
        .background(
            GuideBubbleShape(arrowOnLeading: edge == .left)
                .fill(.regularMaterial)
        )
        .overlay {
            GuideBubbleShape(arrowOnLeading: edge == .left)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct GuideBubbleShape: Shape {
    let arrowOnLeading: Bool

    func path(in rect: CGRect) -> Path {
        let arrowWidth: CGFloat = 10
        let bodyRect = arrowOnLeading
            ? rect.insetBy(dx: arrowWidth, dy: 0)
            : CGRect(x: rect.minX, y: rect.minY,
                     width: rect.width - arrowWidth, height: rect.height)
        let radius: CGFloat = 13
        let pointerY = rect.midY
        let pointerTipX = arrowOnLeading ? rect.minX : rect.maxX
        let pointerBaseX = arrowOnLeading ? bodyRect.minX : bodyRect.maxX

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: radius, height: radius))
        path.move(to: CGPoint(x: pointerBaseX, y: pointerY - 8))
        path.addLine(to: CGPoint(x: pointerTipX, y: pointerY))
        path.addLine(to: CGPoint(x: pointerBaseX, y: pointerY + 8))
        path.closeSubpath()
        return path
    }
}
