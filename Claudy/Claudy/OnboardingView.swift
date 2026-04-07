import AppKit
import SwiftUI
import OSLog

// MARK: - Onboarding State

@Observable
@MainActor
final class OnboardingState {
    var currentPage: Int = 0
    let totalPages: Int = 3

    var canGoBack: Bool { currentPage > 0 }
    var canGoNext: Bool { currentPage < totalPages - 1 }
    var isLastPage: Bool { currentPage == totalPages - 1 }

    func next() {
        guard canGoNext else { return }
        currentPage += 1
    }

    func back() {
        guard canGoBack else { return }
        currentPage -= 1
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @State private var state = OnboardingState()

    private let orange = Color(red: 0.757, green: 0.373, blue: 0.235)

    /// Called when the user taps "Let's go" - set by the window host.
    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content area
                ZStack {
                    ForEach(0..<state.totalPages, id: \.self) { index in
                        pageView(for: index)
                            .opacity(state.currentPage == index ? 1 : 0)
                            .offset(x: pageOffset(index: index))
                            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: state.currentPage)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<state.totalPages, id: \.self) { index in
                        Circle()
                            .fill(state.currentPage == index ? orange : Color.secondary.opacity(0.35))
                            .frame(width: state.currentPage == index ? 8 : 6,
                                   height: state.currentPage == index ? 8 : 6)
                            .animation(.spring(response: 0.3), value: state.currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Navigation buttons
                navigationBar
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 460, height: 520)
    }

    // MARK: - Page offset helper

    private func pageOffset(index: Int) -> CGFloat {
        let offset = CGFloat(index - state.currentPage) * 460
        return offset
    }

    // MARK: - Navigation bar

    @ViewBuilder
    private var navigationBar: some View {
        HStack(spacing: 12) {
            if state.canGoBack {
                Button(action: { state.back() }) {
                    Text("Back")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if state.isLastPage {
                Button(action: {
                    UserDefaults.standard.set(true, forKey: DefaultsKeys.onboardingComplete)
                    onComplete?()
                }) {
                    Text("Let's go")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { state.next() }) {
                    Text("Next")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Page routing

    @ViewBuilder
    private func pageView(for index: Int) -> some View {
        switch index {
        case 0: WelcomePage(orange: orange)
        case 1: ModesPage(orange: orange)
        case 2: PrivacyPage(orange: orange)
        default: EmptyView()
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let orange: Color

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            Text("🍊")
                .font(.system(size: 80))
                .padding(.bottom, 24)

            Text("Hey, I'm Claud-y 👋")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            Text("A small AI companion that lives on your Mac. I'm here to keep you company while you work - celebrating wins, commiserating over bugs, keeping you focused.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)

            Spacer(minLength: 32)
        }
    }
}

// MARK: - Page 2: Two Modes

private struct ModesPage: View {
    let orange: Color

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            Text("Two ways to chat")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            HStack(alignment: .top, spacing: 14) {
                ModeCard(
                    emoji: "🍊",
                    title: "Companion",
                    bodyText: "I run completely locally. No internet, no account, no data sent anywhere. Free forever.",
                    accentColor: orange
                )

                ModeCard(
                    emoji: "✨",
                    title: "Claude AI",
                    bodyText: "Connect your Anthropic API key for full AI conversations - code review, debugging, anything. Your key stays in your Mac's Keychain.",
                    accentColor: Color(red: 0.2, green: 0.55, blue: 0.9)
                )
            }
            .padding(.horizontal, 28)

            Text("You start in Companion mode. Switch anytime from the chat window.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 20)

            Spacer(minLength: 24)
        }
    }
}

private struct ModeCard: View {
    let emoji: String
    let title: String
    let bodyText: String  // renamed from 'body' - 'body' is reserved for the View protocol requirement
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(emoji)
                .font(.system(size: 32))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accentColor.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// MARK: - Page 3: Privacy

private struct PrivacyPage: View {
    let orange: Color

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            Text("Your privacy, simply")
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 20) {
                PrivacyRow(
                    icon: "lock.fill",
                    iconColor: orange,
                    text: "Nothing is stored between sessions"
                )
                PrivacyRow(
                    icon: "antenna.radiowaves.left.and.right.slash",
                    iconColor: orange,
                    text: "No telemetry, no analytics, no tracking"
                )
                PrivacyRow(
                    icon: "key.fill",
                    iconColor: orange,
                    text: "Your API key lives in your Mac's Keychain only - never on our servers (there are no servers)"
                )
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 32)

            Text("Claud-y is free and open source.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }
}

private struct PrivacyRow: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - NSWindow host

/// Manages the onboarding NSWindow lifecycle.
@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.claudy", category: "Onboarding")

    /// Shows onboarding if the user hasn't completed it yet.
    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKeys.onboardingComplete) else { return }
        // Set the flag *before* SwiftUI renders CharacterRootView (which initialises
        // IdleMonitor). IdleMonitor checks this same key; setting it here prevents it
        // from firing the duplicate speech-bubble intro on top of the window.
        UserDefaults.standard.set(true, forKey: DefaultsKeys.onboardingComplete)
        let controller = OnboardingWindowController()
        // Retain strongly via a static so it survives past the call site.
        OnboardingWindowController._activeController = controller
        controller.show()
    }

    // Strong reference so the controller (and window) are not deallocated immediately.
    private static var _activeController: OnboardingWindowController?

    private func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Claud-y"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor

        // Corner radius via layer
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 20

        var onboardingView = OnboardingView()
        onboardingView.onComplete = { [weak self] in
            self?.close()
        }

        window.contentView = NSHostingView(rootView: onboardingView)
        // NotificationCenter observer instead of NSWindowDelegate - avoids NSObject
        // conformance which would cause a "body" redeclaration error with SwiftUI structs.
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // The NotificationCenter closure is @Sendable in Swift 6.
            // Hop to @MainActor before touching any actor-isolated properties.
            Task { @MainActor [weak self] in
                self?.window = nil
                self?.closeObserver = nil
                OnboardingWindowController._activeController = nil
                self?.logger.info("Onboarding window closed by user")
            }
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        logger.info("Onboarding window shown")
    }

    private func close() {
        // Remove observer before closing to prevent the notification firing redundantly.
        if let o = closeObserver { NotificationCenter.default.removeObserver(o) }
        closeObserver = nil
        window?.close()
        window = nil
        OnboardingWindowController._activeController = nil
        logger.info("Onboarding complete")
    }
}
