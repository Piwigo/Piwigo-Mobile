//
//  Upload+CoreDataClass.swift
//  piwigoKit
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
        photoMaxSize = uploadProperties.photoMaxSize
        videoMaxSize = uploadProperties.videoMaxSize
        compressImageOnUpload = uploadProperties.compressImageOnUpload
        photoQuality = Int16(uploadProperties.photoQuality)
        prefixFileNameBeforeUpload = uploadProperties.prefixFileNameBeforeUpload
        defaultPrefix = uploadProperties.defaultPrefix
        deleteImageAfterUpload = uploadProperties.deleteImageAfterUpload
        markedForAutoUpload = uploadProperties.markedForAutoUpload
    }
    
    func updateStatus(with state: kPiwigoUploadState?, error: String?) throws {
        // Update the upload request only if a new state has a value.
        guard let newStatus = state else {
            throw UploadError.missingData
        }
        
        // State of upload request
        requestState = Int16(newStatus.rawValue)
        
        // Section into which the upload request belongs to
        requestSectionKey = newStatus.sectionKey

        // Error message description
        requestError = error ?? ""
    }
}

extension Upload {
    public var state: kPiwigoUploadState {
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
        case kPiwigoUploadState.uploadingFail.rawValue:
            return .uploadingFail
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

    public var stateLabel: String {
        return state.stateInfo
    }

    public var privacy: kPiwigoPrivacy {
        switch self.privacyLevel {
        case kPiwigoPrivacy.everybody.rawValue:
            return .everybody
        case kPiwigoPrivacy.adminsFamilyFriendsContacts.rawValue:
        return .adminsFamilyFriendsContacts
        case kPiwigoPrivacy.adminsFamilyFriends.rawValue:
        return .adminsFamilyFriends
        case kPiwigoPrivacy.adminsFamily.rawValue:
        return .adminsFamily
        case kPiwigoPrivacy.admins.rawValue:
        return .admins
        case kPiwigoPrivacy.count.rawValue:
        return .count
        case kPiwigoPrivacy.unknown.rawValue:
        return .unknown
        default:
            return .unknown
        }
    }

    public func getProperties() -> UploadProperties {
        return UploadProperties(localIdentifier: self.localIdentifier,
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
            resizeImageOnUpload: self.resizeImageOnUpload,
            photoMaxSize: self.photoMaxSize, videoMaxSize:self.videoMaxSize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload,
            markedForAutoUpload: self.markedForAutoUpload)
    }

    public func getProperties(with state: kPiwigoUploadState, error: String) -> UploadProperties {
        return UploadProperties(localIdentifier: self.localIdentifier,
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
            resizeImageOnUpload: self.resizeImageOnUpload,
            photoMaxSize: self.photoMaxSize, videoMaxSize: self.videoMaxSize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload,
            markedForAutoUpload: self.markedForAutoUpload)
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
public enum SectionKeys: String {
    case Section1, Section2, Section3, Section4
}

extension SectionKeys {
    public var name: String {
        switch self {
        case .Section1:
            return NSLocalizedString("uploadSection_impossible", comment: "Impossible Uploads")
        case .Section2:
            return NSLocalizedString("uploadSection_resumable", comment: "Resumable Uploads")
        case .Section3:
            return NSLocalizedString("uploadSection_queue", comment: "Upload Queue")
        case .Section4:
            fallthrough
        default:
            return "—?—"
        }
    }
}


// MARK: - Upload States
public enum kPiwigoUploadState : Int16 {
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
    
    case deleted
    case uploadingFail
    case finishingFail
}

extension kPiwigoUploadState {
    public var stateInfo: String {
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
        case .uploadingError, .uploadingFail:
            return NSLocalizedString("imageUploadTableCell_uploading", comment: "Uploading...") + " " +
                   NSLocalizedString("errorHUD_label", comment: "Error")
        case .uploaded:
            return NSLocalizedString("imageUploadTableCell_uploaded", comment: "Uploaded")

        case .finishing:
            return NSLocalizedString("imageUploadTableCell_finishing", comment: "Finishing...")
        case .finishingError, .finishingFail:
            return NSLocalizedString("imageUploadTableCell_finishing", comment: "Finishing...") + " " +
                   NSLocalizedString("errorHUD_label", comment: "Error")
        case .finished, .moderated:
            return NSLocalizedString("imageUploadProgressBar_completed", comment: "Completed")
            
        case .deleted:      // Image deleted from the Piwigo server
            return ""
        }
    }
    
    public var sectionKey: String {
        switch self {
        case .preparingFail,
             .formatError,
             .uploadingFail,
             .finishingFail:
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
             .moderated,
             .deleted:
            fallthrough
        default:
            return SectionKeys.Section4.rawValue
        }
    }
}
