//
//  AlbumUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/12/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import CoreLocation
import Foundation
import piwigoKit
import UIKit

enum pwgAlbumCollectionType {
    case new, old
}

enum pwgImageCollectionType {
    case popup, full
}

class AlbumUtilities: NSObject {
    
    // MARK: - Constants
    static let kAlbumCellSpacing = CGFloat(8)               // Horizontal spacing between album cells
    static let kAlbumCellVertSpacing = CGFloat(8)           // Vertical spacing between album cells
    static let kAlbumMarginsSpacing = CGFloat(4)            // Left and right margins for albums
    static let kAlbumOldCellSpacing = CGFloat(4)            // Horizontal spacing between old album cells
//    static let kAlbumOldCellVertSpacing = CGFloat(0)        // Vertical spacing between old album cells
    
    static let kImageCellSpacing4iPhone = CGFloat(1)        // Spacing between images (horizontally and vertically)
    static let kImageCellHorSpacing4iPad = CGFloat(8)
    static let kImageCellHorSpacing4iPadPopup = CGFloat(1)
    static let kImageCellVertSpacing4iPad = CGFloat(8)
    static let kImageCellVertSpacing4iPadPopup = CGFloat(1)
    //    static let kImageMarginsSpacing = CGFloat(0)            // Left and right margins for images
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
    //                    let error = PwgSession.shared.error(for: uploadJSON.errorCode,
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
                       failure: @escaping (Error) -> Void) {
        
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
                let pwgData = try decoder.decode(CategoriesAddJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Successful?
                if let catId = pwgData.data.id, catId != Int32.min {
                    // Album successfully created ▶ Add it to list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: catId)]
                    NotificationCenter.default.post(name: Notification.Name.pwgAddRecentAlbum,
                                                    object: nil, userInfo: userInfo)
                    completion(catId)
                }
                else {
                    // Could not create album
                    failure(PwgSessionError.unexpectedError)
                }
            } catch {
                // Data cannot be digested
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
                         failure: @escaping (Error) -> Void) {
        
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
                let pwgData = try decoder.decode(CategoriesSetInfoJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Successful?
                if pwgData.success {
                    // Album successfully updated
                    completion()
                }
                else {
                    // Could not set album data
                    failure(PwgSessionError.unexpectedError)
                }
            } catch {
                // Data cannot be digested
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
                     failure: @escaping (Error) -> Void) {
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
                let pwgData = try decoder.decode(CategoriesMoveJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Successful?
                if pwgData.success {
                    // Album successfully moved
                    completion()
                }
                else {
                    // Could not move album
                    failure(PwgSessionError.unexpectedError)
                }
            } catch {
                // Data cannot be digested
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
                            failure: @escaping (Error) -> Void) {
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
                let pwgData = try decoder.decode(CategoriesCalcOrphansJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Data retrieved successfully?
                guard let nberOrphans = pwgData.data?.first?.nbImagesBecomingOrphan else {
                    // Could not retrieve number of orphans
                    failure(PwgSessionError.unexpectedError)
                    return
                }
                
                completion(nberOrphans)
            } catch {
                // Data cannot be digested
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
                       failure: @escaping (Error) -> Void) {
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
                let pwgData = try decoder.decode(CategoriesDeleteJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Successful?
                if pwgData.success {
                    // Album successfully deleted ▶ Remove category from list of recent albums
                    let userInfo = ["categoryId" : NSNumber.init(value: catID)]
                    NotificationCenter.default.post(name: Notification.Name.pwgRemoveRecentAlbum,
                                                    object: nil, userInfo: userInfo)
                    completion()
                }
                else {
                    // Could not delete album
                    failure(PwgSessionError.unexpectedError)
                }
            } catch {
                // Data cannot be digested
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
                                  failure: @escaping (Error) -> Void) {
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
                let pwgData = try decoder.decode(CategoriesSetRepresentativeJSON.self, from: jsonData)
                
                // Piwigo error?
                if pwgData.errorCode != 0 {
                    let error = PwgSession.shared.error(for: pwgData.errorCode, errorMessage: pwgData.errorMessage)
                    failure(error)
                    return
                }
                
                // Successful?
                if pwgData.success {
                    // Album thumbnail successfully changed ▶ Update catagory in cache
                    albumData.thumbnailId = imageData.pwgID
                    let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
                    albumData.thumbnailUrl = ImageUtilities.getPiwigoURL(imageData, ofMinSize: thumnailSize) as NSURL?
                    completion()
                }
                else {
                    // Could not set album thumbnail
                    failure(PwgSessionError.unexpectedError)
                }
            } catch {
                // Data cannot be digested
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
    static func getSafeAreaSize(ofNavigationViewController viewController: UIViewController?) -> CGSize {
        var safeAreaWidth: CGFloat = UIScreen.main.bounds.size.width
        let safeAreaHeight: CGFloat = UIScreen.main.bounds.size.height
        if let root = viewController {
            safeAreaWidth = root.view.frame.size.width
            safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
        }
        return CGSize(width: safeAreaWidth, height: safeAreaHeight)
    }
    
    static func sizeOfPage(forView view: UIView? = nil) -> CGSize {
        if let viewBounds = view?.bounds.inset(by: view?.safeAreaInsets ?? UIEdgeInsets.zero) {
            return viewBounds.size
        }
        return UIScreen.main.bounds.size
    }
    
    static func viewWidth(for view: UIView, pageSize: CGSize) -> CGFloat {
        // Available width in portrait mode
        var orientation: UIInterfaceOrientation = .portrait
        if #available(iOS 13, *) {
            // Interface depends on device and orientation
            orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        return orientation == .portrait ? pageSize.width : pageSize.height
    }
    
    
    // MARK: - Album/Images Collections | Album Thumbnails
    static func optimumAlbumThumbnailSizeForDevice() -> pwgImageSize {
        // Size of album thumbnails is 144x144 points (see AlbumTableViewCell.xib)
        let albumThumbnailSize: CGFloat = 144
//        if #available(iOS 13.0, *) {
//            albumThumbnailSize *= pwgImageSize.maxSaliencyScale
//        }
        
        // Loop over all sizes
        let sizes = pwgImageSize.allCases.dropLast(1)
        for size in sizes {
            if size.minPoints >= albumThumbnailSize {
                return size
            }
        }
        return .xxLarge
    }
    
    static func albumWidth(forSafeAreaSize size: CGSize, maxCellWidth: CGFloat) -> CGFloat
    {
        // Collection view margins and spacings
        var margins: CGFloat, spacing: CGFloat
        if AlbumVars.shared.displayAlbumDescriptions {
            margins = 0.0
            spacing = kAlbumOldCellSpacing
        } else {
            margins = 2 * kAlbumMarginsSpacing
            spacing = kAlbumCellSpacing
        }

        // Number of albums per row in portrait
        let widthInPortrait = min(size.width, size.height)
        let numerator = widthInPortrait + spacing - margins
        let denominator = maxCellWidth + spacing
        let nbAlbumsPerRowInPortrait = max(1.0, (numerator / denominator).rounded())
        
        // Width of album cells determined for the portrait mode
        let albumWidthInPortrait = (widthInPortrait - (nbAlbumsPerRowInPortrait - 1.0) * spacing + margins) / nbAlbumsPerRowInPortrait
        
        // Number of albums per row we should display right now
        let albumsPerRow = ((size.width + spacing - margins) / (albumWidthInPortrait + spacing)).rounded()
        
        // Width of albums for that number
        return ((size.width - (albumsPerRow - 1.0) * spacing - margins) / albumsPerRow).rounded(.down)
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
        var horizontalSpacing = CGFloat.zero
        switch type {
        case .popup:
            horizontalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPadPopup
        case .full:
            horizontalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellHorSpacing4iPad
        }
        return horizontalSpacing
    }
    
    static func imageCellVerticalSpacing(forCollectionType type: pwgImageCollectionType) -> CGFloat {
        var verticalSpacing = CGFloat.zero
        switch type {
        case .popup:
            verticalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPadPopup
        case .full:
            verticalSpacing = UIDevice.current.userInterfaceIdiom == .phone ? kImageCellSpacing4iPhone : kImageCellVertSpacing4iPad
        }
        return verticalSpacing
    }
    
    static func imagesPerRowInPortrait(forMaxWidth maxWidth: CGFloat) -> Int {
        // Returns the number thumbnails per row for a given image width
        let pageSize = sizeOfPage(forView: nil)
        let viewWidth = min(pageSize.width, pageSize.height)
        let horSpacing = imageCellHorizontalSpacing(forCollectionType: .full)
        let numerator = viewWidth + horSpacing
        let denominator = horSpacing + maxWidth
        let nberOfImagePerRow = Int(round(numerator / denominator))
        return max(minNberOfImagesPerRow, nberOfImagePerRow)
    }
    
    static func imageSize(forSafeAreaSize size: CGSize, imagesPerRowInPortrait: Int) -> CGFloat {
        return imageSize(forSafeAreaSize: size, imagesPerRowInPortrait: imagesPerRowInPortrait,
                         collectionType: .full)
    }
    
    static func imageSize(forSafeAreaSize size: CGSize, imagesPerRowInPortrait: Int,
                          collectionType type: pwgImageCollectionType) -> CGFloat {
        // Collection view margins and spacings
        let margins = 0.0
        let spacing = imageCellHorizontalSpacing(forCollectionType: type)
        
        // CGFloat version of imagesPerRowInPortrait
        let nberOfImagesInPortrait = CGFloat(imagesPerRowInPortrait)

        // Size of images in portrait mode
        let widthInPortrait = min(size.width, size.height)
        let imagesSizeInPortrait = (widthInPortrait - (nberOfImagesInPortrait - 1.0) * spacing - margins) / nberOfImagesInPortrait

        // Number of images per row we should display right now
        let numerator = size.width + spacing - margins
        let denominator = imagesSizeInPortrait + spacing
        let imagesPerRow = max(CGFloat(minNberOfImagesPerRow), (numerator / denominator).rounded())
                
        // Width of squared images for that number
        return ((size.width - (imagesPerRow - 1) * spacing - margins) / imagesPerRow).rounded(.down)
    }
    
    static func numberOfImagesToDownloadPerPage() -> Int {
        // CGFloat version of imagesPerRowInPortrait
        let nberOfImagesInPortrait = CGFloat(AlbumVars.shared.thumbnailsPerRowInPortrait)
        
        // Size of screen
        let screenSize = sizeOfPage()
        
        // Image horizontal cell spacing
        let imageCellHorizontalSpacing = imageCellHorizontalSpacing(forCollectionType: .full)
        let imageCellVerticalSpacing = imageCellVerticalSpacing(forCollectionType: .full)
        
        // Size of images determined for the portrait mode
        let minWidth = min(screenSize.width, screenSize.height)
        let imagesSizeInPortrait = floor((minWidth - (nberOfImagesInPortrait - 1.0) * imageCellHorizontalSpacing) / nberOfImagesInPortrait)
        
        // Images per row in portrait and landscape modes
        var numerator = screenSize.width + imageCellHorizontalSpacing
        let denominator = imageCellHorizontalSpacing + imagesSizeInPortrait
        let imagesPerRowInPortrait = Double(max(minNberOfImagesPerRow, Int(round(numerator / denominator))))
        numerator = screenSize.height + imageCellHorizontalSpacing
        let imagesPerRowInLandscape = Double(max(minNberOfImagesPerRow, Int(round(numerator / denominator))))
        
        // Minimum size of squared images
        let portrait = (imagesPerRowInPortrait - 1.0) * imageCellHorizontalSpacing
        let sizeInPortrait = floor((screenSize.width - portrait) / imagesPerRowInPortrait)
        let landscape = (imagesPerRowInLandscape - 1.0) * imageCellVerticalSpacing
        let sizeInLandscape = floor((screenSize.height - landscape) / imagesPerRowInLandscape)
        let size = min(sizeInPortrait, sizeInLandscape)
        
        // Number of images to download per page, independently of the orientation
        let cellArea = (size + imageCellVerticalSpacing) * (size + imageCellHorizontalSpacing)
        let viewArea = screenSize.width * screenSize.height
        return Int(ceil(viewArea / cellArea))
    }
    
    static func imageDetailsSize(forView view: UIView) -> CGFloat {
        // Size of view or screen
        let cellSize = sizeOfPage(forView:view)
        return CGFloat(min(cellSize.width - 2.0 * kImageDetailsMarginsSpacing, 340.0))
    }
    
    // MARK: - Album/Images Collections | Image Section
    static func getDateLabels(for timeIntervals: [TimeInterval], arePwgDates: Bool) -> (String, String) {
        // Creation date of images (or of availability)
        let refDate = DateUtilities.unknownDateInterval     // i.e. unknown date
        var dateLabelText = " "                             // Displayed when there is no date available
        var optionalDateLabelText = " "
        
        // Determine lowest time interval after "1900-01-01 00:00:00 UTC"
        var lowest = TimeInterval.greatestFiniteMagnitude
        for ti in timeIntervals {
            autoreleasepool {
                if ti > refDate, ti < lowest {
                    lowest = ti
                }
            }
        }
        
        // Determine greatest time interval after "1900-01-01 00:00:00 UTC"
        var greatest = refDate
        for ti in timeIntervals {
            autoreleasepool {
                if ti > refDate, ti > greatest {
                    greatest = ti
                }
            }
        }
        
        // Determine if images of this section were all taken after "1900-01-08 00:00:00 UTC"
        if lowest > DateUtilities.weekAfterInterval, lowest < TimeInterval.greatestFiniteMagnitude {
            // Get correspondig date
            let startDate = Date(timeIntervalSinceReferenceDate: lowest)
            
            // Display date/month/year by default, will add weekday/time in the absence of location data
            let dateStyle: DateFormatter.Style = UIScreen.main.bounds.size.width > 400 ? .long : .medium
            dateLabelText = DateFormatter.localizedString(from: startDate, dateStyle: dateStyle, timeStyle: .none)
            
            // See http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
            let optFormatter = DateUtilities.dateFormatter()
            if arePwgDates {
                switch UIScreen.main.bounds.size.width {
                case 0..<400:
                    optFormatter.setLocalizedDateFormatFromTemplate("eee HH:mm")
                case 400...600:
                    optFormatter.setLocalizedDateFormatFromTemplate("eeee HH:mm")
                default:
                    optFormatter.setLocalizedDateFormatFromTemplate("eeee HH:mm:ss")
                }
            } else {
                optFormatter.setLocalizedDateFormatFromTemplate("eeee")
            }
            optionalDateLabelText = optFormatter.string(from: startDate)
            
            // Get creation date of last image and check that it is after "1900-01-08 00:00:00"
            if greatest > DateUtilities.weekAfterInterval, greatest != lowest {
                // Get correspondig date
                let endDate = Date(timeIntervalSinceReferenceDate: greatest)

                // Images taken the same day?
                let firstImageDay = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
                let lastImageDay = Calendar.current.dateComponents([.year, .month, .day], from: endDate)
                if firstImageDay == lastImageDay {
                    // Images were taken the same day
                    // => Keep dateLabel as already set
                    // => Add ending time to optional string
                    if arePwgDates {
                        let timeStyle = UIScreen.main.bounds.size.width > 600 ? "HH:mm:ss" : "HH:mm"
                        optFormatter.setLocalizedDateFormatFromTemplate(timeStyle)
                        optionalDateLabelText += " - " + optFormatter.string(from: endDate)
                    }
                    return (dateLabelText, optionalDateLabelText)
                }
                
                // => Images taken the same month?
                let firstImageMonth = Calendar.current.dateComponents([.year, .month], from: startDate)
                let lastImageMonth = Calendar.current.dateComponents([.year, .month], from: endDate)
                if firstImageMonth == lastImageMonth {
                    // Images taken during the same month => Display days of month
                    let dateFormatter = DateIntervalFormatter()
                    dateFormatter.timeStyle = .none
                    switch UIScreen.main.bounds.size.width {
                    case 0..<400:
                        dateFormatter.dateStyle = .medium
                    default:
                        dateFormatter.dateStyle = .long
                    }
                    dateLabelText = dateFormatter.string(from: startDate, to: endDate)
                    
                    // Define optional string with day/time values
                    // See http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
                    let optFormatter = DateUtilities.dateFormatter()
                    optFormatter.locale = .current
                    if arePwgDates {
                        switch UIScreen.main.bounds.size.width {
                        case 0..<400:
                            optFormatter.setLocalizedDateFormatFromTemplate("eee HH:mm")
                        case 400..<600:
                            optFormatter.setLocalizedDateFormatFromTemplate("eeee d HH:mm")
                        default:
                            optFormatter.setLocalizedDateFormatFromTemplate("eeee d HH:mm:ss")
                        }
                    } else {
                        switch UIScreen.main.bounds.size.width {
                        case 0..<400:
                            optFormatter.setLocalizedDateFormatFromTemplate("eee d")
                        default:
                            optFormatter.setLocalizedDateFormatFromTemplate("eeee d")
                        }
                    }
                    optionalDateLabelText = optFormatter.string(from: startDate) + " — " + optFormatter.string(from: endDate)
                    return (dateLabelText, optionalDateLabelText)
                }
                
                // => Images not taken the same month => Display day/month of year
                let dateFormatter = DateUtilities.dateIntervalFormatter()
                dateFormatter.timeStyle = .none
                switch UIScreen.main.bounds.size.width {
                case 0..<400:
                    dateFormatter.dateTemplate = "YYMMdd"
                case 400..<600:
                    dateFormatter.dateStyle = .medium
                default:
                    dateFormatter.dateStyle = .long
                }
                dateLabelText = dateFormatter.string(from: startDate, to: endDate)
                
                // Define optional string with day/time values
                // See http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns
                let optFormatter = DateUtilities.dateFormatter()
                if arePwgDates {
                    switch UIScreen.main.bounds.size.width {
                    case 0..<400:
                        optFormatter.setLocalizedDateFormatFromTemplate("eee HH:mm")
                    case 400..<600:
                        optFormatter.setLocalizedDateFormatFromTemplate("eeee d HH:mm")
                    default:
                        optFormatter.setLocalizedDateFormatFromTemplate("eeee d HH:mm:ss")
                    }
                } else {
                    switch UIScreen.main.bounds.size.width {
                    case 0..<400:
                        optFormatter.setLocalizedDateFormatFromTemplate("eee d")
                    default:
                        optFormatter.setLocalizedDateFormatFromTemplate("eeee d")
                    }
                }
                optionalDateLabelText = optFormatter.string(from: startDate) + " — " + optFormatter.string(from: endDate)
            }
        }
        return (dateLabelText, optionalDateLabelText)
    }
    
    static func getLocation(of images: [Image]) -> CLLocation {
        // Initialise location of section with invalid location
        var verticalAccuracy = CLLocationAccuracy.zero
        if #available(iOS 14, *) {
            verticalAccuracy = kCLLocationAccuracyReduced
        } else {
            verticalAccuracy = kCLLocationAccuracyThreeKilometers
        }
        var locationForSection = CLLocation(coordinate: kCLLocationCoordinate2DInvalid,
                                            altitude: CLLocationDistance(0.0),
                                            horizontalAccuracy: kCLLocationAccuracyBest,
                                            verticalAccuracy: verticalAccuracy,
                                            timestamp: Date())

        // Loop over images in section
        for image in images {

            // Any location data ?
            guard image.latitude != 0.0, image.longitude != 0.0 else {
                // Image has no valid location data => Next image
                continue
            }

            // Location found => Store if first found and move to next section
            if !CLLocationCoordinate2DIsValid(locationForSection.coordinate) {
                // First valid location => Store it
                let coordinate = CLLocationCoordinate2DMake(image.latitude, image.longitude)
                locationForSection = CLLocation(coordinate: coordinate, altitude: 0,
                                                horizontalAccuracy: kCLLocationAccuracyBest,
                                                verticalAccuracy: verticalAccuracy,
                                                timestamp: locationForSection.timestamp)
            } else {
                // Another valid location => Compare to first one
                let newLocation = CLLocation(latitude: image.latitude, longitude: image.longitude)
                let distance = locationForSection.distance(from: newLocation)
                
                // Similar location?
                let meanLatitude: CLLocationDegrees = (locationForSection.coordinate.latitude + newLocation.coordinate.latitude)/2
                let meanLongitude: CLLocationDegrees = (locationForSection.coordinate.longitude + newLocation.coordinate.longitude)/2
                let newCoordinate = CLLocationCoordinate2DMake(meanLatitude,meanLongitude)
                if distance < kCLLocationAccuracyBest {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyBest,
                                                    verticalAccuracy: locationForSection.verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyNearestTenMeters {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyNearestTenMeters,
                                                    verticalAccuracy: locationForSection.verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyHundredMeters {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyHundredMeters,
                                                    verticalAccuracy: locationForSection.verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyKilometer {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyKilometer,
                                                    verticalAccuracy: locationForSection.verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else if distance < kCLLocationAccuracyThreeKilometers {
                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: 0,
                                                    horizontalAccuracy: kCLLocationAccuracyThreeKilometers,
                                                    verticalAccuracy: locationForSection.verticalAccuracy,
                                                    timestamp: locationForSection.timestamp)
                    return locationForSection
                } else {
                    // Above 3 km, we estimate that it is a different location
                    return locationForSection
                }
             }
        }
        return locationForSection
    }
}
