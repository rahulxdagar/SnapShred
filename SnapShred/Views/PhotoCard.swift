//
//  PhotoCard.swift
//  SnapShred
//

import Photos
import SwiftUI

/// One photo in the deck, with its metadata floating on glass.
struct PhotoCard: View {
    let asset: PHAsset
    /// Direction the card is being dragged towards, with 0...1 strength.
    var pull: (direction: SwipeDirection, progress: CGFloat)?
    /// Only the top card plays motion, so cards underneath stay cheap.
    var isActive = false

    static let cornerRadius: CGFloat = 36

    var body: some View {
        AssetImage(asset: asset, style: .fitOverBlur)
            .overlay { motion }
            .overlay(alignment: .bottom) { details.padding(14) }
            .overlay { stamp }
            .clipShape(.rect(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1 + 3 * (pull?.progress ?? 0))
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
    }

    private var borderColor: Color {
        guard let pull else { return .white.opacity(0.18) }
        return pull.direction.tint.opacity(0.18 + 0.8 * pull.progress)
    }

    // MARK: Motion

    @ViewBuilder
    private var motion: some View {
        if isActive, asset.mediaType == .video {
            CardVideoPlayer(asset: asset)
        }
    }

    // MARK: Metadata

    private var details: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                if let date = asset.creationDate {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(date, format: .dateTime.day().month(.abbreviated).year())
                            .font(.subheadline.weight(.semibold))
                        Text(date, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                }

                Spacer(minLength: 0)

                ForEach(badges, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.footnote.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: .circle)
                }

                if asset.mediaType == .video {
                    Label(Duration.seconds(asset.duration).formatted(.time(pattern: .minuteSecond)), systemImage: "play.fill")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var badges: [String] {
        var symbols: [String] = []
        if asset.isFavorite { symbols.append("heart.fill") }
        if asset.mediaSubtypes.contains(.photoScreenshot) { symbols.append("camera.viewfinder") }
        if asset.mediaSubtypes.contains(.photoLive) { symbols.append("livephoto") }
        if asset.mediaSubtypes.contains(.photoPanorama) { symbols.append("pano") }
        if asset.mediaSubtypes.contains(.photoHDR) { symbols.append("camera.filters") }
        return symbols
    }

    // MARK: Stamp

    @ViewBuilder
    private var stamp: some View {
        if let pull, pull.progress > 0.02 {
            let (title, symbol, alignment, angle): (String, String, Alignment, Double) = switch pull.direction {
            case .left: ("SHRED", "trash.fill", .topTrailing, 14)
            case .right: ("KEEP", "checkmark", .topLeading, -14)
            case .up: ("FAVORITE", "star.fill", .center, 0)
            case .down: ("LATER", "clock.fill", .top, 0)
            }

            Label(title, systemImage: symbol)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .glassEffect(.regular.tint(pull.direction.tint.opacity(0.75)), in: .capsule)
                .rotationEffect(.degrees(angle))
                .scaleEffect(0.7 + 0.3 * pull.progress)
                .opacity(Double(pull.progress))
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .allowsHitTesting(false)
        }
    }
}
