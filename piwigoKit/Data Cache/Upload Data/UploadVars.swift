//
//  UploadVars.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public class UploadVars: NSObject {
    
    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
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
    /// - None

    
    // MARK: - Vars in UserDefaults / App Group
    // Upload variables stored in UserDefaults / App Group
    /// - Default image sort option
    @UserDefault("localImagesSortRaw", defaultValue: pwgImageSort.dateCreatedDescending.rawValue, userDefaults: UserDefaults.dataSuite)
    private static var localImagesSortRaw: Int16
    public static var localImagesSort: pwgImageSort {
        get { return pwgImageSort(rawValue: localImagesSortRaw) ?? .dateCreatedDescending }
        set(value) {
            if pwgImageSort.allCases.contains(value) {
                localImagesSortRaw = value.rawValue
            }
        }
    }

    /// - Default author name
    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var defaultAuthor: String
    
    /// - Default privacy level
    @UserDefault("defaultPrivacyLevel", defaultValue: pwgPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
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
    
    /// - Max video size to apply when downsizing
    /// - before version 2.7, we stored in 'photoResize' the fraction of the photo or video size to apply when resizing.
    @UserDefault("videoMaxSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public static var videoMaxSize: Int16
    
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
    @UserDefault("autoUploadCategoryId", defaultValue: Int32.min, userDefaults: UserDefaults.dataSuite)
    public static var autoUploadCategoryId: Int32

    /// - IDs of the tags applied to the photos to auto-upload
    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var autoUploadTagIds: String

    /// - Comments to add to the photos to auto-upload
    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var autoUploadComments: String
    
    /// - When the latest deletion of Photo Library images was accomplished
    @UserDefault("dateOfLastPhotoLibraryDeletion", defaultValue: Date.distantPast.timeIntervalSinceReferenceDate, userDefaults: UserDefaults.dataSuite)
    public static var dateOfLastPhotoLibraryDeletion: TimeInterval
}
