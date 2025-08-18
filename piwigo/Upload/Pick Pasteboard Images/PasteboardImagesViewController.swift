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
import piwigoKit
import uploadKit

class PasteboardImagesViewController: UIViewController, UIScrollViewDelegate {
    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    // MARK: - Core Data Providers
    lazy var uploadProvider: UploadProvider = {
        let provider = UploadProvider.shared
        return provider
    }()
    
    lazy var fetchUploadRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves only non-completed upload requests
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.username))
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
    weak var albumDelegate: AlbumViewControllerDelegate?
    var reUploadAllowed = false

    let pendingOperations = PendingOperations()     // Operations in queue for preparing files and cache
    var indexedUploadsInQueue = [(String?,String?,pwgUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    lazy var imageCellSize: CGSize = getImageCellSize()

    var selectedImages = [UploadProperties?]()      // Array of images selected for upload
    var sectionState: SelectButtonState = .none     // To remember the state of the section
    var imagesBeingTouched = [IndexPath]()          // Array of indexPaths of touched images
    var uploadRequests = [UploadProperties]()       // Array of images to upload

    // Collection of images in the pasteboard
    var pbObjects = [PasteboardObject]()            // Objects in pasteboard
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
    var legendLabel = UILabel()                         // Legend presented in the toolbar on iPhone
    var legendBarItem: UIBarButtonItem!


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Collection view — Register the cell before using it
        collectionFlowLayout?.scrollDirection = .vertical
        collectionFlowLayout?.sectionHeadersPinToVisibleBounds = true
        localImagesCollection?.register(UINib(nibName: "LocalImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "LocalImageCollectionViewCell")
        localImagesCollection?.accessibilityIdentifier = "Pasteboard"
        
        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        do {
            try uploads.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }

        // Retrieve pasteboard object indexes and types, then create identifiers
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {

            // Initialise cached indexed uploads
            pbObjects = []
            selectedImages = .init(repeating: nil, count: indexSet.count)
            indexedUploadsInQueue = .init(repeating: nil, count: indexSet.count)

            // Get date of retrieve
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            let pbDateTime = dateFormatter.string(from: Date())

            // Loop over all pasteboard objects
            /// Pasteboard images are identified with identifiers of the type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#" where:
            /// - "Clipboard" is a header telling that the image/video comes from the pasteboard
            /// - "yyyyMMdd-HHmmssSSSS" is the date at which the objects were retrieved
            /// - "typ" is "img" or "mov" depending on the nature of the object
            /// - "#" is the index of the object in the pasteboard
            for idx in indexSet {
                let indexSet = IndexSet(integer: idx)
                var identifier = ""
                // Movies first because movies may contain images
                if UIPasteboard.general.contains(pasteboardTypes: [UTType.movie.identifier], inItemSet: indexSet) {
                    identifier = String(format: "%@%@%@%ld", UploadManager.shared.kClipboardPrefix,
                                        pbDateTime, UploadManager.shared.kMovieSuffix, idx)
                } else {
                    identifier = String(format: "%@%@%@%ld", UploadManager.shared.kClipboardPrefix,
                                        pbDateTime, UploadManager.shared.kImageSuffix, idx)
                }
                let newObject = PasteboardObject(identifier: identifier, types: types[idx])
                pbObjects.append(newObject)
                
                // Retrieve data, store in Upload folder and update cache
                startOperations(for: newObject, at: IndexPath(item: idx, section: 0))
            }
        }

        // At start, there is no image selected
        selectedImages = .init(repeating: nil, count: pbObjects.count)
        
        // Navigation bar
        navigationController?.toolbar.tintColor = PwgColor.orange
        navigationController?.navigationBar.accessibilityIdentifier = "PasteboardImagesNav"

        // The cancel button is used to cancel the selection of images to upload (left side of navigation bar)
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton.accessibilityIdentifier = "Cancel"
        
        // The upload button is available after having selecting images
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        uploadBarButton.isEnabled = false
        uploadBarButton.accessibilityIdentifier = "Upload"
        
        // Configure toolbar
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Title
            title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")

            // Presents the number of photos selected and the Upload button in the toolbar
            navigationController?.isToolbarHidden = false
            legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            // Title
            title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
        }
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = PwgColor.background

        // Navigation bar appearance
        let navigationBar = navigationController?.navigationBar
        navigationController?.view.backgroundColor = PwgColor.background
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = PwgColor.orange

        let attributes = [
            NSAttributedString.Key.foregroundColor: PwgColor.whiteCream,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationBar?.titleTextAttributes = attributes
        navigationBar?.prefersLargeTitles = false

        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithTransparentBackground()
        barAppearance.backgroundColor = PwgColor.background.withAlphaComponent(0.9)
        barAppearance.titleTextAttributes = attributes
        navigationItem.standardAppearance = barAppearance
        navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
        navigationItem.scrollEdgeAppearance = barAppearance
        navigationBar?.prefersLargeTitles = false

        // Toolbar
        legendLabel.textColor = PwgColor.text
        legendBarItem = UIBarButtonItem(customView: legendLabel)
        toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
        navigationController?.toolbar.barTintColor = PwgColor.background
        navigationController?.toolbar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default

        // Collection view
        localImagesCollection.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        localImagesCollection.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Update navigation bar and title
        updateNavBar()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: Notification.Name.pwgUploadProgress, object: nil)
        
        // Register app becoming active for updating the pasteboard
        NotificationCenter.default.addObserver(self, selector: #selector(checkPasteboard),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)

        // Prevent device from sleeping if uploads are in progress
        let uploading: [pwgUploadState] = [.waiting, .preparing, .prepared,
                                           .uploading, .uploaded, .finishing]
        let uploadsToPerform = (uploads.fetchedObjects ?? [])
            .map({uploading.contains($0.state) ? 1 : 0}).reduce(0, +)
        if uploadsToPerform > 0 {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
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

        // Resume upload operations in background queue
        // and update badge and upload button of album navigator
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.isPaused = false
            UploadManager.shared.isExecutingBackgroundUploadTask = false
            UploadManager.shared.findNextImageToUpload()
        }
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
        
        // Disable button
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        guard let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController
        else { preconditionFailure("Could not load UploadSwitchViewController") }
        
        uploadSwitchVC.delegate = self
        uploadSwitchVC.user = user
        uploadSwitchVC.canDeleteImages = false
        uploadSwitchVC.categoryCurrentCounter = categoryCurrentCounter

        // Push Edit view embedded in navigation controller
        let navController = UINavigationController(rootViewController: uploadSwitchVC)
        navController.modalPresentationStyle = .popover
        navController.modalTransitionStyle = .coverVertical
        navController.popoverPresentationController?.sourceView = localImagesCollection
        navController.popoverPresentationController?.barButtonItem = uploadBarButton
        navController.popoverPresentationController?.permittedArrowDirections = .up
        navigationController?.present(navController, animated: true)
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
