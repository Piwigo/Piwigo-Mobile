//
//  PhotoLibrarySelection.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22 October 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

/// State of the Select/Deselect button of a section.
public enum PhotoLibrarySectionSelectState: Sendable, Equatable {
    /// Nothing can be selected in the section (empty, or all assets already uploaded or queued), or not known yet.
    case none
    case select
    case deselect
}

/// The assets selected in the picker of local images, by position (see `PhotoLibraryLayout`).
///
/// Selecting a section inserts one range, whatever its size: no asset is read. The assets which are already
/// uploaded or queued (`queued`, also by position) cannot be selected, unless re-uploading is allowed.
public struct PhotoLibrarySelection: Sendable, Equatable {

    public private(set) var positions = IndexSet()

    public init(positions: IndexSet = IndexSet()) {
        self.positions = positions
    }

    public var count: Int { positions.count }
    public var isEmpty: Bool { positions.isEmpty }

    public func contains(_ position: Int) -> Bool {
        positions.contains(position)
    }

    public mutating func insert(_ position: Int) {
        positions.insert(position)
    }

    public mutating func remove(_ position: Int) {
        positions.remove(position)
    }

    public mutating func removeAll() {
        positions = IndexSet()
    }

    /// Selects the assets of a section which can be selected.
    public mutating func select(range: Range<Int>, excluding queued: IndexSet) {
        guard !range.isEmpty else { return }
        positions.formUnion(IndexSet(integersIn: range).subtracting(queued))
    }

    /// Deselects the assets of a section.
    public mutating func deselect(range: Range<Int>) {
        guard !range.isEmpty else { return }
        positions.subtract(IndexSet(integersIn: range))
    }

    /// Removes the assets which cannot be selected any longer.
    public mutating func remove(_ others: IndexSet) {
        positions.subtract(others)
    }

    /// State of the button of a section: nothing to select if every asset is queued, "Deselect" if every asset is
    /// either selected or queued, "Select" otherwise.
    public func selectState(of range: Range<Int>, queued: IndexSet, reUploadAllowed: Bool) -> PhotoLibrarySectionSelectState {
        if range.isEmpty { return .none }
        let queuedCount = reUploadAllowed ? 0 : queued.count(in: range)
        if queuedCount == range.count { return .none }
        let selectedCount = positions.count(in: range)
        return selectedCount + queuedCount == range.count ? .deselect : .select
    }

    /// Selected positions in the order in which the assets are shown.
    public func orderedPositions(newestFirst: Bool) -> [Int] {
        newestFirst ? Array(positions) : Array(positions).reversed()
    }
}
