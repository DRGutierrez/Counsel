
# Counsel — Project Context

## Product Vision
Counsel is a minimal, professional, voice-first personal advisor.
It prioritizes clarity, trust, and long-term insight over speed, noise, or novelty.

The experience should feel like working with a thoughtful human advisor:
- Calm
- Direct
- Respectful
- Occasionally challenging (not a “yes assistant”)

---

## Core UX Principles

### Sacred Home
- Home screen is always ready to listen
- No feeds, no distractions, no cognitive load
- Microphone-first, typing as fallback

### Professional Tone
- Default tone is professional, concise, and respectful
- Assistant adapts over time based on user behavior (not gimmicky personalities)
- Emotional states are treated as **temporary**, never as long-term traits

### Trust First
- Memory is transparent and undoable
- No hidden persistence
- Reflections are optically slow and deliberate

---

## Mental Model

- **History** = what happened  
- **Reflections** = what it means  
- **Memory** = what should persist (future work)

History is exhaustive.  
Reflections are curated.  
Memory is intentional.

---

## Current Feature Set (Implemented)

### Input
- Typing input via modal sheet
- Voice UI stubbed visually (mic-first UX)

### Processing
- Dedicated processing screen
- Subtle pulse animation
- Copy: “Working on it…”

### Advisor Output
- Memo-style response screen
- Sections:
  - Summary
  - Organized thoughts
  - Optional next-step prompt
- Optional memory acknowledgment with Undo

### History
- Real saved responses
- Timestamped
- Tap to re-open response

### Reflections
- Auto-generated from recent history
- Cadence:
  - Daily for first 7 reflections
  - Weekly thereafter
- Reflection list + detail screen
- Reflections are insight-focused, not logs

### Navigation
- NavigationStack-based routing
- Text-only header navigation
- “Home” always resets to root (true Home)

---

## Technical Architecture

### Stack
- SwiftUI
- NavigationStack
- Combine
- In-memory state via `AppStore`

### Core Models
- `AdvisorResponseModel`
- `HistoryItem`
- `ReflectionItem`

### Store
- `AppStore` (ObservableObject)
  - `history: [HistoryItem]`
  - `reflections: [ReflectionItem]`
  - `recordInteraction()` is the single entry point for user input

### Reflection Logic
- Generated from recent history (heuristic v1)
- Uses theme extraction (token frequency)
- Designed to be replaceable with AI logic later

---

## Design System
- Dark mode first
- Minimal color palette
- Typography-led hierarchy
- Subtle gradients
- No visible chrome unless necessary

---

## Explicit Non-Goals (for now)
- No social features
- No gamification
- No streaks
- No notifications
- No over-personalized “AI personality”

---

## Known Gaps / Planned Next Steps

### Immediate
- Persistence (SwiftData recommended)
- Split monolithic `ContentView.swift` into files

### Near-Term
- AdvisorService abstraction (stub → AI)
- “Turn this into a simple plan” flow
- Plan model + plan detail screen

### Later
- Memory system with user controls
- Voice input pipeline
- Paid tier based on insight depth, not usage limits

---

## Guiding Question
> “Does this help the user think more clearly over time?”

If the answer is no, the feature does not belong in Counsel.
