import AppKit
import SwiftUI

private final class OffWorkReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class OffWorkReminderController {
    private let panel: OffWorkReminderPanel

    init() {
        panel = OffWorkReminderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 116),
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
              message: String, onDismiss: @escaping () -> Void) {
        let bubbleSize = NSSize(width: 260, height: 116)
        let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let preferredX = edge == .left
            ? anchorFrame.maxX + 10
            : anchorFrame.minX - bubbleSize.width - 10
        let preferredY = anchorFrame.midY - bubbleSize.height / 2
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - bubbleSize.width)
        let y = min(max(preferredY, visibleFrame.minY), visibleFrame.maxY - bubbleSize.height)

        panel.contentView = NSHostingView(
            rootView: OffWorkReminderView(
                message: message,
                arrowOnLeading: edge == .left,
                onDismiss: onDismiss
            )
        )
        panel.setFrame(
            NSRect(origin: NSPoint(x: x, y: y), size: bubbleSize),
            display: true,
            animate: false
        )
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel.orderOut(nil)
    }
}

private struct OffWorkReminderView: View {
    let message: String
    let arrowOnLeading: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭提醒")
            }

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("知道了", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.leading, arrowOnLeading ? 20 : 12)
        .padding(.trailing, arrowOnLeading ? 12 : 20)
        .padding(.vertical, 12)
        .frame(width: 260, height: 116)
        .background(
            ReminderBubbleShape(arrowOnLeading: arrowOnLeading)
                .fill(.regularMaterial)
        )
        .overlay {
            ReminderBubbleShape(arrowOnLeading: arrowOnLeading)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct ReminderBubbleShape: Shape {
    let arrowOnLeading: Bool

    func path(in rect: CGRect) -> Path {
        let arrowWidth: CGFloat = 10
        let bodyRect = arrowOnLeading
            ? rect.insetBy(dx: arrowWidth, dy: 0)
            : CGRect(x: rect.minX, y: rect.minY,
                     width: rect.width - arrowWidth, height: rect.height)
        let pointerY = rect.midY
        let pointerTipX = arrowOnLeading ? rect.minX : rect.maxX
        let pointerBaseX = arrowOnLeading ? bodyRect.minX : bodyRect.maxX
        var path = Path()

        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: 13, height: 13))
        path.move(to: CGPoint(x: pointerBaseX, y: pointerY - 8))
        path.addLine(to: CGPoint(x: pointerTipX, y: pointerY))
        path.addLine(to: CGPoint(x: pointerBaseX, y: pointerY + 8))
        path.closeSubpath()

        return path
    }
}
