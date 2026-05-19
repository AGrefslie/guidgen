//
//  UserPreferences.swift
//  GUIDGenerator
//
//  Manages user preferences and settings
//

import Foundation
import Combine
import Carbon

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var isUppercase: Bool {
        didSet {
            UserDefaults.standard.set(isUppercase, forKey: "isUppercase")
        }
    }

    @Published var version: GUIDVersion {
        didSet {
            UserDefaults.standard.set(version.rawValue, forKey: "guidVersion")
        }
    }

    @Published var format: GUIDFormat {
        didSet {
            UserDefaults.standard.set(format.rawValue, forKey: "guidFormat")
        }
    }

    @Published var shortcutKeyCode: UInt16? {
        didSet {
            if let keyCode = shortcutKeyCode {
                UserDefaults.standard.set(keyCode, forKey: "shortcutKeyCode")
            } else {
                UserDefaults.standard.removeObject(forKey: "shortcutKeyCode")
            }
        }
    }

    @Published var shortcutModifiers: UInt32? {
        didSet {
            if let modifiers = shortcutModifiers {
                UserDefaults.standard.set(modifiers, forKey: "shortcutModifiers")
            } else {
                UserDefaults.standard.removeObject(forKey: "shortcutModifiers")
            }
        }
    }

    private init() {
        // Load saved preferences
        self.isUppercase = UserDefaults.standard.object(forKey: "isUppercase") as? Bool ?? true

        let versionRaw = UserDefaults.standard.string(forKey: "guidVersion") ?? GUIDVersion.v4.rawValue
        self.version = GUIDVersion(rawValue: versionRaw) ?? .v4

        let formatRaw = UserDefaults.standard.string(forKey: "guidFormat") ?? GUIDFormat.standard.rawValue
        self.format = GUIDFormat(rawValue: formatRaw) ?? .standard

        if let keyCode = UserDefaults.standard.object(forKey: "shortcutKeyCode") as? UInt16 {
            self.shortcutKeyCode = keyCode
        }

        if let modifiers = UserDefaults.standard.object(forKey: "shortcutModifiers") as? UInt32 {
            self.shortcutModifiers = modifiers
        }
    }

    func hasShortcut() -> Bool {
        return shortcutKeyCode != nil && shortcutModifiers != nil
    }

    func getShortcutDescription() -> String {
        guard let keyCode = shortcutKeyCode, let modifiers = shortcutModifiers else {
            return "No shortcut set"
        }

        var description = ""

        // Check modifiers
        if modifiers & UInt32(cmdKey) != 0 {
            description += "⌘"
        }
        if modifiers & UInt32(optionKey) != 0 {
            description += "⌥"
        }
        if modifiers & UInt32(controlKey) != 0 {
            description += "⌃"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            description += "⇧"
        }

        // Add key
        if let key = keyCodeToString(keyCode) {
            description += key
        } else {
            description += "[\(keyCode)]"
        }

        return description
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`", 65: ".", 67: "*", 69: "+",
            71: "Clear", 75: "/", 76: "Enter", 78: "-", 81: "=", 82: "0",
            83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6", 89: "7",
            91: "8", 92: "9", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
            100: "F8", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15", 114: "F16", 115: "F17",
            116: "F18", 117: "F19", 118: "F4", 49: "Space",
            36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
            122: "F1", 120: "F2"
        ]

        return keyMap[keyCode]
    }
}
