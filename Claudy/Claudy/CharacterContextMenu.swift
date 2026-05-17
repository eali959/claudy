import SwiftUI

/// Right-click context menu for the Claud-y character.
/// Passed as content to `.contextMenu { }` in CharacterSceneView.
///
/// Design principles:
///  • Primary actions first (Chat, Talk)
///  • Like items grouped — Personality + Modes in one submenu,
///    all AI providers in one submenu
///  • Walk options collapsed into a Walk submenu
///  • Help / Donate moved out of main items into a compact section
struct CharacterContextMenu: View {
    let characterViewModel: CharacterViewModel
    let chatViewModel: ChatViewModel
    let demoManager: DemoModeManager
    let onAddQuickAlarm: (Int) -> Void
    let onShowFocusAdder: (FocusToolAdderSheet.ToolType) -> Void
    let onShowHelp: () -> Void
    let onShowDonate: () -> Void
    let onShowScratchpad: () -> Void

    @Environment(WindowManager.self) private var windowManager
    @AppStorage(DefaultsKeys.tamagotchiOverlayEnabled) private var tamagotchiEnabled = false
    @AppStorage(DefaultsKeys.use3DMode) private var use3DMode: Bool = true

    var body: some View {

        // ── PRIMARY ──────────────────────────────────────────────────────────
        Button {
            NotificationCenter.default.post(name: .claudyToggleChat, object: nil)
        } label: {
            Label(
                chatViewModel.isOpen ? "Close Chat" : "Chat with Claud-y",
                systemImage: chatViewModel.isOpen ? "bubble.left.fill" : "bubble.left"
            )
        }
        Button {
            NotificationCenter.default.post(name: .claudyShowVoiceMode, object: nil)
        } label: {
            Label("Talk to Claud-y…", systemImage: "waveform.circle.fill")
        }

        Divider()

        // ── APPEARANCE ───────────────────────────────────────────────────────
        Button {
            use3DMode.toggle()
        } label: {
            Label(
                use3DMode ? "Switch to 2D" : "Switch to 3D",
                systemImage: use3DMode ? "square.on.square" : "cube"
            )
        }

        Menu {
            ForEach(CharacterAccessory.allCases, id: \.self) { acc in
                Button {
                    CharacterAccessory.active = acc
                } label: {
                    Label(
                        acc.displayName,
                        systemImage: CharacterAccessory.active == acc ? "checkmark" : acc.icon
                    )
                }
            }
        } label: { Label("Accessory", systemImage: "eyeglasses") }

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

        // ── PERSONALITY (personality modes + behaviour modes + profiles) ──────
        Menu {
            // Personality styles
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
            Divider()
            // Behaviour modes
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
            Divider()
            // Profile actions
            Button("Export Profile…") {
                characterViewModel.personalityExporter.exportCurrentProfile()
            }
            Button("Import Profile…") {
                characterViewModel.personalityExporter.importProfile { profile in
                    guard let profile else { return }
                    characterViewModel.personalityExporter.apply(profile: profile)
                    characterViewModel.wave()
                }
            }
        } label: { Label("Personality", systemImage: "theatermasks") }

        // ── AI PROVIDER (cloud + local in one submenu) ───────────────────────
        Menu {
            // Cloud providers
            ForEach(APIProvider.allCases.filter { !$0.isLocal }, id: \.self) { p in
                Button {
                    APIProvider.selected = p
                } label: {
                    Label(
                        providerLabel(p),
                        systemImage: APIProvider.selected == p ? "checkmark" : p.icon
                    )
                }
            }
            Divider()
            // Local providers
            ForEach(APIProvider.allCases.filter { $0.isLocal }, id: \.self) { p in
                Button {
                    APIProvider.selected = p
                } label: {
                    Label(
                        providerLabel(p),
                        systemImage: APIProvider.selected == p ? "checkmark" : p.icon
                    )
                }
            }
            Divider()
            Button {
                NotificationCenter.default.post(name: .claudyShowLocalLLMSetup, object: nil)
            } label: {
                Label("Set up local LLM…", systemImage: "lock.shield")
            }
        } label: {
            Label("AI Provider\(localStatusBadge)", systemImage: "antenna.radiowaves.left.and.right")
        }

        Divider()

        // ── TOOLS ─────────────────────────────────────────────────────────────
        let pom: PomodoroManager = characterViewModel.pomodoroManager
        Menu {
            switch pom.state {
            case .idle, .complete:
                Menu {
                    Button { pom.selectedPreset = .short;   pom.start() } label: { Label("Short — 15 min",   systemImage: "15.circle") }
                    Button { pom.selectedPreset = .classic; pom.start() } label: { Label("Classic — 25 min", systemImage: "25.circle") }
                    Button { pom.selectedPreset = .long;    pom.start() } label: { Label("Long — 45 min",    systemImage: "45.circle") }
                    Button { pom.selectedPreset = .deep;    pom.start() } label: { Label("Deep — 60 min",    systemImage: "timer.circle") }
                    Divider()
                    Button { pom.selectedPreset = .custom;  pom.start() } label: { Label("Custom — \(pom.customMinutes) min", systemImage: "slider.horizontal.3") }
                } label: { Label("Start Pomodoro", systemImage: "timer") }
            case .running:
                Button { pom.pause() } label: { Label("Pause Timer", systemImage: "pause.circle.fill") }
                Button { pom.stop()  } label: { Label("Stop Timer",  systemImage: "stop.circle") }
            case .paused:
                Button { pom.resume() } label: { Label("Resume Timer", systemImage: "play.circle.fill") }
                Button { pom.stop()   } label: { Label("Stop Timer",   systemImage: "stop.circle") }
            }
            Divider()
            Menu {
                Button { onAddQuickAlarm(5)   } label: { Label("In 5 minutes",  systemImage: "5.circle") }
                Button { onAddQuickAlarm(10)  } label: { Label("In 10 minutes", systemImage: "10.circle") }
                Button { onAddQuickAlarm(15)  } label: { Label("In 15 minutes", systemImage: "15.circle") }
                Button { onAddQuickAlarm(30)  } label: { Label("In 30 minutes", systemImage: "30.circle") }
                Button { onAddQuickAlarm(60)  } label: { Label("In 1 hour",     systemImage: "1.circle") }
                Button { onAddQuickAlarm(120) } label: { Label("In 2 hours",    systemImage: "2.circle") }
                Divider()
                Button { onShowFocusAdder(.alarm) } label: { Label("Set Custom Alarm…", systemImage: "alarm.waves.left.and.right") }
            } label: { Label("Set Alarm", systemImage: "alarm") }
            let pending = characterViewModel.alarmReminderManager.reminders.filter { !$0.fired }
            Menu {
                Button { onShowFocusAdder(.reminder) } label: { Label("New Reminder…", systemImage: "plus.circle.fill") }
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
                Label("Reminders", systemImage: "checklist")
            }
        } label: { Label("Focus Tools", systemImage: "target") }

        // Tamagotchi
        Menu {
            Button {
                tamagotchiEnabled.toggle()
            } label: {
                Label(
                    tamagotchiEnabled ? "Disable Tamagotchi" : "Enable Tamagotchi",
                    systemImage: tamagotchiEnabled ? "heart.slash" : "heart.fill"
                )
            }
            if tamagotchiEnabled, let tama = characterViewModel.tamagotchiManager {
                Divider()
                Button { tama.feed() } label: { Label("Feed",  systemImage: "fork.knife") }
                Button { tama.play() } label: { Label("Play",  systemImage: "gamecontroller") }
                Button { tama.rest() } label: { Label("Rest",  systemImage: "hand.raised.fill") }
            }
        } label: {
            Label(
                tamagotchiEnabled ? "Tamagotchi ♥" : "Tamagotchi",
                systemImage: tamagotchiEnabled ? "heart.fill" : "heart"
            )
        }

        // Quick Launch — only shown when shortcuts exist
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
            } label: { Label("Launch", systemImage: "bolt.fill") }
        }

        Divider()

        // ── CHARACTER STATE ───────────────────────────────────────────────────
        Button {
            if characterViewModel.animationState == .sleeping {
                characterViewModel.setState(.idle)
            } else {
                characterViewModel.setState(.sleeping)
            }
        } label: {
            Label(
                characterViewModel.animationState == .sleeping ? "Wake Up" : "Sleep",
                systemImage: characterViewModel.animationState == .sleeping ? "sun.max" : "moon.zzz.fill"
            )
        }

        Button {
            characterViewModel.setMuted(!characterViewModel.isMuted)
        } label: {
            Label(
                characterViewModel.isMuted ? "Unmute" : "Mute",
                systemImage: characterViewModel.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill"
            )
        }
        .keyboardShortcut("m", modifiers: .option)

        if let walk = characterViewModel.walkManager {
            Menu {
                Button {
                    walk.walkNow()
                } label: { Label("Walk Now", systemImage: "figure.walk") }
                .disabled(walk.isWalking)

                Button {
                    walk.isEnabled.toggle()
                } label: {
                    Label(
                        walk.isEnabled ? "Disable Auto-Walk" : "Enable Auto-Walk",
                        systemImage: walk.isEnabled ? "figure.stand" : "figure.walk.motion"
                    )
                }
            } label: { Label("Walk", systemImage: "figure.walk") }
        }

        Button {
            windowManager.resetPosition()
        } label: { Label("Reset Position", systemImage: "arrow.counterclockwise") }

        Divider()

        // ── FUN ───────────────────────────────────────────────────────────────
        Button {
            characterViewModel.roastMe()
        } label: { Label("Roast Me", systemImage: "flame.fill") }
        .disabled(characterViewModel.roastModeManager.isRoasting)

        let anyDemoRunning = demoManager.isRunning
        Menu {
            Button { demoManager.start(.v1) } label: { Label("V1 Demo", systemImage: "1.circle") }
                .disabled(anyDemoRunning)
            Button { demoManager.start(.v2) } label: { Label("V2 Demo", systemImage: "2.circle") }
                .disabled(anyDemoRunning)
            Button { demoManager.start(.v3) } label: { Label("V3 Demo", systemImage: "3.circle") }
                .disabled(anyDemoRunning)
            Button { demoManager.start(.v4) } label: { Label("v4 Demo (30 s)", systemImage: "4.circle.fill") }
                .disabled(anyDemoRunning)
            if anyDemoRunning {
                Divider()
                Button { demoManager.stop() } label: { Label("Stop Demo", systemImage: "stop.circle.fill") }
            }
        } label: {
            Label(
                anyDemoRunning ? "Stop Demo" : "Demo",
                systemImage: anyDemoRunning ? "stop.circle.fill" : "play.rectangle.fill"
            )
        }

        Divider()

        // ── SETTINGS & UTILITIES ──────────────────────────────────────────────
        Button { onShowScratchpad() } label: { Label("Scratchpad", systemImage: "note.text") }

        Button {
            NotificationCenter.default.post(name: .claudyOpenSettings, object: nil)
        } label: { Label("Settings…", systemImage: "gearshape.fill") }

        Button { onShowHelp() } label: { Label("Help", systemImage: "questionmark.circle") }

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

    /// Display label for an APIProvider — with live status dot for local providers.
    private func providerLabel(_ p: APIProvider) -> String {
        switch p {
        case .ollama:   return "Ollama "   + (LocalLLMStatus.shared.ollamaUp   ? "🟢" : "🔴")
        case .lmStudio: return "LM Studio " + (LocalLLMStatus.shared.lmStudioUp ? "🟢" : "🔴")
        default:        return p.displayName
        }
    }

    /// Suffix appended to the AI Provider label when a local model is active.
    private var localStatusBadge: String {
        switch APIProvider.selected {
        case .ollama, .lmStudio: return " 🔒"
        default: return ""
        }
    }
}
