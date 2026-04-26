## Context

Three pieces of code interact:

1. `LevelSystemModels.swift` — `addWrongAnswer()` (~line 448) and `addTimeout()` (~line 460) update `currentScore`, `globalScore`, and `levelPenalties` on every wrong tap / timeout. `levelPenalties` accumulates the nominal penalty (10 or 5) for later restoration.
2. `LevelSystemModels.swift` — `resetLevelStats()` (~line 392) does `globalScore += levelPenalties` on retry. The intent is "your retry doesn't carry the failed attempt's score damage", so penalties are refunded if the player retries.
3. `LevelGameView.swift:558-573` — checks `currentScore < 0` (level 1) or `globalScore < 0` (level 2+) and fires `failedReason = .negativeScore` immediately, ending the run.

The level-1 branch exists because `globalScore` is 0 at level 1 (no completed levels), so the original author used `currentScore` as a proxy — but the threshold remained at 0, which makes a single penalty fatal.

Once we clamp scores to `≥ 0`, all three pieces must change consistently. The retry refund (point 2) is the subtle one: if we keep tracking the nominal penalty, retries refund more than was actually subtracted, opening a strategic exploit (intentionally fail a level, retry, gain free points).

## Goals / Non-Goals

**Goals:**
- Make scoring rule unambiguous: scores are non-negative everywhere they're observable.
- Make game over predictable: only the lives system ends a run.
- Resolve the related leaderboard symptom (BUG-011) at the same source.

**Non-Goals:**
- Re-tune levels. After this change level 1 may feel a bit easier; we accept that and revisit balance later if needed.
- Touch unrelated parts of `LevelGameView` (round timer, intro animation, etc.).
- Migrate historical leaderboard entries that may already contain negative scores. They're read-only, low-impact; revisit if they bother the user.

## Decisions

### Track the *actual* penalty applied, not the nominal value

**Decision:** in `addWrongAnswer()` and `addTimeout()`, compute the actual amount subtracted from `globalScore` (after clamping) and add that to `levelPenalties`, instead of the constant 10 / 5.

**Rationale:** `resetLevelStats()` refunds `levelPenalties` to `globalScore` on retry. With clamping, the nominal penalty may be larger than what was actually subtracted (when `globalScore` is near 0). If we tracked the nominal value, retries would *over-refund*, giving players a way to grow `globalScore` by failing on purpose. Tracking the actual subtracted amount keeps the refund math exact.

```swift
// Sketch
let oldGlobal = globalScore
globalScore = max(0, globalScore - 10)
levelPenalties += oldGlobal - globalScore   // 0...10
```

`currentScore` is also clamped, but it's not part of the refund equation — it's reset to 0 every level — so we don't need to track its actual deduction.

### Remove the `.negativeScore` enum case rather than deprecate it

**Decision:** drop `case negativeScore` from `LevelFailureReason` along with its three call sites.

**Rationale:** the case becomes unreachable once the negative-score game-over block is removed. Keeping it as a dead case (a) misleads readers, (b) requires every `switch` over `LevelFailureReason` to keep handling it, and (c) leaves the door open for future code to introduce a new path. Project convention so far has been to delete dead enum cases / branches outright (BUG-000, BUG-018 followed the same approach).

### Don't add a defensive clamp inside `LeaderboardStore.addScore`

**Decision:** rely on `globalScore` being clamped at the source rather than adding a second clamp in `LeaderboardStore.addScore`.

**Rationale:** belt-and-suspenders pattern hides bugs by silently accepting bad inputs. With clamping at the source, any negative score reaching `LeaderboardStore` would indicate a regression worth surfacing in tests or assertions, not silently fixing.

### Alternatives considered

**Alt A — only fix the level-1 branch.**
Replace the level-1 `currentScore < 0` check with a check on `globalScore < 0`. The level-1 instant-game-over goes away, but `globalScore` can still go negative on level 2+, and the leaderboard symptom remains. Rejected: leaves BUG-011 open and keeps inconsistent behavior across levels.

**Alt B — keep the negative-score game over but raise the threshold (e.g., `< -50`).**
Mitigates the level-1 symptom without removing the mechanic. Rejected: introduces an arbitrary magic number, doesn't solve the leaderboard issue, and contradicts the announced "lives are how you fail" rule.

**Alt C — don't deduct points at all, just track wrong taps.**
A simpler scoring model. Rejected: too invasive — changes streak logic, level-completion math, displayed stats. Out of scope.

## Risks / Trade-offs

- **[Risk]** Players who already learned the level-1 instant-game-over might find the new behavior surprisingly forgiving. → **Mitigation:** the change is intentional and accepted by the user; the difficulty curve can be re-tuned later if level 1 feels trivial.
- **[Risk]** A `switch` over `LevelFailureReason` somewhere we haven't seen could break compilation when the case is removed. → **Mitigation:** the build step in the validation phase catches this immediately; we've enumerated the three known call sites.
- **[Risk]** Historical leaderboard entries could already contain negative scores from before this change. → **Mitigation:** they remain in `UserDefaults` and will display as-is. If this becomes a UX issue (a negative high score visible in-game), follow up with a tiny migration in a separate change.
- **[Trade-off]** We trade a stricter game-over rule (negative score = death) for a clearer mental model (lives = death). The clearer model is necessary to ship the lives system honestly to the App Store.

## Migration Plan

No runtime migration needed. The behavior change is binary: before/after both compile, before/after both work, the player just gets a fairer game over rule.

**Rollback:** `git revert` the implementation commit. The clamping disappears, the negative-score game over returns, the enum case comes back, and the spec deltas in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
