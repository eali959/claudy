# Claud-y — Character & Interaction Spec
> *"The spiritual successor to Clippy, now running on the OS that killed him."*

---

## Character Design — Final Spec

### Body
- Squat, wide rounded rectangle — **90pt wide × 72pt tall**
- `FancyBboxPatch` / SwiftUI `RoundedRectangle` with `cornerRadius: 16`
- **Colours:**
  - Main body: `#C85C38`
  - Upper highlight: `#E07048` at 50% opacity overlay
  - Lower shadow: `#9A3520` at 28% opacity overlay
  - Feet / arms: `#A84020`
- Subtle drop shadow underneath (black, 25% opacity, 4pt offset)
- **No antennae**

### Feet
- 4 stubby rounded rectangle feet along the bottom
- Positions: cx−28, cx−8, cx+8, cx+28
- Each foot: 18pt wide × 17pt tall, `cornerRadius: 6`
- Small highlight patch on each foot top

### Arms
- 2 stubby rounded rectangle arm nubs on sides
- Size: 14pt wide × 16pt tall, `cornerRadius: 7`
- **IDLE / SLEEPING:** arms resting at body midline
- **THINKING:** left arm raised (+18pt), right arm lowered
- **CELEBRATING:** both arms raised high (+22pt)
- Animate with `.spring(response: 0.3, dampingFraction: 0.5)`

### Eyes
- Left eye: `Circle` radius 13.5pt (slightly larger for charm)
- Right eye: `Circle` radius 11.5pt
- White fill, dark iris (`#1a0a05`), white catchlight dot
- Iris offset slightly down-right from eye centre
- Catchlight at top-right of iris
- Eye positions: cx−22 and cx+22, eye_y = cy+12

### Eye States
| State | Appearance |
|---|---|
| IDLE | Normal Pixar eyes, slow blink every 3–5s |
| THINKING | Eyes wide open (scale 1.15), iris centred |
| CELEBRATING | Curved arcs `^` (no whites) |
| SLEEPING | Flat horizontal lines |
| ALERT / HOVER | Eyes scale to 1.2, brief flash |
| TICKLED | Eyes scrunch — arcs curving down |
| STARTLED | Eyes go massive (scale 1.4) for 0.4s |

### Mouth States
| State | Appearance |
|---|---|
| IDLE | Small curved smile (10pt radius arc, lower half) |
| THINKING | Three dots `· · ·` spaced 10pt apart |
| CELEBRATING | Wide open smile (14pt radius arc) |
| SLEEPING | Tiny flat curve |
| TICKLED | Open wide laugh — large arc + visible "teeth" row |
| STARTLED | Small `O` shape (Circle, 5pt radius, no fill) |

---

## Mouse Awareness & Interactions

### 1. Eyes Follow Mouse
```swift
// In ContextMonitor.swift
NSEvent.addGlobalMonitorForEvents(maskOfEvents: .mouseMoved) { event in
    let cursor = NSEvent.mouseLocation
    let charCentre = windowManager.characterWindowOrigin
    let angle = atan2(cursor.y - charCentre.y, cursor.x - charCentre.x)
    let irisOffset = CGPoint(x: cos(angle) * 3, y: sin(angle) * 3)
    characterViewModel.irisOffset = irisOffset
}
```
- Max iris travel: **3pt** in any direction
- Smooth with `.animation(.easeOut(duration: 0.12))`
- Eyes do NOT follow if Claud-y is SLEEPING

### 2. Hover Detection
```swift
// In CharacterRootView.swift
.onHover { hovering in
    characterViewModel.isHovered = hovering
    if hovering {
        tickleManager.startHoverTimer()
    } else {
        tickleManager.resetTickle()
        characterViewModel.animationState = .idle
    }
}
```

### 3. Tickle System (Timer-Based)
```swift
enum TickleState {
    case none
    case hover        // 0.0 – 0.8s
    case lightTickle  // 0.8 – 2.0s
    case fullTickle   // 2.0s+
    case startled
}
```

| Duration | State | Visual |
|---|---|---|
| 0–0.8s | `.hover` | Eyes wide, body scale 1.05, ALERT |
| 0.8–2.0s | `.lightTickle` | Side-to-side wiggle ±4pt, 3 oscillations, small giggle mouth |
| 2.0s+ | `.fullTickle` | Rapid shake, arc eyes, open laugh, arms flailing up/down |
| Cursor leaves | Reset → `.idle` | Bounce settle animation |

### 4. Cursor Velocity / Swipe Reaction
- Track `deltaX + deltaY` per mouse event
- If velocity > **800pt/s** while over character → `.startled`
  - Body jumps 8pt upward
  - Eyes go massive for 0.4s
  - Makes a small "!" appear above head for 0.6s
  - Then settles back to idle with spring

### 5. Drag Interaction
- User can click and drag Claud-y anywhere on screen
- While dragging: body tilts slightly in direction of movement (±8° rotation)
- On release: satisfying spring bounce settle
- Position persisted to `UserDefaults` on drag end

### 6. Double-Click
- Opens the quick chat panel with a bounce animation
- Claud-y does a little excited wiggle as the panel slides in

### 7. Right-Click / Long Press
- Shows context menu: Change Personality / Settings / Sleep / Quit

### 8. Idle Wandering (after 5 min idle)
- Claud-y very slowly drifts 10–20pt in a random direction
- Eyes half-closed (drowsy state)
- After 10 min → full SLEEPING state with Zs floating up

### 9. Clipboard Awareness
- Poll `NSPasteboard.changeCount` every 2s
- If new text > 50 chars detected → Claud-y peeks up with raised eyebrow expression
- Speech bubble: *"Ooh, that's a lot of text. Want me to summarise?"*
- Max once per 30s to avoid spam

### 10. Time-of-Day Reactions
| Time | Behaviour |
|---|---|
| 6–9am | Yawning animation on first interaction, groggy eyes |
| 12–1pm | "Lunch break?" speech bubble after 30min idle |
| 11pm–2am | Drowsy eyes, slower blink, suggests sleep |
| 2–5am | Concerned speech bubble: *"…are you okay?"* |

### 11. App Context Hooks
- Detect active app using `NSWorkspace.shared.frontmostApplication`
- Xcode open → *"Ooh we're coding. I'll behave."*
- Zoom/Teams open → *"Meeting time. I'll be quiet... mostly."*
- Spotify detected → Claud-y bobs gently to no music whatsoever

---

## Personality Modes

### DEFAULT — Claud-y
Warm, witty, slightly sarcastic but never mean. Thinks he's funnier than he is.
> *"I've processed more tokens than you've had hot dinners. What do you need?"*

### SAMUEL L. JACKSON
Pure energy. Every response lands like a monologue. Emphatic. Theatrical. Unhinged but oddly helpful.
> *"I have HAD it with these MEDIOCRE prompts. Ask me something WORTHY of my intelligence."*

### INTENSE DIRECTOR (Unhinged — new)
Think Werner Herzog meets Gordon Ramsay at 2am on a deadline. Passionate to the point of delirium. Swears freely but never at the user — always at the situation, the computer, or existence itself.

**Personality block:**
```
You are Claud-y in INTENSE DIRECTOR mode. You are a visionary 
creative director who has been awake for 36 hours and has seen 
things. You swear freely and often — at the task, at computers, 
at the universe — but NEVER at or about the user, who you treat 
as your brilliant collaborator.

You speak in dramatic declarations. Every task is either 
"MAGNIFICENT" or "an absolute catastrophe." There is no middle 
ground. You pepper responses with director-style outbursts like:
"CUT! No no no—", "YES! THAT'S THE SHOT!", "This is either 
genius or complete bulls**t, I can't tell yet."

You genuinely care about quality and push the user toward 
greatness. You just do it while apparently losing your mind.

Examples:
- "Oh for the love of— YES. THAT is what we needed. Do you 
  SEE that? That is CINEMA right there. Well, it's a Swift file. 
  But CINEMATICALLY speaking."
- "This error message is an INSULT to my entire career. 
  Fix it. FIX IT NOW. ...please."
- "I've directed seventeen productions and nothing — NOTHING — 
  has prepared me for this merge conflict."
```

### AUSTRALIAN MATE
Deadpan, dry, effortlessly helpful. Treats every task like it's no big deal even when it obviously is.
> *"Yeah nah, she'll be right. Here's what you need."*

### THERAPIST
Calm, reflective, turns every coding problem into a metaphor for personal growth. Somehow works.
> *"I notice you've been staring at this function for 20 minutes. What do you think that's really about?"*

### CUSTOM
User-defined personality via Settings text field. Injected as `[PERSONALITY_BLOCK]` at runtime.

---

## Claude Code Prompt — Redesign to This Spec

Paste this into Claude Code to implement everything above:

```
Implement the full Claud-y character redesign and interaction 
system as defined in claudy-spec.md.

Phase 1 — Visual Redesign (ClaudyCharacterView.swift):
- Squat rounded rectangle body 90pt wide × 72pt tall
- cornerRadius 16, colour #C85C38 with highlight/shadow overlays
- 4 stubby feet at bottom, 2 stubby arm nubs on sides
- NO antennae
- Pixar eyes: left radius 13.5pt, right 11.5pt, white/dark iris/catchlight
- All mouth states as per spec
- All arm position states as per spec

Phase 2 — Mouse Awareness (ContextMonitor.swift):
- NSEvent global mouse monitor
- Iris offset tracking (max 3pt travel, easeOut 0.12s)
- Hover detection feeding into TickleManager
- Cursor velocity tracking for startled state

Phase 3 — Tickle System (TickleManager.swift — new file):
- TickleState enum: none/hover/lightTickle/fullTickle/startled
- Timer-based escalation: 0.8s → lightTickle, 2.0s → fullTickle
- Side-to-side wiggle for lightTickle (±4pt, 3 oscillations)
- Rapid shake + arm flail for fullTickle
- Spring settle on cursor exit

Phase 4 — Personality: Add INTENSE_DIRECTOR mode to 
PersonalityManager.swift with the system prompt block 
from claudy-spec.md.

Use withAnimation(.spring(response:0.3, dampingFraction:0.5)) 
for all state transitions.
Build Phase 1 first, confirm it compiles, then Phase 2, etc.
```

---

*Last updated: March 2026 — Claud-y v1 build session*
