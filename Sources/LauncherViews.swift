import AppKit
import SwiftUI

struct EdgeLauncherView: View {
    @ObservedObject var model: EdgeLauncherModel
    @ObservedObject var store: LauncherStore
    unowned let controller: EdgeLauncherController

    var body: some View {
        let onRight = model.edge == .right

        return ZStack(alignment: onRight ? .trailing : .leading) {
            if model.isMenuVisible {
                SemicircleMenu(
                    items: store.items,
                    radius: model.menuRadius,
                    iconSize: model.iconSize,
                    animationSpeed: model.animationSpeed,
                    onRight: onRight,
                    isExpanded: model.isExpanded,
                    isOffWorkReminder: model.isOffWorkReminder,
                    openSettings: controller.openSettings,
                    launch: controller.launch
                )
                EdgeDragHandle(
                    onRight: onRight,
                    onDrag: { controller.moveTrigger(to: NSEvent.mouseLocation) },
                    onDragEnded: controller.finishMovingTrigger
                )
                .zIndex(1)
                .allowsHitTesting(model.isExpanded)
            } else {
                EdgeTrigger(
                    onRight: onRight,
                    triggerMode: model.triggerMode,
                    action: controller.expand,
                    onDrag: { controller.moveTrigger(to: NSEvent.mouseLocation) },
                    onDragEnded: controller.finishMovingTrigger
                )
                    .transition(.opacity)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: onRight ? .trailing : .leading
        )
        .ignoresSafeArea()
    }
}

private struct EdgeTrigger: View {
    let onRight: Bool
    let triggerMode: LauncherTriggerMode
    let action: () -> Void
    let onDrag: () -> Void
    let onDragEnded: () -> Void
    @State private var isHovering = false

    var body: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .overlay {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.accentColor.opacity(0.65), radius: 5)
            }
            .frame(width: 16, height: 44)
            .scaleEffect(isHovering ? 1.06 : 1)
        .contentShape(Capsule())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if triggerMode == .click {
                action()
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in onDrag() }
                .onEnded { _ in onDragEnded() }
        )
        .help(triggerMode == .hover
              ? "Quick Start（悬浮展开，拖拽可调整位置）"
              : "Quick Start（点击展开，拖拽可调整位置）")
        .contextMenu {
            Button("退出 Quick Start", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
        .padding(onRight ? .trailing : .leading, 2)
    }
}

private struct EdgeDragHandle: View {
    let onRight: Bool
    let onDrag: () -> Void
    let onDragEnded: () -> Void
    @State private var isHovering = false

    var body: some View {
        Color.clear
            .frame(width: 20, height: 52)
            .overlay {
                if isHovering {
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 20, height: 52)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.45))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                }
                        )
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in onDrag() }
                    .onEnded { _ in onDragEnded() }
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .help("拖拽以移动 Quick Start")
            .padding(onRight ? .trailing : .leading, 2)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: onRight ? .trailing : .leading
            )
    }
}

private struct SemicircleMenu: View {
    let items: [LauncherItem]
    let radius: CGFloat
    let iconSize: CGFloat
    let animationSpeed: Double
    let onRight: Bool
    let isExpanded: Bool
    let isOffWorkReminder: Bool
    let openSettings: () -> Void
    let launch: (LauncherItem) -> Void
    @State private var revealed = false

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(
                x: onRight ? proxy.size.width - 34 : 34,
                y: proxy.size.height / 2
            )
            let count = max(items.count, 1)

            ZStack {
                if !isOffWorkReminder {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let target = point(for: index, count: count, center: center)

                        RadialItemButton(item: item, diameter: iconSize, selected: false) {
                            launch(item)
                        }
                        .position(target)
                        // Start beneath the settings button and fly out along the arc.
                        .offset(
                            x: revealed ? 0 : center.x - target.x,
                            y: revealed ? 0 : center.y - target.y
                        )
                        .scaleEffect(revealed ? 1 : 0.72)
                        .opacity(revealed ? 1 : 0)
                        .animation(
                            .spring(response: 0.34 / animationSpeed, dampingFraction: 0.8)
                                .delay(Double(index) * 0.045 / animationSpeed),
                            value: revealed
                        )
                    }
                }

                SettingsButton(
                    action: openSettings,
                    isOffWorkReminder: isOffWorkReminder
                )
                    .position(center)
                    // Let the settings button finish its return by leaving the
                    // expanded panel before the edge capsule takes its place.
                    .offset(x: isExpanded ? 0 : (onRight ? 60 : -60))
                    .animation(
                        isExpanded
                            ? .easeOut(duration: 0.18 / animationSpeed)
                            : .easeIn(duration: 0.18 / animationSpeed)
                                .delay(0.62 / animationSpeed),
                        value: isExpanded
                    )
            }
        }
        .onAppear { revealed = isExpanded }
        .onChange(of: isExpanded) { _, expanded in
            revealed = expanded
        }
    }

    private func point(for index: Int, count: Int, center: CGPoint) -> CGPoint {
        let angle = CGFloat(90) + (CGFloat(index) + 0.5) * 180 / CGFloat(count)
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + (onRight ? 1 : -1) * radius * cos(radians),
            y: center.y - radius * sin(radians)
        )
    }
}

struct FullCircleMenuView: View {
    @ObservedObject var model: FullMenuModel
    @ObservedObject var store: LauncherStore
    unowned let controller: FullMenuController

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = model.menuRadius
            let count = max(store.items.count, 1)

            ZStack {
                ZStack {
                    Circle().fill(Color.white.opacity(0.38))
                    Circle().fill(Color.black.opacity(0.14))
                    Circle().stroke(Color.white.opacity(0.28), lineWidth: 1)
                }
                    .frame(width: radius * 2 + 104, height: radius * 2 + 104)
                    .shadow(color: .black.opacity(0.24), radius: 24, y: 8)
                    .position(center)

                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                    let target = fullPoint(for: index, count: count, center: center, radius: radius)

                    RadialItemButton(item: item, diameter: model.iconSize,
                                     selected: item.id == model.selectedID) {
                        controller.launch(item)
                    }
                    .position(target)
                    .offset(
                        x: model.isVisible ? 0 : center.x - target.x,
                        y: model.isVisible ? 0 : center.y - target.y
                    )
                    .scaleEffect(model.isVisible ? 1 : 0.72)
                    .opacity(model.isVisible ? 1 : 0)
                    .animation(
                        .spring(response: 0.35 / model.animationSpeed, dampingFraction: 0.8)
                            .delay(Double(index) * 0.045 / model.animationSpeed),
                        value: model.isVisible
                    )
                }

                SettingsButton(
                    action: controller.openSettings,
                    isOffWorkReminder: model.isOffWorkReminder
                )
                    .position(center)
            }
        }
    }

    private func fullPoint(for index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = CGFloat(-90) + CGFloat(index) * 360 / CGFloat(count)
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + radius * cos(radians),
            y: center.y - radius * sin(radians)
        )
    }
}

private struct RadialItemButton: View {
    let item: LauncherItem
    let diameter: CGFloat
    let selected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(max(5, diameter * 0.12))
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Circle().stroke(
                                selected ? Color.accentColor : Color.white.opacity(0.3),
                                lineWidth: selected ? 3 : 1
                            )
                        }
                }
                .shadow(color: .black.opacity(0.28), radius: isHovering ? 12 : 6, y: 3)
                .scaleEffect(isHovering ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("\(item.kind.title)：\(item.name)")
        .accessibilityLabel(item.name)
    }
}

private struct SettingsButton: View {
    let action: () -> Void
    let isOffWorkReminder: Bool
    private let diameter: CGFloat = 52
    @State private var isHovering = false
    @State private var cursorLocation = CGPoint(x: 26, y: 26)
    @State private var isBlinking = false

    var body: some View {
        Button(action: action) {
            let size = CGSize(width: diameter, height: diameter)
            let leftEye = CGPoint(x: 18, y: 22)
            let rightEye = CGPoint(x: 34, y: 22)

            ZStack {
                if isOffWorkReminder {
                    SunglassesFace(diameter: diameter)
                } else {
                    Circle()
                        .fill(faceGradient)

                    ZStack {
                        faceEye(at: leftEye, in: size)
                        faceEye(at: rightEye, in: size)

                        SurprisedMouth()
                            .fill(Color.black)
                            .frame(width: 6, height: 5)
                            .position(x: 26, y: 34)
                            .opacity(isHovering ? 1 : 0)
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 8, height: 1.5)
                            .position(x: 26, y: 34)
                            .opacity(isHovering ? 0 : 1)
                    }
                    .offset(faceOffset)
                    .animation(.easeOut(duration: 0.12), value: cursorLocation)
                    .animation(.easeOut(duration: 0.18), value: isHovering)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    cursorLocation = location
                case .ended:
                    isHovering = false
                    cursorLocation = CGPoint(x: diameter / 2, y: diameter / 2)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64.random(in: 2_500_000_000...5_500_000_000))
                } catch {
                    return
                }

                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.08)) {
                    isBlinking = true
                }

                do {
                    try await Task.sleep(nanoseconds: 120_000_000)
                } catch {
                    return
                }

                withAnimation(.easeInOut(duration: 0.08)) {
                    isBlinking = false
                }
            }
        }
        .help("打开 Quick Start 设置")
        .accessibilityLabel("打开 Quick Start 设置")
        .contextMenu {
            Button("退出 Quick Start", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
    }

    private var faceGradient: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 1.0, green: 0.84, blue: 0.34),
                Color(red: 1.0, green: 0.64, blue: 0.24)
            ],
            center: .center,
            startRadius: 2,
            endRadius: diameter * 0.62
        )
    }

    @ViewBuilder
    private func faceEye(at center: CGPoint, in size: CGSize) -> some View {
        if isBlinking {
            Capsule()
                .fill(Color.black)
                .frame(width: 6, height: 1)
                .position(center)
        } else {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 6, height: 6)
                    .opacity(isHovering ? 0 : 1)

                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                            .offset(pupilOffset(for: center))
                    }
                    .opacity(isHovering ? 1 : 0)
            }
            .position(center)
            .animation(.easeOut(duration: 0.18), value: isHovering)
        }
    }

    private func pupilOffset(for eye: CGPoint) -> CGSize {
        let dx = cursorLocation.x - eye.x
        let dy = cursorLocation.y - eye.y
        let distance = max(hypot(dx, dy), 0.001)
        let travel = min(2.0, distance * 0.16)

        return CGSize(
            width: dx / distance * travel,
            height: dy / distance * travel
        )
    }

    private var faceOffset: CGSize {
        guard isHovering else { return .zero }

        return CGSize(
            width: max(-3.2, min(3.2, (cursorLocation.x - diameter / 2) / (diameter / 2) * 3.2)),
            height: max(-3.2, min(3.2, (cursorLocation.y - diameter / 2) / (diameter / 2) * 3.2))
        )
    }
}

private struct SunglassesFace: View {
    let diameter: CGFloat

    var body: some View {
        Text("😎")
            .font(.system(size: diameter * 0.88))
            .lineLimit(1)
        .frame(width: diameter, height: diameter)
        .accessibilityLabel("下班提醒")
    }
}

private struct SurprisedMouth: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let curveHeight = rect.height * 0.52
        let controlOffset = rect.width * 0.32
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + curveHeight))
        path.addCurve(
            to: CGPoint(x: centerX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + curveHeight * 0.15),
            control2: CGPoint(x: centerX - controlOffset, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + curveHeight),
            control1: CGPoint(x: centerX + controlOffset, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + curveHeight * 0.15)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}
