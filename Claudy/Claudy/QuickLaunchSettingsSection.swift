import SwiftUI

struct QuickLaunchSettingsSection: View {
    @Binding var quickShortcuts: [QuickLaunchManager.Shortcut]
    @Binding var newShortcutName: String
    @Binding var newShortcutBundleID: String
    @Binding var newShortcutKey: String

    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        Section {
            if quickShortcuts.isEmpty {
                Label("No shortcuts yet - add up to \(QuickLaunchManager.maxShortcuts) below.", systemImage: "rocket")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(quickShortcuts) { shortcut in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(orange.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text(String(shortcut.name.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(shortcut.name)
                                    .font(.system(size: 13, weight: .semibold))
                                if !shortcut.shortcutKey.isEmpty {
                                    Text("⌘\(shortcut.shortcutKey.uppercased())")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Text(shortcut.bundleID)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button {
                            QuickLaunchManager.shared.launch(shortcut)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Launch \(shortcut.name)")
                    }
                    .frame(minHeight: 44)
                }
                .onDelete { offsets in
                    QuickLaunchManager.shared.remove(at: offsets)
                    quickShortcuts = QuickLaunchManager.shared.shortcuts
                }
            }

            if quickShortcuts.count < QuickLaunchManager.maxShortcuts {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add shortcut")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    VStack(spacing: 6) {
                        LabeledContent("Name") {
                            TextField("e.g. Terminal", text: $newShortcutName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                        LabeledContent("Bundle ID") {
                            TextField("e.g. com.apple.Terminal", text: $newShortcutBundleID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        LabeledContent("⌘ Key") {
                            HStack {
                                TextField("t", text: $newShortcutKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 48)
                                    .onChange(of: newShortcutKey) { _, val in
                                        if val.count > 1, let last = val.last {
                                            newShortcutKey = String(last)
                                        }
                                    }
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                        }
                    }
                    Button {
                        let name = newShortcutName.trimmingCharacters(in: .whitespaces)
                        let bid  = newShortcutBundleID.trimmingCharacters(in: .whitespaces)
                        let key  = newShortcutKey.trimmingCharacters(in: .whitespaces).lowercased()
                        guard !name.isEmpty, !bid.isEmpty else { return }
                        QuickLaunchManager.shared.add(
                            QuickLaunchManager.Shortcut(name: name, bundleID: bid, shortcutKey: key)
                        )
                        quickShortcuts = QuickLaunchManager.shared.shortcuts
                        newShortcutName = ""
                        newShortcutBundleID = ""
                        newShortcutKey = ""
                    } label: {
                        Label("Add Shortcut", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(orange)
                    .disabled(newShortcutName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              newShortcutBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.top, 4)
            }
        } header: {
            Label("Quick Launch", systemImage: "bolt.fill").font(.headline)
        } footer: {
            Text("Shortcuts appear in the right-click context menu. The optional ⌘ key activates them from the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
