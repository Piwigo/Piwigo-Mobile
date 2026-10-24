import XCTest
@testable import PwgUploadKit

final class PhotoLibrarySelectionTests: XCTestCase {

    func testSelectingASectionInsertsOneRangeWithoutTheQueuedAssets() {
        var selection = PhotoLibrarySelection()
        let queued = IndexSet([102, 150, 199])
        selection.select(range: 100..<200, excluding: queued)
        XCTAssertEqual(selection.count, 97)
        XCTAssertFalse(selection.contains(150))
        XCTAssertTrue(selection.contains(100))
        XCTAssertTrue(selection.contains(199 - 1))
        XCTAssertEqual(selection.positions.rangeView.count, 3)          // 100..<102, 103..<150, 151..<199
    }

    func testDeselectingASectionLeavesTheOthers() {
        var selection = PhotoLibrarySelection(positions: IndexSet(integersIn: 0..<300))
        selection.deselect(range: 100..<200)
        XCTAssertEqual(selection.count, 200)
        XCTAssertFalse(selection.contains(100))
        XCTAssertTrue(selection.contains(99))
        XCTAssertTrue(selection.contains(200))
    }

    func testVeryLargeSelectionIsCheap() {
        var selection = PhotoLibrarySelection()
        selection.select(range: 0..<1_000_000, excluding: IndexSet([5, 500_000]))
        XCTAssertEqual(selection.count, 999_998)
        XCTAssertEqual(selection.positions.rangeView.count, 3)
        selection.deselect(range: 0..<1_000_000)
        XCTAssertTrue(selection.isEmpty)
    }

    func testSelectStateOfASection() {
        let range = 10..<20
        var selection = PhotoLibrarySelection()
        let none = IndexSet()
        XCTAssertEqual(selection.selectState(of: 5..<5, queued: none, reUploadAllowed: false), .none)
        XCTAssertEqual(selection.selectState(of: range, queued: none, reUploadAllowed: false), .select)
        selection.select(range: 10..<15, excluding: none)
        XCTAssertEqual(selection.selectState(of: range, queued: none, reUploadAllowed: false), .select)
        selection.select(range: range, excluding: none)
        XCTAssertEqual(selection.selectState(of: range, queued: none, reUploadAllowed: false), .deselect)
    }

    func testQueuedAssetsCountAsDoneUnlessReUploadIsAllowed() {
        let range = 0..<10
        let allQueued = IndexSet(integersIn: range)
        var selection = PhotoLibrarySelection()
        XCTAssertEqual(selection.selectState(of: range, queued: allQueued, reUploadAllowed: false), .none)
        XCTAssertEqual(selection.selectState(of: range, queued: allQueued, reUploadAllowed: true), .select)

        let someQueued = IndexSet([2, 3])
        selection.select(range: range, excluding: someQueued)
        XCTAssertEqual(selection.count, 8)
        XCTAssertEqual(selection.selectState(of: range, queued: someQueued, reUploadAllowed: false), .deselect)
        XCTAssertEqual(selection.selectState(of: range, queued: someQueued, reUploadAllowed: true), .select)
    }

    func testOrderedPositionsFollowTheDisplayedOrder() {
        let selection = PhotoLibrarySelection(positions: IndexSet([7, 1, 4]))
        XCTAssertEqual(selection.orderedPositions(newestFirst: true), [1, 4, 7])
        XCTAssertEqual(selection.orderedPositions(newestFirst: false), [7, 4, 1])
    }

    func testRemovingTheQueuedAssets() {
        var selection = PhotoLibrarySelection(positions: IndexSet(integersIn: 0..<10))
        selection.remove(IndexSet([3, 4, 20]))
        XCTAssertEqual(selection.count, 8)
        selection.insert(3)
        XCTAssertTrue(selection.contains(3))
        selection.remove(3)
        XCTAssertFalse(selection.contains(3))
        selection.removeAll()
        XCTAssertTrue(selection.isEmpty)
    }
}
