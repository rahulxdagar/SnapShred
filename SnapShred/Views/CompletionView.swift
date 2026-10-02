//
//  CompletionView.swift
//  SnapShred
//

import SwiftUI

/// Shown once every photo in the current filter has a verdict.
struct CompletionView: View {
    @Environment(SwipeSession.self) private var session
    @Binding var showBin: Bool
    let resetProgress: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: isEmptyFilter ? session.filter.systemImage : "sparkles")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: appeared)
                .frame(width: 128, height: 128)
                .glassEffect(.regular.tint(.accentColor.opacity(0.35)), in: .circle)

            VStack(spacing: 8) {
                Text(isEmptyFilter ? session.filter.emptyTitle : "All Caught Up")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)

            if !isEmptyFilter {
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        stat(value: session.sessionKept, label: "Kept", tint: .keep)
                        stat(value: session.bin.count, label: "To Shred", tint: .shred)
                    }
                }
            }

            VStack(spacing: 12) {
                if !session.bin.isEmpty {
                    Button {
                        showBin = true
                    } label: {
                        Label("Review \(session.bin.count) to Shred", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.shred)
                    .controlSize(.extraLarge)
                }

                if isEmptyFilter {
                    Button("Show All Photos", systemImage: "photo.on.rectangle.angled") {
                        session.filter = .photos
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                } else {
                    Button("Start Over", systemImage: "arrow.counterclockwise", action: resetProgress)
                        .buttonStyle(.glass)
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: 340)
        }
        .padding(32)
        .onAppear { appeared = true }
    }

    private var isEmptyFilter: Bool { session.totalInFilter == 0 }

    private var message: String {
        if isEmptyFilter {
            return session.filter.emptyMessage
        }
        return session.bin.isEmpty
            ? "You've reviewed every item in \(session.filter.title)."
            : "Take one last look before they're gone."
    }

    private func stat(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption.weight(.medium))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .frame(width: 120, height: 84)
        .glassEffect(.regular.tint(tint.opacity(0.3)), in: .rect(cornerRadius: 24))
    }
}
