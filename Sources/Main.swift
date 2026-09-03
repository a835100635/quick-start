import AppKit

@main
enum QuickStartMain {
    /// NSApplication.delegate is unowned, so retain it for the process lifetime.
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
