import Testing
@testable import ColorGame

/// Deterministic RNG (SplitMix64) so card generation is reproducible.
private struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

struct ColorMatchGameTests {
  @Test func cardsAreBalancedAndNeverRepeatAnswerMoreThanThreeTimes() {
    var rng = SeededGenerator(state: 42)
    var answers: [Bool] = []
    for _ in 0..<2000 {
      let card = ColorMatchGame.makeCard(previousAnswers: answers, using: &rng)
      answers.append(card.isMatch)
    }
    let matches = answers.filter { $0 }.count
    #expect(matches > 800 && matches < 1200)

    var run = 1
    for i in 1..<answers.count {
      run = answers[i] == answers[i - 1] ? run + 1 : 1
      #expect(run <= ColorMatchGame.maxSameAnswerStreak)
    }
  }

  @Test func timeBudgetShrinksAndHasFloor() {
    var previous = ColorMatchGame.timeBudget(afterCorrect: 0)
    #expect(previous == ColorMatchGame.initialTime)
    for n in 1...200 {
      let budget = ColorMatchGame.timeBudget(afterCorrect: n)
      #expect(budget <= previous)
      #expect(budget >= ColorMatchGame.minimumTime)
      previous = budget
    }
    #expect(ColorMatchGame.timeBudget(afterCorrect: 200) == ColorMatchGame.minimumTime)
  }

  @Test func correctAnswerScoresAndAdvances() {
    let game = ColorMatchGame(rng: SeededGenerator(state: 1))
    game.tick(1.0)
    let correct = game.answer(isSame: game.card.isMatch)
    #expect(correct)
    #expect(game.score == 1)
    #expect(game.phase == .playing)
    #expect(game.remaining == game.budget) // timer reset for the new card
    #expect(game.budget == ColorMatchGame.timeBudget(afterCorrect: 1))
  }

  @Test func firstWrongAnswerEndsTheRun() {
    let game = ColorMatchGame(rng: SeededGenerator(state: 2))
    _ = game.answer(isSame: game.card.isMatch)
    let correct = game.answer(isSame: !game.card.isMatch)
    #expect(!correct)
    #expect(game.score == 1)
    #expect(game.phase == .over(reason: .wrongAnswer))
    // Further input is ignored.
    #expect(!game.answer(isSame: game.card.isMatch))
    #expect(game.score == 1)
  }

  @Test func timeoutEndsTheRun() {
    let game = ColorMatchGame(rng: SeededGenerator(state: 3))
    game.tick(ColorMatchGame.initialTime - 0.1)
    #expect(game.phase == .playing)
    game.tick(0.2)
    #expect(game.phase == .over(reason: .timeout))
    #expect(game.remaining == 0)
  }

  @Test func resetStartsAFreshRun() {
    let game = ColorMatchGame(rng: SeededGenerator(state: 4))
    _ = game.answer(isSame: game.card.isMatch)
    _ = game.answer(isSame: !game.card.isMatch)
    #expect(game.isOver)
    game.reset()
    #expect(game.score == 0)
    #expect(game.phase == .playing)
    #expect(game.remaining == ColorMatchGame.initialTime)
  }

  @Test func leaderboardKeyStorage() {
    #expect(LeaderboardKey(gameType: .colorOnly, mistakeTolerance: .easy).storageKey == "leaderboard.colorOnly.easy")
    #expect(LeaderboardKey(gameType: .colorMatch, mistakeTolerance: nil).storageKey == "leaderboard.colorMatch")
    #expect(LeaderboardKey.all.count == 7)
  }
}
