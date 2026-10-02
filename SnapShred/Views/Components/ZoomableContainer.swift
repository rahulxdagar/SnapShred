//
//  ZoomableContainer.swift
//  SnapShred
//

import SwiftUI

/// Pinch to zoom, drag to pan, double-tap to toggle zoom. When not zoomed,
/// dragging down past a threshold calls `onSwipeDown`; a single tap calls `onTap`.
struct ZoomableContainer<Content: View>: View {
    var maxScale: CGFloat = 5
    var onSwipeDown: () -> Void = {}
    var onTap: () -> Void = {}
    @ViewBuilder var content: Content

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private let dismissThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            content
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(.rect)
                .gesture(magnify(in: proxy.size))
                .simultaneousGesture(pan(in: proxy.size))
                // The double tap must be attached first so a single tap waits for it to fail.
                .onTapGesture(count: 2) { location in
                    toggleZoom(at: location, in: proxy.size)
                }
                .onTapGesture(perform: onTap)
        }
    }

    private var isZoomed: Bool { committedScale > 1.01 }

    // MARK: Gestures

    private func magnify(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Allow a little rubber-banding past the limits while pinching.
                scale = min(max(committedScale * value.magnification, 0.8), maxScale * 1.2)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    scale = min(max(scale, 1), maxScale)
                    committedScale = scale
                    offset = scale > 1.01 ? clamped(offset, in: size) : .zero
                    committedOffset = offset
                }
            }
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if isZoomed {
                    offset = CGSize(
                        width: committedOffset.width + value.translation.width,
                        height: committedOffset.height + value.translation.height
                    )
                } else {
                    // Only downward motion, for pull-to-dismiss.
                    offset = CGSize(width: 0, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if !isZoomed, value.translation.height > dismissThreshold {
                    onSwipeDown()
                    return
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    offset = isZoomed ? clamped(offset, in: size) : .zero
                    committedOffset = offset
                }
            }
    }

    private func toggleZoom(at location: CGPoint, in size: CGSize) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if isZoomed {
                scale = 1
                offset = .zero
            } else {
                // Keep the tapped point under the finger.
                scale = 2.5
                let fromCenter = CGSize(width: location.x - size.width / 2, height: location.y - size.height / 2)
                offset = clamped(CGSize(width: -fromCenter.width * (scale - 1), height: -fromCenter.height * (scale - 1)), in: size)
            }
            committedScale = scale
            committedOffset = offset
        }
    }

    /// Keeps the zoomed content covering the frame instead of drifting off screen.
    private func clamped(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}
