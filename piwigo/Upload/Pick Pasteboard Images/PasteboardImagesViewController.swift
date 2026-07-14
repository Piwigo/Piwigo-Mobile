//
//  PasteboardImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 6 December 2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import MobileCoreServices
import Photos
import UIKit
import PwgKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

final class PasteboardImagesViewController: UIViewController, UIScrollViewDelegate {
    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    lazy var fetchUploadRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves only non-completed upload requests
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.user))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        return fetchRequest
    }()

    public lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchUploadRequest,
                                                 managedObjectContext: self.mainContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil)
        uploads.delegate = self
        return uploads
    }()
    

    // MARK: - Variables and Cached Values
    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var categoryCurrentCounter: Int64 = UploadVars.shared.categoryCounterInit
    weak var albumDelegate: (any AlbumViewControllerDelegate)?
    var reUploadAllowed = false

    let pendingOperations = PendingOperations()     // Operations in queue for preparing files and cache
    var indexedUploadsInQueue = [(String?,String?,pwgUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    lazy var imageCellSize: CGSize = getImageCellSize()

    var selectedImages = [UploadProperties?]()      // Array of images selected for upload
    var sectionState: SelectButtonState = .none     // To remember the state of the section
    var imagesBeingTouched = [IndexPath]()          // Array of indexPaths of touched images
    var uploadRequests = [UploadProperties]()       // Array of upload requests

    // Collection of images in the pasteboard
    var pbObjects = [PasteboardObject]()            // Objects in pasteboard
    var pbChangeCount = -1                          // Pasteboard change count at last retrieve
    lazy var pasteboardTypes : [String] = {
        return [UTType.image.identifier, UTType.movie.identifier]
    }()
    
    
    // MARK: - View
    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
        
    // Buttons
    var cancelBarButton: UIBarButtonItem!               // For cancelling the selection of images
    var uploadBarButton: UIBarButtonItem!               // for uploading selected images
    var actionBarButton: UIBarButtonItem!               // For allowing to re-upload images


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Collection view — Register the cell before using it
        collectionFlowLayout?.scrollDirection = .vertical
        localImagesCollection?.register(UINib(nibName: "LocalImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "LocalImageCollectionViewCell")
        localImagesCollection?.accessibilityIdentifier = "Pasteboard"
        if #available(iOS 26.0, *) {
            collectionFlowLayout?.sectionHeadersPinToVisibleBounds = false
        } else {
            collectionFlowLayout?.sectionHeadersPinToVisibleBounds = true
        }
        
        // Pan gesture for selecting a series of images by swiping over the cells
        // (gestureRecognizerShouldBegin restricts it to horizontal pans,
        // so it does not interfere with the vertical scrolling)
        let imageSeriesRecognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRecognizer.minimumNumberOfTouches = 1
        imageSeriesRecognizer.maximumNumberOfTouches = 1
        imageSeriesRecognizer.cancelsTouchesInView = false
        imageSeriesRecognizer.delegate = self
        localImagesCollection?.addGestureRecognizer(imageSeriesRecognizer)
        
        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        do {
            try uploads.performFetch()
        } catch {
            debugPrint("Error: \(error.localizedDescription)")
        }
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "PasteboardImagesNav"
        
        // The cancel button is used to cancel the selection of images to upload (left side of navigation bar)
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton.accessibilityIdentifier = "Cancel"
        
        // The upload button is available after having selecting images
        if #available(iOS 17.0, *) {
            uploadBarButton = UIBarButtonItem(image: UIImage(systemName: "arrowshape.up.fill"),
                                              style: .plain, target: self, action: #selector(didTapUploadButton))
        } else {
            // Fallback on previous version
            uploadBarButton = UIBarButtonItem(image: UIImage(named: "arrowshape.up.fill"),
                                              style: .plain, target: self, action: #selector(didTapUploadButton))
        }
        uploadBarButton.isEnabled = false
        uploadBarButton.accessibilityIdentifier = "Upload"
        
        // Title
        title = String(localized: "categoryUpload_pasteboard", comment: "Clipboard")

        // Retrieve pasteboard objects, store them in the Uploads directory
        // and refresh the collection view (must be called after the creation of the bar buttons)
        checkPasteboard()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)

        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: Notification.Name.pwgUploadProgress, object: nil)

        // Register app becoming active for updating the pasteboard
        NotificationCenter.default.addObserver(self, selector: #selector(checkPasteboard),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = PwgColor.background

        // Navigation bar appearance
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Collection view
        localImagesCollection.indicatorStyle = InterfaceVars.shared.isDarkPaletteActive ? .white : .black
        localImagesCollection.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Update navigation bar and title
        updateNavBar()

        // Prevent device from sleeping if uploads are in progress before iOS 26
        if #unavailable(iOS 26.0) {
            UIApplication.shared.isIdleTimerDisabled = (UploadVars.shared.nberOfUploadsToComplete > 0)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if localImagesCollection.visibleCells.count > 0,
           let cell = localImagesCollection.visibleCells.first {
            if let indexPath = localImagesCollection.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { [self] _ in
                    self.updateNavBar()
                    self.imageCellSize = self.getImageCellSize()
                    self.localImagesCollection.reloadData()

                    // Scroll to previous position
                    self.localImagesCollection.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
                })
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cancel operations if needed
        pendingOperations.preparationQueue.cancelAllOperations()

        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Show Upload Options
    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        uploadRequests = selectedImages.compactMap({ $0 })
        if uploadRequests.isEmpty { return }

        // Show upload parameter views
        presentUploadOptions()
    }

    /// Presents the upload parameter views for the requests stored in "uploadRequests"
    func presentUploadOptions() {
        // Disable buttons
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false

        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
        else { preconditionFailure("Could not load UploadSwitchViewController") }
        
        uploadSwitchVC.delegate = self
        uploadSwitchVC.user = self.user
        uploadSwitchVC.categoryId = self.categoryId
        uploadSwitchVC.categoryCurrentCounter = self.categoryCurrentCounter
        uploadSwitchVC.canDeleteImages = false
        uploadSwitchVC.uploadRequests = self.uploadRequests
        
        // Push Edit view embedded in navigation controller
        let navController = UINavigationController(rootViewController: uploadSwitchVC)
        #if targetEnvironment(macCatalyst)
        navController.modalPresentationStyle = .formSheet
        navController.modalTransitionStyle = .coverVertical
        #else
        navController.modalPresentationStyle = .popover
        navController.modalTransitionStyle = .coverVertical
        navController.popoverPresentationController?.sourceView = view
        navController.popoverPresentationController?.barButtonItem = uploadBarButton
        navController.popoverPresentationController?.permittedArrowDirections = .up
        #endif
        present(navController, animated: true)
    }
}


// MARK: - Video Poster
extension AVURLAsset {
    func extractedImage() -> UIImage! {
        var image: UIImage = pwgImageType.image.placeHolder
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            image = UIImage(cgImage: try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil))
        } catch {
            // Could not extract frame => placeholder
        }
        return image
    }
}
