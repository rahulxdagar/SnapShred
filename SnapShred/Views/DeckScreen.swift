//
//  DeckScreen.swift
//  SnapShred
//

import Photos
import SwiftUI

/// The main swiping experience.
struct DeckScreen: View {
    @Environment(SwipeSession.self) private var session

    @State private var drag: CGSize = .zero
    @State private var isFlying = false
    @State private var armedDirection: SwipeDirection?
    @State private var lastSwipe: SwipeDirection?
    @State private var swipeCount = 0
    @State private var undoCount = 0
    @State private var showBin = false
    @State private var confirmReset = false
    @State private var cardSize: CGSize = .zero

    private let threshold: CGFloat = 110

    var body: some View {
        NavigationStack {
            ZStack {
                backdrop
                content
            }
            .navigationTitle(session.filter.title)
            .navigationSubtitle(subtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) {
                if !session.deck.isEmpty { controls }
            }
            .sheet(isPresented: $showBin) {
                ReviewBinView()
            }
            .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset Progress", role: .destructive) { session.resetProgress() }
            } message: {
                Text("Every photo will be shown again and the shred bin will be emptied. Nothing is deleted.")
            }
        }
        .sensoryFeedback(.selection, trigger: armedDirection) { _, new in new != nil }
        .sensoryFeedback(trigger: swipeCount) {
            lastSwipe == .left ? .impact(weight: .heavy) : .impact(weight: .light)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: undoCount)
        .task {
            if !session.isLoaded { session.reload() }
        }
    }

    private var subtitle: String {
        guard session.isLoaded else { return "Loading…" }
        return "\(session.remaining.formatted()) left to review"
    }

    // MARK: Backdrop

    /// The current photo, blown up and blurred, washed with the color of the pending verdict.
    private var backdrop: some View {
        ZStack {
            AmbientBackground()

            if let top = session.deck.first {
                AssetImage(asset: top, pixelSize: CGSize(width: 160, height: 160))
                    .blur(radius: 60, opaque: true)
                    .saturation(1.4)
                    .opacity(0.75)
                    .id(top.localIdentifier)
                    .transition(.opacity)
            }

            if let pull {
                pull.direction.tint
                    .opacity(0.35 * pull.progress)
                    .blendMode(.plusLighter)
            }

            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: session.deck.first?.localIdentifier)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if !session.isLoaded {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        } else if session.deck.isEmpty {
            CompletionView(showBin: $showBin, resetProgress: { confirmReset = true })
                .transition(.scale(0.9).combined(with: .opacity))
        } else {
            cardStack
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
    }

    private var cardStack: some View {
        let visible = Array(session.deck.prefix(3).enumerated())
        return ZStack {
            ForEach(visible.reversed(), id: \.element.localIdentifier) { index, asset in
                let isTop = index == 0
                let depth = max(0, CGFloat(index) - (pull?.progress ?? 0))

                PhotoCard(asset: asset, pull: isTop ? pull : nil)
                    .scaleEffect(1 - depth * 0.06)
                    .offset(y: depth * 22)
                    .brightness(-Double(depth) * 0.08)
                    .offset(isTop ? drag : .zero)
                    .rotationEffect(.degrees(isTop ? Double(drag.width / 22) : 0), anchor: .bottom)
                    .gesture(dragGesture, isEnabled: isTop && !isFlying)
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: asset))
                    .accessibilityHint("Swipe left to shred, right to keep, up to favorite.")
                    .accessibilityAction(named: "Shred") { commit(.left) }
                    .accessibilityAction(named: "Keep") { commit(.right) }
                    .accessibilityAction(named: "Favorite") { commit(.up) }
                    .zIndex(Double(-index))
            }
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { cardSize = $0 }
    }

    private func accessibilityLabel(for asset: PHAsset) -> String {
        let kind = asset.mediaType == .video ? "Video" : "Photo"
        guard let date = asset.creationDate else { return kind }
        return "\(kind) from \(date.formatted(date: .long, time: .omitted))"
    }

    // MARK: Gesture

    /// The direction and strength (0...1) the top card is currently being pulled.
    private var pull: (direction: SwipeDirection, progress: CGFloat)? {
        let horizontal = abs(drag.width)
        let vertical = -drag.height
        if vertical > horizontal, vertical > 8 {
            return (.up, min(1, vertical / threshold))
        }
        guard horizontal > 8 else { return nil }
        return (drag.width < 0 ? .left : .right, min(1, horizontal / threshold))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
                armedDirection = (pull?.progress ?? 0) >= 1 ? pull?.direction : nil
            }
            .onEnded { value in
                armedDirection = nil
                let predicted = value.predictedEndTranslation
                let t = value.translation

                if t.width < -threshold || predicted.width < -threshold * 2.5 && abs(t.width) > abs(t.height) {
                    commit(.left)
                } else if t.width > threshold || predicted.width > threshold * 2.5 && abs(t.width) > abs(t.height) {
                    commit(.right)
                } else if -t.height > threshold || -predicted.height > threshold * 2.5 {
                    commit(.up)
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) { drag = .zero }
                }
            }
    }

    private func offscreen(_ direction: SwipeDirection) -> CGSize {
        let width = max(cardSize.width, 300) * 1.6
        let height = max(cardSize.height, 500) * 1.4
        switch direction {
        case .left: return CGSize(width: -width, height: drag.height + 40)
        case .right: return CGSize(width: width, height: drag.height + 40)
        case .up: return CGSize(width: drag.width, height: -height)
        }
    }

    /// Flings the top card off screen, then records the verdict.
    private func commit(_ direction: SwipeDirection) {
        guard !isFlying, !session.deck.isEmpty else { return }
        isFlying = true
        lastSwipe = direction

        withAnimation(.easeOut(duration: 0.26)) {
            drag = offscreen(direction)
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                session.swipe(direction)
                drag = .zero
            }
            swipeCount += 1
            isFlying = false
        }
    }

    /// Brings the last card back from the side it left.
    private func undo() {
        guard !isFlying, session.canUndo else { return }
        isFlying = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if let direction = session.undo() {
                drag = offscreen(direction)
            }
        }
        undoCount += 1

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                drag = .zero
            } completion: {
                isFlying = false
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        let pull = pull
        func emphasis(_ direction: SwipeDirection) -> CGFloat {
            pull?.direction == direction ? pull?.progress ?? 0 : 0
        }

        return GlassEffectContainer(spacing: 24) {
            HStack(spacing: 18) {
                GlassActionButton(title: "Undo", systemImage: "arrow.uturn.backward", diameter: 52) {
                    undo()
                }
                .disabled(!session.canUndo)

                GlassActionButton(title: "Shred", systemImage: "xmark", tint: .shred, diameter: 76, emphasis: emphasis(.left)) {
                    commit(.left)
                }

                GlassActionButton(title: "Favorite", systemImage: "star.fill", tint: .favorite, diameter: 52, emphasis: emphasis(.up)) {
                    commit(.up)
                }

                GlassActionButton(title: "Keep", systemImage: "heart.fill", tint: .keep, diameter: 76, emphasis: emphasis(.right)) {
                    commit(.right)
                }
            }
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var session = session

        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Show", selection: $session.filter) {
                    ForEach(LibraryFilter.allCases) { filter in
                        Label(filter.title, systemImage: filter.systemImage).tag(filter)
                    }
                }
                Picker("Order", selection: $session.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }

                Section {
                    Button("Reset Progress", systemImage: "arrow.counterclockwise", role: .destructive) {
                        confirmReset = true
                    }
                } header: {
                    Text("Shredded \(session.lifetimeShredded.formatted()) · Freed \(Int64(session.lifetimeBytesFreed).formatted(.byteCount(style: .file)))")
                }
            } label: {
                Label("Options", systemImage: "line.3.horizontal.decrease")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showBin = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: session.bin.isEmpty ? "trash" : "trash.fill")
                    if !session.bin.isEmpty {
                        Text(session.bin.count, format: .number)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(session.bin.count)))
                    }
                }
                .foregroundStyle(session.bin.isEmpty ? Color.primary : Color.shred)
                .animation(.snappy, value: session.bin.count)
            }
            .accessibilityLabel("Shred bin, \(session.bin.count) items")
        }
    }
}
