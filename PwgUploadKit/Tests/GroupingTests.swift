import XCTest
@testable import PwgUploadKit

final class GroupingTests: XCTestCase {

    private let day: Set<Calendar.Component> = [.year, .month, .day]
    private let week: Set<Calendar.Component> = [.year, .weekOfYear]
    private let month: Set<Calendar.Component> = [.year, .month]

    func testPassMatchesTheReferenceGroupings() {
        for (n, years, ratio, seed) in [(1, 1, 1.0, UInt64(1)), (2, 1, 1.0, 2), (60, 1, 0.5, 3),
                                        (3_000, 2, 0.4, 4), (15_000, 6, 0.3, 5)] {
            let times = syntheticTimes(count: n, years: years, activeDayRatio: ratio, seed: seed)
            let chunk = serialChunk(times)
            XCTAssertEqual(chunk.day, referenceSections(times, components: day), "day n=\(n)")
            XCTAssertEqual(chunk.week, referenceSections(times, components: week), "week n=\(n)")
            XCTAssertEqual(chunk.month, referenceSections(times, components: month), "month n=\(n)")
        }
    }

    func testSectionsCoverTheAlbumContiguously() {
        let times = syntheticTimes(count: 8_000, years: 4, seed: 8)
        let chunk = serialChunk(times)
        for ranges in [chunk.day, chunk.week, chunk.month] {
            XCTAssertEqual(ranges.first?.lowerBound, 0)
            XCTAssertEqual(ranges.last?.upperBound, times.count)
            for (a, b) in zip(ranges, ranges.dropFirst()) { XCTAssertEqual(a.upperBound, b.lowerBound) }
            XCTAssertTrue(ranges.allSatisfy { !$0.isEmpty })
        }
    }

    func testEmptyRangeGivesNoSection() {
        let chunk = groupAssets(dateAt: { _ in nil }, range: 0..<0)
        XCTAssertEqual(chunk?.day, [])
    }

    func testMissingDatesAreTreatedAsNow() {
        // Same as the former implementation: an asset without creation date counts as created now.
        let chunk = groupAssets(dateAt: { _ in nil }, range: 0..<5)
        XCTAssertEqual(chunk?.day, [0..<5])
    }

    /// Cutting the album at any position and joining the halves gives the same sections.
    func testJoiningTwoChunksAtAnyCutGivesTheSerialSections() {
        let times = syntheticTimes(count: 700, years: 1, activeDayRatio: 0.5, seed: 17)
        let expected = serialChunk(times)
        let dateAt: (Int) -> Date? = { Date(timeIntervalSinceReferenceDate: times[$0]) }
        for cut in 1..<times.count {
            let a = groupAssets(dateAt: dateAt, range: 0..<cut)!
            let b = groupAssets(dateAt: dateAt, range: cut..<times.count)!
            let joined = join(a, b)
            XCTAssertEqual(joined.day, expected.day, "cut \(cut)")
            XCTAssertEqual(joined.week, expected.week, "cut \(cut)")
            XCTAssertEqual(joined.month, expected.month, "cut \(cut)")
        }
    }

    func testJoiningManyChunksKeepsTheKeysOfBothEnds() {
        let times = syntheticTimes(count: 5_000, years: 3, activeDayRatio: 0.5, seed: 19)
        let expected = serialChunk(times)
        let dateAt: (Int) -> Date? = { Date(timeIntervalSinceReferenceDate: times[$0]) }
        for parts in 2...6 {
            let size = times.count / parts
            var chunks = [GroupingChunk]()
            for p in 0..<parts {
                chunks.append(groupAssets(dateAt: dateAt, range: (p * size)..<(p == parts - 1 ? times.count : (p + 1) * size))!)
            }
            let joined = chunks.dropFirst().reduce(chunks[0]) { join($0, $1) }
            XCTAssertEqual(joined.day, expected.day, "parts \(parts)")
            XCTAssertEqual(joined.week, expected.week, "parts \(parts)")
            XCTAssertEqual(joined.month, expected.month, "parts \(parts)")
        }
    }

    func testCancellationStopsThePass() {
        let times = syntheticTimes(count: 5_000, years: 2, seed: 23)
        let dateAt: (Int) -> Date? = { Date(timeIntervalSinceReferenceDate: times[$0]) }
        XCTAssertNil(groupAssets(dateAt: dateAt, range: 0..<times.count, isCancelled: { true }))
        var checks = 0
        XCTAssertNil(groupAssets(dateAt: dateAt, range: 0..<times.count, isCancelled: { checks += 1; return checks > 2 }))
        XCTAssertEqual(checks, 3)                                   // checked once per block of 1,000 assets
    }
}
