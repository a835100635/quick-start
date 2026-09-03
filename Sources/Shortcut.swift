import Carbon.HIToolbox
import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var display: String {
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
        default: return result + "key \(keyCode)"
        }
    }
}
