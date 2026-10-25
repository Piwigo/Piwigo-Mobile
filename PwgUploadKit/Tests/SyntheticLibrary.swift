import Foundation
@testable import PwgUploadKit

/// Deterministic generator (SplitMix64).
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Creation dates of a synthetic album, newest first: photos are taken on `activeDayRatio` of the days, a few on most of
/// them, many on some (exponential distribution), `count` photos ending today.
func syntheticTimes(count: Int, years: Int = 15, activeDayRatio: Double = 0.35, seed: UInt64 = 42) -> [TimeInterval] {
    var rng = SplitMix64(seed: seed)
    let days = years * 365
    let meanPerActiveDay = max(1.0, Double(count) / (Double(days) * activeDayRatio))
    var t = [TimeInterval]()
    t.reserveCapacity(count)
    let today = Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate + 86_400
    var day = 0
    while t.count < count {
        let dayStart = today - Double(day + 1) * 86_400
        day += 1
        if day > days * 4 { break }
        if rng.nextDouble() > activeDayRatio { continue }
        let n = max(1, Int(-log(1 - rng.nextDouble()) * meanPerActiveDay) + 1)
        var inDay = (0..<n).map { _ in dayStart + rng.nextDouble() * 86_399 }
        inDay.sort(by: >)
        t.append(contentsOf: inDay)
    }
    return Array(t.prefix(count))
}

/// An album in memory which counts what the windowed pass asks of it and how many assets are alive at once.
final class SyntheticWindowedSource: WindowedSource, @unchecked Sendable {
    final class Window: DateWindow {
        let times: ArraySlice<TimeInterval>
        unowned let owner: SyntheticWindowedSource
        var count: Int { times.count }
        init(times: ArraySlice<TimeInterval>, owner: SyntheticWindowedSource) {
            self.times = times; self.owner = owner
            owner.adjustLive(+times.count)
        }
        deinit { owner.adjustLive(-times.count) }
        func date(at index: Int) -> Date? { Date(timeIntervalSinceReferenceDate: times[times.startIndex + index]) }
    }

    let times: [TimeInterval]            // newest first
    private let lock = NSLock()
    private var _countQueries = 0, _windowFetches = 0, _liveAssets = 0, _maxLiveAssets = 0
    var countQueries: Int { lock.withLock { _countQueries } }
    var windowFetches: Int { lock.withLock { _windowFetches } }
    var liveAssets: Int { lock.withLock { _liveAssets } }
    var maxLiveAssets: Int { lock.withLock { _maxLiveAssets } }

    init(times: [TimeInterval]) { self.times = times }
    var totalCount: Int { times.count }
    var newestDate: Date { Date(timeIntervalSinceReferenceDate: times.first ?? 0) }
    var oldestDate: Date { Date(timeIntervalSinceReferenceDate: times.last ?? 0) }

    /// First index whose time is < `t` (times are descending).
    private func firstBelow(_ t: TimeInterval) -> Int {
        var lo = 0, hi = times.count
        while lo < hi { let mid = (lo + hi) / 2; if times[mid] < t { hi = mid } else { lo = mid + 1 } }
        return lo
    }
    private func range(_ from: Date, _ to: Date) -> Range<Int> {
        firstBelow(to.timeIntervalSinceReferenceDate)..<firstBelow(from.timeIntervalSinceReferenceDate)
    }
    func count(from: Date, to: Date) -> Int {
        lock.withLock { _countQueries += 1 }
        return range(from, to).count
    }
    func window(from: Date, to: Date) -> any DateWindow {
        lock.withLock { _windowFetches += 1 }
        return Window(times: times[range(from, to)], owner: self)
    }
    func adjustLive(_ delta: Int) {
        lock.withLock { _liveAssets += delta; _maxLiveAssets = max(_maxLiveAssets, _liveAssets) }
    }
}

/// Reference grouping: one simple loop per grouping, comparing the calendar key of consecutive assets.
func referenceSections(_ times: [TimeInterval], components: Set<Calendar.Component>) -> [Range<Int>] {
    guard !times.isEmpty else { return [] }
    let calendar = Calendar.current
    var ranges = [Range<Int>]()
    var start = 0
    var key = calendar.dateComponents(components, from: Date(timeIntervalSinceReferenceDate: times[0]))
    for i in 1..<times.count {
        let k = calendar.dateComponents(components, from: Date(timeIntervalSinceReferenceDate: times[i]))
        if k != key { ranges.append(start..<i); start = i; key = k }
    }
    ranges.append(start..<times.count)
    return ranges
}

func serialChunk(_ times: [TimeInterval]) -> GroupingChunk {
    groupAssets(dateAt: { Date(timeIntervalSinceReferenceDate: times[$0]) }, range: 0..<times.count)!
}
