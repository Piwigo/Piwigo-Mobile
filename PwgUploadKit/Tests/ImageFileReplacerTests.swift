//
//  ImageFileReplacerTests.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import XCTest
@testable import PwgUploadKit

final class ImageFileReplacerTests: XCTestCase {

    private func text(_ data: Data?) -> String? {
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }

    func testCleanReplyIsReturnedAsIs() {
        let reply = #"{"stat":"ok","result":{"id":78972,"file":"a.jpg"}}"#
        XCTAssertEqual(text(ImageFileReplacer.firstJSONObject(in: Data(reply.utf8))), reply)
    }

    /// What the Community plugin printed around the reply when the category was missing
    func testWarningBeforeAndFatalErrorAfterTheReplyAreIgnored() {
        let json = #"{"stat":"ok","result":{"id":78972,"file":"a.jpg","name":"A {braced} \"name\""}}"#
        let reply = "<br />\n<b>Warning</b>:  Undefined array key \"category\" in <b>/main.inc.php</b> on line <b>291</b><br />\n"
            + json
            + "<br />\n<b>Fatal error</b>:  Uncaught mysqli_sql_exception: You have an error in your SQL syntax\nStack trace:\n#0 {main}\n  thrown in <b>x.php</b>"
        XCTAssertEqual(text(ImageFileReplacer.firstJSONObject(in: Data(reply.utf8))), json)
    }

    func testIncompleteOrMissingJSONGivesNothing() {
        XCTAssertNil(ImageFileReplacer.firstJSONObject(in: Data("<b>Fatal error</b>".utf8)))
        XCTAssertNil(ImageFileReplacer.firstJSONObject(in: Data(#"{"stat":"ok","result":{"id":1"#.utf8)))
        XCTAssertNil(ImageFileReplacer.firstJSONObject(in: Data()))
    }
}
