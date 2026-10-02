//
//  CardVideoPlayer.swift
//  SnapShred
//

import AVFoundation
import Photos
import SwiftUI

/// Loops a video silently on top of its card, with a glass mute toggle.
///
/// It sits exactly over the card's still frame (both are aspect-fit). The player
/// layer stays transparent until its first frame renders, so the hand-off is seamless.
struct CardVideoPlayer: View {
    let asset: PHAsset

    @AppStorage("cardVideosMuted") private var isMuted = true
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let player {
                PlayerLayerView(player: player)
                    .allowsHitTesting(false)
            }

            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(14)
            .accessibilityLabel(isMuted ? "Unmute video" : "Mute video")
        }
        .task(id: asset.localIdentifier) { await start() }
        .onChange(of: isMuted) { player?.isMuted = isMuted }
        .onDisappear(perform: stop)
    }

    private func start() async {
        // Mix with other audio so a silent autoplay never stops the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)

        guard let item = await PhotoService.shared.playerItem(for: asset), !Task.isCancelled else { return }
        let queue = AVQueuePlayer()
        queue.isMuted = isMuted
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        queue.play()
    }

    private func stop() {
        player?.pause()
        looper = nil
        player = nil
    }
}

/// Hosts an `AVPlayerLayer` without the system playback controls.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
