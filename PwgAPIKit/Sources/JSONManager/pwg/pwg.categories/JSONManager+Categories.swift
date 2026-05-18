//
//  JSONManager+Categories.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 25/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

public extension JSONManager {
    // MARK: - Albums
    @concurrent
    func fetchAlbums(forUserWithAdminRights hasAdminRights: Bool,
                     inParentWithId parentId: Int32, recursively: Bool = false,
                     thumbnailSize: pwgImageSize) async throws(PwgKitError) -> [CategoryGetInfo] {
        // Smart album requested?
        if parentId < 0 { preconditionFailure("••> Cannot fetch data of smart album!") }
        debugPrint("••> Fetch albums in parent with ID: \(parentId)")
        
        // Launch the HTTP(S) request
        var pwgData = try await JSONManager.shared.getAlbums(inParentWithId: parentId,
                                                             recursively: recursively,
                                                             thumbnailSize: thumbnailSize)
        
        // Get Community albums if needed (not needed for admins)
        if hasAdminRights == false,
           ServerVars.shared.usesCommunityPluginV29 {
            let comData = try await getCommunityAlbums(inParentWithId: parentId,
                                                       recursively: recursively)
            // Combine album data
            for comAlbum in comData {
                if let index = pwgData.firstIndex(where: { $0.id == comAlbum.id }) {
                    pwgData[index].hasUploadRights = true
                }
                else {
                    var newAlbum = comAlbum
                    newAlbum.hasUploadRights = true
                    pwgData.append(newAlbum)
                }
            }
        }
        
        return pwgData
    }
//        // Import album data into Core Data.
//        do {
//            // Update albums if Community installed (not needed for admins)
//            if hasAdminRights == false,
//               ServerVars.shared.usesCommunityPluginV29 {
//                // Non-admin user and Community installed —> collect Community albums
//                try await fetchCommunityAlbums(inParentWithId: parentId, recursively: recursively,
//                                               albums: pwgData)
//                return []
//            }
//
////            // Import the albumJSON into Core Data.
////            try albumProvider.importAlbums(pwgData, recursively: recursively, inParent: parentId)
//        }
//        catch let error as PwgKitError {
//            throw error
//        }
//        catch {
//            throw .otherError(innerError: error)
//        }
//    }
    
    @concurrent
    func getAlbums(inParentWithId parentId: Int32, recursively: Bool,
                   thumbnailSize: pwgImageSize) async throws(PwgKitError) -> [CategoryGetInfo] {
        // Prepare parameters
        let paramsDict: [String : Any] = [
            "cat_id"            : parentId,
            "recursive"         : recursively,
            "faked_by_community": ServerVars.shared.usesCommunityPluginV29 ? "false" : "true",
            "thumbnail_size"    : thumbnailSize.argument
        ]
        
        // Launch the HTTP(S) request
        let pwgData = try await JSONManager.shared.postRequest(withMethod: pwgCategoriesGetList, paramDict: paramsDict,
                                                               jsonObjectClientExpectsToReceive: CategoriesGetListJSON.self,
                                                               countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
        return pwgData.data
    }

    @concurrent
    func create(withName name:String, description: String, status: String,
                inAlbumWithId parentAlbumId: Int32) async throws(PwgKitError) -> Int32 {
        
        // Prepare parameters
        let paramsDict: [String : Any] = ["name"    : name,
                                          "parent"  : parentAlbumId,
                                          "comment" : description,
                                          "status"  : status]
        
        // Retrieve album ID
        let pwgData = try await postRequest(withMethod: pwgCategoriesAdd, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: CategoriesAddJSON.self,
                                            countOfBytesClientExpectsToReceive: 1040)
        
        if let catId = pwgData.data.id, catId != Int32.min {
            return catId
        }
        else {
            // Could not retrieve album ID
            throw .unexpectedError
        }
    }
    
    @concurrent
    func setInfos(_ albumId: Int32, withName name:String, description: String) async throws(PwgKitError) {
        
        // Prepare parameters
        /// token required for updating HTML in name/comment
        let paramsDict: [String : Any] = ["category_id" : albumId,
                                          "name"        : name,
                                          "comment"     : description,
                                          "pwg_token"   : ServerVars.shared.pwgToken
        ]
        
        // Update album data
        _ = try await postRequest(withMethod: pwgCategoriesSetInfo, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: CategoriesSetInfoJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
    
    @concurrent
    func move(_ albumId: Int32, intoAlbumWithId newParentId: Int32) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : albumId,
                                          "parent"      : newParentId,
                                          "pwg_token"   : ServerVars.shared.pwgToken]
        
        // Move album
        _ = try await JSONManager.shared.postRequest(withMethod: pwgCategoriesMove, paramDict: paramsDict,
                                                     jsonObjectClientExpectsToReceive: CategoriesMoveJSON.self,
                                                     countOfBytesClientExpectsToReceive: 1000)
    }
    
    @concurrent
    func deleteCategory(withID catID: Int32, inMode mode: pwgAlbumDeletionMode) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id"         : catID,
                                          "photo_deletion_mode" : mode.pwgArg,
                                          "pwg_token"           : ServerVars.shared.pwgToken]
        
        // Delete album
        _ = try await postRequest(withMethod: pwgCategoriesDelete, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: CategoriesDeleteJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
    
    
    // MARK: - Images
    @concurrent
    func calcOrphans(_ catID: Int32) async throws(PwgKitError) -> Int64 {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id": catID]
        
        // Get number of orphans
        let pwgData = try await postRequest(withMethod: pwgCategoriesCalcOrphans, paramDict: paramsDict,
                                            jsonObjectClientExpectsToReceive: CategoriesCalcOrphansJSON.self,
                                            countOfBytesClientExpectsToReceive: 2100)
        
        // Data retrieved successfully?
        if let nberOrphans = pwgData.data?.first?.nbImagesBecomingOrphan {
            return nberOrphans
        } else {
            throw .unexpectedError
        }
    }
    
    @concurrent
    func setRepresentative(ofAlbumWithID albumID: Int32, withImageID imageID: Int64) async throws(PwgKitError) {
        // Prepare parameters
        let paramsDict: [String : Any] = ["category_id" : albumID,
                                          "image_id"    : imageID]
        
        _ = try await postRequest(withMethod: pwgCategoriesSetRepresentative, paramDict: paramsDict,
                                  jsonObjectClientExpectsToReceive: CategoriesSetRepresentativeJSON.self,
                                  countOfBytesClientExpectsToReceive: 1000)
    }
    
    @concurrent
    func getImages(ofAlbumWithId albumId: Int32, withQuery query: String,
                   sort: pwgImageSort, fromPage page:Int, perPage: Int) async throws(PwgKitError) -> (PageData,[ImageGetInfo]) {
        // Prepare parameters
        var method = pwgCategoriesGetImages
        var paramsDict: [String : Any] = [
            "per_page"  : perPage,
            "page"      : page,
            "order"     : sort.param
        ]
        switch albumId {
        case pwgSmartAlbum.search.rawValue:
            method = pwgImagesSearch
            paramsDict["query"] = "*" + query + "*"

        case pwgSmartAlbum.visits.rawValue:
            paramsDict["recursive"] = true
            paramsDict["f_min_hit"] = 1
            
        case pwgSmartAlbum.best.rawValue:
            paramsDict["recursive"] = true
            paramsDict["f_min_rate"] = 1
            
        case pwgSmartAlbum.recent.rawValue:
            let recentPeriod = ServerVars.shared.recentPeriodList[ServerVars.shared.recentPeriodIndex]
            let maxPeriod = ServerVars.shared.recentPeriodList.last ?? 99
            let nberDays = recentPeriod == 0 ? maxPeriod : recentPeriod
            let daysAgo1 = Date(timeIntervalSinceNow: TimeInterval(-3600 * 24 * nberDays))
            let daysAgo2 = Calendar.current.date(byAdding: .day, value: -nberDays, to: Date()) ?? daysAgo1
            let dateAvailableString = DateUtilities.string(from: daysAgo2.timeIntervalSinceReferenceDate)
            paramsDict["recursive"] = true
            paramsDict["f_min_date_available"] = dateAvailableString
            
        case pwgSmartAlbum.favorites.rawValue:
            method = pwgUsersFavoritesGetList
            
        case Int32.min...pwgSmartAlbum.tagged.rawValue:
            method = pwgTagsGetImages
            paramsDict["tag_id"] = pwgSmartAlbum.tagged.rawValue - albumId
            
        default:    // Standard Piwigo album
            paramsDict["cat_id"] = albumId
        }
        
        let pwgData = try await self.postRequest(withMethod: method, paramDict: paramsDict,
                                                 jsonObjectClientExpectsToReceive: CategoriesGetImagesJSON.self,
                                                 countOfBytesClientExpectsToReceive: NSURLSessionTransferSizeUnknown)
        if let paging = pwgData.paging {
            return (paging, pwgData.data)
        }
        throw .unexpectedError
    }
}
