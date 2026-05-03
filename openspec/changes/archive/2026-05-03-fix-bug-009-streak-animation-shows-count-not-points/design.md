## Context

The streak-bonus pipeline is split across three points in `LevelGameView.swift`:

1. **`@State` declaration** (line 50): `streakBonusAmount` holds the value rendered by the animation overlay.
2. **`.onChange(of: levelRun.lastBonusEarned)` handler** (line 468): when the bonus delta is non-zero, copy it into `streakBonusAmount` and trigger the animation.
3. **Call site** (line 420): `StreakAnimationView(bonusAmount: streakBonusAmount)` consumes the value.

The model side (`LevelSystemModels.swift`, `addCorrectAnswer`) already maintains `currentStreak`, incremented before the bonus delta is computed. At the moment the animation fires, `currentStreak` equals the milestone count exactly. So we can switch the rendered metric without touching the model at all — just change which `@State` we capture and how we render it.

## Goals / Non-Goals

**Goals:**
- Replace the misleading "+X pt" text with an achievement-style "X in a row!" label.
- Keep the trigger semantics identical (`lastBonusEarned > 0` → animate).
- Keep the visual style identical (🔥 emoji, gradient background, scale-in then fade).

**Non-Goals:**
- Re-time the animation relative to the score update.
- Add new milestones, new visual effects, or new audio cues.
- Touch the bonus math in `LevelSystemModels.swift`.

## Decisions

### Capture the streak count, not the bonus delta

**Decision:** in the `.onChange` handler, set `streakDisplayCount = levelRun.currentStreak` (and rename the state variable accordingly).

**Rationale:** the displayed value should be the achievement metric (streak length), and `currentStreak` is the right source of truth for that. Capturing it at the same moment `lastBonusEarned > 0` fires guarantees the displayed count matches the milestone that triggered the animation. No timing shift, no data invention.

### Keep `lastBonusEarned` as the trigger signal

**Decision:** don't switch the trigger to a different signal even though the displayed value is no longer the bonus.

**Rationale:** `lastBonusEarned > 0` is already the canonical "a milestone just hit" signal in the model layer. Switching to e.g. `currentStreak % 10 == 0` would re-implement milestone detection on the view side and risk drift. Keep one source of truth.

### Wording: "X in a row!" vs alternatives

**Decision:** use `"\(streakCount) in a row!"`.

**Rationale:** this is the most direct phrasing that maps to the achievement (consecutive correct answers) without genre jargon. Alternatives considered:
- `"Streak \(streakCount)!"` — terser but less self-explanatory.
- `"\(streakCount)× combo!"` — gaming convention, may feel out of register for a casual color-matching game.
- `"\(streakCount) in a row!"` — chosen for clarity.

The 🔥 emoji is preserved as the visual cue that "something celebratory is happening".

## Risks / Trade-offs

- **[Risk]** Localisation: "in a row!" is English. Future localisation will need to translate this string. → **Mitigation:** the project has no localisation infrastructure today; this string joins the others (level intro, error flash, etc.) as English-only for now. Note for the eventual localisation pass.

- **[Trade-off]** Player loses the on-screen feedback about *how many* bonus points were earned. The points still appear in the score, but the granularity per-milestone is no longer surfaced. Acceptable for the casual audience and aligns with "lives are simple, score is simple" direction.

## Migration Plan

No runtime migration. The change is purely visual. Saved scores and leaderboard entries are unaffected.

**Rollback:** `git revert` the implementation commit. The previous "+X pt" text returns; the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
