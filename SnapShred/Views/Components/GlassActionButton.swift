//
//  GlassActionButton.swift
//  SnapShred
//

import SwiftUI

/// A round, interactive Liquid Glass button used for the deck controls.
struct GlassActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color?
    var diameter: CGFloat = 64
    /// 0...1 — how strongly the current drag is pointing at this action.
    var emphasis: CGFloat = 0
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.36, weight: .bold))
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.35))
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .circle)
        .scaleEffect(1 + 0.18 * emphasis)
        .accessibilityLabel(title)
    }

    private var glass: Glass {
        guard let tint else { return .regular.interactive() }
        return .regular.tint(tint.opacity(0.55 + 0.4 * emphasis)).interactive()
    }
}
