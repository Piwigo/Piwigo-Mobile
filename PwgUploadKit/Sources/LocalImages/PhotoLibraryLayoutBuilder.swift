//
//  PhotoLibraryLayoutBuilder.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22 October 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// MARK: - Sections of a chunk of the album
/// Sections of a chunk of the album, with the calendar keys at both ends so that two chunks can be joined.
struct GroupingChunk: Sendable {
    var day = [Range<Int>](), week = [Range<Int>](), month = [Range<Int>]()
    var firstDay = DateComponents(), lastDay = DateComponents()
    var firstWeek = DateComponents(), lastWeek = DateComponents()
    var firstMonth = DateComponents(), lastMonth = DateComponents()
}

/// One pass over `range`, newest first: reads each creation date once and computes the day, week and month sections
/// together, in blocks of 1,000 assets (each with its own autorelease pool). Returns nil if cancelled.
func groupAssets(dateAt: (Int) -> Date?, range: Range<Int>, isCancelled: () -> Bool = { false }) -> GroupingChunk? {
    let calendar = Calendar.current
    let byDays: Set<Calendar.Component> = [.year, .month, .day]
    let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
    let byMonths: Set<Calendar.Component> = [.year, .month]
    var out = GroupingChunk()
    guard !range.isEmpty else { return out }
    let first = dateAt(range.lowerBound) ?? Date()
    var dayComponents = calendar.dateComponents(byDays, from: first)
    var weekComponents = calendar.dateComponents(byWeeks, from: first)
    var monthComponents = calendar.dateComponents(byMonths, from: first)
    out.firstDay = dayComponents; out.firstWeek = weekComponents; out.firstMonth = monthComponents
    var firstDay = range.lowerBound, firstWeek = range.lowerBound, firstMonth = range.lowerBound
    let step = 1_000
    var blockStart = range.lowerBound
    while blockStart < range.upperBound {
        if isCancelled() { return nil }
        let blockEnd = min(blockStart + step, range.upperBound)
        autoreleasepool {
            for index in blockStart..<blockEnd {
                let creationDate = dateAt(index) ?? Date()
                let newDay = calendar.dateComponents(byDays, from: creationDate)
                if newDay == dayComponents { continue }
                out.day.append(firstDay..<index)
                firstDay = index
                dayComponents = newDay
                let newWeek = calendar.dateComponents(byWeeks, from: creationDate)
                if newWeek != weekComponents {
                    out.week.append(firstWeek..<index)
                    firstWeek = index
                    weekComponents = newWeek
                }
                let newMonth = calendar.dateComponents(byMonths, from: creationDate)
                if newMonth != monthComponents {
                    out.month.append(firstMonth..<index)
                    firstMonth = index
                    monthComponents = newMonth
                }
            }
        }
        blockStart = blockEnd
    }
    out.day.append(firstDay..<range.upperBound)
    out.week.append(firstWeek..<range.upperBound)
    out.month.append(firstMonth..<range.upperBound)
    out.lastDay = dayComponents; out.lastWeek = weekComponents; out.lastMonth = monthComponents
    return out
}

/// Joins two consecutive chunks: a section which straddles the cut is the union of both halves.
func join(_ a: GroupingChunk, _ b: GroupingChunk) -> GroupingChunk {
    func merge(_ x: [Range<Int>], _ y: [Range<Int>], same: Bool) -> [Range<Int>] {
        guard same, let lastX = x.last, let firstY = y.first else { return x + y }
        return x.dropLast() + [lastX.lowerBound..<firstY.upperBound] + y.dropFirst()
    }
    var out = GroupingChunk()
    out.day = merge(a.day, b.day, same: a.lastDay == b.firstDay)
    out.week = merge(a.week, b.week, same: a.lastWeek == b.firstWeek)
    out.month = merge(a.month, b.month, same: a.lastMonth == b.firstMonth)
    // The joined chunk starts where `a` starts and ends where `b` ends, so it can be joined again.
    out.firstDay = a.firstDay; out.firstWeek = a.firstWeek; out.firstMonth = a.firstMonth
    out.lastDay = b.lastDay; out.lastWeek = b.lastWeek; out.lastMonth = b.lastMonth
    return out
}


// MARK: - Windows
/// A window of the album, newest first. It is created for one date interval and released after use, so that the
/// memory PhotoKit keeps for a fetch result (about 2.3 KB per asset on iOS 27) never covers more than one window
/// per thread.
protocol DateWindow: AnyObject {
    var count: Int { get }
    func date(at index: Int) -> Date?
}

/// What the windowed pass needs from the album.
protocol WindowedSource: Sendable {
    /// Number of assets of the album.
    var totalCount: Int { get }
    var newestDate: Date { get }
    var oldestDate: Date { get }
    /// Count query: assets created in [from, to). Creates no asset.
    func count(from: Date, to: Date) -> Int
    /// The same assets, newest first. `.distantPast` … `.distantFuture` stands for the whole album.
    func window(from: Date, to: Date) -> any DateWindow
}

struct WindowLeaf: Sendable {
    let interval: DateInterval
    let count: Int
    let offset: Int           // position of the window's first asset in the album
    var end: Int { offset + count }
}

struct WindowPlan: Sendable {
    var leaves = [WindowLeaf]()
    var total: Int { leaves.last?.end ?? 0 }
    var countQueries = 0
}

/// Plans the windows: one count query per calendar year; a year holding more than `maxWindow` assets is cut into
/// months, a month into days. An album of at most `maxWindow` assets is one window and costs no query.
func planWindows(_ source: any WindowedSource, maxWindow: Int, calendar: Calendar = .current,
                 isCancelled: () -> Bool = { false }) -> WindowPlan {
    var plan = WindowPlan()
    let n = source.totalCount
    guard n > 0 else { return plan }
    if n <= maxWindow {
        plan.leaves = [WindowLeaf(interval: DateInterval(start: .distantPast, end: .distantFuture), count: n, offset: 0)]
        return plan
    }
    let levels: [Calendar.Component] = [.year, .month, .day]
    var offset = 0
    func visit(_ interval: DateInterval, level: Int) {
        if isCancelled() { return }
        plan.countQueries += 1
        let c = source.count(from: interval.start, to: interval.end)
        if c == 0 { return }
        if c <= maxWindow || level == levels.count - 1 {
            plan.leaves.append(WindowLeaf(interval: interval, count: c, offset: offset))
            offset += c
            return
        }
        var children = [DateInterval]()
        var cur = calendar.dateInterval(of: levels[level + 1], for: interval.start)
        while let child = cur, child.start < interval.end {
            children.append(child)
            cur = calendar.dateInterval(of: levels[level + 1], for: child.end)
        }
        for child in children.reversed() { visit(child, level: level + 1) }
    }
    var year = calendar.dateInterval(of: .year, for: source.newestDate)
    let oldest = source.oldestDate
    while let y = year, y.end > oldest {
        visit(y, level: 0)
        year = calendar.dateInterval(of: .year, for: y.start.addingTimeInterval(-1))
    }
    return plan
}

/// Maps a position of the album to a date, holding one window at a time; positions are read in increasing order.
final class WindowCursor {
    private let source: any WindowedSource
    private let leaves: [WindowLeaf]
    private var leafIndex = -1
    private var window: (any DateWindow)?

    init(source: any WindowedSource, leaves: [WindowLeaf]) { self.source = source; self.leaves = leaves }

    func date(at position: Int) -> Date? {
        if leafIndex < 0 || position < leaves[leafIndex].offset || position >= leaves[leafIndex].end {
            var lo = 0, hi = leaves.count - 1
            while lo < hi {
                let mid = (lo + hi) / 2
                if leaves[mid].end <= position { lo = mid + 1 } else { hi = mid }
            }
            window = nil                                  // release the previous window first
            leafIndex = lo
            window = source.window(from: leaves[lo].interval.start, to: leaves[lo].interval.end)
        }
        let local = position - leaves[leafIndex].offset
        guard let w = window, local < w.count else { return nil }
        return w.date(at: local)
    }
}

/// Chunks computed by the threads of a pass.
private final class ChunkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks = [Int: GroupingChunk]()
    private var failed = false
    func set(_ index: Int, _ chunk: GroupingChunk?) {
        lock.lock(); defer { lock.unlock() }
        if let chunk { chunks[index] = chunk } else { failed = true }
    }
    func ordered(count: Int) -> [GroupingChunk]? {
        lock.lock(); defer { lock.unlock() }
        return failed ? nil : (0..<count).compactMap { chunks[$0] }
    }
}

/// The single pass over the windows, on up to `threads` threads: each takes consecutive windows holding about the
/// same number of assets, and the sections straddling a cut are joined. Blocks until done; returns nil if cancelled.
func groupAssets(in source: any WindowedSource, plan: WindowPlan, threads: Int,
                 isCancelled: @Sendable () -> Bool = { false }) -> GroupingChunk? {
    let leaves = plan.leaves
    guard !leaves.isEmpty else { return GroupingChunk() }
    let threads = max(1, min(threads, leaves.count))
    // Cut at the leaf boundary closest to total * t / threads.
    var cuts = [0]
    for t in 1..<max(threads, 1) {
        let target = plan.total * t / threads
        var lo = cuts.last!, hi = leaves.count - 1
        while lo < hi {                                    // the leaf holding `target`
            let mid = (lo + hi) / 2
            if leaves[mid].end <= target { lo = mid + 1 } else { hi = mid }
        }
        let cut = (target - leaves[lo].offset <= leaves[lo].end - target) ? lo : lo + 1
        if cut > cuts.last! && cut < leaves.count { cuts.append(cut) }
    }
    cuts.append(leaves.count)

    let chunkCount = cuts.count - 1
    let box = ChunkBox()
    let boundaries = cuts
    withoutActuallyEscaping(isCancelled) { cancelled in
        DispatchQueue.concurrentPerform(iterations: chunkCount) { c in
            let mine = Array(leaves[boundaries[c]..<boundaries[c + 1]])
            let cursor = WindowCursor(source: source, leaves: mine)
            let chunk = groupAssets(dateAt: { cursor.date(at: $0) },
                                    range: mine.first!.offset..<mine.last!.end, isCancelled: cancelled)
            box.set(c, chunk)
        }
    }
    guard let ordered = box.ordered(count: chunkCount), var joined = ordered.first else { return nil }
    for chunk in ordered.dropFirst() { joined = join(joined, chunk) }
    return joined
}


// MARK: - PhotoKit
private final class PHWindow: DateWindow {
    let result: PHFetchResult<PHAsset>
    init(_ r: PHFetchResult<PHAsset>) { result = r }
    var count: Int { result.count }
    func date(at index: Int) -> Date? { result.object(at: index).creationDate }
}

/// An album of the Photo Library seen as windows of dates. PhotoKit documents the fetch results as immutable and
/// safe to read from any thread.
private final class PHWindowedSource: WindowedSource, @unchecked Sendable {
    let collection: PHAssetCollection
    let totalCount: Int
    let newestDate: Date
    let oldestDate: Date

    static func fetch(_ collection: PHAssetCollection, from: Date?, to: Date?, sorted: Bool) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        if sorted { options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)] }
        if let from, let to {
            options.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", from as NSDate, to as NSDate)
        }
        return PHAsset.fetchAssets(in: collection, options: options)
    }

    init?(collection: PHAssetCollection) {
        let all = PHWindowedSource.fetch(collection, from: nil, to: nil, sorted: true)
        guard all.count > 0, let newest = all.object(at: 0).creationDate,
              let oldest = all.object(at: all.count - 1).creationDate else { return nil }
        self.collection = collection
        totalCount = all.count
        newestDate = newest
        oldestDate = oldest
    }

    func count(from: Date, to: Date) -> Int {
        PHWindowedSource.fetch(collection, from: from, to: to, sorted: false).count
    }

    func window(from: Date, to: Date) -> any DateWindow {
        let whole = from == .distantPast && to == .distantFuture
        return PHWindow(PHWindowedSource.fetch(collection, from: whole ? nil : from, to: whole ? nil : to, sorted: true))
    }
}


// MARK: - Entry points
/// Flag set when the task which started a background job is cancelled.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}

/// Runs blocking work on a dispatch thread, without holding a thread of the cooperative pool (a pass over a large
/// album blocks for seconds, which would starve other tasks on devices with two cores). Cancelling the calling task
/// stops the work at its next check.
func runInBackground<T: Sendable>(qos: DispatchQoS.QoSClass = .userInitiated,
                                  _ work: @escaping @Sendable (_ isCancelled: @Sendable () -> Bool) -> T) async -> T {
    let flag = CancelFlag()
    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(returning: work({ flag.isCancelled }))
            }
        }
    } onCancel: {
        flag.cancel()
    }
}

public enum PhotoLibraryLayoutBuilder {

    /// Largest number of assets a window should hold, which bounds the memory of a pass (about 2.3 KB per asset on
    /// iOS 27) whatever the size of the album.
    static let maxWindow = 5_000

    /// Builds the day, week and month groupings of an album, newest first, without ever keeping more than a few
    /// thousand assets per thread in memory (see `DateWindow`). Returns nil if the task is cancelled.
    ///
    /// The album is read in windows of dates, on two threads. If the windows do not cover exactly `expectedCount`
    /// assets (assets without creation date, or an album which changed in the meantime), the album is read in one
    /// serial pass, which gives the same sections as the former implementation.
    public static func build(inCollectionWithIdentifier identifier: String, expectedCount: Int,
                             threads: Int = 2) async -> PhotoLibraryLayouts? {
        await runInBackground { isCancelled in
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil)
            guard let collection = collections.firstObject else { return nil }
            return build(in: collection, expectedCount: expectedCount, threads: threads, isCancelled: isCancelled)
        }
    }

    static func build(in collection: PHAssetCollection, expectedCount: Int, threads: Int,
                      isCancelled: @Sendable () -> Bool) -> PhotoLibraryLayouts? {
        guard expectedCount > 0 else {
            return PhotoLibraryLayouts(count: 0, day: [], week: [], month: [])
        }
        if let source = PHWindowedSource(collection: collection), source.totalCount == expectedCount {
            let plan = planWindows(source, maxWindow: maxWindow, isCancelled: isCancelled)
            if isCancelled() { return nil }
            if plan.total == expectedCount {
                guard let chunk = groupAssets(in: source, plan: plan, threads: threads, isCancelled: isCancelled)
                else { return nil }
                return PhotoLibraryLayouts(count: expectedCount, day: chunk.day, week: chunk.week, month: chunk.month)
            }
        }
        // Serial pass on a result of its own, released afterwards
        let images = PHWindowedSource.fetch(collection, from: nil, to: nil, sorted: true)
        let n = images.count
        guard n > 0 else { return PhotoLibraryLayouts(count: 0, day: [], week: [], month: []) }
        guard let chunk = groupAssets(dateAt: { images.object(at: $0).creationDate }, range: 0..<n,
                                      isCancelled: isCancelled)
        else { return nil }
        return PhotoLibraryLayouts(count: n, day: chunk.day, week: chunk.week, month: chunk.month)
    }
}
