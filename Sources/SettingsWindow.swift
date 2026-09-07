import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var onConfigurationChanged: (() -> Void)?
    private var onGlobalShortcutChanged: (() -> Void)?
    private var onOffWorkReminderPreview: ((String) -> Void)?
    private var onClose: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Start 设置"
        window.minSize = NSSize(width: 900, height: 650)
        window.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
                : NSColor(calibratedRed: 0.995, green: 0.997, blue: 1.0, alpha: 1)
        }
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    var isShowing: Bool {
        window?.isVisible ?? false
    }

    func show(
        onConfigurationChanged: @escaping () -> Void,
        onGlobalShortcutChanged: @escaping () -> Void,
        onOffWorkReminderPreview: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onConfigurationChanged = onConfigurationChanged
        self.onGlobalShortcutChanged = onGlobalShortcutChanged
        self.onOffWorkReminderPreview = onOffWorkReminderPreview
        self.onClose = onClose
        window?.contentView = NSHostingView(
            rootView: LoopReminderSettingsView(
                store: .shared,
                onConfigurationChanged: { [weak self] in
                    self?.onConfigurationChanged?()
                },
                onGlobalShortcutChanged: { [weak self] in
                    self?.onGlobalShortcutChanged?()
                },
                onOffWorkReminderPreview: { [weak self] message in
                    self?.onOffWorkReminderPreview?(message)
                }
            )
        )
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.onClose?()
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var store: LauncherStore
    let onConfigurationChanged: () -> Void
    let onGlobalShortcutChanged: () -> Void
    @State private var showOverFullScreen = LauncherSettings.showOverFullScreen
    @State private var expandWhileSettingsOpen = LauncherSettings.expandWhileSettingsOpen
    @State private var triggerMode = LauncherSettings.triggerMode
    @State private var launchAtLogin = LauncherSettings.launchAtLogin
    @State private var menuRadius = LauncherSettings.menuRadius
    @State private var iconSize = LauncherSettings.iconSize
    @State private var animationSpeed = LauncherSettings.animationSpeed
    @State private var globalShortcut = LauncherSettings.globalShortcut
    @State private var offWorkReminderEnabled = LauncherSettings.offWorkReminderEnabled
    @State private var expressionReminders = LauncherSettings.expressionReminders
    @State private var editingReminder: ExpressionReminder?
    @State private var isAddingReminder = false
    let onOffWorkReminderPreview: (String) -> Void

    var body: some View {
        TabView {
            launcherSettings
                .tabItem {
                    Label("快捷启动", systemImage: "square.grid.2x2")
                }

            expressionSettings
                .tabItem {
                    Label("表情", systemImage: "face.smiling")
                }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(minWidth: 540, minHeight: 760)
    }

    private var launcherSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("快捷启动")
                .font(.title2.weight(.semibold))

            Text("拖拽屏幕边缘触发器可上下移动，或拖到另一侧。半圆菜单最多显示 8 项。")
                .foregroundStyle(.secondary)

            List {
                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            Text(item.kind.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            store.move(item, by: -1)
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        .help("上移")
                        Button {
                            store.move(item, by: 1)
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == store.items.count - 1)
                        .help("下移")
                        Button(role: .destructive) {
                            store.remove(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("移除 \(item.name)")
                    }
                }
            }
            .frame(minHeight: 220)

            HStack {
                Button("添加应用…") { choose(.application) }
                Button("添加文件夹…") { choose(.folder) }
                Spacer()
                Text("\(store.items.count)/8")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle(
                "在全屏应用上显示",
                isOn: $showOverFullScreen
            )
            .onChange(of: showOverFullScreen) { _, isEnabled in
                LauncherSettings.showOverFullScreen = isEnabled
                onConfigurationChanged()
            }

            Toggle(
                "登录时启动 Quick Start",
                isOn: $launchAtLogin
            )
            .onChange(of: launchAtLogin) { _, isEnabled in
                do {
                    try LauncherSettings.setLaunchAtLogin(isEnabled)
                } catch {
                    NSLog("Quick Start: 登录项注册失败 — \(error.localizedDescription)")
                    launchAtLogin = LauncherSettings.launchAtLogin
                }
            }

            Toggle(
                "打开设置时展开快捷菜单",
                isOn: $expandWhileSettingsOpen
            )
            .onChange(of: expandWhileSettingsOpen) { _, isEnabled in
                LauncherSettings.expandWhileSettingsOpen = isEnabled
                onConfigurationChanged()
            }

            Picker("触发类型", selection: $triggerMode) {
                ForEach(LauncherTriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: triggerMode) { _, mode in
                LauncherSettings.triggerMode = mode
                onConfigurationChanged()
            }

            HStack {
                Text("菜单半径")
                Slider(
                    value: $menuRadius,
                    in: 80...240,
                    step: 5
                )
                Text("\(Int(menuRadius)) pt")
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            .onChange(of: menuRadius) { _, value in
                LauncherSettings.menuRadius = value
                onConfigurationChanged()
            }

            HStack {
                Text("快捷图标大小")
                Slider(
                    value: $iconSize,
                    in: 40...64,
                    step: 2
                )
                Text("\(Int(iconSize)) pt")
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            .onChange(of: iconSize) { _, value in
                LauncherSettings.iconSize = value
                onConfigurationChanged()
            }

            HStack {
                Text("动画速度")
                Slider(
                    value: $animationSpeed,
                    in: 0.5...2,
                    step: 0.1
                )
                Text(String(format: "%.1f×", animationSpeed))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
            .onChange(of: animationSpeed) { _, value in
                LauncherSettings.animationSpeed = value
                onConfigurationChanged()
            }

            HStack {
                Text("全局菜单快捷键")
                ShortcutRecorderField(shortcut: globalShortcut) { shortcut in
                    globalShortcut = shortcut
                    LauncherSettings.globalShortcut = shortcut
                    onGlobalShortcutChanged()
                }
                .frame(width: 150, height: 28)
                Text("点击后按下新组合键；按 ⌫ 清除")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Spacer()
                Button("退出 Quick Start", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private var expressionSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("表情提醒")
                .font(.title2.weight(.semibold))

            Text("达到提醒时间且鼠标未悬停在启动器上时，自动显示墨镜表情和提示气泡。每个时间点只能设置一条提醒。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("启用表情提醒", isOn: $offWorkReminderEnabled)
                .onChange(of: offWorkReminderEnabled) { _, isEnabled in
                    LauncherSettings.offWorkReminderEnabled = isEnabled
                    onConfigurationChanged()
                }

            List {
                ForEach(sortedExpressionReminders) { reminder in
                    HStack(spacing: 12) {
                        Text(reminder.timeTitle)
                            .font(.headline.monospacedDigit())
                            .frame(width: 48, alignment: .leading)

                        Text(reminder.message)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            onOffWorkReminderPreview(reminder.message)
                        } label: {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("预览提醒")

                        Button {
                            editingReminder = reminder
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("编辑提醒")

                        Button(role: .destructive) {
                            expressionReminders.removeAll { $0.id == reminder.id }
                            saveExpressionReminders()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("删除提醒")
                    }
                }
            }
            .frame(minHeight: 180)

            HStack {
                Button("添加提醒…") {
                    isAddingReminder = true
                }

                Spacer()

                Text("\(expressionReminders.count) 条提醒")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isAddingReminder) {
            ExpressionReminderEditor(
                title: "添加提醒",
                reminder: nextAvailableReminder,
                existingReminders: expressionReminders
            ) { reminder in
                expressionReminders.append(reminder)
                saveExpressionReminders()
                isAddingReminder = false
            }
        }
        .sheet(item: $editingReminder) { reminder in
            ExpressionReminderEditor(
                title: "编辑提醒",
                reminder: reminder,
                existingReminders: expressionReminders.filter { $0.id != reminder.id }
            ) { updatedReminder in
                guard let index = expressionReminders.firstIndex(where: {
                    $0.id == updatedReminder.id
                }) else { return }
                expressionReminders[index] = updatedReminder
                saveExpressionReminders()
                editingReminder = nil
            }
        }
    }

    private var sortedExpressionReminders: [ExpressionReminder] {
        expressionReminders.sorted {
            $0.hour == $1.hour ? $0.minute < $1.minute : $0.hour < $1.hour
        }
    }

    private var nextAvailableReminder: ExpressionReminder {
        let occupiedMinutes = Set(expressionReminders.map { $0.hour * 60 + $0.minute })
        let startingMinute = 9 * 60
        let availableMinute = (0..<(24 * 60))
            .map { (startingMinute + $0) % (24 * 60) }
            .first { !occupiedMinutes.contains($0) } ?? 0

        return ExpressionReminder(
            hour: availableMinute / 60,
            minute: availableMinute % 60,
            message: "该休息一下了"
        )
    }

    private func saveExpressionReminders() {
        expressionReminders = sortedExpressionReminders
        LauncherSettings.expressionReminders = expressionReminders
        onConfigurationChanged()
    }

    private func choose(_ kind: LauncherItemKind) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        switch kind {
        case .application:
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.applicationBundle]
            panel.message = "选择要启动的应用"
        case .folder:
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.message = "选择要打开的文件夹"
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.deletingPathExtension().lastPathComponent
        store.add(name: name, kind: kind, path: url.path)
    }
}

private struct ExpressionReminderEditor: View {
    let title: String
    let reminder: ExpressionReminder
    let existingReminders: [ExpressionReminder]
    let onSave: (ExpressionReminder) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var message: String

    init(title: String, reminder: ExpressionReminder,
         existingReminders: [ExpressionReminder],
         onSave: @escaping (ExpressionReminder) -> Void) {
        self.title = title
        self.reminder = reminder
        self.existingReminders = existingReminders
        self.onSave = onSave
        _time = State(initialValue: reminder.time)
        _message = State(initialValue: reminder.message)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            HStack {
                Text("提醒时间")
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            TextField("提醒文案", text: $message)
                .textFieldStyle(.roundedBorder)

            if hasTimeConflict {
                Text("该时间已存在提醒，请选择其他时间。")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                Button("保存") {
                    onSave(reminder.with(time: time, message: message.trimmingCharacters(in: .whitespaces)))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hasTimeConflict || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 360)
    }

    private var hasTimeConflict: Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return existingReminders.contains {
            $0.hour == components.hour && $0.minute == components.minute
        }
    }
}
