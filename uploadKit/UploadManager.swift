//
//  UploadManager.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://academy.realm.io/posts/gwendolyn-weston-ios-background-networking/

import os
import Foundation
import Photos
import CoreData
import MobileCoreServices
import piwigoKit

@globalActor
public actor UploadManagement {
    public static let shared = UploadManagement()
    
    private init() { }  // Prevents duplicate instances
}

@UploadManagement
public final class UploadManager: NSObject {
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadManager.self))
    
    // Singleton
    public static let shared = UploadManager()
    
    // MARK: - Constants    
    // Constants returning the list of:
    /// - image formats which can be converted with iOS
    /// - movie formats which can be converted with iOS
    /// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
    lazy var acceptedImageExtensions: [String] = {
        var utiTypes: [UTType] = [.ico, .icns,
                                  .png, .gif, .jpeg, .webP, .tiff, .bmp, .svg, .rawImage,
                                  .heic, .heif]
        if #available(iOS 18.2, *) {
            utiTypes += [.jpegxl]
        }
        return utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
    }()
    lazy var acceptedMovieExtensions: [String] = {
        let utiTypes: [UTType] = [.quickTimeMovie,
                                  .mpeg, .mpeg2Video, .mpeg2TransportStream,
                                  .mpeg4Movie, .appleProtectedMPEG4Video, .avi]
        return utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
    }()
    
    // For producing filename suffixes
    lazy var chunkFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5
        return numberFormatter
    }()
    
    // Upload counters kept in memory during upload
    // for updating progress bars and managing tasks
    var uploadCounters = [UploadCounter]()
    
    // Constants used to manage foreground tasks
    let maxNberPreparedUploads = 10             // Maximum number of images prepared in advance
    let maxNberOfTransfers = 1                  // Maximum number of transfers executed in parallel
    public let maxNberOfFailedUploads = 5       // Stop transfers after 5 failures
        
    
    // MARK: - Upload Request States
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing is set to true when a photo/video is going to be prepared,
      and false when the preparation has completed or failed.
    - isUploading contains the localIdentifier of the photos/videos being transferred to the server,
    - isFinishing is set to true when the photo/video parameters are going to be set,
      and false when this job has completed or failed.
    */
    var isPreparing = false                                 // Prepare one image at once
    var isUploading = Set<NSManagedObjectID>()              // IDs of queued transfers
    var isFinishing = false                                 // Finish transfer one image at once
    var isDeleting = Set<NSManagedObjectID>()               // IDs of uploads to be deleted
    
    public var countOfBytesPrepared = UInt64(0)             // Total amount of bytes of prepared files
    public var countOfBytesToUpload = 0                     // Total amount of bytes to be sent
    public var uploadRequestsToPrepare = Set<NSManagedObjectID>()
    public var uploadRequestsToTransfer = Set<NSManagedObjectID>()
        
    /// Uploads directory, sessions and JSON decoder
    let decoder = JSONDecoder()
    
    /// Number of pending upload requests
    public func updateNberOfUploadsToComplete() {
        // Get number of uploads to complete
        let nberOfUploadsToComplete = (uploads.fetchedObjects ?? []).count
        // Store number, update badge and default album view button
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
    }
    
    public override init() {
        super.init()
        
        // Perform fetches
        do {
            try uploads.performFetch()
            try completed.performFetch()
        }
        catch {
            debugPrint("••> Could not fetch pending uploads: \(error.localizedDescription)")
        }
        
        // Register auto-upload disabler
        NotificationCenter.default.addObserver(self, selector: #selector(stopAutoUploader(_:)),
                                               name: Notification.Name.pwgDisableAutoUpload, object: nil)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Core Data Providers
    lazy var userProvider: UserProvider = {
        return UserProvider.shared
    }()
    
    lazy var albumProvider: AlbumProvider = {
        return AlbumProvider.shared
    }()
    
    lazy var imageProvider: ImageProvider = {
        return ImageProvider.shared
    }()
    
    lazy var tagProvider: TagProvider = {
        return TagProvider.shared
    }()
    
    public lazy var uploadProvider: UploadProvider = {
        return UploadProvider.shared
    }()
    
    
    // MARK: - Core Data Object Context
    lazy var uploadBckgContext: NSManagedObjectContext = {
        return uploadProvider.bckgContext
    }()
    
    
    // MARK: - Core Data Source
    private lazy var sortDescriptors: [NSSortDescriptor] = {
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        return sortDescriptors
    }()
    
    private lazy var accountPredicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == $serverPath"))
        andPredicates.append(NSPredicate(format: "user.username == $userName"))
        return andPredicates
    }()
    
    lazy var pendingPredicate: NSPredicate = {
        // Retrieves only non-completed upload requests
        var andPredicates = accountPredicates
        let unwantedStates: [pwgUploadState] = [.finished, .moderated]
        andPredicates.append(NSPredicate(format: "NOT (requestState IN %@)", unwantedStates.map({$0.rawValue})))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    private lazy var fetchPendingRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Retrieves only non-completed upload requests
        let variables = ["serverPath" : NetworkVars.shared.serverPath,
                         "userName"   : NetworkVars.shared.user]
        fetchRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
        return fetchRequest
    }()
    
    public lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchPendingRequest,
                                                 managedObjectContext: self.uploadBckgContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil)
        uploads.delegate = self
        return uploads
    }()
    
    lazy var completedPredicate: NSPredicate = {
        var andPredicates = accountPredicates
        let states: [pwgUploadState] = [.finished, .moderated]
        andPredicates.append(NSPredicate(format: "requestState IN %@", states.map({$0.rawValue})))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    private lazy var fetchCompletedRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Retrieves only completed upload requests
        let variables = ["serverPath" : NetworkVars.shared.serverPath,
                         "userName"   : NetworkVars.shared.user]
        fetchRequest.predicate = completedPredicate.withSubstitutionVariables(variables)
        return fetchRequest
    }()
    
    public lazy var completed: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchCompletedRequest,
                                                 managedObjectContext: self.uploadBckgContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil)
        return uploads
    }()
}


// MARK: - NSFetchedResultsControllerDelegate
extension UploadManager: @UploadManagement NSFetchedResultsControllerDelegate {
    
    public func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            // Check whether this upload request can be launched in the foreground
//            if #unavailable(iOS 26.0) {
                if UploadVars.shared.isExecutingBGUploadTask == false {
                    findNextImageToUpload()
                }
//            }
            // Update number of uploads to complete
            updateNberOfUploadsToComplete()

        case .delete:
            // Update number of uploads to complete
            updateNberOfUploadsToComplete()

        case .move, .update:
            break

        @unknown default:
            fatalError("UploadManager: unknown NSFetchedResultsChangeType")
        }
    }
}
