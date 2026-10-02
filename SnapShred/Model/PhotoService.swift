//
//  PhotoService.swift
//  SnapShred
//

import Photos
import UIKit

/// Thread-safe wrapper around PhotoKit image loading and library mutations.
nonisolated final class PhotoService: @unchecked Sendable {
    static let shared = PhotoService()

    private let imageManager = PHCachingImageManager()

    private init() {}

    // MARK: Images

    /// Streams a fast, degraded image followed by the final one.
    func images(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let image {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if !isDegraded || isCancelled || info?[PHImageErrorKey] != nil {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [imageManager] _ in
                imageManager.cancelImageRequest(requestID)
            }
        }
    }

    func startCaching(_ assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFit, options: nil)
    }

    // MARK: Mutations

    /// Deletes assets. iOS shows its own confirmation and moves them to Recently Deleted.
    func deleteAssets(withIdentifiers identifiers: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    func setFavorite(_ isFavorite: Bool, identifier: String) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
            PHAssetChangeRequest(for: asset).isFavorite = isFavorite
        }
    }

    /// Best-effort estimate of the bytes on disk taken by the given assets.
    func estimatedSize(ofIdentifiers identifiers: [String]) async -> Int64 {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var total: Int64 = 0
        assets.enumerateObjects { asset, _, _ in
            for resource in PHAssetResource.assetResources(for: asset) {
                if let size = resource.value(forKey: "fileSize") as? Int64 {
                    total += size
                }
            }
        }
        return total
    }
}

extension PhotoService {
    static func isUserCancellation(_ error: Error) -> Bool {
        (error as? PHPhotosError)?.code == .userCancelled
            || (error as NSError).code == PHPhotosError.userCancelled.rawValue
    }
}
