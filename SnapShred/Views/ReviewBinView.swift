//
//  ReviewBinView.swift
//  SnapShred
//

import Photos
import SwiftUI

/// The last stop before deletion: rescue anything, then shred the rest in one go.
struct ReviewBinView: View {
    @Environment(SwipeSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var estimatedBytes: Int64?
    @State private var isShredding = false
    @State private var result: (count: Int, bytes: Int64)?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 4)]

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    successView(count: result.count, bytes: result.bytes)
                } else if session.bin.isEmpty {
                    ContentUnavailableView(
                        "Shred Bin Is Empty",
                        systemImage: "trash.slash",
                        description: Text("Swipe left on photos you don't need and they'll wait here until you confirm.")
                    )
                } else {
                    grid
                }
            }
            .navigationTitle(result == nil ? "Shred Bin" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                if result == nil, !session.bin.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Restore All") {
                            withAnimation(.snappy) { session.restoreAll() }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if result == nil, !session.bin.isEmpty { shredButton }
            }
            .alert("Couldn't Delete", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task(id: session.bin.count) {
            estimatedBytes = nil
            estimatedBytes = await session.estimatedBinSize()
        }
        .sensoryFeedback(.success, trigger: result?.count)
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("Tap a photo to rescue it. Shredded items stay in Recently Deleted for 30 days.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(session.bin, id: \.localIdentifier) { asset in
                        BinCell(asset: asset) {
                            withAnimation(.snappy) { session.restore(asset) }
                        }
                        .transition(.scale(0.6).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.top, 8)
        }
    }

    private var shredButton: some View {
        Button(role: .destructive) {
            Task { await shred() }
        } label: {
            HStack(spacing: 10) {
                if isShredding {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "trash.fill")
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Shred \(session.bin.count) \(session.bin.count == 1 ? "Item" : "Items")")
                        .font(.headline)
                    Group {
                        if let estimatedBytes {
                            Text("Frees about \(estimatedBytes.formatted(.byteCount(style: .file)))")
                        } else {
                            Text("Calculating size…")
                        }
                    }
                    .font(.caption)
                    .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(.shred)
        .controlSize(.extraLarge)
        .disabled(isShredding)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func shred() async {
        isShredding = true
        defer { isShredding = false }
        let bytes = estimatedBytes ?? 0
        do {
            if let count = try await session.shredBin(estimatedBytes: bytes) {
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    result = (count, bytes)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Success

    private func successView(count: Int, bytes: Int64) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: count)
                .frame(width: 120, height: 120)
                .glassEffect(.regular.tint(Color.keep.opacity(0.7)), in: .circle)

            VStack(spacing: 6) {
                Text("Shredded \(count) \(count == 1 ? "Item" : "Items")")
                    .font(.system(.title, design: .rounded, weight: .bold))
                if bytes > 0 {
                    Text("About \(bytes.formatted(.byteCount(style: .file))) freed up")
                        .foregroundStyle(.secondary)
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(0.8).combined(with: .opacity))
    }
}

private struct BinCell: View {
    let asset: PHAsset
    let restore: () -> Void

    var body: some View {
        Button(action: restore) {
            AssetImage(asset: asset)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .glassEffect(.regular, in: .circle)
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Keep This Photo", systemImage: "heart", action: restore)
        } preview: {
            AssetImage(asset: asset, style: .fitOverBlur)
                .frame(width: 320, height: 420)
        }
        .accessibilityLabel("Restore photo")
    }
}
