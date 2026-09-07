import AppKit
import SwiftUI

private enum LoopReminderPalette {
    // Use semantic AppKit colors so the custom settings UI follows macOS
    // appearance changes instead of rendering light backgrounds under dark text.
    static let content = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .underPageBackgroundColor)
    static let sidebarSelection = Color(nsColor: .selectedControlColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let selectedCard = Color.accentColor.opacity(0.12)
    static let selectedBorder = Color.accentColor.opacity(0.8)
    static let neutralButton = Color(nsColor: .controlColor)
    static let greenButton = Color.green.opacity(0.12)
}

private enum UpdateCheckState {
    case idle
    case checking
    case upToDate
    case available(version: String, releaseURL: URL, downloadURL: URL)
    case downloading(version: String)
    case installing(version: String)
    case failed(String)
}

private extension UpdateCheckState {
    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }
}

private enum UpdateCheckError: LocalizedError {
    case invalidResponse(statusCode: Int)
    case releaseUnavailable
    case invalidReleaseURL
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode):
            return "更新服务器返回了错误（HTTP \(statusCode)）"
        case .releaseUnavailable:
            return "暂时没有可用的正式版本"
        case .invalidReleaseURL:
            return "无法识别最新版本信息"
        case .rateLimited:
            return "更新服务请求过于频繁，请稍后重试"
        }
    }
}

private enum LoopReminderSection: String, CaseIterable, Identifiable {
    case timers
    case appearance
    case animation
    case basic
    case updates
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .basic: return "设置快捷应用"
        case .animation: return "图标大小和动画"
        case .appearance: return "触发方式"
        case .timers: return "计时器"
        case .updates: return "检查更新"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .timers: return "bell.fill"
        case .appearance: return "paintbrush.fill"
        case .animation: return "wand.and.stars"
        case .basic: return "gearshape.fill"
        case .updates: return "arrow.down.circle"
        case .about: return "info.circle.fill"
        }
    }
}

private final class WheelIntervalState: ObservableObject {
    var isHovering = false
}

private struct WheelAdjustingStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let labelWidth: CGFloat
    @StateObject private var state = WheelIntervalState()
    @State private var scrollMonitor: Any?

    var body: some View {
        Stepper(value: $value, in: range, step: 1) {
            Text("\(value) 分钟")
                .frame(width: labelWidth, alignment: .leading)
        }
        .controlSize(.large)
        .onHover { state.isHovering = $0 }
        .onAppear {
            let binding = $value
            let range = range
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard state.isHovering, event.scrollingDeltaY != 0 else {
                    return event
                }

                let direction = event.scrollingDeltaY > 0 ? 1 : -1
                binding.wrappedValue = min(
                    max(binding.wrappedValue + direction, range.lowerBound),
                    range.upperBound
                )
                return nil
            }
        }
        .onDisappear {
            if let scrollMonitor {
                NSEvent.removeMonitor(scrollMonitor)
            }
            scrollMonitor = nil
        }
    }
}

struct LoopReminderSettingsView: View {
    @ObservedObject var store: LauncherStore
    let onConfigurationChanged: () -> Void
    let onGlobalShortcutChanged: () -> Void
    let onOffWorkReminderPreview: (String) -> Void

    @State private var selectedSection: LoopReminderSection = .timers
    @State private var showOverFullScreen = LauncherSettings.showOverFullScreen
    @State private var expandWhileSettingsOpen = LauncherSettings.expandWhileSettingsOpen
    @State private var triggerMode = LauncherSettings.triggerMode
    @State private var launchAtLogin = LauncherSettings.launchAtLogin
    @State private var menuRadius = LauncherSettings.menuRadius
    @State private var iconSize = LauncherSettings.iconSize
    @State private var animationSpeed = LauncherSettings.animationSpeed
    @State private var globalShortcut = LauncherSettings.globalShortcut
    @State private var offWorkReminderEnabled = LauncherSettings.offWorkReminderEnabled
    @State private var notificationPauseDuration = LauncherSettings.notificationPauseDuration
    @State private var expressionReminders = LauncherSettings.expressionReminders
    @State private var editingReminder: ExpressionReminder?
    @State private var isAddingReminder = false
    @State private var updateState: UpdateCheckState = .idle

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .background(LoopReminderPalette.content)
        .frame(minWidth: 980, minHeight: 720)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading, 24)
                .padding(.top, 26)
                .padding(.bottom, 16)

            VStack(spacing: 4) {
                ForEach(LoopReminderSection.allCases) { section in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selectedSection = section
                        }
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .font(.system(size: 15, weight: selectedSection == section ? .semibold : .regular))
                            .foregroundStyle(selectedSection == section ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(selectedSection == section
                                          ? LoopReminderPalette.sidebarSelection
                                          : .clear)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
            }

            Spacer()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("退出 Quick Start", systemImage: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .padding(.leading, 24)
            .padding(.bottom, 22)
        }
        .frame(width: 238)
        .background(LoopReminderPalette.sidebar)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .timers:
            timerSettings
        case .appearance:
            appearanceSettings
        case .animation:
            animationSettings
        case .basic:
            basicSettings
        case .updates:
            updateSettings
        case .about:
            informationalPage(
                icon: "info.circle.fill",
                title: "关于",
                subtitle: "简单、可靠的桌面提醒工具"
            ) {
                VStack(spacing: 10) {
                    Text("Quick Start")
                        .font(.title3.weight(.semibold))
                    Text("版本 1.0.6")
                        .foregroundStyle(.secondary)
                    Text("让每一次休息都刚刚好。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
    }

    private var updateSettings: some View {
        settingsPage(
            icon: "arrow.down.circle",
            title: "检查更新",
            subtitle: "保持 Quick Start 为最新版本"
        ) {
            VStack(spacing: 18) {
                updateStatusIcon
                    .font(.system(size: 42))

                Text(updateStatusTitle)
                    .font(.headline)

                Text("当前版本 \(currentVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if case .available(let version, _, _) = updateState {
                    Text("发现新版本 \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                if case .failed(let message) = updateState {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await checkForUpdates() }
                    } label: {
                        Label(
                            updateState.isChecking ? "检查中…" : "检查更新",
                            systemImage: updateState.isChecking
                                ? "arrow.triangle.2.circlepath"
                                : "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateState.isChecking)

                    if case .available(let version, let releaseURL, let downloadURL) = updateState {
                        Button {
                            Task {
                                await downloadUpdate(
                                    version: version,
                                    from: downloadURL
                                )
                            }
                        } label: {
                            Label("下载更新", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("打开发布页") {
                            NSWorkspace.shared.open(releaseURL)
                        }
                        .buttonStyle(.bordered)
                    } else if case .downloading = updateState {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在下载更新…")
                            .foregroundStyle(.secondary)
                    } else if case .installing = updateState {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在安装并重启…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        }
        .task {
            guard case .idle = updateState else { return }
            await checkForUpdates()
        }
    }

    @ViewBuilder
    private var updateStatusIcon: some View {
        switch updateState {
        case .idle:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.blue)
        case .checking:
            ProgressView()
                .controlSize(.large)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .downloading:
            ProgressView()
                .controlSize(.large)
        case .installing:
            ProgressView()
                .controlSize(.large)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var updateStatusTitle: String {
        switch updateState {
        case .idle:
            return "准备检查更新"
        case .checking:
            return "正在检查更新…"
        case .upToDate:
            return "当前已是最新版本"
        case .available:
            return "发现新版本"
        case .downloading:
            return "正在下载更新…"
        case .installing:
            return "正在安装并重启…"
        case .failed:
            return "检查更新失败"
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.6"
    }

    private func checkForUpdates() async {
        updateState = .checking

        do {
            var request = URLRequest(
                url: URL(string: "https://github.com/a835100635/quick-start/releases/latest")!
            )
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("text/html", forHTTPHeaderField: "Accept")
            request.setValue("QuickStart/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse
            else {
                throw UpdateCheckError.invalidReleaseURL
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 403 {
                    throw UpdateCheckError.rateLimited
                }
                throw UpdateCheckError.invalidResponse(statusCode: httpResponse.statusCode)
            }

            guard let releaseURL = httpResponse.url,
                  let tagName = latestReleaseTag(from: releaseURL)
            else {
                throw UpdateCheckError.invalidReleaseURL
            }

            let latestVersion = normalizedVersion(tagName)
            if isVersion(latestVersion, newerThan: normalizedVersion(currentVersion)) {
                guard let downloadURL = releaseDownloadURL(for: tagName, version: latestVersion) else {
                    throw UpdateCheckError.releaseUnavailable
                }
                updateState = .available(
                    version: latestVersion,
                    releaseURL: releaseURL,
                    downloadURL: downloadURL
                )
            } else {
                updateState = .upToDate
            }
        } catch {
            updateState = .failed(error.localizedDescription)
        }
    }

    private func downloadUpdate(version: String, from url: URL) async {
        updateState = .downloading(version: version)

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 120
            request.setValue("QuickStart/\(currentVersion)", forHTTPHeaderField: "User-Agent")

            let (temporaryURL, response) = try await URLSession.shared.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw UpdateCheckError.invalidResponse(statusCode: statusCode)
            }

            let downloadsDirectory = FileManager.default.urls(
                for: .downloadsDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            let destinationURL = downloadsDirectory.appendingPathComponent(
                "QuickStart-\(version).dmg"
            )

            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            updateState = .installing(version: version)
            try launchUpdater(with: destinationURL)
        } catch {
            updateState = .failed("更新下载失败：\(error.localizedDescription)")
        }
    }

    private func launchUpdater(with diskImageURL: URL) throws {
        let updaterURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("quick-start-updater-\(UUID().uuidString).sh")
        let targetAppPath = Bundle.main.bundlePath
        let script = """
        #!/bin/bash
        set -e

        DMG="$1"
        TARGET="$2"
        ATTACH_OUTPUT="$(/usr/bin/hdiutil attach -nobrowse -readonly "$DMG")"
        MOUNT="$(printf '%s\\n' "$ATTACH_OUTPUT" | /usr/bin/awk '$0 ~ /\\/Volumes\\// { sub(/^.*(\\/Volumes\\/)/, "/Volumes/"); print; exit }')"
        SOURCE="$MOUNT/QuickStart.app"

        for attempt in $(/usr/bin/seq 1 40); do
            if ! /usr/bin/pgrep -x QuickStart >/dev/null 2>&1; then
                break
            fi
            /bin/sleep 0.25
        done

        /bin/rm -rf "$TARGET"
        /usr/bin/ditto "$SOURCE" "$TARGET"
        /usr/bin/hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
        /bin/rm -f "$DMG" "$0"
        /usr/bin/open "$TARGET"
        """

        try script.write(to: updaterURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: updaterURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [updaterURL.path, diskImageURL.path, targetAppPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApp.terminate(nil)
        }
    }

    private func latestReleaseTag(from url: URL) -> String? {
        let pathComponents = url.pathComponents
        guard let tagIndex = pathComponents.firstIndex(of: "tag"),
              pathComponents.index(after: tagIndex) < pathComponents.endIndex
        else {
            return nil
        }

        let tag = pathComponents[pathComponents.index(after: tagIndex)]
        let isVersionTag = tag.range(
            of: #"^v?[0-9]+(\.[0-9]+){2}$"#,
            options: .regularExpression
        ) != nil
        return isVersionTag ? tag : nil
    }

    private func releaseDownloadURL(for tag: String, version: String) -> URL? {
        URL(
            string: "https://github.com/a835100635/quick-start/releases/download/\(tag)/QuickStart-\(version).dmg"
        )
    }

    private func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }

    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let count = max(candidateParts.count, currentParts.count)

        for index in 0..<count {
            let candidatePart = index < candidateParts.count ? candidateParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    private var timerSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageHeader(icon: "bell.fill", title: "计时器管理", subtitle: "管理您的循环提醒计时器")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                        .font(.system(size: 17, weight: .semibold))
                    Text("通知停留时间")
                        .font(.headline)
                    Slider(value: $notificationPauseDuration, in: 1...10, step: 0.5)
                        .tint(.orange)
                        .padding(.leading, 12)
                    Text(String(format: "%.1f 秒", notificationPauseDuration))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.orange)
                        .frame(width: 65, alignment: .trailing)
                }

                Text("通知显示后停留的时间，最大为下次通知时间-过渡动画时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
            .padding(.bottom, 22)
            .onChange(of: notificationPauseDuration) { _, value in
                LauncherSettings.notificationPauseDuration = value
            }

            HStack(spacing: 12) {
                Button {
                    offWorkReminderEnabled.toggle()
                    LauncherSettings.offWorkReminderEnabled = offWorkReminderEnabled
                    onConfigurationChanged()
                } label: {
                    Label(
                        offWorkReminderEnabled ? "全部暂停" : "全部启动",
                        systemImage: offWorkReminderEnabled ? "pause.fill" : "play.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(LoopReminderPalette.greenButton, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    isAddingReminder = true
                } label: {
                    Label("添加新计时器", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(LoopReminderPalette.neutralButton, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(sortedExpressionReminders.enumerated()), id: \.element.id) { index, reminder in
                        timerRow(reminder, index: index)
                    }
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("计时器颜色会优先于全局配置")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 14)

            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("当前有 \(expressionReminders.count) 个计时器，过多的计时器可能增加心智负担，建议精简使用")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 7)
        }
        .padding(.horizontal, 26)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .sheet(isPresented: $isAddingReminder) {
            LoopReminderEditor(
                title: "添加计时器",
                reminder: nextAvailableReminder,
                existingReminders: expressionReminders
            ) { reminder in
                expressionReminders.append(reminder)
                saveExpressionReminders()
                isAddingReminder = false
            }
        }
        .sheet(item: $editingReminder) { reminder in
            LoopReminderEditor(
                title: "编辑计时器",
                reminder: reminder,
                existingReminders: expressionReminders.filter { $0.id != reminder.id }
            ) { updatedReminder in
                guard let index = expressionReminders.firstIndex(where: { $0.id == updatedReminder.id }) else {
                    return
                }
                expressionReminders[index] = updatedReminder
                saveExpressionReminders()
                editingReminder = nil
            }
        }
    }

    private func timerRow(_ reminder: ExpressionReminder, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(reminder.icon)
                .font(.system(size: 25))
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 5) {
                Text(timerTitle(for: reminder, index: index))
                    .font(.headline)
                Text(timerSubtitle(for: reminder))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onOffWorkReminderPreview(reminder.message)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.green, in: Circle())
            }
            .buttonStyle(.plain)
            .help("预览提醒")

            Button {
                editingReminder = reminder
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
            .help("编辑计时器")
        }
        .padding(.horizontal, 15)
        .frame(height: 70)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(index == 0 ? LoopReminderPalette.selectedCard : LoopReminderPalette.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(index == 0 ? LoopReminderPalette.selectedBorder : Color.clear, lineWidth: 2)
                }
        }
        .contextMenu {
            Button("删除计时器", role: .destructive) {
                expressionReminders.removeAll { $0.id == reminder.id }
                saveExpressionReminders()
            }
        }
    }

    private var appearanceSettings: some View {
        settingsPage(icon: "paintbrush.fill", title: "通用外观", subtitle: "调整窗口和通知的显示方式") {
            Toggle("在全屏应用上显示", isOn: $showOverFullScreen)
                .onChange(of: showOverFullScreen) { _, value in
                    LauncherSettings.showOverFullScreen = value
                    onConfigurationChanged()
                }

            Picker("触发类型", selection: $triggerMode) {
                ForEach(LauncherTriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: triggerMode) { _, value in
                LauncherSettings.triggerMode = value
                onConfigurationChanged()
            }
        }
    }

    private var animationSettings: some View {
        settingsPage(icon: "wand.and.stars", title: "动画和定位", subtitle: "调整快捷菜单的大小、位置和动画") {
            Toggle("打开设置时展开快捷菜单", isOn: $expandWhileSettingsOpen)
                .onChange(of: expandWhileSettingsOpen) { _, value in
                    LauncherSettings.expandWhileSettingsOpen = value
                    onConfigurationChanged()
                }
            sliderRow("菜单半径", value: $menuRadius, range: 80...240, step: 5, suffix: " pt") {
                LauncherSettings.menuRadius = $0
                onConfigurationChanged()
            }
            sliderRow("快捷图标大小", value: $iconSize, range: 40...64, step: 2, suffix: " pt") {
                LauncherSettings.iconSize = $0
                onConfigurationChanged()
            }
            sliderRow("动画速度", value: $animationSpeed, range: 0.5...2, step: 0.1, suffix: "×") {
                LauncherSettings.animationSpeed = $0
                onConfigurationChanged()
            }
        }
    }

    private var basicSettings: some View {
        settingsPage(icon: "gearshape.fill", title: "基本设置", subtitle: "管理快捷启动项目和快捷键") {
            VStack(alignment: .leading, spacing: 10) {
                Text("快捷启动项目")
                    .font(.headline)

                ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                        Text(item.name)
                        Spacer()
                        Button { store.move(item, by: -1) } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == 0)
                        Button { store.move(item, by: 1) } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.borderless)
                        .disabled(index == store.items.count - 1)
                        Button(role: .destructive) { store.remove(item) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    Button("添加应用…") { choose(.application) }
                    Button("添加文件夹…") { choose(.folder) }
                    Spacer()
                    Text("\(store.items.count)/8")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("登录时启动 Quick Start", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, value in
                    do {
                        try LauncherSettings.setLaunchAtLogin(value)
                    } catch {
                        NSLog("Quick Start: 登录项注册失败 — \(error.localizedDescription)")
                        launchAtLogin = LauncherSettings.launchAtLogin
                    }
                }

            HStack {
                Text("全局菜单快捷键")
                Spacer()
                ShortcutRecorderField(shortcut: globalShortcut) { shortcut in
                    globalShortcut = shortcut
                    LauncherSettings.globalShortcut = shortcut
                    onGlobalShortcutChanged()
                }
                .frame(width: 150, height: 28)
            }

        }
    }

    private func pageHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 24)
    }

    private func settingsPage<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            pageHeader(icon: icon, title: title, subtitle: subtitle)
            VStack(alignment: .leading, spacing: 18, content: content)
                .padding(20)
                .background(LoopReminderPalette.card, in: RoundedRectangle(cornerRadius: 14))
            Spacer()
        }
        .padding(30)
    }

    private func informationalPage<Content: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsPage(icon: icon, title: title, subtitle: subtitle, content: content)
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .onChange(of: value.wrappedValue) { _, newValue in onChange(newValue) }
            Text("\(step < 1 ? String(format: "%.1f", value.wrappedValue) : String(format: "%.0f", value.wrappedValue))\(suffix)")
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)
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

    private func timerTitle(for reminder: ExpressionReminder, index: Int) -> String {
        let message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "新计时器" : message
    }

    private func timerSubtitle(for reminder: ExpressionReminder) -> String {
        switch reminder.schedule {
        case .fixed:
            return "[定点] 每天 \(reminder.timeTitle)"
        case .interval:
            return "[循环] \(reminder.intervalTitle)"
        }
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
        store.add(name: url.deletingPathExtension().lastPathComponent, kind: kind, path: url.path)
    }
}

private struct LoopReminderEditor: View {
    let title: String
    let reminder: ExpressionReminder
    let existingReminders: [ExpressionReminder]
    let onSave: (ExpressionReminder) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var message: String
    @State private var icon: String
    @State private var schedule: ExpressionReminderSchedule
    @State private var intervalMinutes: Int
    @FocusState private var focusedField: EditorField?

    private enum EditorField {
        case icon
        case message
    }

    init(
        title: String,
        reminder: ExpressionReminder,
        existingReminders: [ExpressionReminder],
        onSave: @escaping (ExpressionReminder) -> Void
    ) {
        self.title = title
        self.reminder = reminder
        self.existingReminders = existingReminders
        self.onSave = onSave
        _time = State(initialValue: reminder.time)
        _message = State(initialValue: reminder.message)
        _icon = State(initialValue: reminder.icon)
        _schedule = State(initialValue: reminder.schedule)
        _intervalMinutes = State(
            initialValue: max(1, Int((Double(reminder.intervalSeconds) / 60).rounded()))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            Picker("计时方式", selection: $schedule) {
                ForEach(ExpressionReminderSchedule.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if schedule == .fixed {
                HStack {
                    Text("提醒时间")
                    Spacer()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            } else {
                HStack {
                    Text("循环间隔")
                    Spacer()
                    WheelAdjustingStepper(
                        value: $intervalMinutes,
                        range: 1...(24 * 60),
                        labelWidth: 92
                    )
                }
            }

            HStack {
                Text("图标")
                TextField("💧", text: $icon)
                    .focused($focusedField, equals: .icon)
                    .frame(width: 68)
                    .multilineTextAlignment(.center)
                    .onChange(of: icon) { _, newValue in
                        guard !newValue.isEmpty else { return }
                        let selectedIcon = String(newValue.last!)
                        if icon != selectedIcon {
                            icon = selectedIcon
                        }
                        DispatchQueue.main.async {
                            closeCharacterPalette()
                        }
                    }
                Button {
                    focusedField = .icon
                    let editorWindow = NSApp.keyWindow
                    DispatchQueue.main.async {
                        NSApp.orderFrontCharacterPalette(nil)
                        positionCharacterPalette(beside: editorWindow)
                    }
                } label: {
                    Label("选择表情", systemImage: "face.smiling")
                }
                .buttonStyle(.bordered)
                Text("使用 macOS 自带表情")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("提醒文案", text: $message)
                .focused($focusedField, equals: .message)
                .textFieldStyle(.roundedBorder)
            if hasTimeConflict {
                Text("该时间已存在提醒，请选择其他时间。")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button("保存") {
                    onSave(reminder.with(
                        time: time,
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                        icon: normalizedIcon,
                        schedule: schedule,
                        intervalSeconds: intervalMinutes * 60
                    ))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(hasTimeConflict || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 360)
    }

    private var hasTimeConflict: Bool {
        guard schedule == .fixed else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return existingReminders.contains {
            $0.hour == components.hour && $0.minute == components.minute
        }
    }

    private var normalizedIcon: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ExpressionReminder.defaultIcon(for: message) : String(trimmed.prefix(1))
    }
}

private func positionCharacterPalette(beside editorWindow: NSWindow?) {
    guard let editorWindow else { return }

    func reposition() {
        guard let palette = NSApp.windows.first(where: isCharacterPalette) else { return }
        let screen = editorWindow.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let gap: CGFloat = 14
        let inset: CGFloat = 10
        let editorSize = editorWindow.frame.size
        let paletteSize = palette.frame.size

        guard editorSize.width + paletteSize.width + gap + inset * 2 <= visibleFrame.width else {
            return
        }

        let editorX = visibleFrame.minX + inset
        let editorY = min(
            max(editorWindow.frame.midY - editorSize.height / 2, visibleFrame.minY),
            visibleFrame.maxY - editorSize.height
        )
        editorWindow.setFrameOrigin(NSPoint(x: editorX, y: editorY))

        let paletteX = editorX + editorSize.width + gap
        let paletteY = min(
            max(editorY + (editorSize.height - paletteSize.height) / 2, visibleFrame.minY),
            visibleFrame.maxY - paletteSize.height
        )
        palette.setFrameOrigin(NSPoint(x: paletteX, y: paletteY))
    }

    reposition()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: reposition)
}

private func closeCharacterPalette() {
    NSApp.windows
        .filter(isCharacterPalette)
        .forEach { $0.orderOut(nil) }
}

private func isCharacterPalette(_ window: NSWindow) -> Bool {
    guard window.isVisible else { return false }
    let title = window.title.lowercased()
    if title.contains("character")
        || title.contains("emoji")
        || title.contains("表情")
        || title.contains("字符") {
        return true
    }

    return window.level == .floating
        && window.frame.width >= 450
        && window.frame.height >= 500
}
