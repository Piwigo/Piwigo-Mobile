//
//  UploadProperties.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 13/04/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

/**
 A struct for managing upload requests
*/
public struct UploadProperties: Sendable
{
    public let localIdentifier: String             // Unique PHAsset identifier
    public let category: Int32                     // 8
    public let serverPath: String                  // URL path of Piwigo server
    public var serverFileTypes: String             // File formats accepted by the server
    public let requestDate: TimeInterval           // "2020-08-22 19:18:43" as a number of seconds
    public var requestState: pwgUploadState        // See enum above
    public var requestError: String

    public var creationDate: TimeInterval           // "2012-08-23 09:18:43" as a number of seconds
    public var fileName: String                     // "IMG123.JPG"
    public var fileNameExtensionCase: Int16         // See FileExtCase enum
    public var fileNamePrefixEncodedActions: String
    public var fileNameReplaceEncodedActions: String
    public var fileNameSuffixEncodedActions: String
    public var fileType: Int16                      // See pwgImageFileType
    public var mimeType: String                     // "image/png"
    public var md5Sum: String                       // "8b1a9953c4611296a827abf8c47804d7"
    
    public var author: String                       // "Author"
    public var privacyLevel: pwgPrivacy             // 0
    public var imageTitle: String                   // "Image title"
    public var comment: String                      // "A comment…"
    public var tagIds: String                       // List of tag IDs
    public var imageId: Int64                       // 1042

    public var userURIstr: String                   // User instance URI string
    public var stripGPSdataOnUpload: Bool
    public var resizeImageOnUpload: Bool
    public var photoMaxSize: Int16
    public var videoMaxSize: Int16
    public var compressImageOnUpload: Bool
    public var photoQuality: Int16
    public var deleteImageAfterUpload: Bool
    public var markedForAutoUpload: Bool

    // Half of the asset carried by this request. Both halves of a Live Photo uploaded
    // as .both share the same localIdentifier and are told apart by this value.
    public var assetPart: pwgUploadAssetPart = .original

    // PHAsset localIdentifier resolved (in the main app) for a photo shared via the
    // share extension, so that the original can be deleted after a successful upload.
    // nil when the shared item could not be matched to a Photo Library asset.
    public var deleteAssetIdentifier: String? = nil
}

extension UploadProperties {
    // Create new upload from localIdentifier and category
    public init(localIdentifier: String, fileName: String? = nil, category: Int32) {
        // Change case of file name extension?
        var fileNameExtensionCase: Int16 = 0
        if UploadVars.shared.changeCaseOfFileExtension {
            fileNameExtensionCase = UploadVars.shared.caseOfFileExtension
        }
        
        // Prefix file name?
        var prefixFileNameActionList: String = ""
        if UploadVars.shared.prefixFileNameBeforeUpload {
            prefixFileNameActionList = UploadVars.shared.prefixFileNameActionList
        }
        
        // Replace file name?
        var replaceFileNameActionList: String = ""
        if UploadVars.shared.replaceFileNameBeforeUpload {
            replaceFileNameActionList = UploadVars.shared.replaceFileNameActionList
        }
        
        // Suffix file name?
        var suffixFileNameActionList: String = ""
        if UploadVars.shared.suffixFileNameBeforeUpload {
            suffixFileNameActionList = UploadVars.shared.suffixFileNameActionList
        }
        
        // Initialisation
        self.init(localIdentifier: localIdentifier,
            // Category ID of the album to upload to
            category: category,
            
            // Server parameters
            serverPath: ServerVars.shared.serverPath,
            serverFileTypes: ServerVars.shared.serverFileTypes,
            
            // Upload request date is now and state is waiting
            requestDate: Date.timeIntervalSinceReferenceDate,
            requestState: .waiting, requestError: "",
            
            // Photo creation date and filename
            creationDate: Date.timeIntervalSinceReferenceDate,
            fileName: fileName ?? "",
            fileNameExtensionCase: fileNameExtensionCase,
            fileNamePrefixEncodedActions: prefixFileNameActionList,
            fileNameReplaceEncodedActions: replaceFileNameActionList,
            fileNameSuffixEncodedActions: suffixFileNameActionList,
            fileType: Int16.zero, mimeType: "", md5Sum: "",
            
            // Photo author name defaults to name entered in Settings
            author: UploadVars.shared.defaultAuthor,
            
            // Privacy level defaults to level selected in Settings
            privacyLevel: pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel) ?? .everybody,
            
            // No title, comment, tag, filename by default, image ID unknown
            imageTitle: "", comment: "", tagIds: "", imageId: Int64.min,
            
            // Upload settings
            userURIstr: "",
            stripGPSdataOnUpload: UploadVars.shared.stripGPSdataOnUpload,
            resizeImageOnUpload: UploadVars.shared.resizeImageOnUpload,
            photoMaxSize: UploadVars.shared.photoMaxSize,
            videoMaxSize: UploadVars.shared.videoMaxSize,
            compressImageOnUpload: UploadVars.shared.compressImageOnUpload,
            photoQuality: UploadVars.shared.photoQuality,
            deleteImageAfterUpload: UploadVars.shared.deleteImageAfterUpload,
            markedForAutoUpload: false)
    }
    
    // Return string corresponding to the state
    public var stateLabel: String {
        return requestState.stateInfo
    }

    /**
     Identifies the files of this request in the Uploads directory and, through the HTTP header,
     the transfer tasks which carry them. Both halves of a Live Photo share the same
     localIdentifier, so the file key is what tells their files apart.
     NB: Never pass a file key to the Photos framework, use the localIdentifier.
    */
    public var fileKey: String {
        return localIdentifier + assetPart.fileKeySuffix
    }

    /**
     Returns the identifier of the asset a file key was built from, i.e. the identifier which
     the Photos framework and the pickers know. The only place aware of how a file key is
     composed, besides fileKey itself.
    */
    public static func assetIdentifier(from fileKey: String) -> String {
        guard fileKey.hasSuffix(kLivePhotoMovieSuffix)
        else { return fileKey }
        return String(fileKey.dropLast(kLivePhotoMovieSuffix.count))
    }
}
