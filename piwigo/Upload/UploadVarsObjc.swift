//
//  UploadVarsObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class UploadVarsObjc: NSObject {
    
    @objc static var isExecutingBackgroundUploadTask: Bool {
        get { return UploadManager.shared.isExecutingBackgroundUploadTask }
        set (value) { UploadManager.shared.isExecutingBackgroundUploadTask = value }
    }

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
//    @UserDefault("localImagesSort", defaultValue: kPiwigoSort.dateCreatedDescending.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc static var localImagesSort: Int16 {
        get { return UploadVars.localImagesSort }
        set (value) { UploadVars.localImagesSort = value }
    }

    /// - Default author name
//    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var defaultAuthor: String {
        get { return UploadVars.defaultAuthor }
        set (value) { UploadVars.defaultAuthor = value }
    }
    
    /// - Default privacy level
//    @UserDefault("defaultPrivacyLevel", defaultValue: kPiwigoPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc static var defaultPrivacyLevel: Int16 {
        get { return UploadVars.defaultPrivacyLevel }
        set (value) { UploadVars.defaultPrivacyLevel = value }
    }
    
    /// - Strip GPS metadata before uploading
//    @UserDefault("stripGPSdataOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var stripGPSdataOnUpload: Bool {
        get { return UploadVars.stripGPSdataOnUpload }
        set (value) { UploadVars.stripGPSdataOnUpload = value }
    }
    
    /// - Resize photo before uploading
//    @UserDefault("resizeImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var resizeImageOnUpload: Bool {
        get { return UploadVars.resizeImageOnUpload }
        set (value) { UploadVars.resizeImageOnUpload = value }
    }
    
    /// - Fraction of the photo size to apply when resizing
//    @UserDefault("photoResize", defaultValue: 100, userDefaults: UserDefaults.dataSuite)
    @objc static var photoResize : Int16 {
        get { return UploadVars.photoResize }
        set (value) { UploadVars.photoResize = value }
    }
    
    /// - Compress photo before uploading
//    @UserDefault("compressImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var compressImageOnUpload: Bool {
        get { return UploadVars.compressImageOnUpload }
        set (value) { UploadVars.compressImageOnUpload = value }
    }

    /// - Quality factor to adopt when compressing
//    @UserDefault("photoQuality", defaultValue: 98, userDefaults: UserDefaults.dataSuite)
    @objc static var photoQuality: Int16 {
        get { return UploadVars.photoQuality }
        set (value) { UploadVars.photoQuality = value }
    }

    /// - Delete photo after upload
//    @UserDefault("deleteImageAfterUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var deleteImageAfterUpload: Bool {
        get { return UploadVars.deleteImageAfterUpload }
        set (value) { UploadVars.deleteImageAfterUpload = value }
    }
    
    /// - Prefix file name before uploading
//    @UserDefault("prefixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var prefixFileNameBeforeUpload: Bool {
        get { return UploadVars.prefixFileNameBeforeUpload }
        set (value) { UploadVars.prefixFileNameBeforeUpload = value }
    }
    
    /// - Prefix added to file name before uploading
//    @UserDefault("defaultPrefix", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var defaultPrefix: String {
        get { return UploadVars.defaultPrefix }
        set (value) { UploadVars.defaultPrefix = value }
    }

    /// - File types accepted by the Piwigo server
//    @UserDefault("serverFileTypes", defaultValue: "jpg,jpeg,png,gif", userDefaults: UserDefaults.dataSuite)
    @objc static var serverFileTypes: String {
        get { return UploadVars.serverFileTypes }
        set (value) { UploadVars.serverFileTypes = value }
    }

    /// - Chunk size wanted by the Piwigo server (500 KB by default)
//    @UserDefault("uploadChunkSize", defaultValue: 500, userDefaults: UserDefaults.dataSuite)
    @objc static var uploadChunkSize: Int {
        get { return UploadVars.uploadChunkSize }
        set (value) { UploadVars.uploadChunkSize = value }
    }

    /// - Only upload photos when a Wi-Fi network is available
//    @UserDefault("wifiOnlyUploading", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var wifiOnlyUploading: Bool {
        get { return UploadVars.wifiOnlyUploading }
        set (value) { UploadVars.wifiOnlyUploading = value }
    }

    /// - Is auto-upload mode active?
//    @UserDefault("isAutoUploadActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc static var isAutoUploadActive: Bool {
        get { return UploadVars.isAutoUploadActive }
        set (value) { UploadVars.isAutoUploadActive = value }
    }

    /// - Local identifier of the Photo Library album containing photos to upload (i.e. source album)
//    @UserDefault("autoUploadAlbumId", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var autoUploadAlbumId: String {
        get { return UploadVars.autoUploadAlbumId }
        set (value) { UploadVars.autoUploadAlbumId = value }
    }

    /// - Category ID of the Piwigo album to upload photos into (i.e. destination album)
//    @UserDefault("autoUploadCategoryId", defaultValue: NSNotFound, userDefaults: UserDefaults.dataSuite)
    @objc static var autoUploadCategoryId: Int {
        get { return UploadVars.autoUploadCategoryId }
        set (value) { UploadVars.autoUploadCategoryId = value }
    }

    /// - IDs of the tags applied to the photos to auto-upload
//    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var autoUploadTagIds: String {
        get { return UploadVars.autoUploadTagIds }
        set (value) { UploadVars.autoUploadTagIds = value }
    }

    /// - Comments to add to the photos to auto-upload
//    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var autoUploadComments: String {
        get { return UploadVars.autoUploadComments }
        set (value) { UploadVars.autoUploadComments = value }
    }

    
    // MARK: - Vars in Memory
    // Upload variables kept in memory
    /// - None
}
