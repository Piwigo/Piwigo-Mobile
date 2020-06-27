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

@objc
class Upload: NSManagedObject {

    // A unique identifier for removing duplicates. Constrain
    // the Piwigo Upload entity on this attribute in the data model editor.
    @NSManaged var localIdentifier: String
    
    // The other attributes of an upload.
    @NSManaged var category: Int64
    @NSManaged var requestDate: Date
    @NSManaged var requestState: Int16
    @NSManaged var requestDelete: Bool
    @NSManaged var requestError: String?

    @NSManaged var creationDate: Date?
    @NSManaged var fileName: String?
    @NSManaged var mimeType: String?
    
    @NSManaged var author: String?
    @NSManaged var privacyLevel: Int16
    @NSManaged var imageName: String?
    @NSManaged var comment: String?
    @NSManaged var tags: NSSet?
    @NSManaged var imageId: Int64

    // Singleton
    @objc static let sharedInstance: Upload = Upload()
    
    /**
     Updates an Upload instance with the values from a UploadProperties.
     */
    func update(with uploadProperties: UploadProperties) throws {
        
        // Local identifier of the image to upload
        localIdentifier = uploadProperties.localIdentifier
        
        // Category to upload the image to
        category = Int64(uploadProperties.category)
        
        // Date of upload request defaults to now
        requestDate = uploadProperties.requestDate
        
        // State of upload request defaults to "waiting"
        requestState = Int16(uploadProperties.requestState.rawValue)
        
        // Does not suggest to delete the uploaded image by default
        requestDelete = uploadProperties.requestDelete
        
        // Error message description
        requestError = uploadProperties.requestError

        // Photo creation date, filename and MIME type
        creationDate = uploadProperties.creationDate ?? Date.init()
        fileName = uploadProperties.fileName ?? ""
        mimeType = uploadProperties.mimeType ?? ""

        // Photo author name is empty if not provided
        author = uploadProperties.author ?? ""
        
        // Privacy level is the lowest one if not provided
        privacyLevel = Int16(uploadProperties.privacyLevel?.rawValue ?? kPiwigoPrivacyEverybody.rawValue)

        // Other properties
        imageName = uploadProperties.imageTitle ?? ""
        comment = uploadProperties.comment ?? ""
        tags = NSSet.init(set: uploadProperties.tags ?? NSSet.init())
        imageId = Int64(uploadProperties.imageId)
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

    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
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
        case .finished:
            return NSLocalizedString("imageUploadProgressBar_completed", comment: "Completed")
        }
    }
}

struct UploadProperties
{
    let localIdentifier: String             // Unique PHAsset identifier
    let category: Int                       // 8
    let requestDate: Date                   // "2020-08-22 19:18:43"
    var requestState: kPiwigoUploadState    // See enum above
    var requestDelete: Bool                 // false by default
    var requestError: String?

    var creationDate: Date?                 // "2012-08-23 09:18:43"
    var fileName: String?                   // "IMG123.JPG"
    var mimeType: String?                   // "image/png"
    
    var author: String?                     // "Author"
    var privacyLevel: kPiwigoPrivacy?       // 0
    var imageTitle: String?                 // "Image title"
    var comment: String?                    // "A comment…"
    var tags: NSSet?                        // Array of unique tags
    var imageId: Int                        // 1042
}

extension UploadProperties {
    init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier, category: category,
            // Upload request date is now and state is waiting
            requestDate: Date.init(), requestState: .waiting, requestDelete: false, requestError: "",
            // Photo creation date and filename
            creationDate: Date.init(), fileName: "", mimeType: "",
            // Photo author name defaults to name entered in Settings
            author: Model.sharedInstance()?.defaultAuthor ?? "",
            // Privacy level defaults to level selected in Settings
            privacyLevel: Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody,
            // No title, comment, tag, filename by default
            imageTitle: "", comment: "", tags: NSSet.init(), imageId: NSNotFound)
    }
    
    var stateLabel: String {
        return requestState.stateInfo
    }
}
