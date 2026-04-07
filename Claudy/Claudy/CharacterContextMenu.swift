import SwiftUI

/// Right-click context menu for the Claud-y character.
/// Passed as content to `.contextMenu { }` in CharacterSceneView.
struct CharacterContextMenu: View {
    let characterViewModel: CharacterViewModel
    let chatViewModel: ChatViewModel
    let demoManager: DemoModeManager
    let v2DemoManager: V2DemoModeManager
    let onAddQuickAlarm: (Int) -> Void
    let onShowFocusAdder: (FocusToolAdderSheet.ToolType) -> Void
    let onShowHelp: () -> Void
    let onShowDonate: () -> Void
    let onShowScratchpad: () -> Void

    @Environment(WindowManager.self) private var windowManager

    var body: some View {

        // ── Personality ──────────────────────────────────────────────────────
        Menu {
            ForEach(PersonalityMode.allCases, id: \.self) { mode in
                Button {
                    guard mode != PersonalityManager.shared.currentMode else { return }
                    PersonalityManager.shared.currentMode = mode
                    chatViewModel.announcePersonalityChange(to: mode)
                } label: {
                    Label(
                        mode.displayName,
                        systemImage: PersonalityManager.shared.currentMode == mode
                            ? "checkmark" : personalityIcon(mode)
                    )
                }
            }
        } label: { Label("Personality", systemImage: "theatermasks") }

        // ── Mode ─────────────────────────────────────────────────────────────
        Menu {
            ForEach(BehaviorMode.allCases, id: \.self) { mode in
                Button {
                    characterViewModel.behaviorModeManager.activate(mode)
                } label: {
                    Label(
                        mode.displayName,
                        systemImage: characterViewModel.behaviorModeManager.currentMode == mode
                            ? "checkmark" : modeIcon(mode)
                    )
                }
            }
        } label: { Label("Mode", systemImage: "dial.high") }

        // ── Size ─────────────────────────────────────────────────────────────
        Menu {
            ForEach(WindowManager.SizePreset.allCases, id: \.self) { preset in
                Button {
                    windowManager.sizePreset = preset
                } label: {
                    Label(
                        preset.displayName,
                        systemImage: windowManager.sizePreset == preset ? "checkmark" : "circle"
                    )
                }
            }
        } label: { Label("Size", systemImage: "arrow.up.left.and.arrow.down.right") }

        Divider()

        // ── Focus Tools ───────────────────────────────────────────────────────
        let pom: PomodoroManager = characterViewModel.pomodoroManager
        Menu {

            // — Pomodoro —
            switch pom.state {
            case .idle, .complete:
                Menu {
                    Button { pom.selectedPreset = .short;   pom.start() } label: { Label("Short — 15 min",   systemImage: "15.circle") }
                    Button { pom.selectedPreset = .classic; pom.start() } label: { Label("Classic — 25 min", systemImage: "25.circle") }
                    Button { pom.selectedPreset = .long;    pom.start() } label: { Label("Long — 45 min",    systemImage: "45.circle") }
                    Button { pom.selectedPreset = .deep;    pom.start() } label: { Label("Deep — 60 min",    systemImage: "60.circle") }
                    Divider()
                    Button { pom.selectedPreset = .custom;  pom.start() } label: { Label("Custom — \(pom.customMinutes) min", systemImage: "slider.horizontal.3") }
                } label: { Label("Start Pomodoro", systemImage: "timer") }
            case .running:
                Button { pom.pause() } label: { Label("Pause  (\(pom.displayTime))", systemImage: "pause.circle.fill") }
                Button { pom.stop()  } label: { Label("Stop Timer",                  systemImage: "stop.circle") }
            case .paused:
                Button { pom.resume() } label: { Label("Resume  (\(pom.displayTime))", systemImage: "play.circle.fill") }
                Button { pom.stop()   } label: { Label("Stop Timer",                   systemImage: "stop.circle") }
            }

            Divider()

            // — Alarm —
            Menu {
                Button { onAddQuickAlarm(5)   } label: { Label("In 5 minutes",  systemImage: "5.circle") }
                Button { onAddQuickAlarm(10)  } label: { Label("In 10 minutes", systemImage: "10.circle") }
                Button { onAddQuickAlarm(15)  } label: { Label("In 15 minutes", systemImage: "15.circle") }
                Button { onAddQuickAlarm(30)  } label: { Label("In 30 minutes", systemImage: "30.circle") }
                Button { onAddQuickAlarm(60)  } label: { Label("In 1 hour",     systemImage: "1.circle") }
                Button { onAddQuickAlarm(120) } label: { Label("In 2 hours",    systemImage: "2.circle") }
                Button { onAddQuickAlarm(240) } label: { Label("In 4 hours",    systemImage: "4.circle") }
                Divider()
                Button {
                    onShowFocusAdder(.alarm)
                } label: { Label("Set Custom Alarm…", systemImage: "alarm.waves.left.and.right") }
            } label: { Label("Set Alarm", systemImage: "alarm") }

            // — Reminders —
            let pending = characterViewModel.alarmReminderManager.reminders.filter { !$0.fired }
            Menu {
                Button {
                    onShowFocusAdder(.reminder)
                } label: { Label("New Reminder…", systemImage: "plus.circle.fill") }

                if !pending.isEmpty {
                    Divider()
                    ForEach(pending) { reminder in
                        let timeStr: String = {
                            let f = DateFormatter()
                            f.timeStyle = .short
                            f.dateStyle = reminder.fireDate.timeIntervalSinceNow > 86400 ? .short : .none
                            return f.string(from: reminder.fireDate)
                        }()
                        Button {
                            characterViewModel.alarmReminderManager.remove(id: reminder.id)
                        } label: {
                            Label("\(timeStr) — \(reminder.title)", systemImage: "xmark.circle")
                        }
                    }
                    Divider()
                    Button {
                        characterViewModel.alarmReminderManager.clearFired()
                        for r in pending { characterViewModel.alarmReminderManager.remove(id: r.id) }
                    } label: { Label("Clear All", systemImage: "trash") }
                }
            } label: {
                Label(
                    pending.isEmpty ? "Reminders" : "Reminders  (\(pending.count))",
                    systemImage: "checklist"
                )
            }

            // — Stats footer —
            let stats = FocusStatsManager.shared
            if stats.pomodorosToday > 0 {
                Divider()
                Text(stats.summaryLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        } label: { Label("Focus Tools", systemImage: "target") }

        Divider()

        // ── Quick Launch ──────────────────────────────────────────────────────
        let shortcuts = QuickLaunchManager.shared.shortcuts
        if !shortcuts.isEmpty {
            Menu {
                ForEach(shortcuts) { shortcut in
                    let key = shortcut.shortcutKey.first
                    if let key {
                        Button(shortcut.name) {
                            QuickLaunchManager.shared.launch(shortcut)
                            characterViewModel.beSurprised()
                        }
                        .keyboardShortcut(KeyEquivalent(key), modifiers: .command)
                    } else {
                        Button(shortcut.name) {
                            QuickLaunchManager.shared.launch(shortcut)
                            characterViewModel.beSurprised()
                        }
                    }
                }
            } label: { Label("Launch", systemImage: "bolt") }
            Divider()
        }

        // ── Actions ───────────────────────────────────────────────────────────
        Button {
            windowManager.resetPosition()
        } label: { Label("Reset Position", systemImage: "arrow.clockwise") }

        Button {
            if characterViewModel.animationState == .sleeping {
                characterViewModel.setState(.idle)
            } else {
                characterViewModel.setState(.sleeping)
            }
        } label: {
            Label(
                characterViewModel.animationState == .sleeping ? "Wake Up" : "Sleep",
                systemImage: characterViewModel.animationState == .sleeping ? "sun.max" : "moon.zzz"
            )
        }

        Button {
            characterViewModel.setMuted(!characterViewModel.isMuted)
        } label: {
            Label(
                characterViewModel.isMuted ? "Unmute" : "Mute",
                systemImage: characterViewModel.isMuted ? "speaker.wave.2" : "speaker.slash"
            )
        }
        .keyboardShortcut("m", modifiers: .option)

        Button {
            characterViewModel.roastMe()
        } label: { Label("Roast Me", systemImage: "flame") }
        .disabled(characterViewModel.roastModeManager.isRoasting)

        let anyDemoRunning = demoManager.isRunning || v2DemoManager.isRunning
        Menu {
            Button {
                demoManager.start()
            } label: {
                Label("V1 Demo", systemImage: "play.rectangle")
            }
            .disabled(anyDemoRunning)

            Button {
                v2DemoManager.start()
            } label: {
                Label("V2 Demo", systemImage: "play.rectangle.on.rectangle")
            }
            .disabled(anyDemoRunning)

            if anyDemoRunning {
                Divider()
                Button {
                    demoManager.stop()
                    v2DemoManager.stop()
                } label: {
                    Label("Stop Demo", systemImage: "stop.circle")
                }
            }
        } label: {
            Label(
                anyDemoRunning ? "Stop Demo" : "Demo",
                systemImage: anyDemoRunning ? "stop.circle" : "play.rectangle"
            )
        }

        Divider()

        // ── Settings & help ───────────────────────────────────────────────────
        Button {
            NotificationCenter.default.post(name: .claudyOpenSettings, object: nil)
        } label: { Label("Settings…", systemImage: "gear") }

        Button { onShowScratchpad() } label: { Label("Scratchpad", systemImage: "note.text") }

        Button { onShowHelp() } label: { Label("Help", systemImage: "questionmark.circle") }

        Button { onShowDonate() } label: { Label("Support Claud-y…", systemImage: "heart") }

        Divider()

        Button("Quit Claud-y", role: .destructive) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Icon helpers

    private func personalityIcon(_ mode: PersonalityMode) -> String {
        switch mode {
        case .companion:  return "heart"
        case .chatty:     return "bubble.left.and.bubble.right"
        case .hypeCoach:  return "bolt.fill"
        case .director:   return "megaphone"
        case .mate:       return "hand.wave"
        case .listener:   return "ear"
        case .custom:     return "pencil"
        }
    }

    private func modeIcon(_ mode: BehaviorMode) -> String {
        switch mode {
        case .normal:   return "circle"
        case .study:    return "book"
        case .dev:      return "terminal"
        case .work:     return "briefcase"
        case .dance:    return "music.note"
        case .brainRot: return "brain.head.profile"
        }
    }
}
