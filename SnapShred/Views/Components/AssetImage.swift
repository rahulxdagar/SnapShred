//
//  AssetImage.swift
//  SnapShred
//

import Photos
import SwiftUI

/// Loads and displays a PhotoKit asset at a size suited to its frame.
struct AssetImage: View {
    enum Style {
        /// Crops to fill the frame.
        case fill
        /// Shows the whole photo, letterboxed over a blurred copy of itself.
        case fitOverBlur
        /// Shows the whole photo on a transparent background.
        case fit
    }

    let asset: PHAsset
    var style: Style = .fill
    /// Overrides the requested pixel size, e.g. for tiny blurred backdrops.
    var pixelSize: CGSize?

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if style != .fit {
                    Rectangle().fill(.quaternary)
                }

                if let image {
                    switch style {
                    case .fill:
                        filled(image)
                    case .fitOverBlur:
                        filled(image)
                            .blur(radius: 40, opaque: true)
                            .overlay(.black.opacity(0.25))
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .fit:
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: RequestKey(id: asset.localIdentifier, size: requestSize(for: proxy.size))) {
                let size = requestSize(for: proxy.size)
                guard size.width > 0, size.height > 0 else { return }
                for await loaded in PhotoService.shared.images(for: asset, targetSize: size) {
                    image = loaded
                }
            }
        }
    }

    private struct RequestKey: Equatable {
        let id: String
        let size: CGSize
    }

    /// Pixel size to request, rounded up to 100px steps so small layout changes don't refetch.
    private func requestSize(for pointSize: CGSize) -> CGSize {
        if let pixelSize { return pixelSize }
        func bucket(_ value: CGFloat) -> CGFloat { (value * displayScale / 100).rounded(.up) * 100 }
        return CGSize(width: bucket(pointSize.width), height: bucket(pointSize.height))
    }

    private func filled(_ image: UIImage) -> some View {
        Color.clear.overlay {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
        .clipped()
    }
}
