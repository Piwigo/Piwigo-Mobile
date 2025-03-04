//
//  UploadManager.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://academy.realm.io/posts/gwendolyn-weston-ios-background-networking/

import Foundation
import Photos
import CoreData
import MobileCoreServices
import piwigoKit

public class UploadManager: NSObject {

    // Singleton
    public static let shared = UploadManager()
    
    // MARK: - Constants
    // Constants used to name and identify media
    let kOriginalSuffix = "-original"
    public let kIntentPrefix = "Intent-"
    public let kClipboardPrefix = "Clipboard-"
    public let kImageSuffix = "-img-"
    public let kMovieSuffix = "-mov-"
    
    // Constants returning the list of:
    /// - image formats which can be converted with iOS
    /// - movie formats which can be converted with iOS
    /// See: https://developer.apple.com/documentation/uniformtypeidentifiers/system-declared_uniform_type_identifiers
    lazy var acceptedImageExtensions: [String] = {
        if #available(iOS 14.0, *) {
            let utiTypes = [UTType.gif, .jpeg, .tiff, .png, .icns, .bmp, .ico, .rawImage, .svg, .heif, .heic, .webP]
            var fileExtensions = utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
            if #available(iOS 14.3, *) {
                fileExtensions.append("dng")    // i.e. Apple ProRAW
                return fileExtensions
            } else {
                // Fallback on earlier version
                return fileExtensions
            }
        } else {
            // Fallback on earlier version
            return ["heic","heif","png","gif","jpg","jpeg","webp","tif","tiff","bmp","raw","ico","icns"]
        }
    }()
    lazy var acceptedMovieExtensions: [String] = {
        if #available(iOS 14.0, *) {
            let utiTypes = [UTType.quickTimeMovie, .mpeg, .mpeg2Video, .mpeg4Movie, .appleProtectedMPEG4Video, .avi]
            return utiTypes.flatMap({$0.tags[.filenameExtension] ?? []})
        } else {
            return ["mov","mpg","mpeg","mpeg2","mp4","avi"]
        }
    }()

    // For producing filename suffixes
    lazy var chunkFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimumIntegerDigits = 5
        return numberFormatter
    }()

    // Constants used to manage foreground tasks
    let maxNberPreparedUploads = 10             // Maximum number of images prepared in advance
    let maxNberOfTransfers = 1                  // Maximum number of transfers executed in parallel
    public let maxNberOfFailedUploads = 5       // Stop transfers after 5 failures

    // Constants used to manage background tasks
    public let maxCountOfBytesToUpload = 100 * 1024 * 1024  // Up to 100 MB transferred in a series
    public let maxNberOfAutoUploadsPerCheck = 500           // i.e. do not add more than 500 requests at a time

    
    // MARK: - Upload Request States
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing is set to true when a photo/video is going to be prepared,
      and false when the preparation has completed or failed.
    - isUploading contains the localIdentifier of the photos/videos being transferred to the server,
    - isFinishing is set to true when the photo/video parameters are going to be set,
      and false when this job has completed or failed.
    */
    public var isPaused = false                             // Flag used to pause uploads when
                                                            // - sorting local device images
                                                            // - adding upload requests
                                                            // - modifying auto-upload settings
                                                            // - cancelling upload tasks
                                                            // - the app is about to become inactive
    var isPreparing = false                                 // Prepare one image at once
    var isUploading = Set<NSManagedObjectID>()              // IDs of queued transfers
    var isFinishing = false                                 // Finish transfer one image at once
    var isDeleting = Set<NSManagedObjectID>()               // IDs of uploads to be deleted

    public var isExecutingBackgroundUploadTask = false      // True if called by the background task
    public var countOfBytesPrepared = UInt64(0)             // Total amount of bytes of prepared files
    public var countOfBytesToUpload = 0                     // Total amount of bytes to be sent
    public var uploadRequestsToPrepare = Set<NSManagedObjectID>()
    public var uploadRequestsToTransfer = Set<NSManagedObjectID>()

    /// Background queue in which uploads are managed
    public let backgroundQueue: DispatchQueue = {
        return DispatchQueue(label: "org.piwigo.uploadBckgQueue", qos: .background)
    }()
    
    /// Uploads directory, sessions and JSON decoder
    public let uploadsDirectory: URL = DataDirectories.shared.appUploadsDirectory
    public let frgdSession: URLSession = UploadSessions.shared.frgdSession
    public let bckgSession: URLSession = UploadSessions.shared.bckgSession
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
            debugPrint("••> Could not fetch pending uploads: \(error)")
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
    lazy var bckgContext: NSManagedObjectContext = {
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
        let variables = ["serverPath" : NetworkVars.serverPath,
                         "userName"   : NetworkVars.username]
        fetchRequest.predicate = pendingPredicate.withSubstitutionVariables(variables)
        return fetchRequest
    }()

    public lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchPendingRequest,
                                                 managedObjectContext: self.uploadProvider.bckgContext,
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
        let variables = ["serverPath" : NetworkVars.serverPath,
                         "userName"   : NetworkVars.username]
        fetchRequest.predicate = completedPredicate.withSubstitutionVariables(variables)
        return fetchRequest
    }()

    public lazy var completed: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchCompletedRequest,
                                                 managedObjectContext: self.uploadProvider.bckgContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil)
        return uploads
    }()
}


// MARK: - NSFetchedResultsControllerDelegate
extension UploadManager: NSFetchedResultsControllerDelegate {
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            // Check whether this upload request can be launched in the foreground
            if isExecutingBackgroundUploadTask == false {
                findNextImageToUpload()
            }
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
