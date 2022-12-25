//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit
import UIKit

enum pwgImageCollectionType {
    case popup, full
}

@objc
class AlbumUtilities: NSObject {
    
    // MARK: - Constants
    static let kAlbumCellSpacing = CGFloat(8)               // Spacing between albums (horizontally and vertically)
    static let kAlbumMarginsSpacing = CGFloat(4)            // Left and right margins for albums

    static let kImageCellSpacing4iPhone = CGFloat(1)        // Spacing between images (horizontally and vertically)
    static let kImageCellHorSpacing4iPad = CGFloat(8)
    static let kImageCellHorSpacing4iPadPopup = CGFloat(1)
    static let kImageCellVertSpacing4iPad = CGFloat(8)
    static let kImageCellVertSpacing4iPadPopup = CGFloat(1)
    static let kImageMarginsSpacing = CGFloat(4)            // Left and right margins for images
    static let kThumbnailFileSize = CGFloat(144)            // Default Piwigo thumbnail file size

    static let kImageDetailsCellSpacing = CGFloat(8)        // Spacing between image details cells
    static let kImageDetailsMarginsSpacing = CGFloat(16)    // Left and right margins for image details cells

    
    // MARK: - Piwigo Server Methods
//    static func getAlbums(completion: @escaping (Bool) -> Void,
//                          failure: @escaping (NSError) -> Void) {
//
//        // Prepare parameters for setting album thumbnail
//        let paramsDict: [String : Any] = [
//            "cat_id"            : 0,
//            "recursive"         : true,
//            "faked_by_community": NetworkVars.usesCommunityPluginV29 ? "false" : "true",
//            "thumbnail_size"    : thumbnailSizeArg()
//        ]
//
//        let JSONsession = PwgSession.shared
//        JSONsession.postRequest(withMethod: pwgCategoriesGetList, paramDict: paramsDict,
//                                jsonObjectClientExpectsToReceive: CategoriesGetListJSON.self,
//                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
//            // Decode the JSON object and update the category cache.
//            do {
//                // Decode the JSON into codable type CategoriesGetListJSON.
//                let decoder = JSONDecoder()
//                let uploadJSON = try decoder.decode(CategoriesGetListJSON.self, from: jsonData)
//
//                // Piwigo error?
//                if uploadJSON.errorCode != 0 {
//                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
//                                                                 errorMessage: uploadJSON.errorMessage)
//                    failure(error as NSError)
//                    return
//                }
//
//                // Extract albums data from JSON message
//                let albums = parseAlbumJSON(uploadJSON.data)
//
//                // Update Categories Data cache
//                let didUpdateCats = CategoriesData.sharedInstance().replaceAllCategories(albums)
//
//                // Check whether the auto-upload category still exists
//                let autoUploadCatId = UploadVars.autoUploadCategoryId
//                let indexOfAutoUpload = albums.firstIndex(where: {$0.albumId == autoUploadCatId})
//                if indexOfAutoUpload == Int32.min {
//                    UploadManager.shared.disableAutoUpload()
//                }
//
//                // Check whether the default album still exists
//                let defaultCatId = AlbumVars.shared.defaultCategory
//                if defaultCatId != 0 {
//                    let indexOfDefault = albums.firstIndex(where: {$0.albumId == defaultCatId})
//                    if indexOfDefault == Int32.min {
//                        AlbumVars.shared.defaultCategory = 0    // Back to root album
//                    }
//                }
//
//                // Update albums if Community extension installed (not needed for admins)
//                if !NetworkVars.hasAdminRights,
//                   NetworkVars.usesCommunityPluginV29 {
//                    getCommunityAlbums { comAlbums in
//                        // Loop over Community albums
//                        for comAlbum in comAlbums {
//                            CategoriesData.sharedInstance().addCommunityCategory(withUploadRights: comAlbum)
//                        }
//                        // Return albums
//                        completion(didUpdateCats)
//                        return
//                    } failure: { _ in
//                        // Continue without Community albums
//                    }
//                } else {
//                    completion(didUpdateCats)
//                }
//            }
//            catch {
//                // Data cannot be digested
//                let error = error as NSError
//                failure(error)
//            }
//        } failure: { error in
//            /// - Network communication errors
//            /// - Returned JSON data is empty
//            /// - Cannot decode data returned by Piwigo server
//            failure(error)
//        }
//    }
    
//    static func getCommunityAlbums(completion: @escaping ([PiwigoAlbumData]) -> Void,
//                                   failure: @escaping (NSError) -> Void) {
//
//        // Prepare parameters for setting album thumbnail
//        let paramsDict: [String : Any] = ["cat_id"    : 0,
//                                          "recursive" : true]
//
//        let JSONsession = PwgSession.shared
//        JSONsession.postRequest(withMethod: kCommunityCategoriesGetList, paramDict: paramsDict,
//                                jsonObjectClientExpectsToReceive: CommunityCategoriesGetListJSON.self,
//                                countOfBytesClientExpectsToReceive: 1040) { jsonData in
//            // Decode the JSON object and update the category in cache.
//            do {
//                // Decode the JSON into codable type CommunityCategoriesGetListJSON.
//                let decoder = JSONDecoder()
//                let uploadJSON = try decoder.decode(CommunityCategoriesGetListJSON.self, from: jsonData)
//
//                // Piwigo error?
//                if uploadJSON.errorCode != 0 {
//                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
//                                                                 errorMessage: uploadJSON.errorMessage)
//                    failure(error as NSError)
//                    return
//                }
//
//                // Extract albums data from JSON message
//                let communityAlbums = parseAlbumJSON(uploadJSON.data)
//
//                // Return Community albums
//                completion(communityAlbums)
//            }
//            catch {
//                // Data cannot be digested
//                let error = error as NSError
//                failure(error)
//            }
//        } failure: { error in
//            /// - Network communication errors
//            /// - Returned JSON data is empty
//            /// - Cannot decode data returned by Piwigo server
//            failure(error)
//        }
//    }
    
//    private static func parseAlbumJSON(_ jsonAlbums:[CategoryData]) -> [PiwigoAlbumData] {
//        var albums = [PiwigoAlbumData]()
//        for category in jsonAlbums {
//            if let id = category.id {
//                let albumData = PiwigoAlbumData()
//                albumData.albumId = Int(id)
//                albumData.name = NetworkUtilities.utf8mb4String(from: category.name ?? "No Name")
//                albumData.comment = NetworkUtilities.utf8mb4String(from: category.comment ?? "")
//                albumData.globalRank = CGFloat(Float(category.globalRank ?? "") ?? 0.0)
//
//                // When "id_uppercat" is null or not supplied: album at the root
//                if let upperCat = category.upperCat {
//                    albumData.parentAlbumId = Int(upperCat) ?? NSNotFound
//                } else {
//                    albumData.parentAlbumId = 0
//                }
//                if let upperCats = category.upperCats?.components(separatedBy: ",") {
//                    albumData.upperCategories = upperCats
//                } else {
//                    albumData.upperCategories = []
//                }
//
//                // Number of images and sub-albums
//                albumData.numberOfImages = Int(category.nbImages ?? 0)
//                albumData.totalNumberOfImages = Int(category.totalNbImages ?? 0)
//                albumData.numberOfSubCategories = Int(category.nbCategories ?? 0)
//
//                // Thumbnail
//                albumData.albumThumbnailId = Int(category.thumbnailId ?? "") ?? Int64.min
//                albumData.albumThumbnailUrl = NetworkUtilities.encodedImageURL(category.thumbnailUrl ?? "")?.absoluteString
//
//                // When "date_last" is null or not supplied: no date
//                /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
//                let dateFormatter = DateFormatter()
//                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//                albumData.dateLast = dateFormatter.date(from: category.dateLast ?? "")
//
//                // By default, Community users have no upload rights
//                albumData.hasUploadRights = false
//
//                albums.append(albumData)
//            }
//        }
//        return albums
//    }
    
    static func create(withName name:String, description: String, status: String,
                       inParentWithId parentCategeoryId: Int32,
                       completion: @escaping (Int32) -> Void,
                       failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["name"    : name,
                                          "parent"  : parentCategeoryId,
                                          "comment" : description,
                                          "status"  : status]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesAdd, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesAddJSON.self,
                                countOfBytesClientExpectsToReceive: 1040) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesAddJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesAddJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if let catId = uploadJSON.data.id, catId != Int32.min {
                    // Album successfully created ▶ Add it to list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: catId)]
                    NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)
                    completion(catId)
                }
                else {
                    // Could not create album
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func setInfos(_ albumId: Int32, withName name:String, description: String,
                         completion: @escaping () -> Void,
                         failure: @escaping (NSError) -> Void) {

        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : albumId,
                                          "name"        : name,
                                          "comment"     : description]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesSetInfo, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesSetInfoJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesSetInfoJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesSetInfoJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album successfully updated
                    completion()
                }
                else {
                    // Could not set album data
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func move(_ albumId: Int32, intoAlbumWithId newParentId: Int32,
                     completion: @escaping () -> Void,
                     failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : albumId,
                                          "parent"      : newParentId,
                                          "pwg_token"   : NetworkVars.pwgToken]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesMove, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesMoveJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesMoveJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesMoveJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album successfully moved
                    completion()
                }
                else {
                    // Could not move album
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func calcOrphans(_ catID: Int32,
                            completion: @escaping (Int64) -> Void,
                            failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id": catID]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesCalcOrphans, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesCalcOrphansJSON.self,
                                countOfBytesClientExpectsToReceive: 2100) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesCalcOrphansJSON.
                let decoder = JSONDecoder()
                let orphansJSON = try decoder.decode(CategoriesCalcOrphansJSON.self, from: jsonData)

                // Piwigo error?
                if orphansJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: orphansJSON.errorCode,
                                                                 errorMessage: orphansJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Data retrieved successfully?
                guard let nberOrphans = orphansJSON.data?.first?.nbImagesBecomingOrphan else {
                    // Could not retrieve number of orphans
                    failure(JsonError.unexpectedError as NSError)
                    return
                }
                
                completion(nberOrphans)
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func delete(_ catID: Int32, inMode mode: pwgAlbumDeletionMode,
                       completion: @escaping () -> Void,
                       failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id"         : catID,
                                          "photo_deletion_mode" : mode.pwgArg,
                                          "pwg_token"           : NetworkVars.pwgToken]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesDelete, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesDeleteJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesDeleteJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesDeleteJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album successfully deleted ▶ Remove category from list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: catID)]
                    NotificationCenter.default.post(name: Notification.Name.pwgRemoveRecentAlbum,
                                                    object: nil, userInfo: userInfo)
                    completion()
                }
                else {
                    // Could not delete album
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    static func setRepresentative(_ albumData: Album, with imageData: Image,
                                  completion: @escaping () -> Void,
                                  failure: @escaping (NSError) -> Void) {
        // Prepare parameters for setting album thumbnail
        let paramsDict: [String : Any] = ["category_id" : albumData.pwgID,
                                          "image_id"    : imageData.pwgID]

        let JSONsession = PwgSession.shared
        JSONsession.postRequest(withMethod: pwgCategoriesSetRepresentative, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: CategoriesSetRepresentativeJSON.self,
                                countOfBytesClientExpectsToReceive: 1000) { jsonData in
            // Decode the JSON object and update the category in cache.
            do {
                // Decode the JSON into codable type CategoriesSetRepresentativeJSON.
                let decoder = JSONDecoder()
                let uploadJSON = try decoder.decode(CategoriesSetRepresentativeJSON.self, from: jsonData)

                // Piwigo error?
                if uploadJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: uploadJSON.errorCode,
                                                                 errorMessage: uploadJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Successful?
                if uploadJSON.success {
                    // Album thumbnail successfully changed ▶ Update catagory in cache
                    albumData.thumbnailId = imageData.pwgID
                    let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                    albumData.thumbnailUrl = ImageUtilities.getURLs(imageData, ofMinSize: thumnailSize)?.0
                    completion()
                }
                else {
                    // Could not set album thumbnail
                    failure(JsonError.unexpectedError as NSError)
                }
            } catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }


    // MARK: - Album/Images Collections | Common Methods
    static func sizeOfPage(forView view: UIView? = nil) -> CGSize {
        var pageSize: CGSize = view?.frame.size ?? UIScreen.main.bounds.size
        pageSize.width -= view?.safeAreaInsets.left ?? CGFloat.zero
        pageSize.width -= view?.safeAreaInsets.right ?? CGFloat.zero
        return pageSize
    }
    
    @objc
    static func minNberOfImagesPerRow() -> Int {   // => 3 on iPhone, 5 on iPad
        return UIDevice.current.userInterfaceIdiom == .phone ? 3 : 5
    }
    

    // MARK: - Album/Images Collections | Image Thumbnails
    static func optimumThumbnailSizeForDevice() -> pwgImageSize {
        // Get optimum number of images per row
        let nberThumbnailsPerRow = self.minNberOfImagesPerRow()

        // Square?
        var minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.square.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .square
        }
        
        // Thumbnail?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.thumb.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .thumb
        }

        // XXSmall?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.xxSmall.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .xxSmall
        }

        // XSmall?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.xSmall.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .xSmall
        }

        // Small?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.small.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .small
        }

        // Medium?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.medium.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .medium
        }

        // Large?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.large.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .large
        }

        // XLarge?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.xLarge.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .xLarge
        }

        // XXLarge?
        minNberOfImages = self.imagesPerRowInPortrait(forMaxWidth: pwgImageSize.xxLarge.minPixels)
        if minNberOfImages <= nberThumbnailsPerRow {
            return .xxLarge
        }
        
        return .thumb
    }

    static func thumbnailSizeName(for size: pwgImageSize, withInfo: Bool = false) -> String {
        var sizeName = size.name
        
        // Determine the optimum image size for the current device
        let optimumSize = self.optimumThumbnailSizeForDevice()

        // Return name for given thumbnail size
        switch size {
        case .square, .thumb, .xxSmall, .xSmall, .small, .medium:
            if withInfo {
                if size == optimumSize {
                    sizeName.append(contentsOf: NSLocalizedString("defaultImageSize_recommended", comment: " (recommended)"))
                } else {
                    sizeName.append(contentsOf: size.sizeAndScale)
                }
            }
        case .large, .xLarge, .xxLarge:
            if withInfo {
                sizeName.append(contentsOf: size.sizeAndScale)
            }
        case .fullRes:
            break
        }
        return sizeName
    }

    static func imageCellHorizontalSpacing(forCollectionType type: pwgImageCollectionType) -> CGFloat {
        var imageCellHorizontalSpacing = CGFloat.zero
        switch type {
        case .popup:
            imageCellHorizontalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPadPopup
        case .full:
            imageCellHorizontalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPad
        }
        return imageCellHorizontalSpacing
    }
    
    static func imageCellVerticalSpacing(forCollectionType type: pwgImageCollectionType) -> CGFloat {
        var imageCellVerticalSpacing = CGFloat.zero
        switch type {
        case .popup:
            imageCellVerticalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPadPopup
        case .full:
            imageCellVerticalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPad
        }
        return imageCellVerticalSpacing
    }
    
    static func imagesPerRowInPortrait(forMaxWidth: CGFloat) -> Int {
        // We display at least 3 thumbnails per row and images never exceed the thumbnails size
        return imagesPerRowInPortrait(forView: nil, maxWidth: forMaxWidth)
    }

    @objc
    static func imagesPerRowInPortrait(forView view: UIView?, maxWidth: CGFloat) -> Int {
        // We display at least 3 thumbnails per row and images never exceed the thumbnails size
        return imagesPerRowInPortrait(forView: view, maxWidth: maxWidth, collectionType: .full)
    }

    static func imagesPerRowInPortrait(forView view: UIView?, maxWidth: CGFloat,
                                       collectionType type: pwgImageCollectionType) -> Int {
        // We display at least 3 thumbnails per row and images never exceed the thumbnails size
        let pageSize = sizeOfPage(forView: view)
        let viewWidth = min(pageSize.width, pageSize.height)
        let horSpacing = imageCellHorizontalSpacing(forCollectionType: type)
        let numerator = viewWidth - 2 * kImageMarginsSpacing + horSpacing
        let denominator = horSpacing + maxWidth
        let nberOfImagePerRow = Int(round(numerator / denominator))
        return max(minNberOfImagesPerRow(), nberOfImagePerRow)
    }

    static func imageSize(forView view: UIView?, imagesPerRowInPortrait: Int,
                          collectionType type: pwgImageCollectionType) -> CGFloat {
        // CGFloat version of imagesPerRowInPortrait
        let nberOfImagesInPortrait = CGFloat(imagesPerRowInPortrait)

        // Size of view or screen
        let screenSize = sizeOfPage()
        let pageSize = sizeOfPage(forView: view)

        // Image horizontal cell spacing
        let imageCellHorizontalSpacing = imageCellHorizontalSpacing(forCollectionType: type)

        // Size of images determined for the portrait mode in full screen
        let minWidth = min(screenSize.width, screenSize.height)
        let imagesSizeInPortrait = floor((minWidth - 2.0 * kImageMarginsSpacing - (nberOfImagesInPortrait - 1.0) * imageCellHorizontalSpacing) / nberOfImagesInPortrait)
        
        // Images per row in whichever mode we are displaying them
        let numerator = screenSize.width - 2.0 * kImageMarginsSpacing + imageCellHorizontalSpacing
        let denominator = imageCellHorizontalSpacing + imagesSizeInPortrait
        let nberOfImages = Int(round(numerator / denominator))
        var imagesPerRow = Double(max(minNberOfImagesPerRow(), nberOfImages))

        // Images per row for the current size class
        imagesPerRow *= pageSize.width / screenSize.width
        imagesPerRow = max(1.0, round(imagesPerRow))

        // Size of squared images for that number
        let usedWidth = pageSize.width - 2.0 * kImageMarginsSpacing - (imagesPerRow - 1.0) * imageCellHorizontalSpacing
        return CGFloat(floor(usedWidth / imagesPerRow))
    }

    static func imageSize(forView view: UIView?, imagesPerRowInPortrait: Int) -> CGFloat {
        return imageSize(forView: view, imagesPerRowInPortrait: imagesPerRowInPortrait,
                         collectionType: .full)
    }

    @objc
    static func numberOfImagesToDownloadPerPage() -> Int {
        // CGFloat version of imagesPerRowInPortrait
        let nberOfImagesInPortrait = CGFloat(AlbumVars.shared.thumbnailsPerRowInPortrait)
        
        // Size of screen
        let pageSize = sizeOfPage()

        // Image horizontal cell spacing
        let imageCellHorizontalSpacing = imageCellHorizontalSpacing(forCollectionType: .full)
        let imageCellVerticalSpacing = imageCellVerticalSpacing(forCollectionType: .full)

        // Size of images determined for the portrait mode
        let minWidth = min(pageSize.width, pageSize.height)
        let imagesSizeInPortrait = floor((minWidth - 2.0 * kImageMarginsSpacing - (nberOfImagesInPortrait - 1.0) * imageCellHorizontalSpacing) / nberOfImagesInPortrait)
        
        // Images per row in portrait and landscape modes
        let spacing = 2.0 * kImageMarginsSpacing - imageCellHorizontalSpacing
        var numerator = pageSize.width - spacing
        let denominator = imageCellHorizontalSpacing + imagesSizeInPortrait
        let imagesPerRowInPortrait = Double(max(minNberOfImagesPerRow(), Int(round(numerator / denominator))))
        numerator = pageSize.height - spacing
        let imagesPerRowInLandscape = Double(max(minNberOfImagesPerRow(), Int(round(numerator / denominator))))

        // Minimum size of squared images
        let portrait = 2.0 * kImageMarginsSpacing + (imagesPerRowInPortrait - 1.0) * imageCellHorizontalSpacing
        let sizeInPortrait = floor((pageSize.width - portrait) / imagesPerRowInPortrait)
        let landscape = 2.0 * kImageMarginsSpacing + (imagesPerRowInLandscape - 1.0) * imageCellVerticalSpacing
        let sizeInLandscape = floor((pageSize.height - landscape) / imagesPerRowInLandscape)
        let size = min(sizeInPortrait, sizeInLandscape)
        
        // Number of images to download per page, independently of the orientation
        let cellArea = (size + imageCellVerticalSpacing) * (size + imageCellHorizontalSpacing)
        let viewArea = pageSize.width * pageSize.height
        return Int(ceil(viewArea / cellArea))
    }

    static func numberOfImagesPerPage(forView view: UIView, imagesPerRowInPortrait: Int,
                                      collectionType type: pwgImageCollectionType) -> Int {
        // Size of view or screen
        let pageSize = sizeOfPage(forView: view)

        // Size of squared images for that number
        let size = imageSize(forView: view, imagesPerRowInPortrait: imagesPerRowInPortrait)
        
        // Image horizontal & vertical cell spacings
        let imageCellHorizontalSpacing = imageCellHorizontalSpacing(forCollectionType: type)
        let imageCellVerticalSpacing = imageCellVerticalSpacing(forCollectionType: type)

        // Number of images par page
        let cellArea = (size + imageCellVerticalSpacing) * (size + imageCellHorizontalSpacing)
        let viewArea = pageSize.width * pageSize.height
        return Int(ceil(viewArea / cellArea))
    }
    

    // MARK: - Album/Images Collections | Album Thumbnails
    static func optimumAlbumThumbnailSizeForDevice() -> pwgImageSize {
        // Size of album thumbnails is 144x144 points (see AlbumTableViewCell.xib)
        let albumThumbnailSize: CGFloat = 144

        // Square?
        if pwgImageSize.square.minPixels >= albumThumbnailSize {
            return .square
        }
        
        // Thumbnail?
        if pwgImageSize.thumb.minPixels >= albumThumbnailSize {
            return .thumb
        }
        
        // XXSmall?
        if pwgImageSize.xxSmall.minPixels >= albumThumbnailSize {
            return .xxSmall
        }
        
        // XSmall?
        if pwgImageSize.xSmall.minPixels >= albumThumbnailSize {
            return .xSmall
        }
        
        // Small?
        if pwgImageSize.small.minPixels >= albumThumbnailSize {
            return .small
        }
        
        // Medium?
        if pwgImageSize.medium.minPixels >= albumThumbnailSize {
            return .medium
        }
        
        // Large?
        if pwgImageSize.large.minPixels >= albumThumbnailSize {
            return .large
        }
        
        // XLarge?
        if pwgImageSize.xLarge.minPixels >= albumThumbnailSize {
            return .xLarge
        }

        // XXLarge?
        if pwgImageSize.xxLarge.minPixels >= albumThumbnailSize {
            return .xxLarge
        }

        return .medium
    }
    
    static func albumThumbnailSizeName(for size: pwgImageSize, withInfo: Bool = false) -> String {
        var sizeName = size.name
        
        // Determine the optimum image size for the current device
        let optimumSize = self.optimumAlbumThumbnailSizeForDevice()

        // Return name for given thumbnail size
        switch size {
        case .square, .thumb, .xxSmall, .xSmall, .small, .medium:
            if withInfo {
                if size == optimumSize {
                    sizeName.append(contentsOf: NSLocalizedString("defaultImageSize_recommended", comment: " (recommended)"))
                } else {
                    sizeName.append(contentsOf: size.sizeAndScale)
                }
            }
        case .large, .xLarge, .xxLarge:
            if withInfo {
                sizeName.append(contentsOf: size.sizeAndScale)
            }
        case .fullRes:
            break
        }
        return sizeName
    }

    static func imageDetailsSize(forView view: UIView) -> CGFloat {
        // Size of view or screen
        let cellSize = sizeOfPage(forView:view)
        return CGFloat(min(cellSize.width - 2.0 * kImageDetailsMarginsSpacing, 340.0))
    }

    static func numberOfAlbumsPerRowInPortrait(forView view: UIView?, maxWidth: CGFloat) -> Int {
        // Size of view or screen
        let pageSize = sizeOfPage(forView: view)
        let viewWidth = min(pageSize.width, pageSize.height)
        let numerator = viewWidth - 2.0 * kAlbumMarginsSpacing + kAlbumCellSpacing
        let denominator = kAlbumCellSpacing + maxWidth
        return Int(round(numerator / denominator))
    }
    
    static func albumSize(forView view: UIView?,
                          nberOfAlbumsPerRowInPortrait albumsPerRowInPortrait: Int) -> CGFloat {
        // Size of view or screen
        let pageSize = sizeOfPage(forView: view)
        
        // Size of album cells determined for the portrait mode
        let minWidth = min(pageSize.width, pageSize.height)
        let portrait = 2.0 * kAlbumMarginsSpacing + (CGFloat(albumsPerRowInPortrait) - 1.0) * kAlbumCellSpacing
        let albumsSizeInPortrait = floor((minWidth - portrait) / CGFloat(albumsPerRowInPortrait))

        // Album cells per row in whichever mode we are displaying them
        let spacing = 2.0 * kAlbumMarginsSpacing - kAlbumCellSpacing
        let albumsPerRow = round((pageSize.width - spacing) / (kAlbumCellSpacing + albumsSizeInPortrait))

        // Width of albums for that number
        return floor((pageSize.width - 2.0 * kAlbumMarginsSpacing - (albumsPerRow - 1.0) * kAlbumCellSpacing) / albumsPerRow)
    }

    
    // MARK: - Album/Images Collections | Headers & Footers
    static func footerLegend(_ allShown: Bool, _ totalCount: Int64) -> String {
        var legend = ""
        if totalCount == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if totalCount == Int64.zero {
            // Not loading and no images
            legend = NSLocalizedString("noImages", comment:"No Images")
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: totalCount)) {
                let format:String = totalCount > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
            
            // Do we have all images?
            if allShown == false {
                legend.append("\r" + NSLocalizedString("loadingHUD_label", comment:"Loading…"))
            }
        }
        return legend
    }
    
    
    // MARK: - Favorites
//    static func loadFavoritesInBckg() {
//        DispatchQueue.global(qos: .default).async {
//            // Should we load favorites?
//            if NetworkVars.userStatus == .guest { return }
//            if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) == .orderedDescending { return }
//
//            // Initialise favorites album
//            if let favoritesAlbum = PiwigoAlbumData(id: kPiwigoFavoritesCategoryId, andQuery: "") {
//                CategoriesData.sharedInstance().updateCategories([favoritesAlbum])
//            }
//
//            // Load favorites data in the background with dedicated URL session
//            CategoriesData.sharedInstance().getCategoryById(kPiwigoFavoritesCategoryId).loadAllCategoryImageData(
//                withSort: kPiwigoSortObjc(rawValue: UInt32(AlbumVars.shared.defaultSort.rawValue)),
//                forProgress: nil,
//                onCompletion: nil,
//                onFailure: nil)
//        }
//    }
}
