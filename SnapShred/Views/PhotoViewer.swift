//
//  PhotoViewer.swift
//  SnapShred
//

import Photos
import SwiftUI

/// Full-screen, zoomable look at a photo, with the same verdict buttons as the deck.
struct PhotoViewer: View {
    let asset: PHAsset
    /// Called with the chosen verdict just before the viewer dismisses.
    let decide: (SwipeDirection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsChrome = true

    /// Large enough to stay sharp when zoomed, without loading the full original.
    private static let pixelSize = CGSize(width: 3000, height: 3000)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZoomableContainer(
                onSwipeDown: { dismiss() },
                onTap: { withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() } }
            ) {
                AssetImage(asset: asset, style: .fit, pixelSize: Self.pixelSize)
            }
            .ignoresSafeArea()

            if showsChrome {
                chrome.transition(.opacity)
            }
        }
        .statusBarHidden(!showsChrome)
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack {
            HStack(alignment: .top) {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .buttonStyle(.plain)

                Spacer()

                info
            }
            .padding(.horizontal, 20)

            Spacer()

            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 22) {
                    GlassActionButton(title: "Shred", systemImage: "xmark", tint: .shred, diameter: 64) { choose(.left) }
                    GlassActionButton(title: "Favorite", systemImage: "star.fill", tint: .favorite, diameter: 52) { choose(.up) }
                    GlassActionButton(title: "Keep", systemImage: "heart.fill", tint: .keep, diameter: 64) { choose(.right) }
                }
            }
            .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
    }

    private var info: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let date = asset.creationDate {
                Text(date, format: .dateTime.day().month(.wide).year())
                    .font(.subheadline.weight(.semibold))
                Text(date, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.caption)
                    .opacity(0.75)
            }
            Text("\(asset.pixelWidth.formatted()) × \(asset.pixelHeight.formatted())")
                .font(.caption.monospacedDigit())
                .opacity(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func choose(_ direction: SwipeDirection) {
        decide(direction)
        dismiss()
    }
}
