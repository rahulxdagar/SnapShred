// Renders SnapShred's app icon variants into the asset catalog.
//
//   swift Tools/RenderAppIcon.swift
//
// The icon is a frosted-glass photo card whose lower half is being shredded
// into falling strips, over the same mesh gradient the app uses as its backdrop.

import AppKit
import SwiftUI

let size: CGFloat = 1024

enum Variant: String, CaseIterable {
    case light = "AppIcon"
    case dark = "AppIcon-Dark"
    case tinted = "AppIcon-Tinted"
}

// MARK: Background

struct Backdrop: View {
    let variant: Variant

    var body: some View {
        switch variant {
        case .light:
            MeshGradient(
                width: 3, height: 3,
                points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.58, 0.42], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                colors: [
                    Color(red: 0.20, green: 0.10, blue: 0.48), Color(red: 0.38, green: 0.16, blue: 0.70), Color(red: 0.12, green: 0.30, blue: 0.62),
                    Color(red: 0.78, green: 0.20, blue: 0.52), Color(red: 0.46, green: 0.32, blue: 0.98), Color(red: 0.10, green: 0.62, blue: 0.70),
                    Color(red: 0.98, green: 0.36, blue: 0.42), Color(red: 0.92, green: 0.30, blue: 0.48), Color(red: 0.18, green: 0.42, blue: 0.62),
                ]
            )
        case .dark:
            MeshGradient(
                width: 3, height: 3,
                points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.58, 0.42], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.12), Color(red: 0.10, green: 0.05, blue: 0.20), Color(red: 0.03, green: 0.07, blue: 0.16),
                    Color(red: 0.22, green: 0.05, blue: 0.18), Color(red: 0.16, green: 0.10, blue: 0.38), Color(red: 0.03, green: 0.18, blue: 0.22),
                    Color(red: 0.30, green: 0.08, blue: 0.14), Color(red: 0.26, green: 0.07, blue: 0.16), Color(red: 0.05, green: 0.10, blue: 0.16),
                ]
            )
        case .tinted:
            // Tinted icons are rendered in grayscale; iOS applies the user's tint.
            LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: Card

/// The picture printed on the card: a sun over two mountain ridges.
struct Landscape: View {
    let variant: Variant

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if variant == .tinted {
                    LinearGradient(colors: [Color(white: 0.55), Color(white: 0.30)], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.62, blue: 0.48), Color(red: 0.74, green: 0.38, blue: 0.96), Color(red: 0.30, green: 0.30, blue: 0.86)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                Circle()
                    .fill(variant == .tinted ? AnyShapeStyle(Color(white: 0.95)) : AnyShapeStyle(
                        LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.70), Color(red: 1, green: 0.74, blue: 0.40)], startPoint: .top, endPoint: .bottom)
                    ))
                    .frame(width: w * 0.30, height: w * 0.30)
                    .shadow(color: .white.opacity(0.6), radius: w * 0.05)
                    .position(x: w * 0.68, y: h * 0.28)

                Ridge(peaks: [(0, 0.78), (0.28, 0.52), (0.52, 0.70), (0.80, 0.44), (1, 0.62)])
                    .fill(variant == .tinted ? Color(white: 0.22) : Color(red: 0.24, green: 0.16, blue: 0.52).opacity(0.9))
                Ridge(peaks: [(0, 0.70), (0.22, 0.86), (0.46, 0.62), (0.74, 0.88), (1, 0.76)])
                    .fill(variant == .tinted ? Color(white: 0.12) : Color(red: 0.12, green: 0.08, blue: 0.30))
            }
        }
    }
}

struct Ridge: Shape {
    let peaks: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (x, y) in peaks {
            path.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A glass-framed photo: frosted border, specular rim and the landscape inset.
struct GlassCard: View {
    let variant: Variant
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let radius = width * 0.14
        let inset = width * 0.07
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.white.opacity(variant == .dark ? 0.14 : 0.26))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Landscape(variant: variant)
                .clipShape(.rect(cornerRadius: radius - inset * 0.7, style: .continuous))
                .padding(inset)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: width * 0.012
                )
        }
        .frame(width: width, height: height)
    }
}

/// The card with its bottom part cut into strips that drift apart.
struct ShreddedCard: View {
    let variant: Variant

    let width: CGFloat = 520
    let height: CGFloat = 640
    let cut: CGFloat = 0.58
    let strips = 6

    var body: some View {
        let stripWidth = width / CGFloat(strips)
        let cutY = height * cut
        // Small, hand-tuned drift for each strip so the shred looks organic.
        let drops: [CGFloat] = [58, 30, 72, 40, 80, 50]
        let tilts: [Double] = [-6, -3.5, -1, 1.5, 4, 7]
        let spreads: [CGFloat] = [-34, -20, -7, 7, 20, 34]

        ZStack(alignment: .topLeading) {
            ForEach(0..<strips, id: \.self) { i in
                GlassCard(variant: variant, width: width, height: height)
                    .mask(alignment: .topLeading) {
                        Rectangle()
                            .frame(width: stripWidth - 4, height: height - cutY)
                            .offset(x: CGFloat(i) * stripWidth + 2, y: cutY)
                    }
                    .rotationEffect(.degrees(tilts[i]), anchor: UnitPoint(x: (CGFloat(i) + 0.5) / CGFloat(strips), y: cut))
                    .offset(x: spreads[i], y: drops[i])
                    .opacity(0.96)
            }

            GlassCard(variant: variant, width: width, height: height)
                .mask(alignment: .top) {
                    Rectangle().frame(width: width, height: cutY)
                }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(variant == .light ? 0.30 : 0.55), radius: 40, y: 24)
    }
}

// MARK: Icon

struct AppIcon: View {
    let variant: Variant

    var body: some View {
        ZStack {
            Backdrop(variant: variant)

            // Soft glow behind the card.
            Circle()
                .fill(variant == .tinted ? Color.white.opacity(0.12) : Color(red: 0.75, green: 0.55, blue: 1).opacity(0.45))
                .frame(width: 640, height: 640)
                .blur(radius: 120)
                .offset(y: -40)

            ShreddedCard(variant: variant)
                .rotationEffect(.degrees(-6))
                .offset(y: -50)
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

// MARK: Export

@MainActor
func export() throws {
    let output = URL(fileURLWithPath: "SnapShred/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
    for variant in Variant.allCases {
        let renderer = ImageRenderer(content: AppIcon(variant: variant))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }

        // App icons must be opaque, so flatten onto an RGB context without alpha.
        let context = CGContext(
            data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        let data = rep.representation(using: .png, properties: [:])!
        try data.write(to: output.appending(path: "\(variant.rawValue).png"))
        print("Wrote \(variant.rawValue).png")
    }
}

try MainActor.assumeIsolated { try export() }
