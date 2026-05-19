//
//  ContentView.swift
//  GUIDGenerator
//
//  Main application UI
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var preferences = UserPreferences.shared
    @ObservedObject var shortcutManager = ShortcutManager.shared
    @ObservedObject var history = GUIDHistory.shared

    @State private var currentGUID: String = ""
    @State private var showCopiedFeedback: Bool = false
    @State private var isRecordingShortcut: Bool = false
    @State private var historySearch: String = ""
    @State private var copiedEntryID: UUID? = nil

    // Bindings that defer assignment past the current SwiftUI update transaction,
    // avoiding "Publishing changes from within view updates" warnings caused by
    // Picker → @Published mutation during animation.
    private var versionBinding: Binding<GUIDVersion> {
        Binding(
            get: { preferences.version },
            set: { v in DispatchQueue.main.async { preferences.version = v } }
        )
    }
    private var formatBinding: Binding<GUIDFormat> {
        Binding(
            get: { preferences.format },
            set: { f in DispatchQueue.main.async { preferences.format = f } }
        )
    }
    private var uppercaseBinding: Binding<Bool> {
        Binding(
            get: { preferences.isUppercase },
            set: { u in DispatchQueue.main.async { preferences.isUppercase = u } }
        )
    }

    private var filteredHistory: [GUIDHistoryEntry] {
        let trimmed = historySearch.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return history.entries }
        return history.entries.filter {
            $0.value.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)

                Text("GUID Generator")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Generate and manage GUIDs/UUIDs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            Divider()

            // GUID Display and Generation
            VStack(spacing: 16) {
                // Current GUID Display
                if !currentGUID.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text(currentGUID)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                )

                            Button(action: {
                                copyToClipboard()
                            }) {
                                Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundColor(showCopiedFeedback ? .green : .blue)
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard")
                        }

                        if showCopiedFeedback {
                            Text("Copied to clipboard!")
                                .font(.caption)
                                .foregroundColor(.green)
                                .transition(.opacity)
                        }
                    }
                }

                // Generate Button
                Button(action: generateNewGUID) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Generate GUID")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("g", modifiers: [.command])
            }

            Divider()

            historySection

            Divider()

            // Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)

                // UUID Version
                VStack(alignment: .leading, spacing: 6) {
                    Text("Version:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Version", selection: versionBinding) {
                        ForEach(GUIDVersion.allCases) { v in
                            Text(v.displayName).tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Label(preferences.version.explanation, systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Output Format
                VStack(alignment: .leading, spacing: 6) {
                    Text("Output:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Output", selection: formatBinding) {
                        ForEach(GUIDFormat.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Text(preferences.format.sample)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.08))
                        )

                    Label(preferences.format.explanation, systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Case (hidden for base64 — encoding fixes case)
                if preferences.format != .base64 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Case:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Case", selection: uppercaseBinding) {
                            Text("Uppercase").tag(true)
                            Text("Lowercase").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                // Shortcut Recorder
                ShortcutRecorderView(isRecording: $isRecordingShortcut)

                // Help Text
                VStack(alignment: .leading, spacing: 4) {
                    #if APP_STORE
                    Label("Global shortcut copies a new GUID to your clipboard", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    #else
                    Label("Use the global shortcut to paste a new GUID anywhere", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    #endif

                    Label("GUIDs are automatically copied to clipboard", systemImage: "doc.on.clipboard")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if shortcutManager.isEnabled {
                        Label("Shortcut is active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Text("Enjoying the app? A coffee is always appreciated — totally optional.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let url = URL(string: "https://buymeacoffee.com/axelgrefslie") {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy me a coffee")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.yellow.opacity(0.25))
                        )
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("Support development — buymeacoffee.com/axelgrefslie")
                }
            }
            .padding(.bottom, 12)
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 480, minHeight: 1200, idealHeight: 1200)
        .onAppear {
            // Generate initial GUID
            if currentGUID.isEmpty {
                generateNewGUID()
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("History")
                    .font(.headline)
                Text("(\(history.entries.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(role: .destructive) {
                    history.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Clear history")
                .disabled(history.entries.isEmpty)
            }

            if !history.entries.isEmpty {
                TextField("Search…", text: $historySearch)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            }

            if history.entries.isEmpty {
                Text("No GUIDs generated yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else if filteredHistory.isEmpty {
                Text("No matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredHistory) { entry in
                            historyRow(entry)
                        }
                    }
                }
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.05))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyRow(_ entry: GUIDHistoryEntry) -> some View {
        HStack(spacing: 8) {
            Text(entry.value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Text(relativeTime(entry.createdAt))
                .font(.caption2)
                .foregroundColor(.secondary)

            Button {
                history.copy(entry)
                copiedEntryID = entry.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedEntryID == entry.id {
                        copiedEntryID = nil
                    }
                }
            } label: {
                Image(systemName: copiedEntryID == entry.id ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(copiedEntryID == entry.id ? .green : .blue)
            }
            .buttonStyle(.plain)
            .help("Copy")

            Button {
                history.remove(entry)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func generateNewGUID() {
        currentGUID = GUIDGenerator.shared.generateAndCopy()
        showCopiedFeedback = true

        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentGUID, forType: .string)

        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}

#Preview {
    ContentView()
}
