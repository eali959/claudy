# Claud-y — macOS Floating AI Companion

## Project Overview
Claud-y is a macOS desktop companion app. A small, round, animated orange creature lives in a floating transparent window on the user's screen, powered by the Claude API. Think: Clippy but adorable, intelligent, and hilarious.

## Platform & Stack
- Platform: macOS 15+
- Language: Swift 6.0 strict concurrency
- UI: SwiftUI only (no UIKit, no AppKit unless absolutely necessary for floating window)
- Architecture: MVVM with @Observable
- Animation: Pure SwiftUI (custom-drawn character in ClaudyCharacterView.swift)
- AI: Anthropic Claude API (REST, not SDK dependency)
- Package Manager: Swift Package Manager

## Key Architecture Rules
- Use SwiftUI `.windowLevel(.floating)` and `windowManagerRole(.associated)` for always-on-top window
- Character lives in a transparent, draggable `NSPanel` with `isFloatingPanel = true`
- Quick-chat panel slides in from the character using a SwiftUI sheet or popover
- Menu bar `NSStatusItem` controls personality mode, settings, and quit
- All Claude API calls are async/await with proper Swift Concurrency actors
- Use `@Observable` not `ObservableObject`
- Use `NavigationStack` not deprecated `NavigationView`
- Extract SwiftUI views when they exceed 100 lines

## Coding Standards
- Swift 6 strict concurrency throughout
- Prefer value types (structs) over classes where possible
- Use `guard` for early exits
- All async operations via `async/await`
- No print() for logging — use `Logger` from `OSLog`
- SF Symbols for all iconography
- Aim for Apple Human Interface Guidelines compliance

## Claud-y Character Specs
- Character is a round, orange creature (terra cotta / #C15F3C palette)
- Big expressive eyes, nub arms, floats and bobs
- Animation states: idle, thinking, talking, celebrating, confused, sleeping, surprised
- All animations are pure SwiftUI — no external dependencies
- Character is draggable anywhere on screen — persist last position to UserDefaults

## Claude API Integration
- API key stored in macOS Keychain (never hardcoded or in UserDefaults)
- System prompt injected per call from active personality mode
- Rate limit unprompted commentary to max 1 per 60 seconds
- Conversation history kept in memory per session (not persisted unless user opts in)
- Model: claude-haiku-4.5 (or latest suitable model)

## Files to Always Respect
- `ClaudyCharacterView.swift` — the animated character — never refactor structure without asking
- `PersonalityManager.swift` — personality mode state and prompt injection
- `ClaudeAPIService.swift` — all API calls live here, nowhere else

## XcodeBuildMCP
Use XcodeBuildMCP for all build/test/run operations:
- Build: `mcp__xcodebuildmcp__build_sim_name_proj`
- Run: use simulator or macOS target directly
- Clean on error before retry
