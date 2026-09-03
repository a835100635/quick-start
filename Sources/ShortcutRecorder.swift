import AppKit
import Carbon.HIToolbox
import SwiftUI

final class ShortcutRecorderView: NSView {
    var shortcut: Shortcut = .none { didSet { needsDisplay = true } }
    var onCapture: ((Shortcut) -> Void)?

    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == UInt16(kVK_Escape), flags.isEmpty {
            stopRecording()
            return
        }
        if event.keyCode == UInt16(kVK_Delete), flags.isEmpty {
            shortcut = .none
            onCapture?(.none)
            stopRecording()
            return
        }
        guard let shortcut = Shortcut.from(event: event) else {
            NSSound.beep()
            return
        }

        self.shortcut = shortcut
        onCapture?(shortcut)
        stopRecording()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let border = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.12)
                     : NSColor.textBackgroundColor).setFill()
        border.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        border.lineWidth = isRecording ? 2 : 1
        border.stroke()

        let text = isRecording ? "请按下快捷键…" : shortcut.display
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: isRecording ? .regular : .medium),
            .foregroundColor: isRecording ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
            withAttributes: attributes
        )
    }

    private func stopRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }
}

struct ShortcutRecorderField: NSViewRepresentable {
    let shortcut: Shortcut
    let onChange: (Shortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.shortcut = shortcut
        view.onCapture = onChange
        return view
    }

    func updateNSView(_ view: ShortcutRecorderView, context: Context) {
        view.shortcut = shortcut
        view.onCapture = onChange
    }
}
