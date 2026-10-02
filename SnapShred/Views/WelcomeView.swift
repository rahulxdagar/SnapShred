//
//  WelcomeView.swift
//  SnapShred
//

import SwiftUI

/// First-run screen that explains the gestures and asks for library access.
struct WelcomeView: View {
    @Environment(LibraryAuthorization.self) private var authorization
    @Environment(\.openURL) private var openURL

    @State private var fanned = false

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 32) {
                Spacer(minLength: 0)
                hero
                titleBlock
                rules
                Spacer(minLength: 0)
                primaryButton
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.35).delay(0.15)) { fanned = true }
        }
    }

    private var hero: some View {
        ZStack {
            heroCard(symbol: "xmark", tint: .shred, angle: -14, x: -96)
            heroCard(symbol: "heart.fill", tint: .keep, angle: 14, x: 96)
            heroCard(symbol: "photo.on.rectangle.angled", tint: .accentColor, angle: 0, x: 0)
        }
        .frame(height: 190)
    }

    private func heroCard(symbol: String, tint: Color?, angle: Double, x: CGFloat) -> some View {
        // Rotate the glass shape itself; rotating a glass view distorts its refraction.
        let rotation = Angle.degrees(fanned ? angle : 0)
        return Image(systemName: symbol)
            .font(.system(size: 40, weight: .bold))
            .rotationEffect(rotation)
            .frame(width: 112, height: 152)
            .glassEffect(
                .regular.tint(tint?.opacity(0.6)).interactive(),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous).rotation(rotation)
            )
            .offset(x: fanned ? x : 0, y: fanned ? abs(x) * 0.15 : 0)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("SnapShred")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
            Text("Swipe through your library.\nKeep what you love, shred the rest.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            rule("arrow.left", tint: .shred, "Swipe left to mark for shredding")
            rule("arrow.right", tint: .keep, "Swipe right to keep")
            rule("arrow.up", tint: .favorite, "Swipe up to keep and favorite")
            rule("arrow.down", tint: .later, "Swipe down to decide later")
            rule("lock.shield", tint: .white, "Nothing is deleted until you confirm")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func rule(_ symbol: String, tint: Color, _ text: String) -> some View {
        Label {
            Text(text).font(.callout.weight(.medium))
        } icon: {
            Image(systemName: symbol)
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if authorization.wasDenied {
            VStack(spacing: 10) {
                Text("SnapShred needs access to your photos to show them to you.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Open Settings").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
            }
        } else {
            Button {
                Task { await authorization.request() }
            } label: {
                Text("Get Started").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(LibraryAuthorization())
}
