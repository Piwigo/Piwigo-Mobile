//
//  UploadVars.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 25/06/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - File Extension Case
// The raw value is stored in the Core Data persistent store.
// A zero value is adopted in the persistent store when the case should not be changed.
public enum FileExtCase: Int16 {
    case keep = -1
    case lowercase
    case uppercase
}

// Mark UploadVars as Sendable since Apple documents UserDefaults as thread-safe
// and pwgImageSort is Sendable
public class UploadVars: NSObject, @unchecked Sendable {
    
    // Singleton
    public static let shared = UploadVars()
    
    // Constants
//    public var isExecutingBGContinuedUploadTask = false     // True when the task is running (since iOS 26)
    public var isExecutingBGUploadTask = false              // True if called by the background task (before iOS 26)
    public let maxNberOfUploadsPerBckgTask = 100            // i.e. up to 100 requests per bckg task
    public var isPaused = false                             // Flag used to pause uploads when
                                                            // - sorting local device images
                                                            // - adding upload requests
                                                            // - modifying auto-upload settings
                                                            // - cancelling upload tasks
                                                            // - the app is about to become inactive

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
        if let defaultPrefix = UserDefaults.dataSuite.object(forKey: "defaultPrefix") as? String {
            UserDefaults.dataSuite.removeObject(forKey: "defaultPrefix")
            // Add prefix to action list if not empty and enabled (as from v3.4)
            if let prefixFileNameBeforeUpload = UserDefaults.dataSuite.object(forKey: "prefixFileNameBeforeUpload") as? Bool,
               prefixFileNameBeforeUpload, defaultPrefix.isEmpty == false,
               let encodedPrefix = defaultPrefix.base64Encoded {
                let encodedAction = "\(RenameAction.ActionType.addText.rawValue):\(encodedPrefix)"
                UserDefaults.dataSuite.set(encodedAction + ",", forKey: "prefixFileNameActionList")
            }
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
    
    /// - Latest year format chosen by the user
    @UserDefault("defaultYearFormat", defaultValue: pwgDateFormat.year(format: .yyyy).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultYearFormat: String

    /// - Latest month format chosen by the user
    @UserDefault("defaultMonthFormat", defaultValue: pwgDateFormat.month(format: .MM).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultMonthFormat: String

    /// - Latest day format chosen by the user
    @UserDefault("defaultDayFormat", defaultValue: pwgDateFormat.day(format: .dd).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultDayFormat: String

    /// - Latest hour format chosen by the user
    @UserDefault("defaultHourFormat", defaultValue: pwgTimeFormat.hour(format: .HH).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultHourFormat: String

    /// - Latest minute format chosen by the user
    @UserDefault("defaultMinuteFormat", defaultValue: pwgTimeFormat.minute(format: .mm).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultMinuteFormat: String

    /// - Latest second format chosen by the user
    @UserDefault("defaultSecondFormat", defaultValue: pwgTimeFormat.second(format: .ss).asString, userDefaults: UserDefaults.dataSuite)
    public var defaultSecondFormat: String

    /// - First counter value used by each album to name uploaded files
    @UserDefault("categoryCounterInit", defaultValue: Int64(1), userDefaults: UserDefaults.dataSuite)
    public var categoryCounterInit: Int64

    /// - Prefix file name before upload
    @UserDefault("prefixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var prefixFileNameBeforeUpload: Bool
    
    /// - Prefix action list in user's selected order
    @UserDefault("prefixFileNameActionList", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var prefixFileNameActionList: String

    /// - Replace file name before upload
    @UserDefault("replaceFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var replaceFileNameBeforeUpload: Bool
    
    /// - Replace action list in user's selected order
    @UserDefault("replaceFileNameActionList", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var replaceFileNameActionList: String
    
    /// - Suffix file name before upload
    @UserDefault("suffixFileNameBeforeUpload", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var suffixFileNameBeforeUpload: Bool

    /// - Suffix action list in user's selected order
    @UserDefault("suffixFileNameActionList", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var suffixFileNameActionList: String
    
    /// - Change case of file extension or not
    @UserDefault("changeCaseOfFileExtension", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var changeCaseOfFileExtension: Bool
    
    /// - Case of the file extension
    @UserDefault("caseOfFileExtension", defaultValue: FileExtCase.keep.rawValue, userDefaults: UserDefaults.dataSuite)
    public var caseOfFileExtension: Int16

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
