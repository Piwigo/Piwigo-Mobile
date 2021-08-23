//
//  piwigoWebAPI.swift
//  piwigoWebAPI
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://app.quicktype.io/?share=
//     https://jsonlint.com/?code=

import Foundation
import XCTest
import piwigoKit

class piwigoWebAPI: XCTestCase {

    // MARK: - pwg.…
    func testPwgGetInfosDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.getInfos", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(GetInfosJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")

        XCTAssertEqual(result.data[0].name, "version")
        XCTAssertEqual(result.data[0].value, "11.5.0")
    }


    // MARK: - pwg.images…
    func testPwgImagesUploadDecoding() {
        
        // Case of a JPG file
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.upload", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesUploadJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")
        
        XCTAssertEqual(result.data.image_id, 6580)
        XCTAssertEqual(result.data.name, "Delft - 06")
        XCTAssertEqual(result.data.square_src, "https://.../20200628211106-5fc9fb08-sq.jpg")
        XCTAssertEqual(result.data.src, "https://.../20200628211106-5fc9fb08-th.jpg")

        // Case of a PNG file
        guard let url2 = bundle.url(forResource: "pwg.images.upload2", withExtension: "json"),
            let data2 = try? Data(contentsOf: url2) else {
                return
        }
        
        guard let result2 = try? decoder.decode(ImagesUploadJSON.self, from: data2) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result2.status, "ok")
        XCTAssertEqual(result2.errorCode, 0)
        XCTAssertEqual(result2.errorMessage, "")
        
        XCTAssertEqual(result2.data.image_id, 6582)
        XCTAssertEqual(result2.data.name, "Screenshot 2020-06-28 at 14.01.38")
        XCTAssertEqual(result2.data.square_src, "https://.../20200628212043-0a9c6158-sq.png")
        XCTAssertEqual(result2.data.src, "https://.../20200628212043-0a9c6158-th.png")
    }

    func testPwgImagesSetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.setInfo", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesSetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }

    
    // MARK: - pwg.tags…
    func testPwgTagsGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.getList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data[1].id, 14)
        XCTAssertEqual(result.data[2].counter, 9)
    }

    func testPwgTagsGetAdminListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.getAdminList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data[0].id, 1)
        XCTAssertEqual(result.data[2].name, "Piwigo")
    }

    func testPwgTagsAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.add", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(TagAddJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data.id, 26)
    }

    // MARK: - community
    func testCommunityImagesUploadCompletedDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "community.images.uploadCompleted", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CommunityImagesUploadCompletedJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
}
