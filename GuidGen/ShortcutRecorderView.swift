//
//  ShortcutRecorderView.swift
//  GUIDGenerator
//
//  View for capturing keyboard shortcuts from user
//

import SwiftUI
import Carbon
import Combine

struct CapturedShortcut: Equatable {
    let keyCode: UInt16
    let modifiers: UInt32
}

struct ShortcutRecorderView: View {
    @Binding var isRecording: Bool
    @ObservedObject var preferences = UserPreferences.shared
    @ObservedObject var shortcutManager = ShortcutManager.shared

    @State private var errorMessage: String?
    @StateObject private var keyMonitor = KeyboardMonitor()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Global Shortcut:")
                    .font(.headline)

                Spacer()

                if isRecording {
                    Text("Press key combination...")
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.blue, lineWidth: 2, antialiased: true)
                                )
                        )
                        .animation(.easeInOut(duration: 0.3), value: isRecording)
                } else {
                    Text(preferences.getShortcutDescription())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }

            HStack {
                Button(isRecording ? "Cancel" : "Set Shortcut") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .keyboardShortcut(.defaultAction)

                if preferences.hasShortcut() {
                    Button("Clear") {
                        shortcutManager.clearShortcut()
                        errorMessage = nil
                    }
                    .foregroundColor(.red)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }
        }
        .onChange(of: keyMonitor.capturedShortcut) { newValue in
            if let shortcut = newValue, isRecording {
                handleShortcut(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
            }
        }
    }

    private func startRecording() {
        isRecording = true
        errorMessage = nil
        keyMonitor.startMonitoring()
    }

    private func stopRecording() {
        isRecording = false
        errorMessage = nil
        keyMonitor.stopMonitoring()
    }

    private func handleShortcut(keyCode: UInt16, modifiers: UInt32) {
        let validation = shortcutManager.isValidShortcut(keyCode: keyCode, modifiers: modifiers)

        if validation.isValid {
            if shortcutManager.registerHotKey(keyCode: keyCode, modifiers: modifiers) {
                stopRecording()
            } else {
                errorMessage = "Failed to register shortcut. It may conflict with another app."
            }
        } else {
            errorMessage = validation.reason
        }
    }
}

/// Monitors keyboard events using NSEvent.addLocalMonitorForEvents
class KeyboardMonitor: ObservableObject {
    @Published var capturedShortcut: CapturedShortcut?
    private var eventMonitor: Any?

    func startMonitoring() {
        // Remove any existing monitor
        stopMonitoring()

        // Add local event monitor for key down events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil  // Consume the event so it doesn't propagate
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        capturedShortcut = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0

        if event.modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if event.modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }

        // Only process if we have at least one modifier
        if carbonModifiers > 0 {
            DispatchQueue.main.async {
                self.capturedShortcut = CapturedShortcut(keyCode: event.keyCode, modifiers: carbonModifiers)
            }
        }
    }

    deinit {
        stopMonitoring()
    }
}
