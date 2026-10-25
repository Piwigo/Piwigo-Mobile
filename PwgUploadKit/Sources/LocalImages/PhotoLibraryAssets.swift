//
//  PhotoLibraryAssets.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22 October 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

/// An album of the Photo Library fetched by decreasing creation date, which can be handed to a background task.
///
/// PhotoKit documents a `PHFetchResult` as immutable and safe to read from any thread. The synchronous methods are
/// meant to run off the main thread and return nil when `isCancelled` says so; the async ones run them in the
/// background and stop when their task is cancelled.
public struct PhotoLibraryAssets: @unchecked Sendable {

    public let result: PHFetchResult<PHAsset>

    public init(_ result: PHFetchResult<PHAsset>) {
        self.result = result
    }

    public var count: Int { result.count }

    /// Positions of the assets with these local identifiers, and the identifiers of those which can be deleted.
    /// Assets which are not in this album are left out.
    public func positions(ofAssetsWithIdentifiers identifiers: [String], isCancelled: () -> Bool = { false })
        -> (positions: [String: Int], deletable: Set<String>)? {
        var positions = [String: Int](), deletable = Set<String>()
        guard !identifiers.isEmpty else { return (positions, deletable) }
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
        var cancelled = false
        var seen = 0
        let result = self.result
        withoutActuallyEscaping(isCancelled) { isCancelled in
            assets.enumerateObjects { asset, _, stop in
                seen += 1
                if seen % 100 == 0, isCancelled() { cancelled = true; stop.pointee = true; return }
                let index = result.index(of: asset)
                guard index != NSNotFound else { return }
                positions[asset.localIdentifier] = index
                if asset.canPerform(.delete) { deletable.insert(asset.localIdentifier) }
            }
        }
        return cancelled ? nil : (positions, deletable)
    }

    /// Local identifiers of the assets at these positions, in increasing order of position.
    public func identifiers(at positions: IndexSet, isCancelled: () -> Bool = { false }) -> [String]? {
        var identifiers = [String]()
        identifiers.reserveCapacity(positions.count)
        var counter = 0
        for range in positions.rangeView {
            var index = range.lowerBound
            while index < range.upperBound {
                if isCancelled() { return nil }
                let blockEnd = min(index + 200, range.upperBound)
                autoreleasepool {
                    for position in index..<blockEnd where position < result.count {
                        identifiers.append(result.object(at: position).localIdentifier)
                    }
                }
                counter += blockEnd - index
                index = blockEnd
            }
        }
        return identifiers
    }

    /// Positions in another fetch of the same album (after a change of the Photo Library) of the assets selected
    /// here. Selected assets which are no longer there are dropped.
    public func remap(_ positions: IndexSet, in other: PhotoLibraryAssets, isCancelled: () -> Bool = { false }) -> IndexSet? {
        guard !positions.isEmpty else { return IndexSet() }
        guard let identifiers = identifiers(at: positions, isCancelled: isCancelled),
              let found = other.positions(ofAssetsWithIdentifiers: identifiers, isCancelled: isCancelled)
        else { return nil }
        return IndexSet(found.positions.values)
    }

    // MARK: - In the background
    public func positions(ofAssetsWithIdentifiers identifiers: [String]) async
        -> (positions: [String: Int], deletable: Set<String>)? {
        await runInBackground { isCancelled in
            self.positions(ofAssetsWithIdentifiers: identifiers, isCancelled: isCancelled)
        }
    }

    /// Positions in another fetch of the same album of the assets selected here (as an array, since `IndexSet` is
    /// not `Sendable` before iOS 16).
    public func remap(_ positions: IndexSet, in other: PhotoLibraryAssets) async -> [Int]? {
        let selected = positions.rangeView.map { $0 }
        return await runInBackground { isCancelled in
            self.remap(selected.reduce(into: IndexSet()) { $0.insert(integersIn: $1) }, in: other, isCancelled: isCancelled)
                .map { Array($0) }
        }
    }

    /// Local identifiers of the assets at these positions, in increasing order of position.
    public func identifiers(at positions: IndexSet) async -> [String]? {
        await runInBackground { isCancelled in
            self.identifiers(at: positions, isCancelled: isCancelled)
        }
    }
}
