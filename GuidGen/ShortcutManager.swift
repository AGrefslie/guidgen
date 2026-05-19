//
//  ShortcutManager.swift
//  GUIDGenerator
//
//  Manages global keyboard shortcuts using Carbon Event Manager
//

import Foundation
import Carbon
import AppKit
import Combine

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    private var eventHotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    @Published var isEnabled: Bool = false

    private init() {
        setupEventHandler()
        // Defer publish-causing work past current run loop so we don't mutate
        // @Published state while a SwiftUI view is still in its update phase.
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            self?.loadAndRegisterShortcut()
        }
    }

    deinit {
        unregisterHotKey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    /// Register a new global hotkey
    func registerHotKey(keyCode: UInt16, modifiers: UInt32) -> Bool {
        // Unregister existing hotkey
        unregisterHotKey()

        // Convert Carbon modifiers to EventHotKeyModifier format
        var carbonModifiers: UInt32 = 0

        if modifiers & UInt32(cmdKey) != 0 {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers & UInt32(optionKey) != 0 {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers & UInt32(controlKey) != 0 {
            carbonModifiers |= UInt32(controlKey)
        }
        if modifiers & UInt32(shiftKey) != 0 {
            carbonModifiers |= UInt32(shiftKey)
        }

        // Create hotkey ID
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("GUID".fourCharCodeValue)
        hotKeyID.id = 1

        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            eventHotKey = ref
            isEnabled = true

            // Save to preferences
            UserPreferences.shared.shortcutKeyCode = keyCode
            UserPreferences.shared.shortcutModifiers = modifiers

            return true
        }

        return false
    }

    /// Unregister the current hotkey
    func unregisterHotKey() {
        if let hotKey = eventHotKey {
            UnregisterEventHotKey(hotKey)
            eventHotKey = nil
            isEnabled = false
        }
    }

    /// Clear saved shortcut
    func clearShortcut() {
        unregisterHotKey()
        UserPreferences.shared.shortcutKeyCode = nil
        UserPreferences.shared.shortcutModifiers = nil
    }

    /// Load and register shortcut from preferences
    private func loadAndRegisterShortcut() {
        guard let keyCode = UserPreferences.shared.shortcutKeyCode,
              let modifiers = UserPreferences.shared.shortcutModifiers else {
            return
        }

        registerHotKey(keyCode: keyCode, modifiers: modifiers)
    }

    /// Setup Carbon event handler for hotkey events
    private func setupEventHandler() {
        var eventTypes = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]

        let handler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            // When hotkey is pressed, generate and paste GUID using current prefs
            GUIDGenerator.shared.generateAndPaste()
            return noErr
        }

        InstallEventHandler(GetEventDispatcherTarget(), handler, 1, &eventTypes, nil, &eventHandler)
    }

    /// Validate that a shortcut doesn't conflict with common system shortcuts
    func isValidShortcut(keyCode: UInt16, modifiers: UInt32) -> (isValid: Bool, reason: String?) {
        // Check if at least one modifier is pressed
        let hasModifier = modifiers & UInt32(cmdKey | optionKey | controlKey) != 0

        if !hasModifier {
            return (false, "Shortcut must include at least Cmd, Option, or Control")
        }

        // Check for conflicts with common system shortcuts
        let conflictingShortcuts: [(keyCode: UInt16, modifiers: UInt32, name: String)] = [
            (0x06, UInt32(cmdKey), "Cmd+Z (Undo)"),
            (0x07, UInt32(cmdKey), "Cmd+X (Cut)"),
            (0x08, UInt32(cmdKey), "Cmd+C (Copy)"),
            (0x09, UInt32(cmdKey), "Cmd+V (Paste)"),
            (0x00, UInt32(cmdKey), "Cmd+A (Select All)"),
            (0x0D, UInt32(cmdKey), "Cmd+W (Close Window)"),
            (0x0C, UInt32(cmdKey), "Cmd+Q (Quit)"),
            (0x31, UInt32(cmdKey), "Cmd+Space (Spotlight)"),
            (0x30, UInt32(cmdKey), "Cmd+Tab (App Switcher)"),
        ]

        for conflict in conflictingShortcuts {
            if conflict.keyCode == keyCode && conflict.modifiers == modifiers {
                return (false, "Conflicts with system shortcut: \(conflict.name)")
            }
        }

        return (true, nil)
    }
}

// Helper extension to convert String to FourCharCode
extension String {
    var fourCharCodeValue: Int {
        var result: Int = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { bytes in
                for i in 0..<min(4, data.count) {
                    result = result << 8 + Int(bytes[i])
                }
            }
        }
        return result
    }
}
