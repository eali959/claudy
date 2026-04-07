import AppKit
import SwiftUI
import SwiftData
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.claudy", category: "App")
    var floatingWindowController: FloatingWindowController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

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
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Personality submenu
        let personalityMenu = NSMenu()
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
        let personalityItem = NSMenuItem(title: "Personality", action: nil, keyEquivalent: "")
        personalityItem.submenu = personalityMenu
        menu.addItem(personalityItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Show / Hide Claud-y", action: #selector(toggleCharacter), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    #if DEBUG
    @objc private func startDemoMode() {
        NotificationCenter.default.post(name: .claudyStartDemo, object: nil)
    }
    #endif
}
