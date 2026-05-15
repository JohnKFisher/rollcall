

## Important Scope Clarification

The following items are:
- Directional concepts
- UI inspiration
- Structural thoughts

These are NOT:
- Finalized designs
- Immediate implementation requirements
- Pixel-perfect specifications

The app should keep these concepts in mind while implementing current functionality, but should NOT attempt major UI redesign work yet.

---

## 17. Persistent Team Banner

### Concept
Add a thin persistent banner at the top of the app.

### Purpose
Display:
- Current team name
- Team identity/color context

### Benefits
Improves:
- Orientation
- Multi-team clarity
- Branding consistency

### Additional Goal
Allows removal of redundant team-name labels elsewhere.

---

## 18. Redesigned “Next Batter” Full-Width Section

### Concept
Add a prominent full-width “Now Batting / Next Batter” area on Game Day screen at top of screen

### Desired Capabilities
Display:
- Current player name
- Current player number
- Current player photo

Controls:
- Play cue
- Manual next
- Manual previous

### Smart Behavior
When cue playback ends:
- UI should smoothly advance toward next batter automatically

### Performance Requirement
Current/Next batter’s audio should always be:
- Preloaded
- Prewarmed
- Ready instantly

### Goal
Make Game Day operation smoother and more live-event focused.

---

## 19. Reduced Emphasis on Grid Buttons

### Concept
If “Next Batter” becomes primary workflow:
- Individual player buttons can become less dominant

### Direction
Likely:
- 3-column layout
- Possibly 4-column layout later

### Goal
Cleaner overall visual hierarchy.

---

## 20. Match General Clips UI to Game Day UI

### Concept
General Clips area should visually align with:
- Game Day controls
- Button styling
- Interaction language

### Goal
Improve overall consistency.

---

## 21. Future User-Added General Clips

### Current State
General clips are currently built-in only.

### Future Direction
Potential future support for:
- User-added general clips

### Similar To
Workflow similar to:
- Adding songs/audio

But:
- Not tied to specific players

### Important
Not immediate priority.

---

## 22. Rename “More” Section to “Settings”

### Concept
Rename:
- “More”
to:
- “Settings”

### Additional Goal
Restructure menu organization more logically.

### Goal
Improve discoverability and navigation clarity.

---

## 23. Rethink Bottom Tab Flow Entirely

### Concept
Bottom navigation likely needs full reconsideration.

### Current Thoughts
Possibly:
- Move Clips after Game Day

But overall:
- Entire navigation structure should be reevaluated later

### Important
No final structure decided yet.

---

## 24. General Color & Theme Review

### Concept
Future pass on:
- Color palette
- Theme consistency
- Team-color integration

### Goal
Improve:
- Cohesion
- Identity
- Visual polish

---

# Implementation Guidance for Codex / AI Assistants

## Important Priorities

### Immediate Focus
Prioritize:
1. Stability
2. Correct behavior
3. Responsiveness
4. Usability
5. Reliable playback flow

### Do NOT Prioritize Yet
Avoid:
- Large-scale visual redesigns
- Major architectural UI rewrites
- Overengineering design systems

---

## Design Philosophy

The app should feel:
- Fast
- Simple
- Reliable
- Game-day friendly
- Low-friction

This is not intended to become:
- A complex media editor
- A highly configurable power-user tool
- A heavily nested settings application

The ideal feel is:
- Fast live-event utility
- Minimal taps
- Clear behavior
- Strong immediate feedback

---

## Known Areas Likely Requiring Future Iteration

The following systems are expected to evolve further later:
- Announcer workflows
- Bottom tab structure
- Game Day layout
- General visual styling
- Color systems
- Audio workflow polish

Implement current fixes with flexibility in mind.
