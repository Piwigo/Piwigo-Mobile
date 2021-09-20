//
//  UploadVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Privacy Levels
public enum kPiwigoPrivacy : Int16 {
    case everybody = 0
    case adminsFamilyFriendsContacts = 1
    case adminsFamilyFriends = 2
    case adminsFamily = 4
    case admins = 8
    case count = 5
    case unknown = -1
}

extension kPiwigoPrivacy {
    public var name: String {
        switch self {
        case .everybody:
            return NSLocalizedString("privacyLevel_everybody", comment: "Everybody")
        case .adminsFamilyFriendsContacts:
            return NSLocalizedString("privacyLevel_adminsFamilyFriendsContacts", comment: "Admins, Family, Friends, Contacts")
        case .adminsFamilyFriends:
            return NSLocalizedString("privacyLevel_adminsFamilyFriends", comment: "Admins, Family, Friends")
        case .adminsFamily:
            return NSLocalizedString("privacyLevel_adminFamily", comment: "Admins, Family")
        case .admins:
            return NSLocalizedString("privacyLevel_admin", comment: "Admins")
        default:
            return ""
        }
    }
}


// MARK: - Max Photo Sizes
public enum pwgPhotoMaxSizes: Int16, CaseIterable {
    case fullResolution = 0, Retina5K, UHD4K, DCI2K, FullHD, HD, qHD, nHD
}

extension pwgPhotoMaxSizes {
    public var pixels: Int {
        switch self {
        case .fullResolution:   return Int.max
        case .Retina5K:         return 5120
        case .UHD4K:            return 3840
        case .DCI2K:            return 2048
        case .FullHD:           return 1920
        case .HD:               return 1280
        case .qHD:              return 960
        case .nHD:              return 640
        }
    }
    
    public var name: String {
        switch self {
        case .fullResolution:   return NSLocalizedString("UploadPhotoSize_original", comment: "No Downsizing")
        case .Retina5K:         return "5K | 14.7 Mpx"
        case .UHD4K:            return "4K | 8.29 Mpx"
        case .DCI2K:            return "2K | 2.21 Mpx"
        case .FullHD:           return "Full HD | 2.07 Mpx"
        case .HD:               return "HD | 0.92 Mpx"
        case .qHD:              return "qHD | 0.52 Mpx"
        case .nHD:              return "nHD | 0.23 Mpx"
        }
    }
}

// MARK: - Max Video Sizes
public enum pwgVideoMaxSizes: Int16, CaseIterable {
    case fullResolution = 0, UHD4K, FullHD, HD, qHD, nHD
}

extension pwgVideoMaxSizes {
    public var pixels: Int {
        switch self {
        case .fullResolution:   return Int.max
        case .UHD4K:            return 3840
        case .FullHD:           return 1920
        case .HD:               return 1280
        case .qHD:              return 960
        case .nHD:              return 640
        }
    }
    
    public var name: String {
        switch self {
        case .fullResolution:   return NSLocalizedString("UploadPhotoSize_original", comment: "No Downsizing")
        case .UHD4K:            return "4K | ≈26.7 Mbit/s"
        case .FullHD:           return "Full HD | ≈15.6 Mbit/s"
        case .HD:               return "HD | ≈11.3 Mbit/s"
        case .qHD:              return "qHD | ≈5.8 Mbit/s"
        case .nHD:              return "nHD | ≈2.8 Mbit/s"
        }
    }
}

// MARK: - Photo Sort Options
public enum kPiwigoSort : Int16 {
    case nameAscending = 0              // Photo title, A → Z
    case nameDescending                 // Photo title, Z → A
            
    case dateCreatedDescending          // Date created, new → old
    case dateCreatedAscending           // Date created, old → new
            
    case datePostedDescending           // Date posted, new → old
    case datePostedAscending            // Date posted, old → new
            
    case fileNameAscending              // File name, A → Z
    case fileNameDescending             // File name, Z → A
            
    case ratingScoreDescending          // Rating score, high → low
    case ratingScoreAscending           // Rating score, low → high
        
    case visitsDescending               // Visits, high → low
    case visitsAscending                // Visits, low → high
        
    case manual                         // Manual order
    case random                         // Random order
//    case kPiwigoSortVideoOnly
//    case kPiwigoSortImageOnly
    
    case count
}

public class UploadVars: NSObject {
    
    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
        if let _ = UserDefaults.dataSuite.object(forKey: "photoResize") {
            UserDefaults.dataSuite.removeObject(forKey: "photoResize")
        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Upload variables stored in UserDefaults / Standard
    /// - None

    
    // MARK: - Vars in UserDefaults / App Group
    // Upload variables stored in UserDefaults / App Group
    /// - Default image sort option
    @UserDefault("localImagesSort", defaultValue: kPiwigoSort.dateCreatedDescending.rawValue, userDefaults: UserDefaults.dataSuite)
    public static var localImagesSort: Int16

    /// - Default author name
    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var defaultAuthor: String
    
    /// - Default privacy level
    @UserDefault("defaultPrivacyLevel", defaultValue: kPiwigoPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
    public static var defaultPrivacyLevel: Int16
    
    /// - Strip GPS metadata before uploading
    @UserDefault("stripGPSdataOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var stripGPSdataOnUpload: Bool
    
    /// - Resize photo before uploading
    @UserDefault("resizeImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var resizeImageOnUpload: Bool
    
    /// - Max photo size to apply when downsizing
    /// - before version 2.7, we stored in 'photoResize' the fraction of the photo size to apply when resizing.
    @UserDefault("photoMaxSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public static var photoMaxSize: Int16
    public class func selectedPhotoSizeFromSize(_ size:Int16) -> Int16 {
        for index in (0...pwgPhotoMaxSizes.allCases.count-1).reversed() {
            if size < pwgPhotoMaxSizes(rawValue: Int16(index))?.pixels ?? 0 {
                return Int16(index)
            }
        }
        return 0
    }
    
    /// - Max video size to apply when downsizing
    /// - before version 2.7, we stored in 'photoResize' the fraction of the photo or video size to apply when resizing.
    @UserDefault("videoMaxSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public static var videoMaxSize: Int16
    public class func selectedVideoSizeFromSize(_ size:Int16) -> Int16 {
        for index in (0...pwgVideoMaxSizes.allCases.count-1).reversed() {
            if size < pwgVideoMaxSizes(rawValue: Int16(index))?.pixels ?? 0 {
                return Int16(index)
            }
        }
        return 0
    }
    
    /// - Compress photo before uploading
    @UserDefault("compressImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var compressImageOnUpload: Bool

    /// - Quality factor to adopt when compressing
    @UserDefault("photoQuality", defaultValue: 98, userDefaults: UserDefaults.dataSuite)
    public static var photoQuality: Int16

    /// - Delete photo after upload
    @UserDefault("deleteImageAfterUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var deleteImageAfterUpload: Bool
    
    /// - Prefix file name before uploading
    @UserDefault("prefixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var prefixFileNameBeforeUpload: Bool
    
    /// - Prefix added to file name before uploading
    @UserDefault("defaultPrefix", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var defaultPrefix: String

    /// - File types accepted by the Piwigo server
    @UserDefault("serverFileTypes", defaultValue: "jpg,jpeg,png,gif", userDefaults: UserDefaults.dataSuite)
    public static var serverFileTypes: String

    /// - Chunk size wanted by the Piwigo server (500 KB by default)
    @UserDefault("uploadChunkSize", defaultValue: 500, userDefaults: UserDefaults.dataSuite)
    public static var uploadChunkSize: Int

    /// - Only upload photos when a Wi-Fi network is available
    @UserDefault("wifiOnlyUploading", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var wifiOnlyUploading: Bool

    /// - Is auto-upload mode active?
    @UserDefault("isAutoUploadActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public static var isAutoUploadActive: Bool

    /// - Local identifier of the Photo Library album containing photos to upload (i.e. source album)
    @UserDefault("autoUploadAlbumId", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var autoUploadAlbumId: String

    /// - Category ID of the Piwigo album to upload photos into (i.e. destination album)
    @UserDefault("autoUploadCategoryId", defaultValue: NSNotFound, userDefaults: UserDefaults.dataSuite)
    public static var autoUploadCategoryId: Int

    /// - IDs of the tags applied to the photos to auto-upload
    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var autoUploadTagIds: String

    /// - Comments to add to the photos to auto-upload
    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var autoUploadComments: String
    
    /// - When the latest deletion of Photo Library images was accomplished
    static let kPiwigoOneDay = (TimeInterval)(24 * 60 * 60)     // i.e. 1 day
    @UserDefault("dateOfLastPhotoLibraryDeletion", defaultValue: Date.distantPast.timeIntervalSinceReferenceDate, userDefaults: UserDefaults.dataSuite)
    public static var dateOfLastPhotoLibraryDeletion: TimeInterval

    
    // MARK: - Vars in Memory
    // Upload variables kept in memory
    /// - None
}
