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
    @NSManaged var requestSate: Int16
    @NSManaged var requestProgress: Float

    @NSManaged var creationDate: Date?
    @NSManaged var fileName: String?
    @NSManaged var author: String?
    @NSManaged var privacyLevel: Int16

    @NSManaged var title: String?
    @NSManaged var comment: String?
    @NSManaged var tags: Set<Tag>?
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
        requestSate = Int16(uploadProperties.requestState.rawValue)
        
        // Progress of upload requests during transfer defaults to 0.0
        requestProgress = uploadProperties.requestProgress

        // Photo creation date and filename
        creationDate = uploadProperties.creationDate ?? Date.init()
        fileName = uploadProperties.fileName ?? ""

        // Photo author name is empty if not provided
        author = uploadProperties.author ?? ""
        
        // Privacy level is the lowest one if not provided
        privacyLevel = Int16(uploadProperties.privacyLevel?.rawValue ?? kPiwigoPrivacyEverybody.rawValue)

        // Other properties
        title = uploadProperties.title ?? ""
        comment = uploadProperties.comment ?? ""
        tags = uploadProperties.tags ?? []
        imageId = Int64(uploadProperties.imageId)
    }
}

extension Upload {
    var state: kPiwigoUploadState {
        
        switch self.requestSate {
        case kPiwigoUploadState.waiting.rawValue:
            return .waiting
            
        case kPiwigoUploadState.preparing.rawValue:
            return .preparing
        case kPiwigoUploadState.formatError.rawValue:
            return .formatError

        case kPiwigoUploadState.uploading.rawValue:
            return .uploading

        case kPiwigoUploadState.finishing.rawValue:
            return .finishing
            
        case kPiwigoUploadState.uploaded.rawValue:
            return .uploaded
        case kPiwigoUploadState.paused.rawValue:
            return .paused
        default:
            return .waiting
        }
    }

    var stateLabel: String {
        switch state {
        case .waiting:
            return NSLocalizedString("imageUploadTableCell_waiting", comment: "Waiting...")

        case .preparing:
            return NSLocalizedString("imageUploadTableCell_preparing", comment: "Preparing...")
        case .formatError:
            return NSLocalizedString("imageUploadError_format", comment: "File format not accepted by Piwigo server.")

        case .uploading:
            return NSLocalizedString("imageUploadTableCell_uploading", comment: "Uploading...")

        case .finishing:
            return NSLocalizedString("imageUploadTableCell_finishing", comment: "Finishing...")

        case .uploaded:
            return NSLocalizedString("imageUploadTableCell_uploaded", comment: "Uploaded")
        case .paused:
            return NSLocalizedString("imageUploadTableCell_paused", comment: "Paused")
        }
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
}


// MARK: - Upload properties
/**
 A struct for managing upload requests
*/
@objc
enum kPiwigoUploadState : Int16 {
    case waiting
    
    case preparing
    case formatError

    case uploading
    
    case finishing
    case uploaded
    case paused
}

struct UploadProperties
{
    let localIdentifier: String             // Unique PHAsset identifier
    let category: Int                       // 8
    let requestDate: Date                   // "2020-08-22 19:18:43"
    var requestState: kPiwigoUploadState    // See enum above
    var requestProgress: Float              // 0.0 ... 1.0

    var creationDate: Date?                 // "2012-08-23 09:18:43"
    var fileName: String?                   // "IMG123.JPG"
    var author: String?                     // "Author"
    var privacyLevel: kPiwigoPrivacy?       // 0
    var title: String?                      // "Image title"
    var comment: String?                    // "A comment…"
    var tags: Set<Tag>?                     // Array of tags
    var imageId: Int                       // 1042
}

extension UploadProperties {
    init(localIdentifier: String, category: Int) {
        self.init(localIdentifier: localIdentifier, category: category,
            // Upload request date is now and state is waiting
            requestDate: Date.init(), requestState: .waiting, requestProgress: 0.0,
            // Photo creation date and filename
            creationDate: Date.init(), fileName: "",
            // Photo author name defaults to name entered in Settings
            author: Model.sharedInstance()?.defaultAuthor ?? "",
            // Privacy level defaults to level selected in Settings
            privacyLevel: Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody,
            // No title, comment, tag, filename by default
            title: "", comment: "", tags: [], imageId: NSNotFound)
    }
}
