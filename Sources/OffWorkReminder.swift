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
            contentRect: NSRect(x: 0, y: 0, width: 248, height: 92),
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
        let bubbleSize = NSSize(width: 248, height: 92)
        let gap: CGFloat = 12
        let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)

        let aboveY = anchorFrame.maxY + gap
        let belowY = anchorFrame.minY - bubbleSize.height - gap
        let canPlaceAbove = aboveY + bubbleSize.height <= visibleFrame.maxY
        let canPlaceBelow = belowY >= visibleFrame.minY

        let arrowEdge: ReminderBubbleShape.ArrowEdge
        let origin: NSPoint
        if canPlaceAbove {
            arrowEdge = .bottom
            origin = NSPoint(
                x: alignedX(anchor: anchorFrame, width: bubbleSize.width, edge: edge, visible: visibleFrame),
                y: aboveY
            )
        } else if canPlaceBelow {
            arrowEdge = .top
            origin = NSPoint(
                x: alignedX(anchor: anchorFrame, width: bubbleSize.width, edge: edge, visible: visibleFrame),
                y: belowY
            )
        } else {
            arrowEdge = edge == .left ? .leading : .trailing
            origin = NSPoint(
                x: edge == .left
                    ? min(anchorFrame.maxX + gap, visibleFrame.maxX - bubbleSize.width)
                    : max(anchorFrame.minX - bubbleSize.width - gap, visibleFrame.minX),
                y: min(max(anchorFrame.midY - bubbleSize.height / 2, visibleFrame.minY),
                       visibleFrame.maxY - bubbleSize.height)
            )
        }

        let x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - bubbleSize.width)
        let y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - bubbleSize.height)
        let arrowAlong: CGFloat
        switch arrowEdge {
        case .leading, .trailing:
            arrowAlong = bubbleSize.height / 2
        case .top, .bottom:
            arrowAlong = min(max(anchorFrame.midX - x, 24), bubbleSize.width - 24)
        }

        let hosting = LauncherHostingView(
            rootView: OffWorkReminderView(
                message: message,
                arrowEdge: arrowEdge,
                arrowAlong: arrowAlong,
                onDismiss: onDismiss
            )
        )
        hosting.frame = NSRect(origin: .zero, size: bubbleSize)
        panel.contentView = hosting
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

    private func alignedX(anchor: NSRect, width: CGFloat, edge: LauncherEdge, visible: NSRect) -> CGFloat {
        let preferred = edge == .right
            ? anchor.maxX - width + 6
            : anchor.minX - 6
        return min(max(preferred, visible.minX), visible.maxX - width)
    }
}

private struct OffWorkReminderView: View {
    let message: String
    let arrowEdge: ReminderBubbleShape.ArrowEdge
    let arrowAlong: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("关闭提醒")
            }

            HStack {
                Spacer()
                Button("知道了", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.leading, arrowEdge == .leading ? 20 : 12)
        .padding(.trailing, arrowEdge == .trailing ? 20 : 12)
        .padding(.top, arrowEdge == .top ? 20 : 12)
        .padding(.bottom, arrowEdge == .bottom ? 20 : 12)
        .frame(width: 248, height: 92)
        .background {
            ReminderBubbleShape(arrowEdge: arrowEdge, arrowAlong: arrowAlong)
                .fill(.regularMaterial)
        }
        .overlay {
            ReminderBubbleShape(arrowEdge: arrowEdge, arrowAlong: arrowAlong)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}

private struct ReminderBubbleShape: Shape {
    enum ArrowEdge {
        case leading, trailing, top, bottom
    }

    let arrowEdge: ArrowEdge
    let arrowAlong: CGFloat

    func path(in rect: CGRect) -> Path {
        let arrow: CGFloat = 10
        let bodyRect: CGRect
        let tip: CGPoint
        let baseA: CGPoint
        let baseB: CGPoint

        switch arrowEdge {
        case .leading:
            bodyRect = CGRect(
                x: rect.minX + arrow, y: rect.minY,
                width: rect.width - arrow, height: rect.height
            )
            let along = min(max(arrowAlong, 18), rect.height - 18)
            tip = CGPoint(x: rect.minX, y: along)
            baseA = CGPoint(x: bodyRect.minX, y: along - 8)
            baseB = CGPoint(x: bodyRect.minX, y: along + 8)
        case .trailing:
            bodyRect = CGRect(
                x: rect.minX, y: rect.minY,
                width: rect.width - arrow, height: rect.height
            )
            let along = min(max(arrowAlong, 18), rect.height - 18)
            tip = CGPoint(x: rect.maxX, y: along)
            baseA = CGPoint(x: bodyRect.maxX, y: along - 8)
            baseB = CGPoint(x: bodyRect.maxX, y: along + 8)
        case .top:
            bodyRect = CGRect(
                x: rect.minX, y: rect.minY + arrow,
                width: rect.width, height: rect.height - arrow
            )
            let along = min(max(arrowAlong, 18), rect.width - 18)
            tip = CGPoint(x: along, y: rect.minY)
            baseA = CGPoint(x: along - 8, y: bodyRect.minY)
            baseB = CGPoint(x: along + 8, y: bodyRect.minY)
        case .bottom:
            bodyRect = CGRect(
                x: rect.minX, y: rect.minY,
                width: rect.width, height: rect.height - arrow
            )
            let along = min(max(arrowAlong, 18), rect.width - 18)
            tip = CGPoint(x: along, y: rect.maxY)
            baseA = CGPoint(x: along - 8, y: bodyRect.maxY)
            baseB = CGPoint(x: along + 8, y: bodyRect.maxY)
        }

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: 13, height: 13))
        path.move(to: baseA)
        path.addLine(to: tip)
        path.addLine(to: baseB)
        path.closeSubpath()
        return path
    }
}
