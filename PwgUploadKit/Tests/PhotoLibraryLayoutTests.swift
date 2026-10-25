import XCTest
@testable import PwgUploadKit

final class PhotoLibraryLayoutTests: XCTestCase {

    private let ranges = [0..<3, 3..<4, 4..<9, 9..<10]

    func testNewestFirstMapsSectionsAndItemsInPlace() {
        let layout = PhotoLibraryLayout(ranges: ranges)
        XCTAssertEqual(layout.sectionCount, 4)
        XCTAssertEqual(layout.itemCount, 10)
        XCTAssertEqual(layout.numberOfItems(inSection: 2), 5)
        XCTAssertEqual(layout.assetIndex(section: 0, item: 0), 0)
        XCTAssertEqual(layout.assetIndex(section: 2, item: 4), 8)
        XCTAssertEqual(layout.range(ofSection: 3), 9..<10)
    }

    func testOldestFirstReversesSectionsAndItems() {
        let layout = PhotoLibraryLayout(ranges: ranges, newestFirst: false)
        XCTAssertEqual(layout.range(ofSection: 0), 9..<10)
        XCTAssertEqual(layout.assetIndex(section: 0, item: 0), 9)
        XCTAssertEqual(layout.assetIndex(section: 3, item: 0), 2)
        XCTAssertEqual(layout.assetIndex(section: 3, item: 2), 0)
        XCTAssertEqual(layout.numberOfItems(inSection: 1), 5)
    }

    func testRoundTripInBothOrdersAndOldestFirstIsTheExactReverse() {
        let times = syntheticTimes(count: 3_000, years: 2)
        for ranges in [referenceSections(times, components: [.year, .month, .day]),
                       referenceSections(times, components: [.year, .month]), [0..<times.count]] {
            var shown = [[Int]]()
            for newestFirst in [true, false] {
                let layout = PhotoLibraryLayout(ranges: ranges, newestFirst: newestFirst)
                var seen = [Int]()
                for s in 0..<layout.sectionCount {
                    for i in 0..<layout.numberOfItems(inSection: s) {
                        let index = layout.assetIndex(section: s, item: i)
                        seen.append(index)
                        let p = layout.position(ofAssetAt: index)
                        XCTAssertEqual(p?.section, s)
                        XCTAssertEqual(p?.item, i)
                    }
                }
                XCTAssertEqual(Set(seen).count, times.count)
                shown.append(seen)
            }
            XCTAssertEqual(shown[0], shown[1].reversed())
        }
    }

    func testPositionOfAnUnknownAssetIsNil() {
        let layout = PhotoLibraryLayout(ranges: ranges)
        XCTAssertNil(layout.position(ofAssetAt: 10))
        XCTAssertNil(layout.position(ofAssetAt: -1))
    }

    func testSingleSectionAndEmptyAlbum() {
        XCTAssertEqual(PhotoLibraryLayout.single(count: 5).ranges, [0..<5])
        let empty = PhotoLibraryLayout.single(count: 0)
        XCTAssertEqual(empty.sectionCount, 1)
        XCTAssertEqual(empty.numberOfItems(inSection: 0), 0)
        XCTAssertEqual(empty.itemCount, 0)
        XCTAssertEqual(PhotoLibraryLayout(ranges: []).itemCount, 0)
    }

    func testChangingTheOrderKeepsTheSections() {
        let layout = PhotoLibraryLayout(ranges: ranges)
        XCTAssertEqual(layout.with(newestFirst: false).ranges, ranges)
        XCTAssertEqual(layout.with(newestFirst: false).with(newestFirst: true), layout)
    }
}
