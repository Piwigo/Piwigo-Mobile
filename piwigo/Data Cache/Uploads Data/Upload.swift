//
//  Upload.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/03/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Tag entity.

import CoreData

// MARK: - Core Data
/**
 Managed object subclass for the Upload entity.
 */
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

@objc
class Upload: NSManagedObject {

    // A unique identifier for removing duplicates. Constrain
    // the Piwigo Upload entity on this attribute in the data model editor.
    @NSManaged var localIdentifier: String
    
    // The other attributes of an upload.
    @NSManaged var serverPath: String
    @NSManaged var category: Int64
    @NSManaged var requestDate: Date
    @NSManaged var requestState: Int16
    @NSManaged var requestSectionKey: String
    @NSManaged var requestError: String?

    @NSManaged var creationDate: Date?
    @NSManaged var fileName: String?
    @NSManaged var mimeType: String?
    @NSManaged var md5Sum: String?
    @NSManaged var isVideo: Bool
    
    @NSManaged var author: String?
    @NSManaged var privacyLevel: Int16
    @NSManaged var imageName: String?
    @NSManaged var comment: String?
    @NSManaged var tagIds: String?
    @NSManaged var imageId: Int64

    @NSManaged var stripGPSdataOnUpload: Bool
    @NSManaged var resizeImageOnUpload: Bool
    @NSManaged var photoResize: Int16
    @NSManaged var compressImageOnUpload: Bool
    @NSManaged var photoQuality: Int16
    @NSManaged var prefixFileNameBeforeUpload: Bool
    @NSManaged var defaultPrefix: String?
    @NSManaged var deleteImageAfterUpload: Bool

    // Singleton
    @objc static let sharedInstance: Upload = Upload()
    
    /**
     Updates an Upload instance with the values from a UploadProperties.
     */
    func update(with uploadProperties: UploadProperties) throws {
        
        // Local identifier of the image to upload
        localIdentifier = uploadProperties.localIdentifier
        
        // Server path to which the image is to be uploaded
        serverPath = uploadProperties.serverPath
        
        // Category to upload the image to
        category = Int64(uploadProperties.category)
        
        // Date of upload request defaults to now
        requestDate = uploadProperties.requestDate
        
        // State of upload request defaults to "waiting"
        requestState = Int16(uploadProperties.requestState.rawValue)
        
        // Section key corresponding to the request state
        requestSectionKey = SectionKeys.init(rawValue: uploadProperties.requestState.sectionKey)!.rawValue
        print("•••>> requestSectionKey: \(requestSectionKey)")

        // Error message description
        requestError = uploadProperties.requestError

        // Photo creation date, filename and MIME type
        creationDate = uploadProperties.creationDate ?? Date.init()
        fileName = uploadProperties.fileName ?? ""
        mimeType = uploadProperties.mimeType ?? ""
        isVideo = uploadProperties.isVideo

        // Photo author name is empty if not provided
        author = uploadProperties.author ?? ""
        
        // Privacy level is the lowest one if not provided
        privacyLevel = Int16(uploadProperties.privacyLevel?.rawValue ?? kPiwigoPrivacyEverybody.rawValue)

        // Other image properties
        imageName = uploadProperties.imageTitle ?? ""
        comment = uploadProperties.comment ?? ""
        tagIds = uploadProperties.tagIds ?? ""
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

    func getUploadProperties(with state: kPiwigoUploadState, error: String?) -> UploadProperties {
        return UploadProperties.init(localIdentifier: self.localIdentifier,
            serverPath: self.serverPath, category: Int(self.category),
            // Upload request date is now and state is waiting
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
            resizeImageOnUpload: self.resizeImageOnUpload, photoResize: Int(self.photoResize),
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: Int(self.photoQuality),
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload)
    }

    func getUploadPropertiesCancellingDeletion() -> UploadProperties {
        return UploadProperties.init(localIdentifier: self.localIdentifier,
            serverPath: self.serverPath, category: Int(self.category),
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
            resizeImageOnUpload: self.resizeImageOnUpload, photoResize: Int(self.photoResize),
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: Int(self.photoQuality),
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: false)
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


// MARK: - Upload properties
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
    let serverPath: String                  // URL path of Piwigo server
    let category: Int                       // 8
    let requestDate: Date                   // "2020-08-22 19:18:43"
    var requestState: kPiwigoUploadState    // See enum above
    var requestError: String?

    var creationDate: Date?                 // "2012-08-23 09:18:43"
    var fileName: String?                   // "IMG123.JPG"
    var mimeType: String?                   // "image/png"
    var md5Sum: String?                     // "8b1a9953c4611296a827abf8c47804d7"
    var isVideo: Bool                       // true/false
    
    var author: String?                     // "Author"
    var privacyLevel: kPiwigoPrivacy?       // 0
    var imageTitle: String?                 // "Image title"
    var comment: String?                    // "A comment…"
    var tagIds: String?                     // List of tag IDs
    var imageId: Int                        // 1042

    var stripGPSdataOnUpload: Bool
    var resizeImageOnUpload: Bool
    var photoResize: Int
    var compressImageOnUpload: Bool
    var photoQuality: Int
    var prefixFileNameBeforeUpload: Bool
    var defaultPrefix: String?
    var deleteImageAfterUpload: Bool
}

extension UploadProperties {
    // Create new upload from localIdentifier and category
    init(localIdentifier: String, serverPath: String, category: Int) {
        self.init(localIdentifier: localIdentifier, serverPath: serverPath, category: category,
            // Upload request date is now and state is waiting
            requestDate: Date.init(), requestState: .waiting, requestError: "",
            // Photo creation date and filename
            creationDate: Date.init(), fileName: "", mimeType: "", md5Sum: "", isVideo: false,
            // Photo author name defaults to name entered in Settings
            author: Model.sharedInstance()?.defaultAuthor ?? "",
            // Privacy level defaults to level selected in Settings
            privacyLevel: Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody,
            // No title, comment, tag, filename by default, image ID unknown
            imageTitle: "", comment: "", tagIds: "", imageId: NSNotFound,
            // Upload settings
            stripGPSdataOnUpload: Model.sharedInstance().stripGPSdataOnUpload,
            resizeImageOnUpload: Model.sharedInstance().resizeImageOnUpload,
            photoResize: Model.sharedInstance().photoResize,
            compressImageOnUpload: Model.sharedInstance().compressImageOnUpload,
            photoQuality: Model.sharedInstance().photoQuality,
            prefixFileNameBeforeUpload: Model.sharedInstance().prefixFileNameBeforeUpload,
            defaultPrefix: Model.sharedInstance().defaultPrefix ?? "",
            deleteImageAfterUpload: false)
    }
    
    // Update upload request state and error
    func update(with state: kPiwigoUploadState, error: String?) -> UploadProperties {
        return UploadProperties.init(localIdentifier: self.localIdentifier,
            serverPath: self.serverPath, category: self.category,
            // Upload request date is now and state is waiting
            requestDate: self.requestDate, requestState: state, requestError: error,
            // Photo creation date and filename
            creationDate: self.creationDate, fileName: self.fileName,
            mimeType: self.mimeType, md5Sum: self.md5Sum, isVideo: self.isVideo,
            // Photo parameters
            author: self.author, privacyLevel: self.privacyLevel,
            imageTitle: self.imageTitle, comment: self.comment,
            tagIds: self.tagIds, imageId: self.imageId,
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload, photoResize: self.photoResize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload)
    }
        
    var stateLabel: String {
        return requestState.stateInfo
    }
}
