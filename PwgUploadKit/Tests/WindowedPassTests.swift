import XCTest
@testable import PwgUploadKit

final class WindowedPassTests: XCTestCase {

    // MARK: Equivalence with the serial pass

    func testEqualsSerialPassForEveryWindowSizeAndThreadCount() {
        let configs: [(n: Int, years: Int, ratio: Double, seed: UInt64)] =
            [(1, 1, 1, 1), (2, 1, 1, 2), (60, 1, 0.5, 3), (3_000, 2, 0.4, 4), (15_000, 6, 0.3, 5)]
        for cfg in configs {
            let times = syntheticTimes(count: cfg.n, years: cfg.years, activeDayRatio: cfg.ratio, seed: cfg.seed)
            let expected = serialChunk(times)
            for maxWindow in [3, 40, 700, 1_000_000] {
                let source = SyntheticWindowedSource(times: times)
                let plan = planWindows(source, maxWindow: maxWindow)
                XCTAssertEqual(plan.total, times.count)
                for threads in [1, 2, 3, 4, 7] {
                    let got = groupAssets(in: source, plan: plan, threads: threads)
                    let label = "n=\(cfg.n) maxWindow=\(maxWindow) threads=\(threads)"
                    XCTAssertEqual(got?.day, expected.day, "day \(label)")
                    XCTAssertEqual(got?.week, expected.week, "week \(label)")
                    XCTAssertEqual(got?.month, expected.month, "month \(label)")
                }
            }
        }
    }

    // MARK: Plan invariants

    func testPlanLeavesAreContiguousDescendingAndBounded() {
        let times = syntheticTimes(count: 20_000, years: 8, activeDayRatio: 0.3, seed: 9)
        for maxWindow in [10, 200, 3_000] {
            let source = SyntheticWindowedSource(times: times)
            let plan = planWindows(source, maxWindow: maxWindow)
            XCTAssertEqual(plan.total, times.count)
            var expectedOffset = 0
            var previousStart: Date? = nil
            for leaf in plan.leaves {
                XCTAssertEqual(leaf.offset, expectedOffset)
                XCTAssertGreaterThan(leaf.count, 0)
                let isDay = Calendar.current.dateInterval(of: .day, for: leaf.interval.start) == leaf.interval
                XCTAssertTrue(leaf.count <= maxWindow || isDay, "leaf of \(leaf.count) assets above \(maxWindow) is not a day")
                if let prev = previousStart { XCTAssertLessThanOrEqual(leaf.interval.end, prev, "leaves overlap or are out of order") }
                previousStart = leaf.interval.start
                expectedOffset += leaf.count
            }
            XCTAssertEqual(source.countQueries, plan.countQueries)
        }
    }

    func testSmallAlbumIsOneWindowWithoutAnyQuery() {
        let times = syntheticTimes(count: 500, years: 3)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 10_000)
        XCTAssertEqual(plan.leaves.count, 1)
        XCTAssertEqual(plan.countQueries, 0)
        XCTAssertEqual(source.countQueries, 0)
        _ = groupAssets(in: source, plan: plan, threads: 2)
        XCTAssertEqual(source.windowFetches, 1)
    }

    func testOneCountQueryPerYearUntilAYearIsTooBig() {
        let times = syntheticTimes(count: 10_000, years: 10, activeDayRatio: 0.5, seed: 21)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 5_000)
        let years = Set(plan.leaves.map { Calendar.current.component(.year, from: $0.interval.start) })
        XCTAssertEqual(plan.countQueries, years.count)
        XCTAssertEqual(plan.leaves.count, years.count)
    }

    // MARK: Memory bound

    func testLiveAssetsAreBoundedByTheLargestWindowsInFlight() {
        let times = syntheticTimes(count: 30_000, years: 10, activeDayRatio: 0.4, seed: 33)
        for threads in [1, 2, 4] {
            let source = SyntheticWindowedSource(times: times)
            let plan = planWindows(source, maxWindow: 800)
            let largest = plan.leaves.map(\.count).max()!
            _ = groupAssets(in: source, plan: plan, threads: threads)
            XCTAssertLessThanOrEqual(source.maxLiveAssets, threads * largest,
                                     "threads=\(threads): \(source.maxLiveAssets) assets alive at once, largest window \(largest)")
            XCTAssertEqual(source.liveAssets, 0, "every window must be released")
        }
    }

    func testEveryWindowIsFetchedOnce() {
        let times = syntheticTimes(count: 12_000, years: 5, seed: 41)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 500)
        _ = groupAssets(in: source, plan: plan, threads: 3)
        XCTAssertEqual(source.windowFetches, plan.leaves.count)
    }

    // MARK: Edge cases

    func testEmptyAndSingleAsset() {
        let empty = SyntheticWindowedSource(times: [])
        let plan = planWindows(empty, maxWindow: 10)
        XCTAssertTrue(plan.leaves.isEmpty)
        let r = groupAssets(in: empty, plan: plan, threads: 2)
        XCTAssertEqual(r?.day, [])

        let one = SyntheticWindowedSource(times: [1_000_000])
        let p1 = planWindows(one, maxWindow: 10)
        let r1 = groupAssets(in: one, plan: p1, threads: 4)
        XCTAssertEqual(r1?.day, [0..<1])
    }

    func testOneGiantDayStaysOneLeaf() {
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: 600_000_000)).timeIntervalSinceReferenceDate
        let times = (0..<1_000).map { day + 86_000 - Double($0) * 80 }
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 10)
        XCTAssertEqual(plan.leaves.count, 1)
        XCTAssertEqual(plan.leaves[0].count, 1_000)
        let got = groupAssets(in: source, plan: plan, threads: 3)
        XCTAssertEqual(got?.day, [0..<1_000])
    }

    /// Many assets exactly on, and one second before, every month start, and across New Year.
    func testTiesOnCalendarBoundaries() {
        let cal = Calendar.current
        var times = [TimeInterval]()
        var comps = DateComponents(year: 2019, month: 1, day: 1)
        for _ in 0..<36 {
            let start = cal.date(from: comps)!.timeIntervalSinceReferenceDate
            times += Array(repeating: start, count: 5)                 // exactly on the boundary
            times += Array(repeating: start - 1, count: 5)             // one second before
            times += [start + 3 * 86_400, start + 10 * 86_400, start + 17 * 86_400]
            comps.month! += 1
            if comps.month! > 12 { comps.month = 1; comps.year! += 1 }
        }
        times.sort(by: >)
        let expected = serialChunk(times)
        for maxWindow in [4, 12, 60, 10_000] {
            let source = SyntheticWindowedSource(times: times)
            let plan = planWindows(source, maxWindow: maxWindow)
            XCTAssertEqual(plan.total, times.count)
            for threads in [1, 2, 3, 5] {
                let got = groupAssets(in: source, plan: plan, threads: threads)
                XCTAssertEqual(got?.day, expected.day, "day maxWindow=\(maxWindow) threads=\(threads)")
                XCTAssertEqual(got?.week, expected.week, "week maxWindow=\(maxWindow) threads=\(threads)")
                XCTAssertEqual(got?.month, expected.month, "month maxWindow=\(maxWindow) threads=\(threads)")
            }
        }
    }

    /// A long empty gap between two dense periods (the filler album: 1980–1998, then 2015–2025).
    func testLongEmptyGap() {
        let a = syntheticTimes(count: 4_000, years: 3, activeDayRatio: 0.6, seed: 51)
        let times = a + a.map { $0 - 25 * 365 * 86_400 }
        let expected = serialChunk(times)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 500)
        let got = groupAssets(in: source, plan: plan, threads: 2)
        XCTAssertEqual(got?.day, expected.day)
        XCTAssertEqual(got?.week, expected.week)
        XCTAssertEqual(got?.month, expected.month)
        XCTAssertLessThan(plan.countQueries, 25 + 3 * 13 + 400)       // one query per empty year, not per day
    }

    // MARK: Cancellation

    func testCancellationReturnsNothingAndReleasesTheWindows() {
        let times = syntheticTimes(count: 5_000, years: 3, seed: 61)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 500)
        XCTAssertNil(groupAssets(in: source, plan: plan, threads: 2, isCancelled: { true }))
        XCTAssertEqual(source.liveAssets, 0)
        // Cancelled half way: the second block of the first window is never read.
        let counter = Counter()
        XCTAssertNil(groupAssets(in: source, plan: plan, threads: 1, isCancelled: { counter.next() > 2 }))
        XCTAssertEqual(source.liveAssets, 0)
    }

    func testCancelledPlanningStops() {
        let times = syntheticTimes(count: 20_000, years: 8, seed: 62)
        let source = SyntheticWindowedSource(times: times)
        let plan = planWindows(source, maxWindow: 100, isCancelled: { true })
        XCTAssertTrue(plan.leaves.isEmpty)
        XCTAssertEqual(source.countQueries, 0)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}
