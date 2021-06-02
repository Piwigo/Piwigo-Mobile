//
//  UploadProperties.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

/**
 A struct for managing upload requests
*/
struct UploadProperties
{
    let localIdentifier: String             // Unique PHAsset identifier
    let category: Int                       // 8
    let serverPath: String                  // URL path of Piwigo server
    var serverFileTypes: String             // File formats accepted by the server
    let requestDate: TimeInterval           // "2020-08-22 19:18:43" as a number of seconds
    var requestState: kPiwigoUploadState    // See enum above
    var requestError: String

    var creationDate: TimeInterval          // "2012-08-23 09:18:43" as a number of seconds
    var fileName: String                    // "IMG123.JPG"
    var mimeType: String                    // "image/png"
    var md5Sum: String                      // "8b1a9953c4611296a827abf8c47804d7"
    var isVideo: Bool                       // true/false
    
    var author: String                      // "Author"
    var privacyLevel: kPiwigoPrivacy        // 0
    var imageTitle: String                  // "Image title"
    var comment: String                     // "A comment…"
    var tagIds: String                      // List of tag IDs
    var imageId: Int                        // 1042

    var stripGPSdataOnUpload: Bool
    var resizeImageOnUpload: Bool
    var photoResize: Int16
    var compressImageOnUpload: Bool
    var photoQuality: Int16
    var prefixFileNameBeforeUpload: Bool
    var defaultPrefix: String
    var deleteImageAfterUpload: Bool
    var markedForAutoUpload: Bool
}

extension UploadProperties {
    // Create new upload from localIdentifier and category
    init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier,
            // Category ID of the album to upload to
            category: category,
            
            // Server parameters
            serverPath: NetworkVars.shared.serverPath,
            serverFileTypes: UploadVars.shared.serverFileTypes,
            
            // Upload request date is now and state is waiting
            requestDate: Date().timeIntervalSinceReferenceDate,
            requestState: .waiting, requestError: "",
            
            // Photo creation date and filename
            creationDate: Date().timeIntervalSinceReferenceDate, fileName: "",
            mimeType: "", md5Sum: "", isVideo: false,
            
            // Photo author name defaults to name entered in Settings
            author: UploadVars.shared.defaultAuthor,
            
            // Privacy level defaults to level selected in Settings
            privacyLevel: kPiwigoPrivacy(UploadVars.shared.defaultPrivacyLevel),
            
            // No title, comment, tag, filename by default, image ID unknown
            imageTitle: "", comment: "", tagIds: "", imageId: NSNotFound,
            
            // Upload settings
            stripGPSdataOnUpload: UploadVars.shared.stripGPSdataOnUpload,
            resizeImageOnUpload: UploadVars.shared.resizeImageOnUpload,
            photoResize: UploadVars.shared.photoResize,
            compressImageOnUpload: UploadVars.shared.compressImageOnUpload,
            photoQuality: UploadVars.shared.photoQuality,
            prefixFileNameBeforeUpload: UploadVars.shared.prefixFileNameBeforeUpload,
            defaultPrefix: UploadVars.shared.defaultPrefix,
            deleteImageAfterUpload: UploadVars.shared.deleteImageAfterUpload,
            markedForAutoUpload: false)
    }
    
    // Return string corresponding to the state
    var stateLabel: String {
        return requestState.stateInfo
    }
}
