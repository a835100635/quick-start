import Carbon.HIToolbox
import Foundation
import ServiceManagement

enum LauncherEdge: String {
    case left
    case right
}

enum LauncherSettings {
    private static let defaults = UserDefaults.standard

    static var edge: LauncherEdge {
        get { LauncherEdge(rawValue: defaults.string(forKey: "edge") ?? "") ?? .left }
        set { defaults.set(newValue.rawValue, forKey: "edge") }
    }

    /// The trigger's centre as a proportion of the screen's usable vertical area.
    static var verticalPosition: Double {
        get {
            let value = defaults.object(forKey: "verticalPosition") as? Double ?? 0.5
            return min(max(value, 0), 1)
        }
        set { defaults.set(min(max(newValue, 0), 1), forKey: "verticalPosition") }
    }

    static var showOverFullScreen: Bool {
        get { defaults.object(forKey: "showOverFullScreen") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showOverFullScreen") }
    }

    static var menuRadius: Double {
        get {
            let value = defaults.double(forKey: "menuRadius")
            return (80...240).contains(value) ? value : 180
        }
        set { defaults.set(min(max(newValue, 80), 240), forKey: "menuRadius") }
    }

    static var iconSize: Double {
        get {
            let value = defaults.double(forKey: "iconSize")
            return (40...64).contains(value) ? value : 58
        }
        set { defaults.set(min(max(newValue, 40), 64), forKey: "iconSize") }
    }

    /// Multiplier: 0.5× is slower, 2× is faster.
    static var animationSpeed: Double {
        get {
            let value = defaults.double(forKey: "animationSpeed")
            return (0.5...2).contains(value) ? value : 1
        }
        set { defaults.set(min(max(newValue, 0.5), 2), forKey: "animationSpeed") }
    }

    static var expandWhileSettingsOpen: Bool {
        get { defaults.object(forKey: "expandWhileSettingsOpen") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "expandWhileSettingsOpen") }
    }

    static var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static var globalShortcut: Shortcut {
        get {
            guard let data = defaults.data(forKey: "globalShortcut"),
                  let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data)
            else {
                return Shortcut(keyCode: UInt32(kVK_Escape), modifiers: UInt32(shiftKey))
            }
            return shortcut
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "globalShortcut")
        }
    }
}
