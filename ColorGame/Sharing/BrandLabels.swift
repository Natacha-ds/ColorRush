import SwiftUI

extension GameType {
  var brandLabel: LocalizedStringKey {
    switch self {
    case .colorOnly: "COLOR"
    case .colorAndText: "COLOR+WORD"
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
