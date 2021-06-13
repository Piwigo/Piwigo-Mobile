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
    
    // Singleton
    @objc static let shared = UploadVarsObjc()
    
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
    @objc var localImagesSort: Int16 {
        get { return UploadVars.shared.localImagesSort }
        set (value) { UploadVars.shared.localImagesSort = value }
    }

    /// - Default author name
//    @UserDefault("defaultAuthor", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var defaultAuthor: String {
        get { return UploadVars.shared.defaultAuthor }
        set (value) { UploadVars.shared.defaultAuthor = value }
    }
    
    /// - Default privacy level
//    @UserDefault("defaultPrivacyLevel", defaultValue: kPiwigoPrivacy.everybody.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc var defaultPrivacyLevel: Int16 {
        get { return UploadVars.shared.defaultPrivacyLevel }
        set (value) { UploadVars.shared.defaultPrivacyLevel = value }
    }
    
    /// - Strip GPS metadata before uploading
//    @UserDefault("stripGPSdataOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var stripGPSdataOnUpload: Bool {
        get { return UploadVars.shared.stripGPSdataOnUpload }
        set (value) { UploadVars.shared.stripGPSdataOnUpload = value }
    }
    
    /// - Resize photo before uploading
//    @UserDefault("resizeImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var resizeImageOnUpload: Bool {
        get { return UploadVars.shared.resizeImageOnUpload }
        set (value) { UploadVars.shared.resizeImageOnUpload = value }
    }
    
    /// - Fraction of the photo size to apply when resizing
//    @UserDefault("photoResize", defaultValue: 100, userDefaults: UserDefaults.dataSuite)
    @objc var photoResize : Int16 {
        get { return UploadVars.shared.photoResize }
        set (value) { UploadVars.shared.photoResize = value }
    }
    
    /// - Compress photo before uploading
//    @UserDefault("compressImageOnUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var compressImageOnUpload: Bool {
        get { return UploadVars.shared.compressImageOnUpload }
        set (value) { UploadVars.shared.compressImageOnUpload = value }
    }

    /// - Quality factor to adopt when compressing
//    @UserDefault("photoQuality", defaultValue: 98, userDefaults: UserDefaults.dataSuite)
    @objc var photoQuality: Int16 {
        get { return UploadVars.shared.photoQuality }
        set (value) { UploadVars.shared.photoQuality = value }
    }

    /// - Delete photo after upload
//    @UserDefault("deleteImageAfterUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var deleteImageAfterUpload: Bool {
        get { return UploadVars.shared.deleteImageAfterUpload }
        set (value) { UploadVars.shared.deleteImageAfterUpload = value }
    }
    
    /// - Prefix file name before uploading
//    @UserDefault("prefixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var prefixFileNameBeforeUpload: Bool {
        get { return UploadVars.shared.prefixFileNameBeforeUpload }
        set (value) { UploadVars.shared.prefixFileNameBeforeUpload = value }
    }
    
    /// - Prefix added to file name before uploading
//    @UserDefault("defaultPrefix", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var defaultPrefix: String {
        get { return UploadVars.shared.defaultPrefix }
        set (value) { UploadVars.shared.defaultPrefix = value }
    }

    /// - File types accepted by the Piwigo server
//    @UserDefault("serverFileTypes", defaultValue: "jpg,jpeg,png,gif", userDefaults: UserDefaults.dataSuite)
    @objc var serverFileTypes: String {
        get { return UploadVars.shared.serverFileTypes }
        set (value) { UploadVars.shared.serverFileTypes = value }
    }

    /// - Chunk size wanted by the Piwigo server (500 KB by default)
//    @UserDefault("uploadChunkSize", defaultValue: 500, userDefaults: UserDefaults.dataSuite)
    @objc var uploadChunkSize: Int {
        get { return UploadVars.shared.uploadChunkSize }
        set (value) { UploadVars.shared.uploadChunkSize = value }
    }

    /// - Only upload photos when a Wi-Fi network is available
//    @UserDefault("wifiOnlyUploading", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var wifiOnlyUploading: Bool {
        get { return UploadVars.shared.wifiOnlyUploading }
        set (value) { UploadVars.shared.wifiOnlyUploading = value }
    }

    /// - Is auto-upload mode active?
//    @UserDefault("isAutoUploadActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    @objc var isAutoUploadActive: Bool {
        get { return UploadVars.shared.isAutoUploadActive }
        set (value) { UploadVars.shared.isAutoUploadActive = value }
    }

    /// - Local identifier of the Photo Library album containing photos to upload (i.e. source album)
//    @UserDefault("autoUploadAlbumId", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var autoUploadAlbumId: String {
        get { return UploadVars.shared.autoUploadAlbumId }
        set (value) { UploadVars.shared.autoUploadAlbumId = value }
    }

    /// - Category ID of the Piwigo album to upload photos into (i.e. destination album)
//    @UserDefault("autoUploadCategoryId", defaultValue: NSNotFound, userDefaults: UserDefaults.dataSuite)
    @objc var autoUploadCategoryId: Int {
        get { return UploadVars.shared.autoUploadCategoryId }
        set (value) { UploadVars.shared.autoUploadCategoryId = value }
    }

    /// - IDs of the tags applied to the photos to auto-upload
//    @UserDefault("autoUploadTagIds", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var autoUploadTagIds: String {
        get { return UploadVars.shared.autoUploadTagIds }
        set (value) { UploadVars.shared.autoUploadTagIds = value }
    }

    /// - Comments to add to the photos to auto-upload
//    @UserDefault("autoUploadComments", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var autoUploadComments: String {
        get { return UploadVars.shared.autoUploadComments }
        set (value) { UploadVars.shared.autoUploadComments = value }
    }

    
    // MARK: - Vars in Memory
    // Upload variables kept in memory
    /// - None
}
