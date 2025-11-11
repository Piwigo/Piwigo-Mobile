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
    func update(with uploadProperties: UploadProperties, tags: Set<Tag>, forUser user: User? = nil) throws {
        
        // Update the upload request only if the Id and category properties have values.
        guard uploadProperties.localIdentifier.count > 0,
              Int64(uploadProperties.category) != 0 else {
            throw PwgKitError.missingUploadData
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
        if fileNameExtensionCase != uploadProperties.fileNameExtensionCase {
            fileNameExtensionCase = uploadProperties.fileNameExtensionCase
        }
        if fileNamePrefixEncodedActions != uploadProperties.fileNamePrefixEncodedActions {
            fileNamePrefixEncodedActions = uploadProperties.fileNamePrefixEncodedActions
        }
        if fileNameReplaceEncodedActions != uploadProperties.fileNameReplaceEncodedActions {
            fileNameReplaceEncodedActions = uploadProperties.fileNameReplaceEncodedActions
        }
        if fileNameSuffixEncodedActions != uploadProperties.fileNameSuffixEncodedActions {
            fileNameSuffixEncodedActions = uploadProperties.fileNameSuffixEncodedActions
        }
        if mimeType != uploadProperties.mimeType {
            mimeType = uploadProperties.mimeType
        }
        if md5Sum != uploadProperties.md5Sum {
            md5Sum = uploadProperties.md5Sum
        }
        if fileType != uploadProperties.fileType {
            fileType = uploadProperties.fileType
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
            var newTags = Set<Tag>()
            // Tags retrieved in another context!
            newTagIds.forEach({
                if let copy = self.managedObjectContext?.object(with: $0) as? Tag {
                    newTags.insert(copy)
                }
            })
            self.tags = newTags
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
    public func setState(_ state: pwgUploadState, error: Error? = nil, save: Bool) {
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
        
        // Should we save changes now?
        if save {
            self.managedObjectContext?.saveIfNeeded()
        }
    }
    
    /**
        Delete files before deleting object
     */
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        
        // Delete corresponding temporary files if any
        var prefix = ""
        if #available(iOS 16.0, *) {
            prefix = self.localIdentifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            prefix = self.localIdentifier.replacingOccurrences(of: "/", with: "-")
        }
        if !prefix.isEmpty {
            // Delete associated files stored in the Upload folder
            let fm = FileManager.default
            do {
                // Get list of files
                let uploadsDirectory: URL = DataDirectories.appUploadsDirectory
                var filesToDelete = try fm.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])

                // Delete files whose filenames starts with the prefix
                filesToDelete.removeAll(where: { !$0.lastPathComponent.hasPrefix(prefix) })
                try filesToDelete.forEach({ try fm.removeItem(at: $0) })
            }
            catch let error {
                debugPrint("••> could not clear the Uploads folder: \(error)")
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

    public var isVideo: Bool {
        return pwgImageFileType(rawValue: self.fileType) == .video
    }
    
    public func getProperties() -> UploadProperties {
        let tags = self.tags?.compactMap({$0}) ?? []
        let newTagIds = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        return UploadProperties(
            localIdentifier: self.localIdentifier,
            // Category ID of the album to upload to
            category: self.category,
            
            // Server parameters
            serverPath: self.user?.server?.path ?? NetworkVars.shared.serverPath,
            serverFileTypes: self.user?.server?.fileTypes ?? NetworkVars.shared.serverFileTypes,
            
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: self.state, requestError: self.requestError,

            // Photo creation date and filename
            creationDate: self.creationDate,
            fileName: self.fileName,
            fileNameExtensionCase: self.fileNameExtensionCase,
            fileNamePrefixEncodedActions: self.fileNamePrefixEncodedActions,
            fileNameReplaceEncodedActions: self.fileNameReplaceEncodedActions,
            fileNameSuffixEncodedActions: self.fileNameSuffixEncodedActions,
            fileType: self.fileType, mimeType: self.mimeType, md5Sum: self.md5Sum,
            
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: newTagIds, imageId: self.imageId,
            
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload,
            photoMaxSize: self.photoMaxSize, videoMaxSize:self.videoMaxSize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
            deleteImageAfterUpload: self.deleteImageAfterUpload,
            markedForAutoUpload: self.markedForAutoUpload)
    }

    public func getProperties(with state: pwgUploadState, error: String) -> UploadProperties {
        let tags = self.tags?.compactMap({$0}) ?? []
        let newTagIds = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        return UploadProperties(
            localIdentifier: self.localIdentifier,
            
            // Category ID of the album to upload to
            category: self.category,
            
            // Server parameters
            serverPath: self.user?.server?.path ?? NetworkVars.shared.serverPath,
            serverFileTypes: self.user?.server?.fileTypes ?? NetworkVars.shared.serverFileTypes,
            
            // Upload request date, state and error
            requestDate: self.requestDate, requestState: state, requestError: error,
            
            // Photo creation date and filename
            creationDate: self.creationDate,
            fileName: self.fileName,
            fileNameExtensionCase: self.fileNameExtensionCase,
            fileNamePrefixEncodedActions: self.fileNamePrefixEncodedActions,
            fileNameReplaceEncodedActions: self.fileNameReplaceEncodedActions,
            fileNameSuffixEncodedActions: self.fileNameSuffixEncodedActions,
            fileType: self.fileType, mimeType: self.mimeType, md5Sum: self.md5Sum,
            
            // Photo author name defaults to name entered in Settings
            author: self.author, privacyLevel: self.privacy,
            imageTitle: self.imageName, comment: self.comment,
            tagIds: newTagIds, imageId: self.imageId,
            
            // Upload settings
            stripGPSdataOnUpload: self.stripGPSdataOnUpload,
            resizeImageOnUpload: self.resizeImageOnUpload,
            photoMaxSize: self.photoMaxSize, videoMaxSize: self.videoMaxSize,
            compressImageOnUpload: self.compressImageOnUpload, photoQuality: self.photoQuality,
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
public enum SectionKeys: String, CaseIterable, Sendable {
    case Section1, Section2, Section3, Section4
}

extension SectionKeys {
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var name: String {
        switch self {
        case .Section1:
            return String(localized: "uploadSection_impossible", bundle: piwigoKit,
                          comment: "Impossible Uploads")
        case .Section2:
            return String(localized: "uploadSection_resumable", bundle: piwigoKit,
                          comment: "Resumable Uploads")
        case .Section3:
            return String(localized: "uploadSection_queue", bundle: piwigoKit,
                          comment: "Upload Queue")
        case .Section4:
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
}

extension pwgUploadState {
    // When adopting iOS 16 as minimum target, migrate to LocalizedStringResource()
    public var stateInfo: String {
        switch self {
        case .waiting:
            return String(localized: "imageUploadTableCell_waiting", bundle: piwigoKit, comment: "Waiting...")
        case .preparing:
            return String(localized: "imageUploadTableCell_preparing", bundle: piwigoKit, comment: "Preparing...")
        case .preparingError, .preparingFail:
            return String(localized: "imageUploadTableCell_preparing", bundle: piwigoKit, comment: "Preparing...") + " " +
                   String(localized: "errorHUD_label", bundle: piwigoKit, comment: "Error")
        case .prepared:
            return String(localized: "imageUploadTableCell_prepared", bundle: piwigoKit, comment: "Ready for upload...")
        case .formatError:
            return String(localized: "imageUploadError_format", bundle: piwigoKit, comment: "File format not accepted by Piwigo server.")

        case .uploading:
            return String(localized: "imageUploadTableCell_uploading", bundle: piwigoKit, comment: "Uploading...")
        case .uploadingError, .uploadingFail:
            return String(localized: "imageUploadTableCell_uploading", bundle: piwigoKit, comment: "Uploading...") + " " +
                   String(localized: "errorHUD_label", bundle: piwigoKit, comment: "Error")
        case .uploaded:
            return String(localized: "imageUploadTableCell_uploaded", bundle: piwigoKit, comment: "Uploaded")

        case .finishing:
            return String(localized: "imageUploadTableCell_finishing", bundle: piwigoKit, comment: "Finishing...")
        case .finishingError, .finishingFail:
            return String(localized: "imageUploadTableCell_finishing", bundle: piwigoKit, comment: "Finishing...") + " " +
                   String(localized: "errorHUD_label", bundle: piwigoKit, comment: "Error")
        case .finished, .moderated:
            return String(localized: "imageUploadProgressBar_completed", bundle: piwigoKit, comment: "Completed")
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
             .moderated:
            fallthrough
        default:
            return SectionKeys.Section4.rawValue
        }
    }
}
