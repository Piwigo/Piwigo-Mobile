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
    let acceptedImageFormats: String = {
        return "heic,heif,png,gif,jpg,jpeg,webp,tif,tiff,bmp,raw,ico,icns"
    }()
    let acceptedMovieFormats: String = {
        return "mov,mpg,mpeg,mpeg2,mp4,avi"
    }()

    // Constants used to manage foreground tasks
    let maxNberPreparedUploads = 10             // Maximum number of images prepared in advance
    let maxNberOfTransfers = 1                  // Maximum number of transfers executed in parallel
    public let maxNberOfFailedUploads = 5       // Stop transfers after 5 failures

    // Constants used to manage background tasks
    public let maxCountOfBytesToUpload = 50 * 1024 * 1024   // Up to 50 MB transferred in a series
    public let maxNberOfUploadsPerBckgTask = 100            // i.e. 100 requests to be considered
    public let maxNberOfAutoUploadsPerCheck = 500           // i.e. do not add more than 500 requests at a time

    
    // MARK: - Upload Request States
    /** The manager prepares an image for upload and then launches the transfer.
    - isPreparing is set to true when a photo/video is going to be prepared,
      and false when the preparation has completed or failed.
    - isUploading contains the localIdentifier of the photos/videos being transferred to the server,
    - isFinishing is set to true when the photo/video parameters are going to be set,
      and false when this job has completed or failed.
    */
    public var nberOfUploadsToComplete = 0                  // Stored and used by AppDelegate
    public var isPaused = false                             // Flag used to pause/resume uploads
    var isPreparing = false                                 // Prepare one image at once
    var isUploading = Set<NSManagedObjectID>()              // IDs of queued transfers
    var isFinishing = false                                 // Finish transfer one image at once

    public var isExecutingBackgroundUploadTask = false      // true is called by the background task
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
    let frgdSession: URLSession = UploadSessions.shared.frgdSession
    let bckgSession: URLSession = UploadSessions.shared.bckgSession
    let decoder = JSONDecoder()
    
    deinit {
//        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)

        // Close upload session
//        sessionManager.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    

    // MARK: - Core Data Object Contexts
    lazy var bckgContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.bckgContext
        return context
    }()

    
    // MARK: - Core Data Providers
    lazy var imageProvider: ImageProvider = {
        let provider : ImageProvider = ImageProvider()
        return provider
    }()

    public lazy var uploadProvider: UploadProvider = {
        let provider : UploadProvider = UploadProvider()
        return provider
    }()


    // MARK: - Core Data Source
    lazy var fetchPendingRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves only non-completed upload requests
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        var unwantedStates: [pwgUploadState] = [.finished, .moderated, .deleted]
        andPredicates.append(NSPredicate(format: "NOT (requestState IN %@)", unwantedStates.map({$0.rawValue})))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 20
        fetchRequest.returnsObjectsAsFaults = false
        return fetchRequest
    }()

    lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchPendingRequest,
                                                 managedObjectContext: self.bckgContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil) // "org.piwigo.bckg.pendingUploads")
        uploads.delegate = self
        return uploads
    }()

    lazy var fetchCompletedRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves only completed upload requests
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        var states: [pwgUploadState] = [.finished, .moderated, .deleted]
        andPredicates.append(NSPredicate(format: "requestState IN %@", states.map({$0.rawValue})))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var completed: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchCompletedRequest,
                                                 managedObjectContext: self.bckgContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil) // "org.piwigo.frgd.completedUploads")
        return uploads
    }()
}


// MARK: - NSFetchedResultsControllerDelegate
extension UploadManager: NSFetchedResultsControllerDelegate {
    
//    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            print("\(dbg()) Insert Upload…")
            
        case .delete:
            print("\(dbg()) Delete Upload…")

        case .move:
            print("\(dbg()) Move Upload…")

        case .update:
            print("\(dbg()) Update Upload…")
            guard let upload = anObject as? Upload else { return }
            updateCellOfUpload(upload)

        @unknown default:
            fatalError("UploadManager: unknown NSFetchedResultsChangeType")
        }
    }

    func updateNberOfUploadsToComplete() {
        // Update value
        nberOfUploadsToComplete = uploads.fetchedObjects?.count ?? 0
        // Update badge and default album view button
        DispatchQueue.main.async { [unowned self] in
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : self.nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
    }
    
    // Update cell displaying an upload request
    func updateCellOfUpload(_ upload: Upload) {
        // Background task?
        if isExecutingBackgroundUploadTask { return }
        
        // Update UploadQueue cell and button shown in root album (or default album)
        DispatchQueue.main.async {
            let uploadInfo: [String : Any] = ["localIdentifier" : upload.localIdentifier,
                                              "stateLabel"      : upload.stateLabel,
                                              "stateError"      : upload.requestError,
                                              "photoMaxSize"    : upload.photoMaxSize]
            NotificationCenter.default.post(name: .pwgUploadChangedState,
                                            object: nil, userInfo: uploadInfo)
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Update badge and default album view button
        updateNberOfUploadsToComplete()
    }
}
