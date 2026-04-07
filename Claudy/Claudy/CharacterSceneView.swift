import SwiftUI

/// Renders the character, speech bubble, chat overlay, timer badge, quick-action capsule,
/// and demo overlays. Pure rendering — zero .onReceive or .onChange modifiers.
/// All notification wiring remains in CharacterRootView.
struct CharacterSceneView: View {
    let characterViewModel: CharacterViewModel
    let chatViewModel: ChatViewModel
    let demoManager: DemoModeManager
    let v2DemoManager: V2DemoModeManager
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
                        .accessibilityValue(characterViewModel.animationState.accessibilityDescription)
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
                        .contextMenu {
                            CharacterContextMenu(
                                characterViewModel: characterViewModel,
                                chatViewModel: chatViewModel,
                                demoManager: demoManager,
                                v2DemoManager: v2DemoManager,
                                onAddQuickAlarm: onAddQuickAlarm,
                                onShowFocusAdder: onShowFocusAdder,
                                onShowHelp: onShowHelp,
                                onShowDonate: onShowDonate,
                                onShowScratchpad: onShowScratchpad
                            )
                        }

                        // Confetti overlay
                        if characterViewModel.showConfetti {
                            ConfettiView()
                                .offset(y: -30)
                                .transition(.opacity)
                                .zIndex(20)
                        }

                        // V2 demo side label — floats to the right of Claud-y during demo scenes
                        if let label = v2DemoManager.sideLabel {
                            V2SideLabelView(label: label)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .allowsHitTesting(false)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal:   .move(edge: .trailing).combined(with: .opacity)
                                ))
                                .zIndex(15)
                        }
                    } // ZStack (character)

                    // Timer badge - sits below the character body, never overlaps anything
                    if characterViewModel.pomodoroManager.state != .idle {
                        PomodoroTimerBadge(manager: characterViewModel.pomodoroManager)
                            .scaleEffect(timerBadgeScale)
                            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                            .onTapGesture(count: 2) {
                                if demoManager.isRunning   { demoManager.stop();   return }
                                if v2DemoManager.isRunning { v2DemoManager.stop(); return }
                                characterViewModel.pomodoroManager.stop()
                                characterViewModel.showBubbleDirect("Timer reset.", duration: 3)
                            }
                            .onTapGesture(count: 1) {
                                if demoManager.isRunning   { demoManager.stop();   return }
                                if v2DemoManager.isRunning { v2DemoManager.stop(); return }
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
        // DEMO pill - top-left corner, visible during any demo
        .overlay(alignment: .topLeading) {
            if demoManager.isRunning || v2DemoManager.isRunning {
                Text(v2DemoManager.isRunning ? "V2 DEMO" : "DEMO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 5))
                    .opacity(0.55)
                    .padding(10)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        // Demo interrupt - any tap or drag while demo is running stops it
        .overlay {
            if demoManager.isRunning || v2DemoManager.isRunning {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        demoManager.isRunning ? demoManager.stop() : v2DemoManager.stop()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { _ in
                                demoManager.isRunning ? demoManager.stop() : v2DemoManager.stop()
                            }
                    )
                    .allowsHitTesting(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(.clear)
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: characterViewModel.speechBubbleText != nil)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: v2DemoManager.sideLabel != nil)
        .animation(.easeInOut(duration: 0.3), value: characterViewModel.showConfetti)
    }
}
