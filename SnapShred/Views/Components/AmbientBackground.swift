//
//  AmbientBackground.swift
//  SnapShred
//

import SwiftUI

/// A slowly drifting mesh gradient that gives the glass something to refract.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = Float(timeline.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5 + 0.18 * sin(t * 0.35), 0.5 + 0.14 * cos(t * 0.28)], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.10, green: 0.06, blue: 0.24), Color(red: 0.26, green: 0.10, blue: 0.42), Color(red: 0.05, green: 0.12, blue: 0.30),
                    Color(red: 0.55, green: 0.12, blue: 0.40), Color(red: 0.32, green: 0.22, blue: 0.85), Color(red: 0.06, green: 0.40, blue: 0.52),
                    Color(red: 0.08, green: 0.05, blue: 0.16), Color(red: 0.85, green: 0.25, blue: 0.35), Color(red: 0.10, green: 0.08, blue: 0.22),
                ]
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AmbientBackground()
}
