import SwiftUI
import AppKit
import OSLog
import UniformTypeIdentifiers

// MARK: - PersonalityExporter (Section 8)
//
// Export/import personality blends as .claudy JSON files.
// Fully offline — no network calls, no server.
//
// Register .claudy in Info.plist CFBundleDocumentTypes to open with Finder.

// MARK: - Data model

struct ClaudyProfile: Codable, Sendable {
    let version: String
    let name: String
    let primaryMode: String
    let secondaryMode: String?
    let blendRatio: Double?     // 0.0–1.0
    let blendEnabled: Bool

    static let currentVersion = "4.0"
}

// MARK: - Exporter / importer

@MainActor
final class PersonalityExporter {

    private let logger = Logger(subsystem: "com.claudy", category: "PersonalityExporter")

    // MARK: - Export

    func exportCurrentProfile(named name: String = "My Profile") {
        let pm = PersonalityManager.shared
        let profile = ClaudyProfile(
            version: ClaudyProfile.currentVersion,
            name: name,
            primaryMode: pm.currentMode.rawValue,
            secondaryMode: pm.blendEnabled ? pm.secondaryMode.rawValue : nil,
            blendRatio: pm.blendEnabled ? pm.blendRatio : nil,
            blendEnabled: pm.blendEnabled
        )

        guard let data = try? JSONEncoder().encode(profile) else { return }

        let panel = NSSavePanel()
        panel.title = "Export Claud-y Profile"
        panel.nameFieldStringValue = "\(name).claudy"
        if let claudyType = UTType(filenameExtension: "claudy") {
            panel.allowedContentTypes = [claudyType]
        }
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                self.logger.info("Exported profile to \(url.lastPathComponent)")
            } catch {
                self.logger.error("Export failed: \(error)")
            }
        }
    }

    // MARK: - Import

    /// Opens a file picker and returns the parsed profile (not yet applied).
    /// Returns nil on cancel or invalid file.
    func importProfile(completion: @escaping @MainActor (ClaudyProfile?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Import Claud-y Profile"
        if let claudyType = UTType(filenameExtension: "claudy") {
            panel.allowedContentTypes = [claudyType]
        }
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                Task { @MainActor in completion(nil) }
                return
            }
            Task { @MainActor [weak self] in
                let profile = self?.parse(url: url)
                completion(profile)
            }
        }
    }

    private func parse(url: URL) -> ClaudyProfile? {
        guard let data = try? Data(contentsOf: url) else {
            logger.error("Cannot read file: \(url.lastPathComponent)")
            return nil
        }
        guard let profile = try? JSONDecoder().decode(ClaudyProfile.self, from: data),
              !profile.version.isEmpty,
              PersonalityMode(rawValue: profile.primaryMode) != nil else {
            logger.error("Invalid .claudy file: \(url.lastPathComponent)")
            return nil
        }
        return profile
    }

    // MARK: - Apply

    func apply(profile: ClaudyProfile) {
        let pm = PersonalityManager.shared
        if let mode = PersonalityMode(rawValue: profile.primaryMode) {
            pm.currentMode = mode
        }
        if profile.blendEnabled,
           let secondaryRaw = profile.secondaryMode,
           let secondary = PersonalityMode(rawValue: secondaryRaw) {
            pm.secondaryMode = secondary
            pm.blendRatio = min(max(profile.blendRatio ?? 0.5, 0.0), 1.0)
            pm.blendEnabled = true
        } else {
            pm.blendEnabled = false
        }
    }
}

// MARK: - Preview sheet (shown before applying an imported profile)

struct ProfileImportPreviewSheet: View {
    let profile: ClaudyProfile
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Profile")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Name", value: profile.name)
                LabeledContent("Version", value: profile.version)
                LabeledContent("Primary Mode", value: PersonalityMode(rawValue: profile.primaryMode)?.displayName ?? profile.primaryMode)
                if let secondary = profile.secondaryMode,
                   let mode = PersonalityMode(rawValue: secondary) {
                    LabeledContent("Secondary Mode", value: mode.displayName)
                    LabeledContent("Blend", value: String(format: "%.0f%%", (profile.blendRatio ?? 0.5) * 100))
                }
            }
            .padding()
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                Spacer()
                Button("Apply Profile") { onApply() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
