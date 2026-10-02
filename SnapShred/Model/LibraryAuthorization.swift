//
//  LibraryAuthorization.swift
//  SnapShred
//

import Photos

@Observable
final class LibraryAuthorization {
    private(set) var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var canBrowse: Bool { status == .authorized || status == .limited }
    var wasDenied: Bool { status == .denied || status == .restricted }

    func request() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func refresh() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
}
