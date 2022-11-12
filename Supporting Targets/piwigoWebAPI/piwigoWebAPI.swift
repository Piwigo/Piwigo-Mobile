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
    
    // MARK: - community.…
    func testCommunityCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "community.categories.getList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CommunityCategoriesGetListJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.data.contains(where: { $0.id == 4 }))
    }

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
        XCTAssertTrue(result.data.contains(where: { $0.id == "51768" }))
    }

    func testCommunitySessionGetStatusDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "community.session.getStatus", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CommunitySessionGetStatusJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.realUser, "webmaster")
        XCTAssertEqual(result.uploadMethod, "pwg.categories.getAdminList")
    }


    // MARK: - pwg.…
    func testPwgGetInfosDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.getInfos", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: GetInfosJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(GetInfosJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")

        XCTAssertEqual(result.data[0].name, "version")
        XCTAssertEqual(result.data[0].value?.stringValue, "12.2.0")
    }


    // MARK: - pwg.categories…
    func testPwgCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.getList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesGetListJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.data.contains(where: { $0.id == 38 }))
    }

    func testPwgCategoriesAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.add", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesAddJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesAddJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data.id, 587)
    }
    
    func testPwgCategoriesSetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.setInfo", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesSetInfoJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesSetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
    
    func testPwgCategoriesMoveDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.move", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesMoveJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesMoveJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
    
    func testPwgCategoriesCalcOrphansDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.calculateOrphans", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesCalcOrphansJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesCalcOrphansJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data?.first?.nbImagesBecomingOrphan, 8)
    }
    
    func testPwgCategoriesDeleteDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.delete", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesDeleteJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesDeleteJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
    
    func testPwgCategoriesSetRepresentativeDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.setRepresentative", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: CategoriesSetRepresentativeJSON.self) {
            XCTFail()
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesSetRepresentativeJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
    
    func testPwgCategoriesGetImagesDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.categories.getImages", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesGetImagesJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.paging?.perPage, 100)
        XCTAssertEqual(result.paging?.totalCount?.intValue, 8)
        XCTAssertEqual(result.data.first?.datePosted, "2018-08-23 19:01:39")
        XCTAssertEqual(result.data.first?.categories?.first?.id, 2)
        XCTAssertEqual(result.data.last?.derivatives.largeImage?.height?.intValue, 756)
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
//        XCTAssertEqual(result.data.name, "Delft - 06")
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
//        XCTAssertEqual(result2.data.name, "Screenshot 2020-06-28 at 14.01.38")
        XCTAssertEqual(result2.data.square_src, "https://.../20200628212043-0a9c6158-sq.png")
        XCTAssertEqual(result2.data.src, "https://.../20200628212043-0a9c6158-th.png")
    }

    func testPwgImagesUploadCompletedDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.uploadCompleted", withExtension: "json"),
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
    }

    func testPwgImagesGetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.getInfo", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesGetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data.md5checksum, "7870f465dd76af3f0bd6d4f087afa5cd")
        XCTAssertEqual(result.data.derivatives.largeImage?.height?.intValue, 756)
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

    func testPwgImagesDeleteDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.images.delete", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesDeleteJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.result, 1)
    }

    
    // MARK: - pwg.session.…
    func testPwgSessionLoginDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.session.login", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: SessionLoginJSON.self) {
            XCTFail()
            return
        }

        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(SessionLoginJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")

        XCTAssertEqual(result.success, true)
    }

    func testPwgSessionGetStatusDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.session.getStatus", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(SessionGetStatusJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data?.userName, "Eddy")
        XCTAssertEqual(result.data?.language, "fr_FR")
    }

    func testPwgSessionLogoutDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.session.logout", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: SessionLogoutJSON.self) {
            XCTFail()
            return
        }

        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(SessionLogoutJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")

        XCTAssertEqual(result.success, true)
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
        XCTAssertEqual(result.data[1].id?.intValue, 14)
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
        XCTAssertEqual(result.data[0].id?.intValue, 1)
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

    
    // MARK: - pwg.users…
    func testPwgUsersFavoritesGetList() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.users.favorites.getList", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(CategoriesGetImagesJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.paging?.perPage, 2)
        XCTAssertEqual(result.paging?.count, 40)
        XCTAssertEqual(result.data.first?.datePosted, "2018-08-23 19:28:43")
        XCTAssertEqual(result.data.last?.derivatives.largeImage?.height?.intValue, 670)
    }

    func testPwgUsersFavoritesAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.users.favorites.addRemove", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(FavoritesAddRemoveJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.result, true)
    }

    
    // MARK: - reflection.…
    func testReflectionGetMethodListDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "reflection.getMethodList", withExtension: "json"),
            var data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Clean returned data
        if !data.isPiwigoResponseValid(for: ReflectionGetMethodListJSON.self) {
            XCTFail()
            return
        }

        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ReflectionGetMethodListJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.errorCode, 0)
        XCTAssertEqual(result.errorMessage, "")

        XCTAssertEqual(result.data[0], "community.categories.getList")
        XCTAssertEqual(result.data[1], "community.images.uploadCompleted")
    }
}
