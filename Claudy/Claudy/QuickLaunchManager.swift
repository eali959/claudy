import AppKit
import OSLog
import SwiftUI

// MARK: - QuickLaunchManager
// Stores up to 3 user-configured app shortcuts in UserDefaults (as JSON).
// Launches apps via NSWorkspace.

@MainActor
final class QuickLaunchManager {
    static let shared = QuickLaunchManager()
    private let logger = Logger(subsystem: "com.claudy", category: "QuickLaunch")
    private let key = "QuickLaunchShortcuts"

    static let maxShortcuts = 3

    struct Shortcut: Codable, Identifiable, Equatable {
        var id: UUID
        var name: String
        var bundleID: String
        var shortcutKey: String  // single character, e.g. "t" → ⌘T in context menu; empty = no shortcut

        init(id: UUID = UUID(), name: String, bundleID: String, shortcutKey: String = "") {
            self.id = id
            self.name = name
            self.bundleID = bundleID
            self.shortcutKey = shortcutKey
        }
    }

    var shortcuts: [Shortcut] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([Shortcut].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }

    func add(_ shortcut: Shortcut) {
        guard shortcuts.count < Self.maxShortcuts else { return }
        shortcuts.append(shortcut)
    }

    func remove(at offsets: IndexSet) {
        var current = shortcuts
        current.remove(atOffsets: offsets)
        shortcuts = current
    }

    func launch(_ shortcut: Shortcut) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: shortcut.bundleID) {
            NSWorkspace.shared.open(url)
        } else {
            logger.warning("No app found for bundle ID: \(shortcut.bundleID)")
        }
    }
}
