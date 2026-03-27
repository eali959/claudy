# Claud-y Project Memory

## Project Location
`/Users/eali/Documents/App Dev/Apps/Claud-y/Claudy/Claudy.xcodeproj`
Source files: `Claudy/Claudy/`

## Architecture (built from scratch 2026-03-26)
Uses `PBXFileSystemSynchronizedRootGroup` — all files in `Claudy/Claudy/` auto-included in build.

### Key build settings
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (all code is MainActor by default)
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- `GENERATE_INFOPLIST_FILE = YES` (Info.plist is generated)
- `INFOPLIST_KEY_LSUIElement = YES` (no Dock icon)
- `CODE_SIGN_ENTITLEMENTS = Claudy/Claudy.entitlements`
- Deployment target: macOS 26.2
- Swift version: 5.0 (can upgrade to 6.0 via Xcode)

### File inventory
- `ClaudyApp.swift` — @main, NSApplicationDelegateAdaptor, Settings scene
- `AppDelegate.swift` — NSStatusItem menu bar, floating window setup, .accessory policy
- `FloatingPanel.swift` — NSPanel subclass
- `FloatingWindowController.swift` — manages NSPanel lifetime, injects WindowManager env
- `WindowManager.swift` — @Observable drag/resize helper, weak window ref
- `CharacterRootView.swift` — root SwiftUI view in NSPanel
- `ClaudyCharacterView.swift` — pure SwiftUI character (Lottie placeholder)
- `CharacterViewModel.swift` — animation state, blink loop
- `CharacterAnimationState.swift` — enum (idle/thinking/talking/celebrating/confused/sleeping/surprised)
- `ChatView.swift` — chat UI with streaming bubbles
- `ChatViewModel.swift` — message history, streaming via AsyncThrowingStream
- `ClaudeAPIService.swift` — actor, streaming, rate-limiting for unprompted commentary
- `PersonalityManager.swift` — @Observable singleton, loads SystemPrompt.txt from bundle
- `KeychainService.swift` — nonisolated static methods (safe for actor calls)
- `SettingsView.swift` — API key + personality picker
- `SystemPrompt.txt` — system prompt bundled from claudy-system-prompt..txt
- `Claudy.entitlements` — sandbox + network.client

### Critical constraints (from CLAUDE.md)
- Never refactor `ClaudyCharacterView.swift` structure without asking
- All API calls in `ClaudeAPIService.swift` only
- Personality state lives in `PersonalityManager.swift` only
- Model: claude-haiku-4-5-20251001

### Lottie (not yet added)
To add: SPM `https://github.com/airbnb/lottie-spm.git`, product `Lottie`
Lottie JSON files → `Resources/Animations/`
ClaudyCharacterView has placeholders for this swap

### Window chat expand
Single NSPanel resizes when chat opens. Character at bottom, chat slides up above.
WindowManager.resizeForChat(open:) handles NSWindow.setFrame.
