import AppKit
import SwiftUI
import SwiftData
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(subsystem: "com.claudy", category: "App")
    var floatingWindowController: FloatingWindowController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    /// Kept so we can refresh checkmarks whenever the menu opens.
    private var personalitySubmenu: NSMenu?

    /// The app's SwiftData container — local-only, never synced to iCloud.
    /// Nil only if the container fails to initialise (store corruption, disk full).
    /// Access from TamagotchiManager: `(NSApp.delegate as? AppDelegate)?.modelContainer`
    private(set) var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory mode: no Dock icon, no menu bar (app menu is replaced by our status item)
        NSApp.setActivationPolicy(.accessory)

        initSwiftData()

        floatingWindowController = FloatingWindowController()
        floatingWindowController?.showWindow(nil)

        // Show welcome screen on first launch
        OnboardingWindowController.showIfNeeded()

        setupMenuBar()

        // Listen for settings requests posted from the SwiftUI context menu.
        // Using a notification decouples the nonactivating-panel context from AppKit window management.
        NotificationCenter.default.addObserver(
            forName: .claudyOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.openSettings() }
        }

        logger.info("Claud-y launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        floatingWindowController?.savePosition()
    }

    // MARK: - SwiftData

    private func initSwiftData() {
        do {
            let container = try TamagotchiContainer.make()
            modelContainer = container
            smokeTestSwiftData(container: container)
            logger.info("SwiftData container ready")
        } catch {
            logger.error("SwiftData container failed: \(error.localizedDescription) — Tamagotchi features unavailable")
        }
    }

    private func smokeTestSwiftData(container: ModelContainer) {
        let context = ModelContext(container)
        do {
            let existing = try context.fetch(FetchDescriptor<TamagotchiState>())
            if existing.isEmpty {
                let state = TamagotchiState()
                context.insert(state)
                try context.save()
                logger.info("SwiftData: TamagotchiState created (first launch)")
            } else {
                let s = existing[0]
                logger.info("SwiftData: TamagotchiState loaded — hunger=\(s.hunger) happiness=\(s.happiness) energy=\(s.energy)")
            }
        } catch {
            logger.error("SwiftData smoke test failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        guard let button = statusItem?.button else { return }
        let icon = NSImage(named: "MenuBarIcon")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 22, height: 22)
        button.image = icon ?? makeMenuBarIcon()
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Claud-y"
        let m = buildMenu()
        m.delegate = self     // refresh provider/mode header on open
        statusItem?.menu = m
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // ── V4 STATUS HEADER ────────────────────────────────────────────────
        // Three independent axes shown at the top so the user can see at a
        // glance which AI is active, which personality, and which behaviour
        // mode.  These are NOT the same thing — Provider = which AI talks,
        // Personality = how it talks, Behaviour Mode = what it focuses on.
        let provider = APIProvider.selected
        let aiItem = NSMenuItem(
            title: "AI: \(provider.displayName) · \(provider.isLocal ? "On-device" : "Cloud")",
            action: nil, keyEquivalent: ""
        )
        aiItem.image = NSImage(systemSymbolName: provider.icon, accessibilityDescription: nil)
        aiItem.isEnabled = false
        menu.addItem(aiItem)

        let personalityName = PersonalityManager.shared.currentMode.displayName
        let personalityHeader = NSMenuItem(
            title: "Personality: \(personalityName)",
            action: nil, keyEquivalent: ""
        )
        personalityHeader.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: nil)
        personalityHeader.isEnabled = false
        menu.addItem(personalityHeader)

        // Behaviour mode — only show if BehaviorModeManager is available.
        // Read directly from UserDefaults to avoid coupling.
        let behaviorRaw = UserDefaults.standard.string(forKey: "BehaviorMode") ?? "normal"
        let behaviorHeader = NSMenuItem(
            title: "Mode: \(behaviorRaw.capitalized)",
            action: nil, keyEquivalent: ""
        )
        behaviorHeader.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        behaviorHeader.isEnabled = false

        // V4 polish — live activity indicators (demo running / voice mode active)
        if VoiceModeManager.shared.isVoiceModeActive {
            let voiceItem = NSMenuItem(
                title: "🎙 Voice mode active",
                action: nil, keyEquivalent: ""
            )
            voiceItem.image = NSImage(systemSymbolName: "waveform.circle.fill",
                                       accessibilityDescription: nil)
            voiceItem.isEnabled = false
            menu.addItem(voiceItem)
        }
        menu.addItem(behaviorHeader)

        menu.addItem(.separator())

        // ── SWITCHERS ───────────────────────────────────────────────────────
        // Personality submenu (full picker)
        let personalityMenu = NSMenu()
        personalityMenu.delegate = self
        let pm = PersonalityManager.shared
        for mode in PersonalityMode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(selectPersonality(_:)),
                keyEquivalent: ""
            )
            item.representedObject = mode.rawValue
            item.target = self
            item.state = mode == pm.currentMode ? .on : .off
            personalityMenu.addItem(item)
        }
        personalitySubmenu = personalityMenu
        let personalityItem = NSMenuItem(title: "Switch Personality", action: nil, keyEquivalent: "")
        personalityItem.submenu = personalityMenu
        menu.addItem(personalityItem)

        // Note: AI Provider switcher and Behaviour Mode switcher are reachable
        // via Settings… (avoids three deeply nested submenus in the menu bar).

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Show / Hide Claud-y", action: #selector(toggleCharacter), keyEquivalent: " ")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Profile export / import
        let profileMenu = NSMenu()
        let exportItem = NSMenuItem(title: "Export Profile…", action: #selector(exportProfile), keyEquivalent: "")
        exportItem.target = self
        profileMenu.addItem(exportItem)
        let importItem = NSMenuItem(title: "Import Profile…", action: #selector(importProfile), keyEquivalent: "")
        importItem.target = self
        profileMenu.addItem(importItem)
        let profileParent = NSMenuItem(title: "Profile", action: nil, keyEquivalent: "")
        profileParent.submenu = profileMenu
        menu.addItem(profileParent)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Claud-y",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        #if DEBUG
        menu.addItem(.separator())
        let devMenu = NSMenu()
        let demoItem = NSMenuItem(
            title: "Start Demo Mode",
            action: #selector(startDemoMode),
            keyEquivalent: ""
        )
        demoItem.target = self
        devMenu.addItem(demoItem)
        let devParent = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
        devParent.submenu = devMenu
        menu.addItem(devParent)
        #endif

        return menu
    }

    // MARK: - NSMenuDelegate

    /// Refreshes personality checkmarks just before the submenu appears.
    /// Called each time the user opens the Personality submenu so stale
    /// state (changed from the SwiftUI right-click menu) is always reflected.
    func menuWillOpen(_ menu: NSMenu) {
        // AppKit guarantees this is called on the main thread.
        // @preconcurrency on NSMenuDelegate lets us keep this @MainActor-isolated
        // so we can access personalitySubmenu without any Sendability issues.
        if menu === personalitySubmenu {
            let current = PersonalityManager.shared.currentMode
            for item in menu.items {
                guard let raw = item.representedObject as? String else { continue }
                item.state = (raw == current.rawValue) ? .on : .off
            }
            return
        }
        // Main status menu — rebuild to refresh the Provider/Mode header
        // since the user may have switched providers since last open.
        if menu === statusItem?.menu {
            let fresh = buildMenu()
            fresh.delegate = self
            statusItem?.menu = fresh
        }
    }

    // MARK: - Icon

    private func makeMenuBarIcon() -> NSImage {
        // Use the white silhouette from the asset catalog - it's a template image
        // so macOS automatically inverts it for light/dark menu bars.
        if let asset = NSImage(named: "MenuBarIcon") {
            asset.isTemplate = true
            return asset
        }
        // Fallback: draw programmatically if asset is missing
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Actions

    @objc private func selectPersonality(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = PersonalityMode(rawValue: rawValue) else { return }
        PersonalityManager.shared.currentMode = mode
        // Update checkmarks
        sender.menu?.items.forEach {
            $0.state = ($0.representedObject as? String == mode.rawValue) ? .on : .off
        }
    }

    @objc private func toggleCharacter() {
        guard let window = floatingWindowController?.window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Claud-y Settings"
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 540, height: 500)
            window.center()
            window.contentView = NSHostingView(
                rootView: SettingsView().environment(PersonalityManager.shared)
            )
            settingsWindow = window

            // Revert to accessory mode when the settings window closes.
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }

        // Accessory-mode apps can't reliably make a window key without becoming active.
        // Temporarily switch to regular mode, activate, then show the window.
        // We revert to .accessory when the window closes (observer above).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func exportProfile() {
        PersonalityExporter().exportCurrentProfile()
    }

    @objc private func importProfile() {
        PersonalityExporter().importProfile { profile in
            guard let profile = profile else { return }
            if let mode = PersonalityMode(rawValue: profile.primaryMode) {
                PersonalityManager.shared.currentMode = mode
            }
        }
    }

    #if DEBUG
    @objc private func startDemoMode() {
        NotificationCenter.default.post(name: .claudyStartDemo, object: nil)
    }
    #endif
}
