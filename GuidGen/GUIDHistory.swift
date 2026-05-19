//
//  GUIDHistory.swift
//  GUIDGenerator
//
//  Persistent history of recently generated GUIDs
//

import Foundation
import Combine
import AppKit

struct GUIDHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let value: String
    let createdAt: Date

    init(value: String, createdAt: Date = Date()) {
        self.id = UUID()
        self.value = value
        self.createdAt = createdAt
    }
}

final class GUIDHistory: ObservableObject {
    static let shared = GUIDHistory()

    static let maxEntries = 50
    private static let storageKey = "guidHistory.v1"

    @Published private(set) var entries: [GUIDHistoryEntry] = []

    private init() {
        load()
    }

    func record(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Defer mutation past the current SwiftUI view update cycle to avoid
        // "Publishing changes from within view updates" warnings when called
        // from view-update-adjacent contexts (onAppear, button actions, etc).
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            guard let self else { return }
            if self.entries.first?.value == trimmed { return }
            self.entries.insert(GUIDHistoryEntry(value: trimmed), at: 0)
            if self.entries.count > Self.maxEntries {
                self.entries.removeLast(self.entries.count - Self.maxEntries)
            }
            self.save()
        }
    }

    func remove(_ entry: GUIDHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    @discardableResult
    func copy(_ entry: GUIDHistoryEntry) -> String {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.value, forType: .string)
        return entry.value
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            // Persistence failure is non-fatal; in-memory state remains valid.
            NSLog("GUIDHistory: failed to encode history: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            entries = try JSONDecoder().decode([GUIDHistoryEntry].self, from: data)
        } catch {
            NSLog("GUIDHistory: failed to decode history: \(error)")
            entries = []
        }
    }
}
