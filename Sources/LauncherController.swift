import AppKit
import Carbon.HIToolbox
import SwiftUI

final class EdgeLauncherModel: ObservableObject {
    @Published var isExpanded = false
    /// Keeps the radial menu in the hierarchy while its icons return to centre.
    @Published var isMenuVisible = false
    @Published var isDragging = false
    @Published var revealTick = 0
    @Published var edge: LauncherEdge = LauncherSettings.edge
    @Published var triggerMode: LauncherTriggerMode = LauncherSettings.triggerMode
    @Published var menuRadius = CGFloat(LauncherSettings.menuRadius)
    @Published var iconSize = CGFloat(LauncherSettings.iconSize)
    @Published var animationSpeed = LauncherSettings.animationSpeed
}

final class FullMenuModel: ObservableObject {
    @Published var isVisible = false
    @Published var selectedID: UUID?
    @Published var menuRadius = CGFloat(LauncherSettings.menuRadius)
    @Published var iconSize = CGFloat(LauncherSettings.iconSize)
    @Published var animationSpeed = LauncherSettings.animationSpeed
}

final class EdgeLauncherController: NSObject {
    let displayID: CGDirectDisplayID
    let model = EdgeLauncherModel()
    weak var manager: LauncherManager?

    private let panel = LauncherPanel()
    private var collapseWork: DispatchWorkItem?
    private var keepsExpandedForSettings = false

    var triggerFrame: NSRect {
        panel.frame
    }

    private var screen: NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value == displayID
        }
    }

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        super.init()

        let container = LauncherContainerView()
        container.onPointerEntered = { [weak self] in self?.pointerEntered() }
        container.onPointerExited = { [weak self] in self?.pointerExited() }

        let hosting = LauncherHostingView(
            rootView: EdgeLauncherView(model: model, store: .shared, controller: self)
        )
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        panel.contentView = container
        layout(expanded: false)
        panel.orderFrontRegardless()
    }

    deinit {
        panel.orderOut(nil)
    }

    func layout() {
        layout(expanded: model.isMenuVisible)
    }

    func refreshLevel() {
        panel.applyLevel()
        panel.orderFrontRegardless()
    }

    func expand() {
        guard !model.isExpanded else { return }
        collapseWork?.cancel()
        manager?.edgeDidActivate(self)
        model.isMenuVisible = true
        layout(expanded: true)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.34 / LauncherSettings.animationSpeed,
                                  dampingFraction: 0.82)) {
                self.model.isExpanded = true
                self.model.revealTick &+= 1
            }
        }
    }

    func collapse() {
        guard model.isExpanded || model.isMenuVisible else { return }
        collapseWork?.cancel()
        withAnimation(.easeOut(duration: 0.18 / LauncherSettings.animationSpeed)) {
            model.isExpanded = false
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.isExpanded else { return }
            self.model.isMenuVisible = false
            self.layout(expanded: false)
        }
        collapseWork = work
        // Account for the staggered radial return before removing the menu view.
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.72 / LauncherSettings.animationSpeed,
            execute: work
        )
    }

    func openSettings() {
        manager?.showSettings()
    }

    func launch(_ item: LauncherItem) {
        item.open()
        manager?.dismissAll()
    }

    func moveTrigger(to point: CGPoint) {
        guard let screen else { return }
        model.isDragging = true
        let visibleFrame = screen.visibleFrame
        let centerY = min(max(point.y, visibleFrame.minY + 26), visibleFrame.maxY - 26)

        LauncherSettings.verticalPosition = (centerY - visibleFrame.minY) / visibleFrame.height
        LauncherSettings.edge = point.x >= screen.frame.midX ? .right : .left
        manager?.refresh()
    }

    func finishMovingTrigger() {
        model.isDragging = false
        collapse()
    }

    func setSettingsPreview(_ enabled: Bool) {
        guard keepsExpandedForSettings != enabled else { return }
        let wasKeepingExpandedForSettings = keepsExpandedForSettings
        keepsExpandedForSettings = enabled

        if enabled {
            expand()
        } else if wasKeepingExpandedForSettings || !panel.frame.contains(NSEvent.mouseLocation) {
            collapse()
        }
    }

    private func pointerEntered() {
        guard LauncherSettings.triggerMode == .hover else { return }
        collapseWork?.cancel()
        expand()
    }

    private func pointerExited() {
        guard model.isExpanded, !model.isDragging, !keepsExpandedForSettings else { return }
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.panel.frame.contains(NSEvent.mouseLocation) else { return }
            self.collapse()
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: work)
    }

    private func layout(expanded: Bool) {
        guard let screen else { return }
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let onRight = LauncherSettings.edge == .right
        model.edge = LauncherSettings.edge
        model.triggerMode = LauncherSettings.triggerMode
        model.menuRadius = CGFloat(LauncherSettings.menuRadius)
        model.iconSize = CGFloat(LauncherSettings.iconSize)
        model.animationSpeed = LauncherSettings.animationSpeed
        let centerY = visibleFrame.minY + visibleFrame.height * LauncherSettings.verticalPosition

        let frame: NSRect
        if expanded {
            let radius = CGFloat(LauncherSettings.menuRadius)
            let width = radius + 104
            let height = radius * 2 + 112
            let minimumY = visibleFrame.minY
            let maximumY = max(minimumY, visibleFrame.maxY - height)
            frame = NSRect(
                x: onRight ? fullFrame.maxX - width : fullFrame.minX,
                y: min(max(minimumY, centerY - height / 2), maximumY),
                width: width,
                height: height
            )
        } else {
            frame = NSRect(
                x: onRight ? fullFrame.maxX - 20 : fullFrame.minX,
                y: centerY - 26,
                width: 20,
                height: 52
            )
        }

        panel.setFrame(frame, display: true, animate: false)
    }
}

final class FullMenuController: NSObject {
    let model = FullMenuModel()
    weak var manager: LauncherManager?

    private let panel = LauncherPanel()
    private var keyMonitor: Any?
    private var outsideMonitor: Any?

    override init() {
        super.init()
        panel.contentView = LauncherHostingView(
            rootView: FullCircleMenuView(model: model, store: .shared, controller: self)
        )
    }

    deinit {
        removeMonitors()
        panel.orderOut(nil)
    }

    func toggle(on screen: NSScreen) {
        model.isVisible ? dismiss() : show(on: screen)
    }

    func show(on screen: NSScreen) {
        syncAppearance()
        let radius = model.menuRadius
        let size = radius * 2 + 140
        let frame = NSRect(
            x: screen.frame.midX - size / 2,
            y: screen.frame.midY - size / 2,
            width: size,
            height: size
        )

        panel.applyLevel()
        panel.setFrame(frame, display: true, animate: false)
        model.selectedID = LauncherStore.shared.items.first?.id
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            model.isVisible = true
        }
    }

    func dismiss() {
        guard model.isVisible else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            model.isVisible = false
        }
        removeMonitors()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, !self.model.isVisible else { return }
            self.panel.orderOut(nil)
            NSApp.deactivate()
        }
    }

    func openSettings() {
        dismiss()
        manager?.showSettings()
    }

    func launch(_ item: LauncherItem) {
        item.open()
        dismiss()
    }

    private func moveSelection(by offset: Int) {
        let items = LauncherStore.shared.items
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == model.selectedID } ?? 0
        let next = (current + offset + items.count) % items.count
        model.selectedID = items[next].id
    }

    private func launchSelection() {
        guard let id = model.selectedID,
              let item = LauncherStore.shared.items.first(where: { $0.id == id })
        else { return }
        launch(item)
    }

    private func installMonitors() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.isVisible, self.panel.isKeyWindow else { return event }

            switch Int(event.keyCode) {
            case kVK_Escape:
                self.dismiss()
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.launchSelection()
            case kVK_LeftArrow, kVK_UpArrow:
                self.moveSelection(by: -1)
            case kVK_RightArrow, kVK_DownArrow:
                self.moveSelection(by: 1)
            default:
                return event
            }
            return nil
        }

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.dismiss() }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        keyMonitor = nil
        outsideMonitor = nil
    }

    fileprivate func syncAppearance() {
        model.menuRadius = CGFloat(LauncherSettings.menuRadius)
        model.iconSize = CGFloat(LauncherSettings.iconSize)
        model.animationSpeed = LauncherSettings.animationSpeed
    }
}

final class LauncherManager {
    private var edgeLaunchers: [CGDirectDisplayID: EdgeLauncherController] = [:]
    private let fullMenu = FullMenuController()
    private let settingsWindow = SettingsWindowController()
    private var firstLaunchGuide: FirstLaunchGuideController?

    init() {
        fullMenu.manager = self
        rebuild()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }
        DispatchQueue.main.async { [weak self] in
            self?.showFirstLaunchGuideIfNeeded()
        }
    }

    func toggleFullMenu() {
        guard let screen = screenAtPointer() ?? NSScreen.main else { return }
        edgeLaunchers.values.forEach { $0.collapse() }
        fullMenu.toggle(on: screen)
    }

    func reloadGlobalShortcut() {
        HotKeys.shared.register { [weak self] in
            self?.toggleFullMenu()
        }
    }

    func edgeDidActivate(_ active: EdgeLauncherController) {
        fullMenu.dismiss()
        edgeLaunchers.values
            .filter { $0 !== active }
            .forEach { $0.collapse() }
    }

    func dismissAll() {
        edgeLaunchers.values.forEach {
            $0.setSettingsPreview(false)
            $0.collapse()
        }
        fullMenu.dismiss()
    }

    func showSettings() {
        dismissAll()
        settingsWindow.show(
            onConfigurationChanged: { [weak self] in self?.refresh() },
            onGlobalShortcutChanged: { [weak self] in self?.reloadGlobalShortcut() },
            onClose: { [weak self] in self?.refresh() }
        )
        syncSettingsPreview()
    }

    func refresh() {
        edgeLaunchers.values.forEach {
            $0.refreshLevel()
            $0.layout()
        }
        fullMenu.panelRefresh()
        syncSettingsPreview()
    }

    private func rebuild() {
        let liveDisplays = Set(NSScreen.screens.compactMap(displayID(for:)))
        edgeLaunchers.keys
            .filter { !liveDisplays.contains($0) }
            .forEach { edgeLaunchers.removeValue(forKey: $0) }

        for id in liveDisplays where edgeLaunchers[id] == nil {
            let controller = EdgeLauncherController(displayID: id)
            controller.manager = self
            edgeLaunchers[id] = controller
        }
        edgeLaunchers.values.forEach { $0.layout() }
    }

    private func screenAtPointer() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
    }

    private func syncSettingsPreview() {
        let previewDisplayID: CGDirectDisplayID?
        if settingsWindow.isShowing, LauncherSettings.expandWhileSettingsOpen,
           let screen = screenAtPointer() {
            previewDisplayID = displayID(for: screen)
        } else {
            previewDisplayID = nil
        }

        for (displayID, launcher) in edgeLaunchers {
            launcher.setSettingsPreview(displayID == previewDisplayID)
        }
    }

    private func showFirstLaunchGuideIfNeeded() {
        guard !LauncherSettings.hasShownFirstLaunchGuide,
              let screen = screenAtPointer() ?? NSScreen.main ?? NSScreen.screens.first,
              let displayID = displayID(for: screen),
              let launcher = edgeLaunchers[displayID]
        else { return }

        let guide = FirstLaunchGuideController()
        guide.show(
            anchorFrame: launcher.triggerFrame,
            on: screen,
            edge: LauncherSettings.edge,
            triggerMode: LauncherSettings.triggerMode
        )
        firstLaunchGuide = guide
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

private extension FullMenuController {
    func panelRefresh() {
        panel.applyLevel()
        syncAppearance()
    }
}
