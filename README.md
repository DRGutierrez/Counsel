[counsel_product_vision_v_1_spec.md](https://github.com/user-attachments/files/24377230/counsel_product_vision_v_1_spec.md)
# Counsel

A calm thinking companion that helps you turn messy thoughts into clear next actions.

---

## What Counsel Is

**Counsel helps you think clearly and move forward.**

It is not:
- a journaling app
- a productivity manager
- a chatty AI assistant

It *is*:
- a place to unload a thought (typed or spoken)
- a system that compresses that thought into clarity
- a guide that helps you take one meaningful next step

> Core loop: **Capture → Clarify → Act → Reflect**

---

## Product Principles (Non‑Negotiable)

These rules keep Counsel simple and useful.

1. **Frictionless capture**  
   The app should work when the user is tired, rushed, or distracted.

2. **Compression over expansion**  
   Counsel should reduce complexity, not add to it.

3. **Action over analysis**  
   Every response should point toward motion, not rumination.

4. **Local‑first, private by default**  
   User data stays on device unless explicitly shared.

5. **History is the source of truth**  
   Everything else is derived and can improve over time.

---

## Core Loop (v1)

1. **Capture**
   - User types or speaks a thought

2. **Clarify**
   Counsel returns:
   - a short summary (what this is really about)
   - 3–5 organized bullets (constraints, options, priorities)
   - a single prompt: *“Turn this into a plan”*

3. **Act**
   - The thought becomes a tiny plan
   - Maximum 3 actions
   - One clearly suggested first step

4. **Reflect**
   - Counsel derives daily/weekly reflections
   - Identifies recurring themes and patterns
   - Offers to turn insights into plans

---

## Data Philosophy

### Persisted
- `HistoryRecord`
  - raw user input (processed)
  - structured AI response
  - timestamp

### Derived (never persisted)
- Reflections
- Themes
- Plans
- Insights

**Why this matters:**
- Improving the AI improves *past* content automatically
- No stale advice
- Minimal schema complexity

---

## AI Responsibilities

### AI *should*:
- Identify the real problem beneath the text
- Extract constraints and priorities
- Suggest the smallest reasonable next step
- Notice patterns across time

### AI should *not*:
- Be verbose or chatty
- Pretend to be a therapist, doctor, or lawyer
- Generate long plans or task lists
- Offer unsolicited life advice

Output must be structured and predictable.

---

## Voice Vision

Voice is a **capture enhancement**, not a gimmick.

### v1 Voice
- Hold to talk
- Live transcription
- Tap send
- Optional spoken summary

### v2 Voice
- Real‑time conversational agent
- Interruptible
- Low latency

---

## Feature Scope

### v1 (Current)
- Typed capture
- Structured response
- Plan generation
- Reflection → Plan flow
- Derived reflections
- History search
- Clear all data

### v1.1 (Next)
- Real AI via backend proxy
- Same response schema

### v1.2
- Voice capture (Speech → Text → AI)

### v1.3
- Polite memory (user‑approved preferences only)

### v2
- Real‑time voice agent
- Better long‑term reflections
- Optional reminders

---

## What Success Looks Like

A successful Counsel session ends with:
- relief (the thought is no longer vague)
- clarity (the problem is understandable)
- momentum (one action feels doable)

If the user closes the app knowing what to do next, Counsel did its job.

---

## Guiding Question for Every New Feature

> Does this make it easier to **think clearly and act** — or does it add noise?

If it adds noise, it does not ship.

