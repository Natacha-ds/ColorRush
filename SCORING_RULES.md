# Level System Scoring, Lives, and Mistake Rules

## 📊 **SCORING SYSTEM**

### **Point Values by Level**
| Level | Points per Correct Answer | Required Score | Perfect Bonus |
|-------|---------------------------|----------------|---------------|
| 1     | 10                        | 200            | None          |
| 2     | 10                        | 250            | None          |
| 3     | 15                        | 300            | +30           |
| 4     | 15                        | 375            | +30           |
| 5     | 20                        | 400            | +40           |
| 6     | 20                        | 500            | +40           |
| 7     | 25                        | 600            | +50           |
| 8     | 25                        | 650            | +50           |
| 9     | 30                        | 700            | +60           |
| 10    | 30                        | 750            | +60           |

### **Correct Answer**
- **Points Added**: `pointsPerRound` (varies by level, see table above)
- **Where Added**:
  - ✅ `currentScore` (level score) - **immediately**
  - ✅ `levelPositivePoints` (tracker for level completion) - **immediately**
  - ❌ `globalScore` - **NOT added immediately**, only added when level completes successfully
- **Tracking**: Increments `levelCorrectAnswers` counter

### **Wrong Answer (Wrong Tap)**
- **Points Deducted**: `-10 points`
- **Where Deducted**:
  - ✅ `currentScore` (level score) - **immediately**
  - ✅ `globalScore` (total run score) - **immediately**
- **Mistake Counters**:
  - ✅ `mistakes` (run-wide) - **+1**
  - ✅ `levelMistakes` (level-specific) - **+1**

### **Timeout (No Tap Before Round Timer)**
- **Points Deducted**: `-5 points`
- **Where Deducted**:
  - ✅ `currentScore` (level score) - **immediately**
  - ✅ `globalScore` (total run score) - **immediately**
- **Timeout Counters**:
  - ✅ `timeouts` (run-wide) - **+1**
  - ✅ `levelTimeouts` (level-specific) - **+1**
- **Special Case (Levels 9-10)**: Non-punitive refresh - **NO penalty**, just refreshes the board

### **Perfect Bonus**
- **When Awarded**: Level completed with `levelMistakes == 0` AND `levelTimeouts == 0`
- **Bonus Value**: See table above (only levels 3-10 have bonuses)
- **Where Added**: `globalScore` - **only when level completes successfully**
- **Note**: Perfect bonus is NOT added to `currentScore` or `levelPositivePoints`

---

## ❤️ **LIVES / MISTAKES SYSTEM**

### **Mistake Tolerance (Run-Wide)**
| Difficulty | Max Mistakes Allowed | Description |
|------------|----------------------|-------------|
| Easy       | 5                    | 5 mistakes allowed |
| Normal     | 3                    | 3 mistakes allowed |
| Hard       | 0                    | No mistakes allowed |

### **What Counts as a Mistake?**
1. **Wrong Tap**: Every incorrect tile tap counts as **1 mistake**
   - Deducts 10 points from both `currentScore` and `globalScore`
   - Increments both `mistakes` (run-wide) and `levelMistakes` (level-specific)

2. **Insufficient Score**: If level timer runs out and player hasn't reached `requiredScore`, counts as **1 mistake**
   - **NO point deduction** (only mistake counter increments)
   - Increments both `mistakes` (run-wide) and `levelMistakes` (level-specific)
   - Level fails, player can retry

3. **Timeout (Missed Answer)**: Does **NOT** count as a mistake
   - Only deducts 5 points
   - Does NOT increment mistake counters
   - Only increments `timeouts` and `levelTimeouts` counters

### **Remaining Lives Calculation**
```
remainingLives = max(0, mistakeTolerance.maxMistakes - mistakes)
```

### **Game Over Conditions**
1. **Max Mistakes Exceeded**: `mistakes > mistakeTolerance.maxMistakes`
   - Example: Easy mode, 6th mistake triggers game over
   - **No retry** - must start new run

2. **Negative Total Score**:
   - **Level 1**: `currentScore < 0` (since no globalScore exists yet)
   - **Level 2+**: `globalScore < 0`
   - **No retry** - must start new run

---

## 🎯 **SCORE TRACKING**

### **Score Variables**

1. **`currentScore`** (Level Score)
   - Starts at 0 for each level
   - Can go negative due to penalties
   - Used to determine if level passes (`currentScore >= requiredScore`)
   - Reset to 0 when starting a new level or retrying

2. **`levelPositivePoints`** (Positive Points Tracker)
   - Tracks only positive points earned this level (from correct answers)
   - Does NOT include penalties
   - Does NOT include perfect bonus
   - Reset to 0 when starting a new level or retrying
   - **Only added to `globalScore` when level completes successfully**

3. **`globalScore`** (Total Run Score)
   - Cumulative score across all completed levels
   - **Immediately affected by penalties** (wrong taps, timeouts)
   - **Only gets positive points when level completes successfully**
   - Reset to 0 when starting a new run
   - Used for leaderboard

### **Score Flow**

**During Level:**
- ✅ Correct answer: `currentScore += pointsPerRound`, `levelPositivePoints += pointsPerRound`
- ❌ Wrong answer: `currentScore -= 10`, `globalScore -= 10`
- ⏱️ Timeout: `currentScore -= 5`, `globalScore -= 5`

**On Level Completion:**
- ✅ `globalScore += levelPositivePoints` (add all positive points earned)
- ✅ `globalScore += perfectBonus` (if perfect level)

**On Level Failure (Retry):**
- ❌ `levelPositivePoints` is discarded (never added to `globalScore`)
- ✅ Penalties from failed attempt remain in `globalScore`
- ✅ `currentScore` and `levelPositivePoints` reset to 0 for retry

**On Game Over:**
- ✅ Current `globalScore` (including penalties) is saved to leaderboard
- ✅ All stats reset for new run

---

## 🔄 **LEVEL COMPLETION / FAILURE**

### **Level Completion**
- **Condition**: When global timer runs out, `currentScore >= requiredScore`
- **Actions**:
  1. `globalScore += levelPositivePoints`
  2. `globalScore += perfectBonus` (if applicable)
  3. Store level score in `levelScores[currentLevel]`
  4. Add to `completedLevels` array
  5. If perfect, add to `perfectLevels` array
  6. Move to next level (or end run if level 10)

### **Level Failure (Insufficient Score)**
- **Condition**: When global timer runs out, `currentScore < requiredScore`
- **Actions**:
  1. Count as 1 mistake: `mistakes += 1`, `levelMistakes += 1`
  2. Check if this exceeds mistake tolerance (game over)
  3. Level can be retried
  4. `levelPositivePoints` from failed attempt is discarded

### **Game Over (Run-Ending)**
- **Conditions**:
  1. `mistakes > mistakeTolerance.maxMistakes`
  2. `globalScore < 0` (or `currentScore < 0` on Level 1)
- **Actions**:
  1. Save current `globalScore` to leaderboard
  2. Reset all stats for new run
  3. No retry - must start completely new run

---

## 📝 **SPECIAL CASES**

### **Levels 9-10 (Non-Punitive Refresh)**
- Round timer: 1 second
- **No penalty** if player doesn't tap before timer expires
- Board just refreshes with new colors
- **No point deduction, no timeout counter increment**
- Still need to reach `requiredScore` to pass level

### **Level 1 Negative Score Check**
- Uses `currentScore < 0` instead of `globalScore < 0`
- Prevents immediate game over on first mistake when `globalScore` is still 0

### **Retry Logic**
- When retrying a level:
  - `currentScore` resets to 0
  - `levelPositivePoints` resets to 0
  - `levelMistakes` resets to 0
  - `levelTimeouts` resets to 0
  - `levelCorrectAnswers` resets to 0
  - **BUT**: `mistakes` (run-wide) and `globalScore` are **NOT reset**
  - Previous attempt's penalties remain in `globalScore`
  - Previous attempt's positive points are discarded

---

## 🎮 **GAME TYPE DIFFERENCES**

### **Color Only Mode**
- Correctness: Tile background color ≠ announced color
- Simpler logic

### **Color + Text Mode**
- Correctness: BOTH background color ≠ announced color AND text label ≠ announced color name
- Wrong if: background matches OR text matches
- More complex, Stroop-style interference

---

## 📊 **DISPLAYED VALUES**

### **Level Complete Screen**
- **"Your Score"**: `finalLevelScore = currentScore + perfectBonus`
- **"Total Score"**: `globalScore + levelPositivePoints + perfectBonus` (before `completeLevel()` is called)
- **Stat Blocks**:
  - 💎 Correct: `levelCorrectAnswers` (count)
  - 💔 Mistakes: `mistakesPenalty = levelMistakes * -10` (penalty points)
  - ⭐ Bonus: `perfectBonus` if perfect, else 0
  - ⏱️ Missed: `timeoutsPenalty = levelTimeouts * -5` (penalty points)

### **Level Failed Screen**
- **"Your Score"**: `finalLevelScore = currentScore + perfectBonus`
- **"Total Score"**: `globalScore + levelPositivePoints` (includes penalties from failed attempt)
- **Stat Blocks**: Same as Level Complete

### **Game Over Screen**
- **"Final Score"**: `globalScore + levelPositivePoints` (current total including penalties)

---

## ⚠️ **POTENTIAL ISSUES TO REVIEW**

1. **Insufficient Score Mistake**: Currently counts as 1 mistake but doesn't deduct points. Is this correct?

2. **Timeout vs Mistake**: Timeouts don't count as mistakes, only deduct 5 points. Is this intentional?

3. **Retry Penalties**: When retrying a level, penalties from the failed attempt remain in `globalScore`, but positive points are discarded. This means retrying can only make your score worse. Is this intended?

4. **Perfect Bonus Display**: On Level Complete screen, `totalScoreWithCurrentLevel` includes perfect bonus before `completeLevel()` is called. This might cause display inconsistency.

5. **Level 1 Negative Check**: Uses `currentScore` instead of `globalScore`. This is intentional to prevent immediate game over, but worth confirming.

