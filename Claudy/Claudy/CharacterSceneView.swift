import SwiftUI

/// Renders the character, speech bubble, chat overlay, timer badge, quick-action capsule,
/// and demo overlays. Pure rendering — zero .onReceive or .onChange modifiers.
/// All notification wiring remains in CharacterRootView.
struct CharacterSceneView: View {
    let characterViewModel: CharacterViewModel
    let chatViewModel: ChatViewModel
    let demoManager: DemoModeManager
    @Binding var showReactionLog: Bool
    let characterOpacity: Double
    let timerBadgeScale: Double
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDragBegan: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onAddQuickAlarm: (Int) -> Void
    let onShowFocusAdder: (FocusToolAdderSheet.ToolType) -> Void
    let onShowHelp: () -> Void
    let onShowDonate: () -> Void
    let onShowScratchpad: () -> Void
    @Environment(WindowManager.self) private var windowManager

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Chat panel
                if chatViewModel.isOpen {
                    ChatView(viewModel: chatViewModel)
                        .frame(width: WindowManager.chatWidth, height: windowManager.chatHeight)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .move(edge: .bottom).combined(with: .opacity)
                        ))
                }

                // Character + speech bubble + timer badge
                VStack(spacing: 4) {

                    // Speech bubble - sits in its own layout row above the character
                    if let bubble = characterViewModel.speechBubbleText {
                        SpeechBubbleView(text: bubble) {
                            characterViewModel.dismissBubble()
                        }
                        .padding(.bottom, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
                        .zIndex(10)
                    }

                    // Character
                    ZStack {
                        ClaudyCharacterView(
                            animationState:  characterViewModel.animationState,
                            isBlinking:      characterViewModel.isBlinking,
                            irisOffset:      characterViewModel.irisOffset,
                            tickleIntensity: characterViewModel.tickleIntensity,
                            danceMove:       characterViewModel.danceModeManager.currentMove,
                            accessory:       CharacterAccessory.active,
                            characterScale:  windowManager.characterScale,
                            onTap:           onTap,
                            onDoubleTap:     onDoubleTap,
                            onDragBegan:     onDragBegan,
                            onDragChanged:   onDragChanged,
                            onDragEnded:     onDragEnded
                        )
                        .frame(width: WindowManager.characterSize, height: WindowManager.characterSize)
                        .scaleEffect(windowManager.characterScale)
                        .opacity(characterOpacity)
                        .accessibilityLabel("Claud-y")
                        .accessibilityValue({
                            let base = characterViewModel.animationState.accessibilityDescription
                            let acc = CharacterAccessory.active.accessibilityLabel
                            return acc.isEmpty ? base : "\(base), \(acc)"
                        }())
                        .accessibilityHint("Tap to \(chatViewModel.isOpen ? "close" : "open") chat. Long press for reaction history.")
                        .accessibilityAddTraits(.isButton)
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 2) {
                                if characterViewModel.isFocusModeActive {
                                    Text("🌙").font(.system(size: 12)).opacity(0.4)
                                }
                                if characterViewModel.isMuted {
                                    Text("🔇").font(.system(size: 12)).opacity(0.4)
                                }
                            }
                            .offset(x: -2, y: -2)
                            .allowsHitTesting(false)
                        }
                        .onHover { hovering in
                            characterViewModel.isHovered = hovering
                            if hovering {
                                characterViewModel.tickleManager.startHoverTimer()
                            } else {
                                characterViewModel.tickleManager.resetTickle()
                            }
                        }
                        // Long-press 3s reveals reaction log
                        .onLongPressGesture(minimumDuration: 3.0, maximumDistance: 20) {
                            showReactionLog = true
                        }
                        // Context menu lives in an isolated child view so that animation
                        // re-renders (irisOffset, isBlinking, etc.) never cause SwiftUI
                        // to rebuild the menu host — which would dismiss open submenus.
                        // Drag callbacks are forwarded through the overlay so the
                        // contentShape hit area doesn't swallow drag events.
                        .overlay {
                            ContextMenuTarget(
                                characterViewModel: characterViewModel,
                                chatViewModel: chatViewModel,
                                demoManager: demoManager,
                                onAddQuickAlarm: onAddQuickAlarm,
                                onShowFocusAdder: onShowFocusAdder,
                                onShowHelp: onShowHelp,
                                onShowDonate: onShowDonate,
                                onShowScratchpad: onShowScratchpad,
                                onDragBegan: onDragBegan,
                                onDragChanged: onDragChanged,
                                onDragEnded: onDragEnded
                            )
                        }

                        // Confetti overlay
                        if characterViewModel.showConfetti {
                            ConfettiView()
                                .offset(y: -30)
                                .transition(.opacity)
                                .zIndex(20)
                        }

                    } // ZStack (character)
                    // DEMO pill — anchored to the character ZStack so it never moves
                    // when chat, tamagotchi, or timer badge change the window height.
                    .overlay(alignment: .topLeading) {
                        if demoManager.isRunning {
                            DemoPill(variant: demoManager.activeVariant)
                                .padding(6)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }

                    // Tamagotchi overlay — compact stat bars + action buttons, below character
                    TamagotchiOverlayIfEnabled(manager: characterViewModel.tamagotchiManager)

                    // Timer badge - sits below the character body, never overlaps anything
                    if characterViewModel.pomodoroManager.state != .idle {
                        PomodoroTimerBadge(manager: characterViewModel.pomodoroManager)
                            .scaleEffect(timerBadgeScale)
                            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                            .onTapGesture(count: 2) {
                                if demoManager.isRunning { demoManager.stop(); return }
                                characterViewModel.pomodoroManager.stop()
                                characterViewModel.showBubbleDirect("Timer reset.", duration: 3)
                            }
                            .onTapGesture(count: 1) {
                                if demoManager.isRunning { demoManager.stop(); return }
                                let pom: PomodoroManager = characterViewModel.pomodoroManager
                                switch pom.state {
                                case .idle, .complete: pom.start()
                                case .running:         pom.pause()
                                case .paused:          pom.resume()
                                }
                            }
                    }

                } // VStack (bubble + character + badge)
            }
        }
        // Quick-action button — contextual prompt for the frontmost app
        .overlay(alignment: .top) {
            if let action = QuickActionManager.shared.currentAction {
                Button {
                    QuickActionManager.shared.actionTapped()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: action.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(action.label)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(red: 0.784, green: 0.361, blue: 0.220).opacity(0.92))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                    removal:   .scale(scale: 0.8, anchor: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: QuickActionManager.shared.currentAction?.label)
        // Demo interrupt - any tap or drag while demo is running stops it
        .overlay {
            if demoManager.isRunning {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        demoManager.stop()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { _ in
                                demoManager.stop()
                            }
                    )
                    .allowsHitTesting(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.clear)
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: characterViewModel.speechBubbleText != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: demoManager.sideLabel != nil)
        .animation(.easeInOut(duration: 0.3), value: characterViewModel.showConfetti)
    }
}

// MARK: - Demo pill

/// Small "V3 DEMO" badge anchored to the character body.
/// Extracted so the pill label is stable and never shifts with window height changes.
private struct DemoPill: View {
    let variant: DemoModeManager.DemoVariant?
    var body: some View {
        let label: String = {
            switch variant {
            case .v1: return "V1 DEMO"
            case .v2: return "V2 DEMO"
            case .v3: return "V3.1 DEMO"
            case nil: return "DEMO"
            }
        }()
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Context menu isolation

/// Hosts the right-click context menu in complete isolation from animated state.
///
/// `CharacterSceneView` re-renders on every animation tick because its body reads
/// `irisOffset`, `isBlinking`, `tickleIntensity`, etc. If `.contextMenu` lives
/// directly in that view, macOS tears down submenu tracking on every re-render.
///
/// By moving the context menu here — a separate `struct` that reads NO animated
/// properties — SwiftUI never re-evaluates this view's body during animation,
/// so submenus stay open when the mouse moves into them.
private struct ContextMenuTarget: View {
    let characterViewModel: CharacterViewModel
    let chatViewModel: ChatViewModel
    let demoManager: DemoModeManager
    let onAddQuickAlarm: (Int) -> Void
    let onShowFocusAdder: (FocusToolAdderSheet.ToolType) -> Void
    let onShowHelp: () -> Void
    let onShowDonate: () -> Void
    let onShowScratchpad: () -> Void
    let onDragBegan: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    @State private var dragActive = false

    var body: some View {
        Color.clear
            .contentShape(Circle())
            // Forward drag events — contentShape gives this overlay a hit area,
            // so without an explicit DragGesture it swallows all drags.
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { value in
                        if !dragActive { dragActive = true; onDragBegan() }
                        onDragChanged(value.translation)
                    }
                    .onEnded { _ in dragActive = false; onDragEnded() }
            )
            .contextMenu {
                CharacterContextMenu(
                    characterViewModel: characterViewModel,
                    chatViewModel: chatViewModel,
                    demoManager: demoManager,
                    onAddQuickAlarm: onAddQuickAlarm,
                    onShowFocusAdder: onShowFocusAdder,
                    onShowHelp: onShowHelp,
                    onShowDonate: onShowDonate,
                    onShowScratchpad: onShowScratchpad
                )
            }
    }
}
