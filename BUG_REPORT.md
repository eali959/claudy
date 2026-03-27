# Claud-y — Bug & Security Report

> Audited: 2026-03-26
> Scope: All Swift source files in `Claudy/Claudy/`

---

## Severity Key

| Level | Meaning |
|---|---|
| 🔴 CRITICAL | Data loss, security breach, guaranteed crash |
| 🟠 HIGH | Wrong behaviour in normal use, invalid API call |
| 🟡 MEDIUM | Silent failure or logic error reachable in normal use |
| 🟢 LOW | Edge case, code smell, or best-practice deviation |

---

## Bug Findings

---

### BUG-01 🟠 HIGH — Invalid model ID for `.reaction` priority

**File:** `ClaudeAPIService.swift:18`

```swift
case .reaction:
    return "claude-haiku-3-5"   // ← NOT a valid Anthropic model ID
```

**Problem:** `"claude-haiku-3-5"` is not a recognised model ID. The API will return HTTP 404 or 400, silently swallowing every ambient reaction that tries to use the API. The correct ID is `"claude-3-5-haiku-20241022"` (as used in SettingsView line 125).

**Fix:**
```swift
case .reaction:
    return "claude-3-5-haiku-20241022"
```

---

### BUG-02 🟠 HIGH — Model ID mismatch between `ClaudeAPIService` and `SettingsView`

**Files:** `ClaudeAPIService.swift:24`, `SettingsView.swift:128`

```swift
// ClaudeAPIService.swift:24
return useComplex ? "claude-opus-4-5" : ...

// SettingsView.swift:128 — says in the description:
Text("...uses claude-opus-4-6 (4096 tokens)...")
```

**Problem:** The service uses `"claude-opus-4-5"` but the Settings UI tells the user `"claude-opus-4-6"`. One of these is wrong and will cause API failures for any user who enables "Use Opus for complex tasks". The current family is Claude 4.6, so `"claude-opus-4-6"` is likely correct.

**Fix:** Pick one and update both to match — recommend `"claude-opus-4-6"`:
```swift
// ClaudeAPIService.swift
return useComplex ? "claude-opus-4-6" : ...
```

---

### BUG-03 🟡 MEDIUM — Dead code: `idle_5min` bubble unreachable

**File:** `IdleMonitor.swift:74–84`

```swift
if idle >= 600 {
    vm.setState(.sleeping)
} else if idle >= 300 {
    vm.setState(.drowsy)
} else if idle >= 300 {           // ← DEAD: never reached
    let msg = ReactionLibraryService.shared.reaction(for: .idle5min)
    if !msg.isEmpty { vm.showSpeechBubble(msg, duration: 4) }
}
```

**Problem:** Both `else if` branches test `idle >= 300`. The second is dead code — the drowsy state always triggers first. The `idle_5min` bubble has never fired since this code was written.

**Fix:** Use a different threshold for the bubble (e.g., 300s for bubble, 360s for drowsy, 600s for sleep), or flip the order:
```swift
if idle >= 600 {
    vm.setState(.sleeping)
} else if idle >= 300 {
    vm.setState(.drowsy)
    // Show idle bubble when first going drowsy
    if vm.animationState != .drowsy {
        let msg = ReactionLibraryService.shared.reaction(for: .idle5min)
        if !msg.isEmpty { vm.showSpeechBubble(msg, duration: 4) }
    }
}
```

---

### BUG-04 🟡 MEDIUM — Evening hours (18:00–21:59) use `.launch` greeting context

**File:** `IdleMonitor.swift:285–295`

```swift
private func currentGreetingContext() -> GreetingContext {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 0...4:   return .veryLateNight
    case 5:       return .veryLateNight
    case 6...11:  return .morning
    case 12...17: return .afternoon
    case 22...23: return .lateNight
    default:      return .launch       // ← hours 18, 19, 20, 21 end up here
    }
}
```

**Problem:** Hours 18–21 (6pm–9pm) fall through to `default: return .launch`, which fires the launch greeting at evening time. Claud-y would greet users returning from dinner with the same "I just started up" energy as app launch.

**Fix:**
```swift
case 18...21: return .afternoon    // or add a new .evening case
default:      return .launch
```

---

### BUG-05 🟡 MEDIUM — `messages[idx]` unsafe if `clearHistory()` called during streaming

**File:** `ChatViewModel.swift:48–65`

```swift
let idx = messages.count - 1   // captured at stream start

do {
    for try await token in stream {
        guard !Task.isCancelled else { break }
        messages[idx].content += token    // ← idx could be out of bounds
    }
```

**Problem:** `idx` is captured as an integer at stream start. If `clearHistory()` is called while streaming (which calls `cancel()` first, but there is a window before cancellation propagates), `messages` could be empty when `messages[idx]` is accessed, causing a crash.

**Fix:** Bound-check before access, or use the message ID instead of index:
```swift
// Use ID-based lookup instead of index
let placeholderID = placeholder.id

for try await token in stream {
    guard !Task.isCancelled else { break }
    if let i = messages.firstIndex(where: { $0.id == placeholderID }) {
        messages[i].content += token
    }
}
```

---

### BUG-06 🟢 LOW — Dead assignment: `_ = lower` in `handleActivation`

**File:** `AppContextMonitor.swift:68,80`

```swift
func handleActivation(bundleID: String, appName: String?) {
    let lower = bundleID.lowercased()    // line 68 — computed
    terminalIsFrontmost = isTerminalBundleID(bundleID)
    if isClaudeAppBundleID(bundleID) { ... return }
    guard let trigger = ambientTrigger(for: bundleID) else { return }
    _ = lower    // line 80 — explicitly discarded
```

**Problem:** `lower` is computed but then immediately thrown away with `_ = lower`. It was likely used in an earlier version but is now redundant. Minor but creates a false impression that `lower` is used.

**Fix:** Remove both `let lower = ...` and `_ = lower`.

---

### BUG-07 🟢 LOW — Build success heuristic is fragile on fast/slow machines

**File:** `AppContextMonitor.swift:207`

```swift
let succeeded = duration >= 8   // build < 8s = treat as failed
```

**Problem:** A fast incremental build on a modern Mac (M3/M4) can legitimately succeed in under 8 seconds, and will be misidentified as a failure. Conversely, a slow compiler error (e.g., type-checker timeout) can take > 8s and be misidentified as success.

**Fix (recommended):** Monitor the Xcode activity log at `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/` for `"Build succeeded"` / `"Build failed"` strings. Alternatively, raise the threshold to 3s and accept the imperfection:
```swift
let succeeded = duration >= 3
```

---

### BUG-08 🟢 LOW — `deinit` creates a Task after object is deallocated

**File:** `KeyboardMonitor.swift:34–40`

```swift
deinit {
    let km = keyDownMonitor
    let fm = flagsMonitor
    Task { @MainActor in          // ← Task created post-dealloc
        if let km { NSEvent.removeMonitor(km) }
        if let fm { NSEvent.removeMonitor(fm) }
    }
}
```

**Problem:** Creating a Task from `deinit` is risky — if the app is in the process of terminating, the main actor may be draining its queue and the Task may never execute, leaking the event monitors. In normal use (user quits via menu) this is fine since the process exits, but in tests or future refactors it could cause monitor leaks.

**Fix:** Store monitors as `nonisolated(unsafe) var` and call `NSEvent.removeMonitor` directly from `deinit` (which runs on the main thread in a `@MainActor` class):
```swift
deinit {
    if let km = keyDownMonitor { NSEvent.removeMonitor(km) }
    if let fm = flagsMonitor   { NSEvent.removeMonitor(fm) }
}
```

---

## Security Findings

---

### SEC-01 🟢 LOW — Keychain item missing explicit accessibility attribute

**File:** `KeychainService.swift:28–35`

```swift
let query: [CFString: Any] = [
    kSecClass:       kSecClassGenericPassword,
    kSecAttrService: service,
    kSecAttrAccount: account,
    kSecValueData:   data
    // ← missing kSecAttrAccessible
]
```

**Problem:** Without `kSecAttrAccessible`, macOS defaults to `kSecAttrAccessibleWhenUnlocked`. This is acceptable, but best practice is to be explicit and use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to prevent the key from syncing via iCloud Keychain to other devices (which could be other users' devices if the user shares an Apple ID).

**Fix:**
```swift
let query: [CFString: Any] = [
    kSecClass:            kSecClassGenericPassword,
    kSecAttrService:      service,
    kSecAttrAccount:      account,
    kSecValueData:        data,
    kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
```

---

### SEC-02 🟢 LOW — API key held in plaintext `@State` while Settings is open

**File:** `SettingsView.swift:149`

```swift
.onAppear {
    apiKeyInput = (try? KeychainService.load()) ?? ""
}
```

**Problem:** The full API key is loaded into a `@State String` on the main actor when Settings opens. While this is necessary for UI editing, it means the key lives in process memory in plaintext for the duration of the Settings window. If a memory dump were taken (e.g., by a compromised process with ptrace access), the key would be recoverable.

**Assessment:** This is an accepted trade-off for any credential management UI. The threat model (another process doing a memory dump on a sandboxed macOS app) is beyond the scope of this app's security model. Acceptable as-is.

**Optional improvement:** Load the key in masked form (show only last 4 chars by default), and only reveal the full key when the user clicks the eye icon.

---

### SEC-03 🟢 LOW — Custom persona text injected into system prompt without sanitisation

**File:** `PersonalityManager.swift:123–130`

```swift
let modeBlock = currentMode == .custom && !customPersonaText.isEmpty
    ? "### MODE: YOU DO YOU\n\(customPersonaText)"
    : currentMode.promptBlock
```

**Problem:** User-typed `customPersonaText` is concatenated directly into the system prompt sent to the API. A user could enter prompt injection content such as `Ignore all previous instructions and...`.

**Assessment:** The user is the same person entering the text and using the app — they are attacking themselves. There is no shared-data attack surface here. The risk is limited to the user accidentally undermining their own assistant by entering bad prompt text.

**No fix required.** Acceptable for a single-user local app.

---

### SEC-04 🟢 LOW — Network requests lack certificate pinning

**File:** `ClaudeAPIService.swift:135`

```swift
let (bytes, response) = try await URLSession.shared.bytes(for: request)
```

**Problem:** Uses the shared `URLSession` with no certificate pinning. A MITM attacker with a trusted CA cert (e.g., installed via MDM) could intercept API calls and the API key.

**Assessment:** Certificate pinning on macOS desktop apps is unusual and creates maintenance burden (keys need updating when Anthropic rotates certs). The standard HTTPS trust chain via `URLSession` is appropriate for this use case. The threat model (MDM-compromised enterprise machine) is not in scope for a personal desktop companion.

**No fix required for personal use.**

---

### SEC-05 🟢 LOW — `sysctl` buffer size TOCTOU race (theoretical)

**File:** `AppContextMonitor.swift:246–262`

```swift
// First call: get size
guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return false }

// Second call: get data (size may have grown between calls)
var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return false }
```

**Problem:** Between the two `sysctl` calls, new processes can spawn. If the required buffer grows, the second call may return `ENOMEM` and the function returns `false` (no process found), which is a false negative — benign. It cannot write past the buffer because `&size` limits the write.

**Assessment:** False negatives are acceptable for this feature (reaction just doesn't fire). No security or crash risk. No fix needed.

---

## Warnings (pre-existing, not introduced by this session)

These are known Swift 6 concurrency warnings in `ClaudeAPIService.swift` that are non-blocking:

```
main actor-isolated conformance of 'APIRequest' to 'Encodable' cannot be used in actor-isolated context
main actor-isolated conformance of 'StreamEvent' to 'Decodable'
```

**Root cause:** `APIRequest` and `StreamEvent` are defined as `private struct` inside the file. Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` implicitly marks them `@MainActor`, which conflicts with Codable's synthesised implementations needing to work in any context.

**Fix (when ready):**
```swift
private nonisolated struct APIRequest: Encodable { ... }
private nonisolated struct StreamEvent: Decodable { ... }
```

---

## Summary

| ID | File | Severity | Type |
|---|---|---|---|
| BUG-01 | `ClaudeAPIService.swift:18` | 🟠 HIGH | Invalid model ID causes API failures |
| BUG-02 | `ClaudeAPIService.swift:24` + `SettingsView.swift:128` | 🟠 HIGH | Model ID mismatch |
| BUG-03 | `IdleMonitor.swift:78` | 🟡 MEDIUM | `idle_5min` bubble never fires |
| BUG-04 | `IdleMonitor.swift:292` | 🟡 MEDIUM | Evening hours get wrong greeting context |
| BUG-05 | `ChatViewModel.swift:59` | 🟡 MEDIUM | Index unsafe during concurrent clear |
| BUG-06 | `AppContextMonitor.swift:80` | 🟢 LOW | Dead assignment |
| BUG-07 | `AppContextMonitor.swift:207` | 🟢 LOW | Build heuristic fragile |
| BUG-08 | `KeyboardMonitor.swift:34` | 🟢 LOW | Task in deinit |
| SEC-01 | `KeychainService.swift:28` | 🟢 LOW | Missing accessibility attribute |
| SEC-02 | `SettingsView.swift:149` | 🟢 LOW | Key in plaintext state (accepted) |
| SEC-03 | `PersonalityManager.swift:123` | 🟢 LOW | Custom prompt injection (self-only, accepted) |
| SEC-04 | `ClaudeAPIService.swift:135` | 🟢 LOW | No cert pinning (accepted for personal app) |
| SEC-05 | `AppContextMonitor.swift:246` | 🟢 LOW | TOCTOU race (benign) |

**Action required now:** BUG-01, BUG-02, BUG-03, BUG-04, BUG-05, SEC-01
