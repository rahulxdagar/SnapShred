//
//  CardLivePhoto.swift
//  SnapShred
//

import Photos
import PhotosUI
import SwiftUI

/// Plays a Live Photo once, silently, when its card reaches the top of the deck.
struct CardLivePhoto: View {
    let asset: PHAsset

    @Environment(\.displayScale) private var displayScale
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let livePhoto {
                    LivePhotoView(livePhoto: livePhoto)
                }
            }
            .task(id: asset.localIdentifier) {
                let size = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
                guard size.width > 0, size.height > 0 else { return }
                livePhoto = await PhotoService.shared.livePhoto(for: asset, targetSize: size)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.isMuted = true
        // The card's drag gesture owns touches; playback is automatic instead.
        view.playbackGestureRecognizer.isEnabled = false
        view.livePhoto = livePhoto
        play(view)
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        guard view.livePhoto !== livePhoto else { return }
        view.livePhoto = livePhoto
        play(view)
    }

    private func play(_ view: PHLivePhotoView) {
        // Playback only starts once the view is in a window.
        DispatchQueue.main.async {
            view.startPlayback(with: .full)
        }
    }
}
