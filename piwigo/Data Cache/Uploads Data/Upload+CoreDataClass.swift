//
//  Upload+CoreDataClass.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Upload entity.
//

import Foundation
import CoreData

public class Upload: NSManagedObject {

    /**
     Updates an Upload instance with the values from a UploadProperties.
     */
    func update(with uploadProperties: UploadProperties) throws {
        
        // Update the upload request only if the Id and category properties have values.
        guard uploadProperties.localIdentifier.count > 0,
              Int64(uploadProperties.category) != 0 else {
                throw UploadError.missingData
        }
        // Local identifier of the image to upload
        localIdentifier = uploadProperties.localIdentifier
        
        // Category to upload the image to
        category = Int64(uploadProperties.category)
        
        // Server path to which the image is to be uploaded
        serverPath = uploadProperties.serverPath
        
        // File formats accepted by the above server
        serverFileTypes = uploadProperties.serverFileTypes
        
        // Date of upload request defaults to now
        requestDate = uploadProperties.requestDate
        
        // State of upload request defaults to "waiting"
        requestState = Int16(uploadProperties.requestState.rawValue)
        
        // Section key corresponding to the request state
        requestSectionKey = uploadProperties.requestState.sectionKey

        // Error message description
        requestError = uploadProperties.requestError

        // Photo creation date, filename and MIME type
        creationDate = uploadProperties.creationDate
        fileName = uploadProperties.fileName
        mimeType = uploadProperties.mimeType
        md5Sum = uploadProperties.md5Sum
        isVideo = uploadProperties.isVideo

        // Photo author name is empty if not provided
        author = uploadProperties.author
        
        // Privacy level is the lowest one if not provided
        privacyLevel = Int16(uploadProperties.privacyLevel.rawValue)

        // Other image properties
        imageName = uploadProperties.imageTitle
        comment = uploadProperties.comment
        tagIds = uploadProperties.tagIds
        imageId = Int64(uploadProperties.imageId)
        
        // Upload settings
        stripGPSdataOnUpload = uploadProperties.stripGPSdataOnUpload
        resizeImageOnUpload = uploadProperties.resizeImageOnUpload
        photoResize = Int16(uploadProperties.photoResize)
        compressImageOnUpload = uploadProperties.compressImageOnUpload
        photoQuality = Int16(uploadProperties.photoQuality)
        prefixFileNameBeforeUpload = uploadProperties.prefixFileNameBeforeUpload
        defaultPrefix = uploadProperties.defaultPrefix
        deleteImageAfterUpload = uploadProperties.deleteImageAfterUpload
    }
    
    func updateStatus(with state: kPiwigoUploadState?, error: String?) throws {
        // Update the upload request only if a new state has a value.
        guard let newStatus = state else {
            throw UploadError.missingData
        }
        
        // State of upload request
        requestState = Int16(newStatus.rawValue)
        
        // Section into which the upload request belongs to
        requestSectionKey = SectionKeys.init(rawValue: newStatus.sectionKey)!.rawValue

        // Error message description
        requestError = error ?? ""
    }
}

extension Upload {
    var state: kPiwigoUploadState {
        switch self.requestState {
        case kPiwigoUploadState.waiting.rawValue:
            return .waiting
            
        case kPiwigoUploadState.preparing.rawValue:
            return .preparing
        case kPiwigoUploadState.preparingError.rawValue:
            return .preparingError
        case kPiwigoUploadState.preparingFail.rawValue:
            return .preparingFail
        case kPiwigoUploadState.formatError.rawValue:
            return .formatError
        case kPiwigoUploadState.prepared.rawValue:
            return .prepared

        case kPiwigoUploadState.uploading.rawValue:
            return .uploading
        case kPiwigoUploadState.uploadingError.rawValue:
            return .uploadingError
        case kPiwigoUploadState.uploaded.rawValue:
            return .uploaded

        case kPiwigoUploadState.finishing.rawValue:
            return .finishing
        case kPiwigoUploadState.finishingError.rawValue:
            return .finishingError
        case kPiwigoUploadState.finished.rawValue:
            return .finished
        case kPiwigoUploadState.moderated.rawValue:
            return .moderated

        default:
            return .waiting
        }
    }

    var stateLabel: String {
        return state.stateInfo
    }

    var privacy: kPiwigoPrivacy {
        switch self.privacyLevel {
        case Int16(kPiwigoPrivacyEverybody.rawValue):
            return kPiwigoPrivacyEverybody
        case Int16(kPiwigoPrivacyAdminsFamilyFriendsContacts.rawValue):
            return kPiwigoPrivacyAdminsFamilyFriendsContacts
        case Int16(kPiwigoPrivacyAdminsFamilyFriends.rawValue):
            return kPiwigoPrivacyAdminsFamilyFriends
        case Int16(kPiwigoPrivacyAdminsFamily.rawValue):
            return kPiwigoPrivacyAdminsFamily
        case Int16(kPiwigoPrivacyAdmins.rawValue):
            return kPiwigoPrivacyAdmins
        case Int16(kPiwigoPrivacyCount.rawValue):
            return kPiwigoPrivacyCount
        case Int16(kPiwigoPrivacyUnknown.rawValue):
            return kPiwigoPrivacyUnknown
        default:
            return kPiwigoPrivacyUnknown
        }
    }

    func getProperties() -> UploadProperties {
        return UploadProperties.init(localIdentifier: self.localIdentifier,
            // Category ID of the album to upload to
            category: Int(self.category),
            // Server parameters
            serverPath: self.serverPath, serverFileTypes: self.serverFileTypes,
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: self.state, requestError: self.requestError,
            // Photo creation date and filename
            creationDate: self.creationDate, fileName: self.fileName,
            mimeType: self.mimeType, md5Sum: self.md5Sum, isVideo: self.isVideo,
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: self.tagIds, imageId: Int(self.imageId),
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload, photoResize: self.photoResize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload)
    }

    func getProperties(with state: kPiwigoUploadState, error: String) -> UploadProperties {
        return UploadProperties.init(localIdentifier: self.localIdentifier,
            // Category ID of the album to upload to
            category: Int(self.category),
            // Server parameters
            serverPath: self.serverPath, serverFileTypes: self.serverFileTypes,
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: state, requestError: error,
            // Photo creation date and filename
            creationDate: self.creationDate, fileName: self.fileName,
            mimeType: self.mimeType, md5Sum: self.md5Sum, isVideo: self.isVideo,
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: self.tagIds, imageId: Int(self.imageId),
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload, photoResize: self.photoResize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload)
    }

    @objc(addUploadsObject:)
    @NSManaged public func addToUploads(_ value: Upload)

    @objc(removeUploadsObject:)
    @NSManaged public func removeFromUploads(_ value: Upload)

    @objc(addUploads:)
    @NSManaged public func addToUploads(_ values: NSSet)

    @objc(removeUploads:)
    @NSManaged public func removeFromUploads(_ values: NSSet)
}


// MARK: - Section Keys
enum SectionKeys: String {
    case Section1, Section2, Section3, Section4
}

extension SectionKeys {
    var name: String {
        switch self {
        case .Section1:
            return NSLocalizedString("uploadSection_impossible", comment: "Impossible Uploads")
        case .Section2:
            return NSLocalizedString("uploadSection_resumable", comment: "Resumable Uploads")
        case .Section3:
            return NSLocalizedString("uploadSection_queue", comment: "Uploads Queue")
        case .Section4:
            fallthrough
        default:
            return "—?—"
        }
    }
}


// MARK: - Upload Properties
/**
 A struct for managing upload requests
*/
@objc
enum kPiwigoUploadState : Int16 {
    case waiting
    
    case preparing
    case preparingError
    case preparingFail
    case formatError
    case prepared

    case uploading
    case uploadingError
    case uploaded

    case finishing
    case finishingError
    case finished
    case moderated
}

extension kPiwigoUploadState {
    var stateInfo: String {
        switch self {
        case .waiting:
            return NSLocalizedString("imageUploadTableCell_waiting", comment: "Waiting...")

        case .preparing:
            return NSLocalizedString("imageUploadTableCell_preparing", comment: "Preparing...")
        case .preparingError, .preparingFail:
            return NSLocalizedString("imageUploadTableCell_preparing", comment: "Preparing...") + " " +
                   NSLocalizedString("errorHUD_label", comment: "Error")
        case .prepared:
            return NSLocalizedString("imageUploadTableCell_prepared", comment: "Ready for upload...")
        case .formatError:
            return NSLocalizedString("imageUploadError_format", comment: "File format not accepted by Piwigo server.")

        case .uploading:
            return NSLocalizedString("imageUploadTableCell_uploading", comment: "Uploading...")
        case .uploadingError:
            return NSLocalizedString("imageUploadTableCell_uploading", comment: "Uploading...") + " " +
                   NSLocalizedString("errorHUD_label", comment: "Error")
        case .uploaded:
            return NSLocalizedString("imageUploadTableCell_uploaded", comment: "Uploaded")

        case .finishing:
            return NSLocalizedString("imageUploadTableCell_finishing", comment: "Finishing...")
        case .finishingError:
            return NSLocalizedString("imageUploadTableCell_finishing", comment: "Finishing...") + " " +
                   NSLocalizedString("errorHUD_label", comment: "Error")
        case .finished, .moderated:
            return NSLocalizedString("imageUploadProgressBar_completed", comment: "Completed")
        }
    }
    
    var sectionKey: String {
        switch self {
        case .preparingFail,
             .formatError:
            return SectionKeys.Section1.rawValue
            
        case .preparingError,
             .uploadingError,
             .finishingError:
            return SectionKeys.Section2.rawValue
            
        case .waiting,
             .preparing,
             .prepared,
             .uploading,
             .uploaded,
             .finishing:
            return SectionKeys.Section3.rawValue
            
        case .finished,
             .moderated:
            fallthrough
        default:
            return SectionKeys.Section4.rawValue
        }
    }
}

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
}

extension UploadProperties {
    // Create new upload from localIdentifier and category
    init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier,
            // Category ID of the album to upload to
            category: category,
            // Server parameters
            serverPath: Model.sharedInstance()?.serverPath ?? "",
            serverFileTypes: Model.sharedInstance()?.serverFileTypes ?? "jpg,jpeg,png,gif",
            // Upload request date is now and state is waiting
            requestDate: Date().timeIntervalSinceReferenceDate,
            requestState: .waiting, requestError: "",
            // Photo creation date and filename
            creationDate: Date().timeIntervalSinceReferenceDate, fileName: "",
            mimeType: "", md5Sum: "", isVideo: false,
            // Photo author name defaults to name entered in Settings
            author: Model.sharedInstance()?.defaultAuthor ?? "",
            // Privacy level defaults to level selected in Settings
            privacyLevel: Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody,
            // No title, comment, tag, filename by default, image ID unknown
            imageTitle: "", comment: "", tagIds: "", imageId: NSNotFound,
            // Upload settings
            stripGPSdataOnUpload: Model.sharedInstance()?.stripGPSdataOnUpload ?? false,
            resizeImageOnUpload: Model.sharedInstance()?.resizeImageOnUpload ?? false,
            photoResize: Int16(Model.sharedInstance()?.photoResize ?? 100),
            compressImageOnUpload: Model.sharedInstance()?.compressImageOnUpload ?? false,
            photoQuality: Int16(Model.sharedInstance()?.photoQuality ?? 98),
            prefixFileNameBeforeUpload: Model.sharedInstance()?.prefixFileNameBeforeUpload ?? false,
            defaultPrefix: Model.sharedInstance()?.defaultPrefix ?? "",
            deleteImageAfterUpload: false)
    }
    
    var stateLabel: String {
        return requestState.stateInfo
    }
}
