import SwiftUI

extension GameType {
  var brandLabel: LocalizedStringKey {
    switch self {
    case .colorOnly: "COLOR"
    case .colorAndText: "COLOR+WORD"
    case .colorMatch: "MATCH"
    }
  }
}

extension MistakeTolerance {
  var brandLabel: LocalizedStringKey {
    switch self {
    case .easy: "ROOKIE"
    case .normal: "PRO"
    case .hard: "MASTER"
    }
  }
}
