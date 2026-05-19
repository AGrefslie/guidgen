//
//  GUIDGenerator.swift
//  GUIDGenerator
//
//  Utility for generating and formatting GUIDs
//

import Foundation
import AppKit

enum GUIDVersion: String, CaseIterable, Identifiable, Codable {
    case v4
    case v7
    case nilUUID

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .v4: return "v4 (random)"
        case .v7: return "v7 (time-ordered)"
        case .nilUUID: return "Nil"
        }
    }

    var explanation: String {
        switch self {
        case .v4:
            return "Fully random 122 bits. RFC 4122 default. Unordered; good general-purpose ID."
        case .v7:
            return "48-bit Unix ms timestamp + random (RFC 9562). Sortable by creation time — ideal as a database primary key."
        case .nilUUID:
            return "All zeros (00000000-0000-0000-0000-000000000000). Sentinel / placeholder value."
        }
    }
}

enum GUIDFormat: String, CaseIterable, Identifiable, Codable {
    case standard
    case noHyphens
    case braces
    case parens
    case base64
    case csharp
    case sql

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:  return "Standard"
        case .noHyphens: return "No Hyphens"
        case .braces:    return "{Braces}"
        case .parens:    return "(Parens)"
        case .base64:    return "Base64"
        case .csharp:    return "C# Literal"
        case .sql:       return "SQL Literal"
        }
    }

    var sample: String {
        switch self {
        case .standard:  return "550e8400-e29b-41d4-a716-446655440000"
        case .noHyphens: return "550e8400e29b41d4a716446655440000"
        case .braces:    return "{550e8400-e29b-41d4-a716-446655440000}"
        case .parens:    return "(550e8400-e29b-41d4-a716-446655440000)"
        case .base64:    return "VQ6EAOKbQdSnFkRmVUQAAA=="
        case .csharp:    return "Guid.Parse(\"550e8400-...\")"
        case .sql:       return "'550e8400-e29b-41d4-a716-446655440000'"
        }
    }

    var explanation: String {
        switch self {
        case .standard:
            return "RFC 4122 canonical form. Hyphen-separated hex, 36 chars. Works almost everywhere."
        case .noHyphens:
            return "32 hex chars, no separators. Common in URLs, filenames, and compact storage."
        case .braces:
            return "Wrapped in {}. Windows / .NET registry & COM style (`Guid.ToString(\"B\")`)."
        case .parens:
            return "Wrapped in (). Less common — used by some legacy systems and Objective-C tooling."
        case .base64:
            return "Raw 16 bytes encoded as Base64 (22 chars + padding). Shorter; not human-readable. Case toggle disabled."
        case .csharp:
            return "Drop-in C# expression. Paste directly into source code to build a Guid."
        case .sql:
            return "Single-quoted standard GUID. Paste into SQL inserts or `WHERE id = '...'` clauses."
        }
    }
}

final class GUIDGenerator {
    static let shared = GUIDGenerator()

    private init() {}

    /// Generate a formatted GUID string using user preferences.
    func generate() -> String {
        let prefs = UserPreferences.shared
        return generate(version: prefs.version, format: prefs.format, uppercase: prefs.isUppercase)
    }

    func generate(version: GUIDVersion, format: GUIDFormat, uppercase: Bool) -> String {
        let bytes = makeBytes(for: version)
        return apply(format: format, to: bytes, uppercase: uppercase)
    }

    /// Generate a GUID, copy to clipboard, record in history.
    @discardableResult
    func generateAndCopy() -> String {
        let value = generate()
        copyToClipboard(value)
        GUIDHistory.shared.record(value)
        return value
    }

    /// Generate, copy, then paste into the focused application.
    /// On the App Store build (sandboxed), synthetic paste isn't allowed —
    /// behave like `generateAndCopy()` instead.
    func generateAndPaste() {
        let value = generate()
        copyToClipboard(value)
        GUIDHistory.shared.record(value)

        #if !APP_STORE
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.pasteFromClipboard()
        }
        #endif
    }

    // MARK: - Byte generation

    private func makeBytes(for version: GUIDVersion) -> [UInt8] {
        switch version {
        case .v4:
            return uuidToBytes(UUID())
        case .v7:
            return makeV7Bytes()
        case .nilUUID:
            return [UInt8](repeating: 0, count: 16)
        }
    }

    private func uuidToBytes(_ uuid: UUID) -> [UInt8] {
        let u = uuid.uuid
        return [
            u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
            u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15
        ]
    }

    /// UUID v7: 48-bit big-endian millisecond timestamp + version 7 + variant + random.
    private func makeV7Bytes() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 16)
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)

        b[0] = UInt8((ms >> 40) & 0xff)
        b[1] = UInt8((ms >> 32) & 0xff)
        b[2] = UInt8((ms >> 24) & 0xff)
        b[3] = UInt8((ms >> 16) & 0xff)
        b[4] = UInt8((ms >> 8) & 0xff)
        b[5] = UInt8(ms & 0xff)

        for i in 6..<16 {
            b[i] = UInt8.random(in: 0...255)
        }

        b[6] = (b[6] & 0x0f) | 0x70   // version 7
        b[8] = (b[8] & 0x3f) | 0x80   // RFC 4122 variant
        return b
    }

    // MARK: - Formatting

    private func apply(format: GUIDFormat, to bytes: [UInt8], uppercase: Bool) -> String {
        if format == .base64 {
            return Data(bytes).base64EncodedString()
        }

        let standard = standardString(bytes)
        let cased = uppercase ? standard.uppercased() : standard

        switch format {
        case .standard:  return cased
        case .noHyphens: return cased.replacingOccurrences(of: "-", with: "")
        case .braces:    return "{\(cased)}"
        case .parens:    return "(\(cased))"
        case .csharp:    return "Guid.Parse(\"\(cased)\")"
        case .sql:       return "'\(cased)'"
        case .base64:    return cased // handled above
        }
    }

    private func standardString(_ bytes: [UInt8]) -> String {
        precondition(bytes.count == 16, "GUID requires 16 bytes")
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let chars = Array(hex)
        func slice(_ lo: Int, _ hi: Int) -> String {
            String(chars[lo..<hi])
        }
        return slice(0, 8)   + "-" +
               slice(8, 12)  + "-" +
               slice(12, 16) + "-" +
               slice(16, 20) + "-" +
               slice(20, 32)
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func pasteFromClipboard() {
        #if !APP_STORE
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'V'
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        #endif
    }
}

