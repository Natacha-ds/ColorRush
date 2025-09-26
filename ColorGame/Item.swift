//
//  Item.swift
//  ColorGame
//
//  Created by Natacha Dehass on 26/09/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
