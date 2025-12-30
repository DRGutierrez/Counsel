
# Counsel — Decisions Log

This document records **non-obvious product and technical decisions**.
Its purpose is to preserve intent over time and prevent accidental regression
as the product evolves.

If a future change contradicts a decision here, it should be intentional.

---

## 1. Home Screen Is Sacred
**Decision:**  
The Home screen contains no feeds, lists, or secondary actions.

**Rationale:**  
The primary value of Counsel is frictionless capture. Any visual clutter
competes with the user’s thought process.

**Implication:**  
- Navigation to History / Reflections must be secondary
- Home must always be one tap away
- No persistent banners, tips, or nudges on Home

---

## 2. History ≠ Reflections
**Decision:**  
History and Reflections are separate concepts and screens.

**Rationale:**  
Users confuse logs with insight. Separating them enforces:
- History = factual record
- Reflections = interpretation and meaning

**Implication:**  
- Not every interaction generates a reflection
- Reflections can be deleted without affecting history
- Paid features will likely live in Reflections, not History

---

## 3. Reflections Are Slow by Design
**Decision:**  
Reflections are generated daily at first, then weekly.

**Rationale:**  
Insight requires accumulation. Early frequency builds habit;
later frequency increases signal quality.

**Implication:**  
- No real-time reflection generation
- No “instant insight” pressure
- Reflections should feel deliberate, not reactive

---

## 4. Emotional State Is Temporary
**Decision:**  
User emotional states are never stored as long-term traits.

**Rationale:**  
Humans fluctuate. Persisting emotional labels erodes trust and accuracy.

**Implication:**  
- Emotional cues may influence *momentary* tone
- Emotional cues must not influence long-term memory
- Memory requires explicit or inferred stability

---

## 5. Memory Requires Transparency
**Decision:**  
When Counsel decides to remember something, the user is notified
and given an immediate Undo.

**Rationale:**  
Silent memory destroys trust faster than almost any UX mistake.

**Implication:**  
- Memory acknowledgment UI is mandatory
- Users must be able to review/remove memories later
- No hidden preference learning

---

## 6. No “AI Personality”
**Decision:**  
Counsel does not present itself as having a personality.

**Rationale:**  
Personality quickly becomes a gimmick. What users want is:
- consistency
- competence
- adaptability

**Implication:**  
- Tone adapts based on behavior, not personas
- No named assistant
- No emojis, jokes, or anthropomorphic language by default

---

## 7. Professional > Friendly
**Decision:**  
Default tone is professional, calm, and concise.

**Rationale:**  
Professional tone scales across:
- executives
- creatives
- stressed users
- analytical users

Friendly tone is optional and situational.

**Implication:**  
- Copy avoids hype
- No motivational language unless explicitly requested
- Pushback is allowed if constructive

---

## 8. NavigationStack Over Custom Router
**Decision:**  
Use native `NavigationStack` instead of a custom routing system.

**Rationale:**  
- Predictable behavior
- Better system integration
- Lower cognitive overhead during iteration

**Implication:**  
- Routing is simple and explicit
- Deep links can be added later if needed

---

## 9. In-Memory First, Persistence Later
**Decision:**  
Start with an in-memory store before adding persistence.

**Rationale:**  
This allows fast iteration on:
- data models
- reflection logic
- UX flow

without locking into premature schema decisions.

**Implication:**  
- Persistence layer must be swappable
- AppStore API should not expose storage details

---

## 10. Monetization Is Capability-Based
**Decision:**  
Future monetization will be based on *depth of insight*, not usage limits.

**Rationale:**  
Paywalls around thinking feel adversarial. Depth-based value feels earned.

**Implication:**  
- Free tier remains useful
- Paid tier unlocks:
  - longer memory
  - richer reflections
  - plan generation
- No ads, no “credits”, no nagging

---

## Guiding Constraint
If a feature:
- adds noise
- reduces trust
- accelerates insight prematurely

It does not belong in Counsel.

Revisit this document before adding complexity.
