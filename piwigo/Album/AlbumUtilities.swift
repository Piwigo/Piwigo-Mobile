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
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
                    albumData.thumbnailUrl = ImageUtilities.getURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    completion()
                }
                else {
                    // Could not set album thumbnail
                    failure(PwgSessionErrors.unexpectedError as NSError)
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
        var pageSize: CGSize = view?.frame.size ?? view?.window?.screen.bounds.size ?? UIScreen.main.bounds.size
        pageSize.width -= view?.safeAreaInsets.left ?? CGFloat.zero
        pageSize.width -= view?.safeAreaInsets.right ?? CGFloat.zero
        return pageSize
    }
    

    // MARK: - Album/Images Collections | Album Thumbnails
    static var minNberOfAlbumsPerRow: Int = {
        return UIDevice.current.userInterfaceIdiom == .phone ? 1 : 2
    }()

    static var maxNberOfAlbumsPerRow: Int = {
        return UIDevice.current.userInterfaceIdiom == .phone ? 1 : 3
    }()

    static func optimumAlbumThumbnailSizeForDevice() -> pwgImageSize {
        // Size of album thumbnails is 144x144 points (see AlbumTableViewCell.xib)
        var albumThumbnailSize: CGFloat = 144
        if #available(iOS 13.0, *) {
            albumThumbnailSize *= pwgImageSize.maxSaliencyScale
        }

        // Loop over all sizes
        let sizes = pwgImageSize.allCases.dropLast(1)
        for size in sizes {
            if size.minPoints >= albumThumbnailSize {
                return size
            }
        }
        return .xxLarge
    }
    
    static func albumSize(forView view: UIView?, maxWidth: CGFloat) -> CGFloat {
        // Size of view or screen
        let pageSize = sizeOfPage(forView: view)
        
        // Number of albums per row in portrait
        let viewWidth = min(pageSize.width, pageSize.height)
        let numerator = viewWidth - 2.0 * kAlbumMarginsSpacing + kAlbumCellSpacing
        let denominator = kAlbumCellSpacing + maxWidth
        let nbAlbumsPerRowInPortrait = Int(round(numerator / denominator))

        // Width of album cells determined for the portrait mode
        let minWidth = min(pageSize.width, pageSize.height)
        let portraitSpacing = 2.0 * kAlbumMarginsSpacing + (CGFloat(nbAlbumsPerRowInPortrait) - 1.0) * kAlbumCellSpacing
        let albumWidthInPortrait = floor((minWidth - portraitSpacing) / CGFloat(nbAlbumsPerRowInPortrait))

        // Album cells per row in whichever mode we are displaying them
        let spacing = 2.0 * kAlbumMarginsSpacing - kAlbumCellSpacing
        let albumsPerRow = round((pageSize.width - spacing) / (kAlbumCellSpacing + albumWidthInPortrait))

        // Width of albums for that number
        return floor((pageSize.width - 2.0 * kAlbumMarginsSpacing - (albumsPerRow - 1.0) * kAlbumCellSpacing) / albumsPerRow)
    }


    // MARK: - Album/Images Collections | Image Thumbnails
    static var minNberOfImagesPerRow: Int = {
        return UIDevice.current.userInterfaceIdiom == .phone ? 3 : 5
    }()

    static var maxNberOfImagesPerRow: Int = {
        return UIDevice.current.userInterfaceIdiom == .phone ? 6 : 10
    }()

    static func optimumThumbnailSizeForDevice() -> pwgImageSize {
        // Returns the lowest size of sufficient resolution
        // to display the minimum number of thumbnails on the device.
        let sizes = pwgImageSize.allCases.dropLast(1)   // Avoids full resolution
        for size in sizes {
            let nbImages = imagesPerRowInPortrait(forMaxWidth: size.minPoints)
            if nbImages <= minNberOfImagesPerRow {
                return size
            }
        }
        return .xxLarge
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
    
    static func imagesPerRowInPortrait(forMaxWidth maxWidth: CGFloat) -> Int {
        // Returns the number thumbnails per row for a given image width
        let pageSize = sizeOfPage(forView: nil)
        let viewWidth = min(pageSize.width, pageSize.height)
        let horSpacing = imageCellHorizontalSpacing(forCollectionType: .full)
        let numerator = viewWidth - 2 * kImageMarginsSpacing + horSpacing
        let denominator = horSpacing + maxWidth
        let nberOfImagePerRow = Int(round(numerator / denominator))
        return max(minNberOfImagesPerRow, nberOfImagePerRow)
    }

    static func imageSize(forView view: UIView?, imagesPerRowInPortrait: Int) -> CGFloat {
        return imageSize(forView: view, imagesPerRowInPortrait: imagesPerRowInPortrait,
                         collectionType: .full)
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
        var imagesPerRow = Double(max(minNberOfImagesPerRow, nberOfImages))

        // Images per row for the current size class
        imagesPerRow *= pageSize.width / screenSize.width
        imagesPerRow = max(1.0, round(imagesPerRow))

        // Size of squared images for that number
        let usedWidth = pageSize.width - 2.0 * kImageMarginsSpacing - (imagesPerRow - 1.0) * imageCellHorizontalSpacing
        return CGFloat(floor(usedWidth / imagesPerRow))
    }

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
        let imagesPerRowInPortrait = Double(max(minNberOfImagesPerRow, Int(round(numerator / denominator))))
        numerator = pageSize.height - spacing
        let imagesPerRowInLandscape = Double(max(minNberOfImagesPerRow, Int(round(numerator / denominator))))

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

    static func imageDetailsSize(forView view: UIView) -> CGFloat {
        // Size of view or screen
        let cellSize = sizeOfPage(forView:view)
        return CGFloat(min(cellSize.width - 2.0 * kImageDetailsMarginsSpacing, 340.0))
    }
}
