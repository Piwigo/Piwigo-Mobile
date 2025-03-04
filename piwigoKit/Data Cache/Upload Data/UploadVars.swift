//
//  UploadVars.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public class UploadVars: NSObject {
    
    // Singleton
    public static let shared = UploadVars()
    
    // Constants
    public let maxNberOfUploadsPerBckgTask = 100            // i.e. up to 100 requests per bckg task

    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
//        if let _ = UserDefaults.standard.object(forKey: "test") {
//            UserDefaults.standard.removeObject(forKey: "test")
//        }
        if let _ = UserDefaults.dataSuite.object(forKey: "photoResize") {
            UserDefaults.dataSuite.removeObject(forKey: "photoResize")
        }
        if let localImagesSort = UserDefaults.dataSuite.object(forKey: "localImagesSort") {
            UserDefaults.dataSuite.removeObject(forKey: "localImagesSort")
            UserDefaults.dataSuite.set(localImagesSort, forKey: "localImagesSortRaw")
        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Upload variables stored in UserDefaults / Standard
    @UserDefault("nberOfPendingUploadRequests", defaultValue: 0)
    public var nberOfUploadsToComplete: Int

    
    // MARK: - Vars in UserDefaults / App Group
    // Upload variables stored in UserDefaults / App Group
    /// - Default image sort option
    @UserDefault("localImagesSortRaw", defaultValue: pwgImageSort.dateCreatedDescending.rawValue, userDefaults: UserDefaults.dataSuite)
    private var localImagesSortRaw: Int16
    public var localImagesSort: pwgImageSort {
        get { return pwgImageSort(rawValue: localImagesSortRaw) ?? .dateCreatedDescending }
        set(value) {
            if pwgImageSort.allCases.contains(value) {
                localImagesSortRaw = value.rawValue
            }
        }
    }

    /// - Default author name
    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var defaultAuthor: String
    
    /// - Default privacy level
    @UserDefault("defaultPrivacyLevel", defaultValue: pwgPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
    public var defaultPrivacyLevel: Int16
    
    /// - Strip GPS metadata before uploading
    @UserDefault("stripGPSdataOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var stripGPSdataOnUpload: Bool
    
    /// - Resize photo before uploading
    @UserDefault("resizeImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var resizeImageOnUpload: Bool
    
    /// - Max photo size to apply when downsizing
    /// - before version 2.7, we stored in 'photoResize' the fraction of the photo size to apply when resizing.
    @UserDefault("photoMaxSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public var photoMaxSize: Int16
    
    /// - Max video size to apply when downsizing
    /// - before version 2.7, we stored in 'photoResize' the fraction of the photo or video size to apply when resizing.
    @UserDefault("videoMaxSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public var videoMaxSize: Int16
    
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
    @UserDefault("autoUploadCategoryId", defaultValue: Int32.min, userDefaults: UserDefaults.dataSuite)
    public var autoUploadCategoryId: Int32

    /// - IDs of the tags applied to the photos to auto-upload
    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var autoUploadTagIds: String

    /// - Comments to add to the photos to auto-upload
    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var autoUploadComments: String
    
    /// - When the latest deletion of Photo Library images was accomplished
    @UserDefault("dateOfLastPhotoLibraryDeletion", defaultValue: Date.distantPast.timeIntervalSinceReferenceDate, userDefaults: UserDefaults.dataSuite)
    public var dateOfLastPhotoLibraryDeletion: TimeInterval
}
