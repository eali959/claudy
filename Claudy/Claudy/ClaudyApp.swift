import SwiftUI

@main
struct ClaudyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Settings window is managed manually in AppDelegate for .accessory apps.
    var body: some Scene {
        WindowGroup(id: "noop") { EmptyView() }
            .defaultLaunchBehavior(.suppressed)
    }
}
