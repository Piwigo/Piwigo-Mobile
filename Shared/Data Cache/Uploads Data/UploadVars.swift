//
//  UploadVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public enum kPiwigoPrivacy : Int16 {
    case everybody = 0
    case adminsFamilyFriendsContacts = 1
    case adminsFamilyFriends = 2
    case adminsFamily = 4
    case admins = 8
    case count = 5
    case unknown = -1
}

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
    
    // Singleton
    public static let shared = UploadVars()
    
    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Upload variables stored in UserDefaults / Standard
    /// - None

    
    // MARK: - Vars in UserDefaults / App Group
    // Upload variables stored in UserDefaults / App Group
    /// - Default image sort option
    @UserDefault("localImagesSort", defaultValue: kPiwigoSort.dateCreatedDescending.rawValue, userDefaults: UserDefaults.dataSuite)
    public var localImagesSort: Int16

    /// - Default author name
    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var defaultAuthor: String
    
    /// - Default privacy level
    @UserDefault("defaultPrivacyLevel", defaultValue: kPiwigoPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
    public var defaultPrivacyLevel: Int16
    
    /// - Strip GPS metadata before uploading
    @UserDefault("stripGPSdataOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var stripGPSdataOnUpload: Bool
    
    /// - Resize photo before uploading
    @UserDefault("resizeImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var resizeImageOnUpload: Bool
    
    /// - Fraction of the photo size to apply when resizing
    @UserDefault("photoResize", defaultValue: 100, userDefaults: UserDefaults.dataSuite)
    public var photoResize : Int16
    
    /// - Compress photo before uploading
    @UserDefault("compressImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var compressImageOnUpload: Bool

    /// - Quality factor to adopt when compressing
    @UserDefault("photoQuality", defaultValue: 98, userDefaults: UserDefaults.dataSuite)
    public var photoQuality: Int16

    /// - Delete photo after upload
    @UserDefault("deleteImageAfterUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var deleteImageAfterUpload: Bool
    
    /// - Prefix file name before uploading
    @UserDefault("prefixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var prefixFileNameBeforeUpload: Bool
    
    /// - Prefix added to file name before uploading
    @UserDefault("defaultPrefix", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var defaultPrefix: String

    /// - File types accepted by the Piwigo server
    @UserDefault("serverFileTypes", defaultValue: "jpg,jpeg,png,gif", userDefaults: UserDefaults.dataSuite)
    public var serverFileTypes: String

    /// - Chunk size wanted by the Piwigo server (500 KB by default)
    @UserDefault("uploadChunkSize", defaultValue: 500, userDefaults: UserDefaults.dataSuite)
    public var uploadChunkSize: Int

    /// - Only upload photos when a Wi-Fi network is available
    @UserDefault("wifiOnlyUploading", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var wifiOnlyUploading: Bool

    /// - Is auto-upload mode active?
    @UserDefault("isAutoUploadActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isAutoUploadActive: Bool

    /// - Local identifier of the Photo Library album containing photos to upload (i.e. source album)
    @UserDefault("autoUploadAlbumId", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var autoUploadAlbumId: String

    /// - Category ID of the Piwigo album to upload photos into (i.e. destination album)
    @UserDefault("autoUploadCategoryId", defaultValue: NSNotFound, userDefaults: UserDefaults.dataSuite)
    public var autoUploadCategoryId: Int

    /// - IDs of the tags applied to the photos to auto-upload
    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var autoUploadTagIds: String

    /// - Comments to add to the photos to auto-upload
    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var autoUploadComments: String

    
    // MARK: - Vars in Memory
    // Upload variables kept in memory
    /// - None
}
