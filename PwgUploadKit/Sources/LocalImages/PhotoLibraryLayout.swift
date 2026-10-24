//
//  PhotoLibraryLayout.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22 October 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

/// The sections of the picker of local images, for one way of grouping the assets of an album.
///
/// An asset is identified by its position in the album fetched by decreasing creation date (position 0 is the newest
/// asset). A grouping is a list of consecutive ranges of positions, newest section first. Showing the oldest assets
/// first only reverses the order of the sections and the order of the assets in each section: it is a matter of
/// mapping, no asset is read.
///
/// The value is immutable and cheap to copy, so that it can be built in the background and swapped in, on the main
/// thread, as a whole.
public struct PhotoLibraryLayout: Sendable, Equatable {

    /// Ranges of positions of the sections, the section of the newest assets first.
    public let ranges: [Range<Int>]
    /// `true` shows the newest assets first (the order of the positions), `false` the oldest first.
    public let newestFirst: Bool

    public init(ranges: [Range<Int>], newestFirst: Bool = true) {
        self.ranges = ranges
        self.newestFirst = newestFirst
    }

    /// One section holding all the assets, which does not depend on any date.
    public static func single(count: Int, newestFirst: Bool = true) -> PhotoLibraryLayout {
        PhotoLibraryLayout(ranges: [0..<count], newestFirst: newestFirst)
    }

    public func with(newestFirst: Bool) -> PhotoLibraryLayout {
        PhotoLibraryLayout(ranges: ranges, newestFirst: newestFirst)
    }

    public var sectionCount: Int { ranges.count }
    public var itemCount: Int { ranges.last?.upperBound ?? 0 }

    /// Positions of the assets of a displayed section, whatever the order.
    public func range(ofSection section: Int) -> Range<Int> {
        newestFirst ? ranges[section] : ranges[ranges.count - 1 - section]
    }

    public func numberOfItems(inSection section: Int) -> Int {
        range(ofSection: section).count
    }

    /// Position of the asset shown at a displayed section and item.
    public func assetIndex(section: Int, item: Int) -> Int {
        let r = range(ofSection: section)
        return newestFirst ? r.lowerBound + item : r.upperBound - 1 - item
    }

    /// Displayed section and item of the asset at a position, by binary search over the sections.
    public func position(ofAssetAt index: Int) -> (section: Int, item: Int)? {
        var lo = 0, hi = ranges.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let r = ranges[mid]
            if index < r.lowerBound {
                hi = mid - 1
            } else if index >= r.upperBound {
                lo = mid + 1
            } else {
                return newestFirst
                    ? (mid, index - r.lowerBound)
                    : (ranges.count - 1 - mid, r.upperBound - 1 - index)
            }
        }
        return nil
    }
}


/// The three groupings of an album by date.
public struct PhotoLibraryLayouts: Sendable, Equatable {
    public let count: Int
    public let day: [Range<Int>]
    public let week: [Range<Int>]
    public let month: [Range<Int>]

    public init(count: Int, day: [Range<Int>], week: [Range<Int>], month: [Range<Int>]) {
        self.count = count
        self.day = day
        self.week = week
        self.month = month
    }
}
