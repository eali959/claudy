import SwiftUI

/// V5.11 — Privacy & Storage settings.
///
/// Per-data-type toggles giving the user full control over what Claud-y
/// saves to disk.  Aligns with the privacy ethos: nothing leaves the
/// device, and the user controls what stays on the device.
///
/// Defaults:
///   - Chat history    OFF (new feature; user must opt-in)
///   - Scratchpad      ON  (always was)
///   - Tamagotchi      ON  (always was)
///   - Focus stats     ON  (always was)
///   - Alarms / reminders ON (always was)
///
/// Each toggle has a "Clear saved" button beside it so users can wipe
/// stored data on demand without leaving the app.
struct PrivacyStorageSection: View {
    @AppStorage(DefaultsKeys.saveChatHistory)        private var saveChatHistory: Bool = false
    @AppStorage(DefaultsKeys.saveScratchpadNotes)    private var saveScratchpad: Bool = true
    @AppStorage(DefaultsKeys.saveTamagotchiState)    private var saveTamagotchi: Bool = true
    @AppStorage(DefaultsKeys.saveFocusStats)         private var saveFocusStats: Bool = true
    @AppStorage(DefaultsKeys.saveAlarmsReminders)    private var saveAlarms: Bool = true

    @State private var showClearChatConfirm: Bool = false
    @State private var showClearScratchpadConfirm: Bool = false

    private let orange = Color(red: 0.784, green: 0.361, blue: 0.220)

    var body: some View {
        Section {
            // Privacy preamble
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text("Nothing leaves your Mac. These toggles control what is kept locally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 6)

            // ── Chat history (NEW in V5.11, default OFF) ────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $saveChatHistory) {
                    Text("Save chat history locally")
                }
                .frame(minHeight: 44)
                Text("When on, your chat with Claud-y is saved to a JSON file in Application Support and restored on next launch. Off by default.")
                    .font(.caption).foregroundStyle(.secondary)
                if ChatHistoryStore.shared.hasSavedHistory {
                    Button(role: .destructive) {
                        showClearChatConfirm = true
                    } label: {
                        Label("Clear saved chat history", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)

            Divider()

            // ── Scratchpad notes ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $saveScratchpad) {
                    Text("Save scratchpad notes")
                }
                .frame(minHeight: 44)
                Text("When on, scratchpad notes are kept across launches. Off means notes vanish when you quit Claud-y.")
                    .font(.caption).foregroundStyle(.secondary)
                if !ScratchpadManager.shared.notes.isEmpty {
                    Button(role: .destructive) {
                        showClearScratchpadConfirm = true
                    } label: {
                        Label("Clear all notes", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)

            Divider()

            // ── Tamagotchi state ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $saveTamagotchi) {
                    Text("Save Tamagotchi state")
                }
                .frame(minHeight: 44)
                Text("When on, hunger/happiness/energy are remembered between sessions. When off, Claud-y starts fresh each launch.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Divider()

            // ── Focus stats ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $saveFocusStats) {
                    Text("Save focus stats")
                }
                .frame(minHeight: 44)
                Text("Pomodoro count, focus minutes, daily streak. When off, today's stats reset on quit.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Divider()

            // ── Alarms & reminders ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $saveAlarms) {
                    Text("Save alarms and reminders")
                }
                .frame(minHeight: 44)
                Text("Pending alarms and reminders are kept across launches. Off means they vanish on quit.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Privacy & Storage", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(orange)
        }
        .alert("Clear saved chat history?", isPresented: $showClearChatConfirm) {
            Button("Clear", role: .destructive) { ChatHistoryStore.shared.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the chat_history.json file from disk. This cannot be undone.")
        }
        .alert("Clear all scratchpad notes?", isPresented: $showClearScratchpadConfirm) {
            Button("Clear", role: .destructive) {
                ScratchpadManager.shared.clearAllNotes()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes every note from the scratchpad. This cannot be undone.")
        }
    }
}
