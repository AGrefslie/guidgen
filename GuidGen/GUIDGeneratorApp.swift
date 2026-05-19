//
//  GUIDGeneratorApp.swift
//  GUIDGenerator
//
//  Main application entry point
//

import SwiftUI
import AppKit

@main
struct GUIDGeneratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("GUID Generator", id: "main") {
            ContentView()
                .frame(minWidth: 480, idealWidth: 480, minHeight: 1120, idealHeight: 1120)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 1120)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        MenuBarExtra("GUID Generator", systemImage: "key.fill") {
            MenuBarContent()
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuBarContent: View {
    @ObservedObject private var history = GUIDHistory.shared
    @ObservedObject private var prefs = UserPreferences.shared
    @Environment(\.openWindow) private var openWindow

    private var versionBinding: Binding<GUIDVersion> {
        Binding(
            get: { prefs.version },
            set: { v in DispatchQueue.main.async { prefs.version = v } }
        )
    }
    private var formatBinding: Binding<GUIDFormat> {
        Binding(
            get: { prefs.format },
            set: { f in DispatchQueue.main.async { prefs.format = f } }
        )
    }
    private var uppercaseBinding: Binding<Bool> {
        Binding(
            get: { prefs.isUppercase },
            set: { u in DispatchQueue.main.async { prefs.isUppercase = u } }
        )
    }

    var body: some View {
        Button("New GUID") {
            GUIDGenerator.shared.generateAndCopy()
        }

        Text("Format: \(prefs.format.displayName) · \(prefs.version.displayName)")

        Divider()

        if !history.entries.isEmpty {
            Menu("Recent") {
                ForEach(history.entries.prefix(15)) { entry in
                    Button(entry.value) {
                        history.copy(entry)
                    }
                }
                Divider()
                Button("Clear History") {
                    history.clear()
                }
            }
        }

        Picker("Version", selection: versionBinding) {
            ForEach(GUIDVersion.allCases) { v in
                Text(v.displayName).tag(v)
            }
        }

        Picker("Format", selection: formatBinding) {
            ForEach(GUIDFormat.allCases) { f in
                Text(f.displayName).tag(f)
            }
        }

        if prefs.format != .base64 {
            Picker("Case", selection: uppercaseBinding) {
                Text("Uppercase").tag(true)
                Text("Lowercase").tag(false)
            }
        }

        Divider()

        Button("Open GUID Generator…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !APP_STORE
        checkAccessibilityPermissions()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running in background
    }

    #if !APP_STORE
    private func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessibilityEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "GUIDGenerator needs accessibility permissions to register global keyboard shortcuts. Please grant permission in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")

                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }
    #endif
}
