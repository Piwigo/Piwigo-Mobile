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

/* Upload instances represent upload requests to Piwigo server.
    - Each instance belongs to a User.
    - Tag instances are associated to upload requests.
    - Image files are stored in a temporary folder until the upload is complete.
 */
public class Upload: NSManagedObject {
    
    /**
     Updates an Upload instance with the values from a UploadProperties.
     */
    func update(with uploadProperties: UploadProperties, tags: [Tag], forUser user: User? = nil) throws {
        
        // Update the upload request only if the Id and category properties have values.
        guard uploadProperties.localIdentifier.count > 0,
              Int64(uploadProperties.category) != 0 else {
            throw UploadError.missingData
        }
        // Local identifier of the image to upload
        if localIdentifier != uploadProperties.localIdentifier {
            localIdentifier = uploadProperties.localIdentifier
        }
        
        // Category to upload the image to
        let newCategory = uploadProperties.category
        if category != newCategory {
            category = newCategory
        }
        
        // Date of upload request defaults to now
        if requestDate != uploadProperties.requestDate {
            requestDate = uploadProperties.requestDate
        }
        
        // State of upload request defaults to "waiting"
        let newState = Int16(uploadProperties.requestState.rawValue)
        if requestState != newState {
            requestState = newState
        }
        
        // Section key corresponding to the request state
        let newSection = uploadProperties.requestState.sectionKey
        if requestSectionKey != newSection {
            requestSectionKey = newSection
        }
        
        // Error message description
        if requestError != uploadProperties.requestError {
            requestError = uploadProperties.requestError
        }
        
        // Photo creation date, filename and MIME type
        if creationDate != uploadProperties.creationDate {
            creationDate = uploadProperties.creationDate
        }
        if fileName != uploadProperties.fileName {
            fileName = uploadProperties.fileName
        }
        if mimeType != uploadProperties.mimeType {
            mimeType = uploadProperties.mimeType
        }
        if md5Sum != uploadProperties.md5Sum {
            md5Sum = uploadProperties.md5Sum
        }
        if isVideo != uploadProperties.isVideo {
            isVideo = uploadProperties.isVideo
        }
        
        // Photo author name is empty if not provided
        if author != uploadProperties.author {
            author = uploadProperties.author
        }
        
        // Privacy level is the lowest one if not provided
        let newLevel = Int16(uploadProperties.privacyLevel.rawValue)
        if privacyLevel != newLevel {
            privacyLevel = newLevel
        }
        
        // Other image properties
        if imageName != uploadProperties.imageTitle {
            imageName = uploadProperties.imageTitle
        }
        if comment != uploadProperties.comment {
            comment = uploadProperties.comment
        }
        let newImageId = Int64(uploadProperties.imageId)
        if imageId != newImageId {
            imageId = newImageId
        }
        let newTagIds = tags.map { $0.objectID }
        let tagIds = Array(self.tags ?? Set<Tag>()).map {$0.objectID }
        if tagIds != newTagIds {
            self.tags = Set(tags)
        }
        
        // Upload settings
        if stripGPSdataOnUpload != uploadProperties.stripGPSdataOnUpload {
            stripGPSdataOnUpload = uploadProperties.stripGPSdataOnUpload
        }
        if resizeImageOnUpload != uploadProperties.resizeImageOnUpload {
            resizeImageOnUpload = uploadProperties.resizeImageOnUpload
        }
        if photoMaxSize != uploadProperties.photoMaxSize {
            photoMaxSize = uploadProperties.photoMaxSize
        }
        if videoMaxSize != uploadProperties.videoMaxSize {
            videoMaxSize = uploadProperties.videoMaxSize
        }
        if compressImageOnUpload != uploadProperties.compressImageOnUpload {
            compressImageOnUpload = uploadProperties.compressImageOnUpload
        }
        if photoQuality != uploadProperties.photoQuality {
            photoQuality = Int16(uploadProperties.photoQuality)
        }
        if prefixFileNameBeforeUpload != uploadProperties.prefixFileNameBeforeUpload {
            prefixFileNameBeforeUpload = uploadProperties.prefixFileNameBeforeUpload
        }
        if defaultPrefix != uploadProperties.defaultPrefix {
            defaultPrefix = uploadProperties.defaultPrefix
        }
        if deleteImageAfterUpload != uploadProperties.deleteImageAfterUpload {
            deleteImageAfterUpload = uploadProperties.deleteImageAfterUpload
        }
        if markedForAutoUpload != uploadProperties.markedForAutoUpload {
            markedForAutoUpload = uploadProperties.markedForAutoUpload
        }
        
        // User account associated to this request
        if self.user == nil {
            self.user = user
        }
    }
    
    /**
     Updates the state of an Upload instance.
     */
    func setState(_ state: pwgUploadState, error: Error? = nil) {
        // State of upload request
        requestState = state.rawValue
        
        // Section into which the upload request belongs to
        requestSectionKey = state.sectionKey
        
        // Error message description
        if let error = error {
            requestError = error.localizedDescription
        } else {
            requestError = ""
        }
    }
    
    /**
     Updates the status of an Upload instance.
     */
    func updateStatus(with state: pwgUploadState?, error: String?) throws {
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
    
    /**
        Delete files before deleting object
     */
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        
        // Delete corresponding temporary files if any
        let prefix = self.localIdentifier.replacingOccurrences(of: "/", with: "-")
        if !prefix.isEmpty {
            // Delete associated files stored in the Upload folder
            let fm = FileManager.default
            do {
                // Get list of files
                let uploadsDirectory: URL = DataDirectories.shared.appUploadsDirectory
                var filesToDelete = try fm.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

                // Delete files whose filenames starts with the prefix
                filesToDelete.removeAll(where: { !$0.lastPathComponent.hasPrefix(prefix) })
                try filesToDelete.forEach({ try fm.removeItem(at: $0) })
            }
            catch let error {
                print("••> could not clear the Uploads folder: \(error)")
            }
        }
    }
}

extension Upload {
    public var state: pwgUploadState {
        return pwgUploadState(rawValue: self.requestState) ?? .waiting
    }

    public var stateLabel: String {
        return state.stateInfo
    }

    public var privacy: pwgPrivacy {
        return pwgPrivacy(rawValue: self.privacyLevel) ?? .unknown
    }

    public func getProperties() -> UploadProperties {
        let tags = self.tags?.compactMap({$0}) ?? []
        let newTagIds = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        return UploadProperties(localIdentifier: self.localIdentifier,
            // Category ID of the album to upload to
            category: self.category,
            // Server parameters
            serverPath: self.user?.server?.path ?? NetworkVars.serverPath,
            serverFileTypes: self.user?.server?.fileTypes ?? UploadVars.serverFileTypes,
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: self.state, requestError: self.requestError,
            // Photo creation date and filename
            creationDate: self.creationDate, fileName: self.fileName,
            mimeType: self.mimeType, md5Sum: self.md5Sum, isVideo: self.isVideo,
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: newTagIds, imageId: self.imageId,
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload,
            photoMaxSize: self.photoMaxSize, videoMaxSize:self.videoMaxSize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            prefixFileNameBeforeUpload: self.prefixFileNameBeforeUpload, defaultPrefix: self.defaultPrefix,
            deleteImageAfterUpload: self.deleteImageAfterUpload,
            markedForAutoUpload: self.markedForAutoUpload)
    }

    public func getProperties(with state: pwgUploadState, error: String) -> UploadProperties {
        let tags = self.tags?.compactMap({$0}) ?? []
        let newTagIds = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        return UploadProperties(localIdentifier: self.localIdentifier,
            // Category ID of the album to upload to
            category: self.category,
            // Server parameters
            serverPath: self.user?.server?.path ?? NetworkVars.serverPath,
            serverFileTypes: self.user?.server?.fileTypes ?? UploadVars.serverFileTypes,
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: state, requestError: error,
            // Photo creation date and filename
            creationDate: self.creationDate, fileName: self.fileName,
            mimeType: self.mimeType, md5Sum: self.md5Sum, isVideo: self.isVideo,
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: newTagIds, imageId: self.imageId,
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
    public static let allValues = [Section1, Section2, Section3, Section4]
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
public enum pwgUploadState : Int16, CaseIterable {
    case waiting        =  0 /* Waiting for preparation */
    
    case preparing      =  1 /* Preparinng image/video file */
    case preparingError =  2 /* Error encountered, should be tried again */
    case preparingFail  =  3 /* Error encountered, useless to retry */
    case formatError    =  4 /* Format not accepted by server, cannot be converted… */
    case prepared       =  5 /* Image/video file to upload ready */

    case uploading      =  6 /* Uploading file to server */
    case uploadingError =  7 /* Error encountered, should be tried again */
    case uploadingFail  = 14 /* Error encountered, useless to retry */
    case uploaded       =  8 /* Image/video file uploaded to the server */

    case finishing      =  9 /* Image title being set after uploading with pwg.images.upload
                                Lounge being emptied after uploading with pwg.images.uploadAsync */
    case finishingError = 10 /* Error encountered, should be tried again */
    case finishingFail  = 15 /* Error encountered, useless to retry */
    case finished       = 11 /* Image title set OR lounged emptied successfully */
    
    case moderated      = 12 /* Images uploaded by a Community user was sent to the moderator
                                Not a critical step, forces server to treat uploaded image */
    case deleted        = 13 /* Uploaded file deleted from the server, can be re-uploaded */
}

extension pwgUploadState {
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
