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
import uploadKit

class piwigoWebAPI: XCTestCase {
    
    // MARK: - community.…
    func testCommunityCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: kCommunityCategoriesGetList, withExtension: "json"),
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
        guard let url = bundle.url(forResource: kCommunityImagesUploadCompleted, withExtension: "json"),
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
        guard let url = bundle.url(forResource: kCommunitySessionGetStatus, withExtension: "json"),
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
        guard let url = bundle.url(forResource: pwgGetInfos, withExtension: "json"),
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
        XCTAssertEqual(result.data[0].name, "version")
        XCTAssertEqual(result.data[0].value?.stringValue, "12.2.0")
    }


    // MARK: - pwg.categories…
    func testPwgCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgCategoriesGetList, withExtension: "json"),
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
        XCTAssertTrue(result.data.contains(where: { $0.commentRaw == "Which are different as explained for example here: https://northamericannature.com/what-is-the-difference-between-insects-and-spiders/" }))
    }

    func testPwgCategoriesAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgCategoriesAdd, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesSetInfo, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesMove, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesCalcOrphans, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesDelete, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesSetRepresentative, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
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
        guard let url = bundle.url(forResource: pwgCategoriesGetImages, withExtension: "json"),
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
        XCTAssertEqual(result.data.first?.isFavorite, true)
        XCTAssertEqual(result.data.first?.datePosted, "2018-08-23 19:01:39")
        XCTAssertEqual(result.data.first?.downloadUrl, "https:/action.php?id=62417&part=e&download")
        XCTAssertEqual(result.data.first?.categories?.first?.id, 2)
        XCTAssertEqual(result.data.last?.derivatives.largeImage?.height?.intValue, 756)
    }

    // MARK: - pwg.images…
    func testPwgImagesExist() {
        
        // Case of a list containing existing and non-existing images
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesExist, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesExistJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
    }
    
    func testPwgImagesGetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesGetInfo, withExtension: "json"),
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
        XCTAssertEqual(result.data.md5checksum, "3175a7347fd5d6348935ec955f52a9e3")
        XCTAssertEqual(result.data.derivatives.largeImage?.height?.intValue, 756)
        XCTAssertEqual(result.data.commentRaw, "<!DOCTYPE html><html lang=\"fr\"><head>    <meta charset=\"UTF-8\">    <title>Exemple avec police</title>    <style>        p {            font-family: 'Comic Sans MS', cursive;            font-size: 18px;            color: #0000FF;        }    </style></head><body>    <p>Great view from Pic du Midi! Visit Piwigo.org</p></body></html>")
    }

    func testPwgImagesSetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesSetInfo, withExtension: "json"),
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

    func testPwgImagesSetCategoryDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesSetCategory, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesSetCategoryJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }

    func testPwgImagesUploadDecoding() {
        
        // Case of a JPG file
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesUpload, withExtension: "json"),
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
        XCTAssertEqual(result2.data.image_id, 6582)
//        XCTAssertEqual(result2.data.name, "Screenshot 2020-06-28 at 14.01.38")
        XCTAssertEqual(result2.data.square_src, "https://.../20200628212043-0a9c6158-sq.png")
        XCTAssertEqual(result2.data.src, "https://.../20200628212043-0a9c6158-th.png")
    }

    func testPwgImagesUploadCompletedDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesUploadCompleted, withExtension: "json"),
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

    func testPwgImagesDeleteDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgImagesDelete, withExtension: "json"),
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

    
    // MARK: - pwg.history.…
    func testPwgSessionHistoryLogDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgHistoryLog, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(HistoryLogJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
    }
    
    
    // MARK: - pwg.session.…
    func testPwgSessionLoginDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgSessionLogin, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(SessionLoginJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.success, true)
    }

    func testPwgSessionGetStatusDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgSessionGetStatus, withExtension: "json"),
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
        XCTAssertEqual(result.data?.language, "en_GB")
        XCTAssertTrue(result.data?.saveVisits ?? false)
    }

    func testPwgSessionLogoutDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgSessionLogout, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(SessionLogoutJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.success, true)
    }


    // MARK: - pwg.tags…
    func testPwgTagsGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgTagsGetList, withExtension: "json"),
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
        guard let url = bundle.url(forResource: pwgTagsGetAdminList, withExtension: "json"),
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

    func testPwgTagsGetAdminList2Decoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "pwg.tags.getAdminList2", withExtension: "json"),
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
        XCTAssertEqual(result.data[0].id?.intValue, 254)
        XCTAssertEqual(result.data[2].name, "Ahmet Akkaya")
    }

    func testPwgTagsAddDecoding() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgTagsAdd, withExtension: "json"),
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
    func testPwgUsersGetList() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgUsersGetList, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }

        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(UsersGetListJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.paging?.perPage, 100)
        XCTAssertEqual(result.paging?.count, 8)
        XCTAssertEqual(result.users.first?.userName, "Eddy")
        XCTAssertEqual(result.users.first?.showNberOfComments?.boolValue, false)
        XCTAssertEqual(result.users.last?.lastVisitFromHistory?.boolValue, false)
    }
    
    func testPwgUsersFavoritesGetList() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgUsersFavoritesGetList, withExtension: "json"),
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
    }

    
    // MARK: - pwg.groups…
    func testPwgGroupsGetList() {
        
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: pwgGroupsGetList, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }

        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(GroupsGetListJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.paging?.perPage, 100)
        XCTAssertEqual(result.paging?.count, 3)
        XCTAssertEqual(result.groups.first?.name, "Group")
        XCTAssertEqual(result.groups.first?.isDefault?.boolValue, false)
        XCTAssertEqual(result.groups.first?.nbUsers?.intValue, 2)
        XCTAssertEqual(result.groups.last?.lastModified, "2025-02-16 17:39:07")
    }
    

    // MARK: - reflection.…
    func testReflectionGetMethodListDecoding() {
        // Case of a successful request
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: kReflectionGetMethodList, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Is this a valid JSON object?
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ReflectionGetMethodListJSON.self, from: data) else {
            XCTFail()
            return
        }

        XCTAssertEqual(result.status, "ok")
        XCTAssertEqual(result.data[0], kCommunityCategoriesGetList)
        XCTAssertEqual(result.data[1], kCommunityImagesUploadCompleted)
    }
}
