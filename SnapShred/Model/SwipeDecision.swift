//
//  SwipeDecision.swift
//  SnapShred
//

import SwiftUI

/// The verdict a user gives a photo.
enum SwipeDecision: String, Codable {
    case keep
    case shred
    case favorite
}

/// The physical direction a card leaves the deck in.
enum SwipeDirection: Equatable {
    case left, right, up
    /// Decide later: the card goes to the back of the queue without a verdict.
    case down

    var decision: SwipeDecision? {
        switch self {
        case .left: .shred
        case .right: .keep
        case .up: .favorite
        case .down: nil
        }
    }

    var tint: Color {
        switch self {
        case .left: .shred
        case .right: .keep
        case .up: .favorite
        case .down: .later
        }
    }
}

extension Color {
    static let shred = Color(red: 1.0, green: 0.27, blue: 0.36)
    static let keep = Color(red: 0.16, green: 0.86, blue: 0.56)
    static let favorite = Color(red: 1.0, green: 0.78, blue: 0.2)
    static let later = Color(red: 0.35, green: 0.62, blue: 1.0)
}
