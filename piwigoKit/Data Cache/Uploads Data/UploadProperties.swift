//
//  UploadProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

/**
 A struct for managing upload requests
*/
public struct UploadProperties
{
    public let localIdentifier: String             // Unique PHAsset identifier
    public let category: Int                       // 8
    public let serverPath: String                  // URL path of Piwigo server
    public var serverFileTypes: String             // File formats accepted by the server
    public let requestDate: TimeInterval           // "2020-08-22 19:18:43" as a number of seconds
    public var requestState: kPiwigoUploadState    // See enum above
    public var requestError: String

    public var creationDate: TimeInterval          // "2012-08-23 09:18:43" as a number of seconds
    public var fileName: String                    // "IMG123.JPG"
    public var mimeType: String                    // "image/png"
    public var md5Sum: String                      // "8b1a9953c4611296a827abf8c47804d7"
    public var isVideo: Bool                       // true/false
    
    public var author: String                      // "Author"
    public var privacyLevel: kPiwigoPrivacy        // 0
    public var imageTitle: String                  // "Image title"
    public var comment: String                     // "A comment…"
    public var tagIds: String                      // List of tag IDs
    public var imageId: Int                        // 1042

    public var stripGPSdataOnUpload: Bool
    public var resizeImageOnUpload: Bool
    public var photoMaxSize: Int16
    public var videoMaxSize: Int16
    public var compressImageOnUpload: Bool
    public var photoQuality: Int16
    public var prefixFileNameBeforeUpload: Bool
    public var defaultPrefix: String
    public var deleteImageAfterUpload: Bool
    public var markedForAutoUpload: Bool
}

extension UploadProperties {
    // Create new upload from localIdentifier and category
    public init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier,
            // Category ID of the album to upload to
            category: category,
            
            // Server parameters
            serverPath: NetworkVars.serverPath,
            serverFileTypes: UploadVars.serverFileTypes,
            
            // Upload request date is now and state is waiting
            requestDate: Date().timeIntervalSinceReferenceDate,
            requestState: .waiting, requestError: "",
            
            // Photo creation date and filename
            creationDate: Date().timeIntervalSinceReferenceDate, fileName: "",
            mimeType: "", md5Sum: "", isVideo: false,
            
            // Photo author name defaults to name entered in Settings
            author: UploadVars.defaultAuthor,
            
            // Privacy level defaults to level selected in Settings
            privacyLevel: kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel) ?? .everybody,
            
            // No title, comment, tag, filename by default, image ID unknown
            imageTitle: "", comment: "", tagIds: "", imageId: NSNotFound,
            
            // Upload settings
            stripGPSdataOnUpload: UploadVars.stripGPSdataOnUpload,
            resizeImageOnUpload: UploadVars.resizeImageOnUpload,
            photoMaxSize: UploadVars.photoMaxSize,
            videoMaxSize: UploadVars.videoMaxSize,
            compressImageOnUpload: UploadVars.compressImageOnUpload,
            photoQuality: UploadVars.photoQuality,
            prefixFileNameBeforeUpload: UploadVars.prefixFileNameBeforeUpload,
            defaultPrefix: UploadVars.defaultPrefix,
            deleteImageAfterUpload: UploadVars.deleteImageAfterUpload,
            markedForAutoUpload: false)
    }
    
    // Return string corresponding to the state
    public var stateLabel: String {
        return requestState.stateInfo
    }
}
