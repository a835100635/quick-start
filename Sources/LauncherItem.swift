import AppKit
import Foundation

enum LauncherItemKind: String, Codable {
    case application
    case folder

    var title: String {
        switch self {
        case .application: return "应用"
        case .folder: return "文件夹"
        }
    }
}

struct LauncherItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: LauncherItemKind
    var path: String

    init(id: UUID = UUID(), name: String, kind: LauncherItemKind, path: String) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
    }

    var icon: NSImage {
        switch kind {
        case .application:
            return NSWorkspace.shared.icon(forFile: path)
        case .folder:
            return NSWorkspace.shared.icon(for: .folder)
        }
    }

    func open() {
        let url = URL(fileURLWithPath: path)
        switch kind {
        case .application:
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        case .folder:
            NSWorkspace.shared.open(url)
        }
    }
}

final class LauncherStore: ObservableObject {
    static let shared = LauncherStore()

    @Published private(set) var items: [LauncherItem] {
        didSet { persist() }
    }

    private let storageKey = "launcherItems"
    private let maximumItemCount = 8

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedItems = try? JSONDecoder().decode([LauncherItem].self, from: data) {
            items = savedItems
        } else {
            items = Self.defaultItems
        }
    }

    func add(name: String, kind: LauncherItemKind, path: String) {
        guard items.count < maximumItemCount else { return }
        items.append(LauncherItem(name: name, kind: kind, path: path))
    }

    func remove(_ item: LauncherItem) {
        items.removeAll { $0.id == item.id }
    }

    func move(_ item: LauncherItem, by offset: Int) {
        guard let index = items.firstIndex(of: item) else { return }
        let destination = index + offset
        guard items.indices.contains(destination) else { return }
        items.swapAt(index, destination)
    }

    private func persist() {
        let data = try? JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static let defaultItems = [
        LauncherItem(name: "Safari", kind: .application, path: "/System/Applications/Safari.app"),
        LauncherItem(name: "终端", kind: .application, path: "/System/Applications/Utilities/Terminal.app"),
        LauncherItem(name: "计算器", kind: .application, path: "/System/Applications/Calculator.app"),
        LauncherItem(name: "应用程序", kind: .folder, path: "/Applications")
    ]
}
