import AppKit
import HotKey

/// A user-configurable global shortcut: a key code plus modifier flags,
/// persisted as plain integers (Carbon key codes are stable across macOS
/// versions, unlike trying to persist `Key` itself).
struct RecordedShortcut: Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt

    var key: Key? { Key(carbonKeyCode: keyCode) }
    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    /// e.g. "⌃ + ⌥ + p" — same "+"-joined, lowercase-letter format the
    /// original hardcoded shortcut list used.
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append((Self.keyLabels[keyCode] ?? "?").lowercased())
        return parts.joined(separator: " + ")
    }

    /// Readable labels for the key codes a shortcut recorder will realistically
    /// see (letters, digits, arrows, common punctuation). Falls back to "?"
    /// for anything exotic rather than guessing.
    private static let keyLabels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    init(keyCode: UInt32, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    init(key: Key, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = key.carbonKeyCode
        self.modifierFlags = modifiers.rawValue
    }
}
