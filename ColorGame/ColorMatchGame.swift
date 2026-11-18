import Combine
import SwiftUI

// MARK: - Cards

/// The eight colors used by Color Match. Softer than the system primaries so
/// they stay comfortable as a full-screen background.
enum MatchColor: CaseIterable, Equatable {
  case red, orange, yellow, green, blue, purple, pink, gray

  var color: Color {
    switch self {
    case .red: Color(hex: 0xE5484D)
    case .orange: Color(hex: 0xF0803C)
    case .yellow: Color(hex: 0xE8B931)
    case .green: Color(hex: 0x30A46C)
    case .blue: Color(hex: 0x3E63DD)
    case .purple: Color(hex: 0x8E4EC6)
    case .pink: Color(hex: 0xE5588F)
    case .gray: Color(hex: 0x6E7681)
    }
  }

  /// Localized, uppercase name shown at the center of the card.
  var name: String {
    switch self {
    case .red: String(localized: "RED")
    case .orange: String(localized: "ORANGE")
    case .yellow: String(localized: "YELLOW")
    case .green: String(localized: "GREEN")
    case .blue: String(localized: "BLUE")
    case .purple: String(localized: "PURPLE")
    case .pink: String(localized: "PINK")
    case .gray: String(localized: "GRAY")
    }
  }
}

struct MatchCard: Equatable {
  /// Color named by the written word.
  let word: MatchColor
  /// Color of the full-screen background.
  let background: MatchColor

  /// True when the background is the color named by the word (✓ is correct).
  var isMatch: Bool { word == background }
}

// MARK: - Game logic

/// Pure game state for Color Match: no SwiftUI view code, driven by explicit
/// `tick(_:)` / `answer(_:)` calls so it can be unit-tested.
final class ColorMatchGame: ObservableObject {
  enum Phase: Equatable {
    case playing
    case over(reason: EndReason)
  }

  enum EndReason: Equatable {
    case wrongAnswer
    case timeout
  }

  // MARK: Tuning

  static let initialTime: TimeInterval = 3.0
  static let decayPerCard: Double = 0.96
  static let minimumTime: TimeInterval = 0.7
  /// Max consecutive cards sharing the same correct answer.
  static let maxSameAnswerStreak = 3

  /// Time allowed for the card shown after `correct` correct answers.
  static func timeBudget(afterCorrect correct: Int) -> TimeInterval {
    max(minimumTime, initialTime * pow(decayPerCard, Double(max(0, correct))))
  }

  /// Generates the next card. Half the cards match; a streak of
  /// `maxSameAnswerStreak` identical answers forces the opposite answer.
  static func makeCard(
    previousAnswers: [Bool],
    using rng: inout some RandomNumberGenerator
  ) -> MatchCard {
    let recent = previousAnswers.suffix(maxSameAnswerStreak)
    let shouldMatch: Bool
    if recent.count == maxSameAnswerStreak, let first = recent.first,
       recent.allSatisfy({ $0 == first }) {
      shouldMatch = !first
    } else {
      shouldMatch = Bool.random(using: &rng)
    }
    let word = MatchColor.allCases.randomElement(using: &rng) ?? .red
    if shouldMatch {
      return MatchCard(word: word, background: word)
    }
    let background = MatchColor.allCases.filter { $0 != word }.randomElement(using: &rng) ?? .blue
    return MatchCard(word: word, background: background)
  }

  // MARK: State

  @Published private(set) var score = 0
  @Published private(set) var card: MatchCard
  @Published private(set) var remaining: TimeInterval
  @Published private(set) var phase: Phase = .playing

  private(set) var budget: TimeInterval
  private var answers: [Bool] = []
  private var rng: any RandomNumberGenerator

  var isOver: Bool {
    if case .over = phase { return true }
    return false
  }

  /// 1 → full time left, 0 → out of time.
  var progress: Double { budget > 0 ? max(0, min(1, remaining / budget)) : 0 }

  init(rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
    var generator = rng
    let first = Self.makeCard(previousAnswers: [], using: &generator)
    self.rng = generator
    card = first
    budget = Self.timeBudget(afterCorrect: 0)
    remaining = Self.timeBudget(afterCorrect: 0)
    answers = [first.isMatch]
  }

  // MARK: Actions

  /// Starts a fresh run (score 0, first-card time budget).
  func reset() {
    var generator = rng
    let first = Self.makeCard(previousAnswers: [], using: &generator)
    rng = generator
    score = 0
    card = first
    answers = [first.isMatch]
    budget = Self.timeBudget(afterCorrect: 0)
    remaining = budget
    phase = .playing
  }

  /// Submits the player's answer for the current card.
  /// - Returns: `true` when the answer was correct.
  @discardableResult
  func answer(isSame: Bool) -> Bool {
    guard !isOver else { return false }
    guard isSame == card.isMatch else {
      phase = .over(reason: .wrongAnswer)
      return false
    }
    score += 1
    advance()
    return true
  }

  /// Advances the countdown. Reaching zero ends the run.
  func tick(_ dt: TimeInterval) {
    guard !isOver, dt > 0 else { return }
    remaining -= dt
    if remaining <= 0 {
      remaining = 0
      phase = .over(reason: .timeout)
    }
  }

  private func advance() {
    var generator = rng
    let next = Self.makeCard(previousAnswers: answers, using: &generator)
    rng = generator
    card = next
    answers.append(next.isMatch)
    budget = Self.timeBudget(afterCorrect: score)
    remaining = budget
  }
}
