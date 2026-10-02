//
//  LibraryFilter.swift
//  SnapShred
//

import Photos

/// Which slice of the library the deck is built from.
enum LibraryFilter: String, CaseIterable, Identifiable {
    case photos
    case screenshots
    case oldScreenshots
    case selfies
    case livePhotos
    case videos

    var id: Self { self }

    var title: String {
        switch self {
        case .photos: "All Photos"
        case .screenshots: "Screenshots"
        case .oldScreenshots: "Old Screenshots"
        case .selfies: "Selfies"
        case .livePhotos: "Live Photos"
        case .videos: "Videos"
        }
    }

    var systemImage: String {
        switch self {
        case .photos: "photo.on.rectangle.angled"
        case .screenshots: "camera.viewfinder"
        case .oldScreenshots: "calendar.badge.clock"
        case .selfies: "person.crop.square"
        case .livePhotos: "livephoto"
        case .videos: "video"
        }
    }

    func fetchAssets(order: SortOrder) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: order == .oldestFirst)]

        let image = PHAssetMediaType.image.rawValue
        switch self {
        case .photos:
            options.predicate = NSPredicate(format: "mediaType == %d", image)
        case .screenshots:
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                image, PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        case .oldScreenshots:
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0 AND creationDate < %@",
                image, PHAssetMediaSubtype.photoScreenshot.rawValue, Self.oldScreenshotCutoff as NSDate
            )
        case .livePhotos:
            options.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                image, PHAssetMediaSubtype.photoLive.rawValue
            )
        case .videos:
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .selfies:
            let albums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil
            )
            if let selfies = albums.firstObject {
                return PHAsset.fetchAssets(in: selfies, options: options)
            }
            options.predicate = NSPredicate(value: false)
        }
        return PHAsset.fetchAssets(with: options)
    }

    /// Screenshots older than this are rarely needed again.
    private static var oldScreenshotCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: Self { self }

    var title: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        }
    }
}
