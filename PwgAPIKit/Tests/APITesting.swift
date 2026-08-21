//
//  PwgAPITesting.swift
//  PwgAPITesting
//
//  Created by Eddy Lelièvre-Berna on 28/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://app.quicktype.io/?share=
//     https://jsonlint.com/?code=

import Foundation
import XCTest
import PwgKit
import PwgAPIKit

final class PwgAPITesting: XCTestCase {
    
    // MARK: - community.…
    func testCommunityCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        XCTAssertEqual(result.createAlbumRights, [5,43])
    }
    
    
    // MARK: - pwg.…
    func testPwgGetInfosDecoding() {
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: pwgGetInfos, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // Try decoding cleaner JSON object
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(GetInfosJSON.self, from: data)
            
            // Return decoded object
            XCTAssertEqual(result.status, "ok")
            XCTAssertEqual(result.data[0].name, "version")
            XCTAssertEqual(result.data[0].value?.stringValue, "16.3.0")
        }
        catch let DecodingError.dataCorrupted(context) {
            // Piwigo error?
            if let pwgError = context.underlyingError as? PwgKitError {
                XCTAssertEqual(pwgError.localizedDescription, "The username and password don't match on the given web address")
            }
            else {
                XCTFail("Error returned is not a Piwigo error.")
            }
        }
        catch let error as DecodingError {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
        catch let error {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
    }
    
    
    // MARK: - pwg.categories…
    func testPwgCategoriesGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        XCTAssertEqual(result.data.pageUrl, "https://.../picture.php?/2")
    }
    
    func testPwgImagesSetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
    
    func testPwgImagesUploadCompletedDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: pwgImagesUploadCompleted, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ImagesUploadCompletedJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
    }
    
    func testPwgImagesDeleteDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        XCTAssertEqual(result.success, true)
    }
    
    
    // MARK: - pwg.history.…
    func testPwgSessionHistoryLogDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        
        // Case of a non-successful request
        let nonSuccessfullLogin = "\(pwgSessionLogin)2"
        guard let url = bundle.url(forResource: nonSuccessfullLogin, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        do {
            let _ = try decoder.decode(SessionLoginJSON.self, from: data)
        }
        catch let DecodingError.dataCorrupted(context) {
            // Piwigo error?
            if let pwgError = context.underlyingError as? PwgKitError {
                XCTAssertEqual(pwgError.localizedDescription, "The username and password don't match on the given web address")
            }
            else {
                XCTFail("Error returned is not a Piwigo error.")
            }
        }
        catch let error as DecodingError {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
        catch let error {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
    }
    
    func testPwgSessionGetStatusDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        XCTAssertEqual(result.data?.language, "en_UK")
        XCTAssertTrue(result.data?.saveVisits ?? false)
        XCTAssertTrue((result.data?.imageSizes ?? []).contains("3xlarge"))
    }
    
    func testPwgSessionLogoutDecoding() {
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: pwgSessionLogout, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(SessionLogoutJSON.self, from: data)
            
            XCTAssertEqual(result.status, "ok")
            XCTAssertEqual(result.success, true)
        }
        catch let DecodingError.dataCorrupted(context) {
            // Piwigo error?
            if let pwgError = context.underlyingError as? PwgKitError {
#if DEBUG
                debugPrint(pwgError.localizedDescription)
#endif
            }
            else {
                XCTFail("Error returned is not a Piwigo error.")
            }
        }
        catch let error as DecodingError {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
        catch let error {
#if DEBUG
            debugPrint(error.localizedDescription)
#endif
            XCTFail("Error returned is not a Piwigo error.")
        }
    }
    
    
    // MARK: - pwg.tags…
    func testPwgTagsGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
        let bundle = Bundle.module
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
    
    
    // MARK: - sharealbum.…
    func testShareAlbumGetListDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumGetList, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumGetListJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.data.contains(where: { $0.pwgID?.int16Value == 2 }))
        XCTAssertTrue(result.data.contains(where: { $0.catID?.int32Value == 43 }))
        XCTAssertTrue(result.data.contains(where: { $0.name == "People" }))
    }
    
    func testShareAlbumGetShareableDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumGetShareable, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumGetShareableJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.data.contains(where: { $0.catID?.int32Value == 5 }))
        XCTAssertTrue(result.data.contains(where: { $0.name == "Sub-album" }))
    }
    
    func testShareAlbumCreateDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumCreate, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumCreateJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertFalse(result.isAlreadyShared)
        XCTAssertEqual(result.data?.catID?.int32Value, 28)
        XCTAssertEqual(result.data?.shareCode, "hvtEixyxCmqF")
    }
    
    func testShareAlbumGetInfoDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumgetInfo, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumGetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.isShared)
        XCTAssertEqual(result.data?.catID?.int32Value, 28)
        XCTAssertEqual(result.data?.name, "Artistics")
        XCTAssertEqual(result.data?.createdBy?.int16Value, 1)
    }
    
    func testShareAlbumRenewDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumRenew, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumRenewJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.isShared)
        XCTAssertEqual(result.data?.catID?.int32Value, 23)
        XCTAssertEqual(result.data?.shareCode, "nemaacwahggh")
    }
    
    func testShareAlbumCancelDecoding() {
        
        // Case of a successful request
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: kShareAlbumCancel, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumCancelJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "ok")
        XCTAssertTrue(result.success)
    }
    
    func testShareAlbumGetInfoOfAlbumNotShared() {
        
        // Case of an album which is not shared
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "sharealbum.notShared", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // An album which is not shared should not be reported as an error
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumGetInfoJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "fail")
        XCTAssertFalse(result.isShared)
        XCTAssertNil(result.data)
    }
    
    func testShareAlbumRenewOfAlbumNotShared() {
        
        // Case of an album which is not shared
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "sharealbum.notShared", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // An album which is not shared should not be reported as an error
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumRenewJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "fail")
        XCTAssertFalse(result.isShared)
        XCTAssertNil(result.data)
    }
    
    func testShareAlbumCancelOfAlbumNotShared() {
        
        // Case of an album which is not shared
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "sharealbum.notShared", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // An album which is not shared should not be reported as an error
        /// The album is not shared any more, i.e. the expected result is achieved.
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumCancelJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "fail")
        XCTAssertTrue(result.success)
    }
    
    func testShareAlbumCreateOfAlbumAlreadyShared() {
        
        // Case of an album which is already shared
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "sharealbum.alreadyShared", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Could not load resource file")
            return
        }
        
        // An album which is already shared should not be reported as an error
        /// The share URL should then be retrieved with sharealbum.getInfo.
        let decoder = JSONDecoder()
        guard let result = try? decoder.decode(ShareAlbumCreateJSON.self, from: data) else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(result.status, "fail")
        XCTAssertTrue(result.isAlreadyShared)
        XCTAssertNil(result.data)
    }
}
