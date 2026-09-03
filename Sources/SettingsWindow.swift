import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var onConfigurationChanged: (() -> Void)?
    private var onGlobalShortcutChanged: (() -> Void)?
    private var onClose: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 705),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Quick Start 设置"
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
        onClose: @escaping () -> Void
    ) {
        self.onConfigurationChanged = onConfigurationChanged
        self.onGlobalShortcutChanged = onGlobalShortcutChanged
        self.onClose = onClose
        window?.contentView = NSHostingView(
            rootView: SettingsView(
                store: .shared,
                onConfigurationChanged: { [weak self] in
                    self?.onConfigurationChanged?()
                },
                onGlobalShortcutChanged: { [weak self] in
                    self?.onGlobalShortcutChanged?()
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

    var body: some View {
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
        .padding(22)
        .frame(minWidth: 540, minHeight: 705)
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
