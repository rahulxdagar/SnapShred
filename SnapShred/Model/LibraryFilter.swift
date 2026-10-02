//
//  LibraryFilter.swift
//  SnapShred
//

import Photos

/// A user-created album that can be used as a deck.
struct Album: Hashable, Identifiable {
    let id: String
    let title: String
    let count: Int

    // Identity is the album alone, so a changed count doesn't break menu selection.
    static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The user's own albums that contain at least one item, sorted by name.
    ///
    /// Shared and synced albums are left out: their items can't be deleted from the device.
    static func userAlbums() -> [Album] {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var albums: [Album] = []
        collections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            guard count > 0 else { return }
            albums.append(Album(id: collection.localIdentifier, title: collection.localizedTitle ?? "Untitled Album", count: count))
        }
        return albums.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

/// Which slice of the library the deck is built from.
enum LibraryFilter: Hashable, Identifiable {
    case photos
    case onThisDay
    case screenshots
    case oldScreenshots
    case selfies
    case livePhotos
    case videos
    case album(Album)

    /// The built-in decks offered alongside the user's albums.
    static let smartDecks: [LibraryFilter] = [
        .photos, .onThisDay, .screenshots, .oldScreenshots, .selfies, .livePhotos, .videos,
    ]

    var id: Self { self }

    var title: String {
        switch self {
        case .photos: "All Photos"
        case .onThisDay: "On This Day"
        case .screenshots: "Screenshots"
        case .oldScreenshots: "Old Screenshots"
        case .selfies: "Selfies"
        case .livePhotos: "Live Photos"
        case .videos: "Videos"
        case .album(let album): album.title
        }
    }

    var systemImage: String {
        switch self {
        case .photos: "photo.on.rectangle.angled"
        case .onThisDay: "calendar"
        case .screenshots: "camera.viewfinder"
        case .oldScreenshots: "calendar.badge.clock"
        case .selfies: "person.crop.square"
        case .livePhotos: "livephoto"
        case .videos: "video"
        case .album: "rectangle.stack"
        }
    }

    var emptyTitle: String {
        switch self {
        case .onThisDay: "No Memories Today"
        case .album: "Album Is Empty"
        default: "No \(title)"
        }
    }

    var emptyMessage: String {
        switch self {
        case .onThisDay: "Nothing was captured on this date in past years. Check back tomorrow."
        case .oldScreenshots: "Every screenshot you have is less than a month old."
        default: "Nothing here to sort through right now."
        }
    }

    func fetchAssets(order: SortOrder) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: order == .oldestFirst)]

        let image = PHAssetMediaType.image.rawValue
        switch self {
        case .photos:
            options.predicate = NSPredicate(format: "mediaType == %d", image)
        case .onThisDay:
            options.predicate = Self.onThisDayPredicate()
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
        case .album(let album):
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [album.id], options: nil)
            if let collection = collections.firstObject {
                return PHAsset.fetchAssets(in: collection, options: options)
            }
            options.predicate = NSPredicate(value: false)
        }
        return PHAsset.fetchAssets(with: options)
    }

    /// Matches photos and videos taken on today's month and day in any earlier year.
    ///
    /// PhotoKit can't query date components, so this ORs together one day-long
    /// range per past year.
    private static func onThisDayPredicate(yearsBack: Int = 40) -> NSPredicate {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let ranges: [NSPredicate] = (1...yearsBack).compactMap { offset in
            guard let start = calendar.date(byAdding: .year, value: -offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            return NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        }
        return NSCompoundPredicate(orPredicateWithSubpredicates: ranges)
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
