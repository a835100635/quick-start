import AppKit
import Carbon.HIToolbox
import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let none = Shortcut(keyCode: 0, modifiers: 0)
    var isSet: Bool { keyCode != 0 || modifiers != 0 }

    var display: String {
        guard isSet else { return "未设置" }
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }

        switch Int(keyCode) {
        case kVK_Space: return result + "空格"
        case kVK_Return: return result + "↩"
        case kVK_Escape: return result + "esc"
        case kVK_LeftArrow: return result + "←"
        case kVK_RightArrow: return result + "→"
        case kVK_UpArrow: return result + "↑"
        case kVK_DownArrow: return result + "↓"
        default: break
        }

        if let characters = Self.characters(for: keyCode) {
            return result + characters.uppercased()
        }
        return result + "key \(keyCode)"
    }

    static func from(event: NSEvent, allowingBareKey: Bool = false) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }

        guard modifiers != 0 || allowingBareKey else { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    private static func characters(for keyCode: UInt32) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let layout = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return -1
            }
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}
