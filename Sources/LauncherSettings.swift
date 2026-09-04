import Carbon.HIToolbox
import Foundation
import ServiceManagement

enum LauncherEdge: String {
    case left
    case right
}

enum LauncherTriggerMode: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: Self { self }

    var title: String {
        switch self {
        case .hover:
            return "鼠标悬浮"
        case .click:
            return "鼠标点击"
        }
    }
}

struct ExpressionReminder: Codable, Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int
    var message: String

    init(id: UUID = UUID(), hour: Int, minute: Int, message: String) {
        self.id = id
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.message = message
    }

    var time: Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    var timeTitle: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func with(time: Date, message: String) -> ExpressionReminder {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return ExpressionReminder(
            id: id,
            hour: components.hour ?? hour,
            minute: components.minute ?? minute,
            message: message
        )
    }
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

    static var triggerMode: LauncherTriggerMode {
        get {
            LauncherTriggerMode(rawValue: defaults.string(forKey: "triggerMode") ?? "") ?? .hover
        }
        set { defaults.set(newValue.rawValue, forKey: "triggerMode") }
    }

    static var offWorkReminderEnabled: Bool {
        get { defaults.object(forKey: "offWorkReminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "offWorkReminderEnabled") }
    }

    static var offWorkReminderTime: Date {
        get {
            let calendar = Calendar.current
            let hour = defaults.object(forKey: "offWorkReminderHour") as? Int ?? 18
            let minute = defaults.object(forKey: "offWorkReminderMinute") as? Int ?? 0
            return calendar.date(
                bySettingHour: min(max(hour, 0), 23),
                minute: min(max(minute, 0), 59),
                second: 0,
                of: Date()
            ) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            defaults.set(components.hour ?? 18, forKey: "offWorkReminderHour")
            defaults.set(components.minute ?? 0, forKey: "offWorkReminderMinute")
        }
    }

    static var offWorkReminderMessage: String {
        get { defaults.string(forKey: "offWorkReminderMessage") ?? "6 点要下班了" }
        set { defaults.set(newValue, forKey: "offWorkReminderMessage") }
    }

    static var expressionReminders: [ExpressionReminder] {
        get {
            guard let data = defaults.data(forKey: "expressionReminders"),
                  let reminders = try? JSONDecoder().decode([ExpressionReminder].self, from: data)
            else {
                let legacyTime = Calendar.current.dateComponents([.hour, .minute], from: offWorkReminderTime)
                return [
                    ExpressionReminder(
                        hour: legacyTime.hour ?? 18,
                        minute: legacyTime.minute ?? 0,
                        message: offWorkReminderMessage
                    )
                ]
            }
            return reminders
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "expressionReminders")
        }
    }

    static var hasShownFirstLaunchGuide: Bool {
        get { defaults.bool(forKey: "hasShownFirstLaunchGuide") }
        set { defaults.set(newValue, forKey: "hasShownFirstLaunchGuide") }
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
