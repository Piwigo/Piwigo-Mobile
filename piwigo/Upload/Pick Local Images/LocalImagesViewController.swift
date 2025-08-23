//
//  LocalImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25 March 2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 18/04/2020
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit

enum SectionType: Int {
    case month
    case week
    case day
    case none
}

class LocalImagesViewController: UIViewController
{
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

        // Retrieves upload requests
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
    let queue = OperationQueue()                    // Queue used to sort and cache things
    var fetchedImages: PHFetchResult<PHAsset>!      // Collection of images in selected non-empty local album
    var sortType: SectionType = .none               // Images grouped by Day, Week, Month or None
    var indexOfImageSortedByMonth: [IndexSet] = []  // Indices of images sorted by month
    var indexOfImageSortedByWeek: [IndexSet] = []   // Indices of images sorted week
    var indexOfImageSortedByDay: [IndexSet] = []    // Indices of images sorted day

    var indexedUploadsInQueue = [(String,pwgUploadState,Bool)?]()  // Arrays of uploads at indices of fetched image
    var selectedImages = [UploadProperties?]()      // Array of images selected for upload
    var selectedSections = [SelectButtonState]()    // State of Select buttons
    var imagesBeingTouched = [IndexPath]()          // Array of indexPaths of touched images
    var uploadRequests = [UploadProperties]()       // Array of images to upload

    var uploadsToDelete = [Upload]()
    lazy var imageCellSize: CGSize = getImageCellSize()
    

    // MARK: - View
    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var categoryCurrentCounter: Int64 = UploadVars.shared.categoryCounterInit
    weak var albumDelegate: AlbumViewControllerDelegate?
    var imageCollectionId: String = String()

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
    
    var cancelBarButton: UIBarButtonItem!           // For cancelling the selection of images
    var uploadBarButton: UIBarButtonItem!           // for uploading selected images
    var trashBarButton: UIBarButtonItem!            // For deleting uploaded images on iPad
    var actionBarButton: UIBarButtonItem!           // on iPhone:
                                                    //  - for reversing the sort order
                                                    //  - for grouping by day, week or month (or not)
                                                    //  - for deleting uploaded images
                                                    //  - for selecting images in the Photo Library
                                                    //  - for allowing to re-upload images
                                                    // on iPad:
                                                    //  - for reversing the sort order
                                                    //  - for grouping by day, week or month (or not)
                                                    //  - for selecting images in the Photo Library
                                                    //  - for allowing to re-upload images
    var legendLabel = UILabel()                     // Legend presented in the toolbar on iPhone
    var legendBarItem: UIBarButtonItem!

    var reUploadAllowed = false


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Collection view - Register the cell before using it
        collectionFlowLayout?.scrollDirection = .vertical
        localImagesCollection?.register(UINib(nibName: "LocalImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "LocalImageCollectionViewCell")
        localImagesCollection?.accessibilityIdentifier = "CameraRoll"
        if #available(iOS 26.0, *) {
            collectionFlowLayout?.sectionHeadersPinToVisibleBounds = false
        } else {
            collectionFlowLayout?.sectionHeadersPinToVisibleBounds = true
        }

        // Check collection Id
        if imageCollectionId.count == 0 {
            PhotosFetch.shared.showPhotosLibraryAccessRestricted(in: self)
        }

        // Fetch a specific path of the Photo Library to reduce the workload
        // and store the fetched assets for future use
        fetchImagesByCreationDate()
        
        // At start, there is no image selected
        selectedImages = .init(repeating: nil, count: fetchedImages.count)
        selectedSections = .init(repeating: .none, count: fetchedImages.count)
        
        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        do {
            try uploads.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }
                                                                                        
        // Sort images in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.sortImagesAndIndexUploads()
        }
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "LocalImagesNav"

        // The cancel button is used to cancel the selection of images to upload
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton.accessibilityIdentifier = "Cancel"
        
        // The upload button is available after having selecting images
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"),
                                          style: .done, target: self, action: #selector(didTapUploadButton))
        uploadBarButton.tintColor = PwgColor.orange
        uploadBarButton.isEnabled = false
        uploadBarButton.accessibilityIdentifier = "Upload"
        
        // The action button proposes:
        /// - to swap between ascending and descending sort orders,
        /// - to choose one of the 4 grouping options,
        /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library,
        /// - to allow/disallow re-uploading photos,
        /// - and to delete photos already uploaded to the Piwigo server on iPhone only.
        var children: [UIMenuElement?] = [swapOrderAction(), groupMenu(),
                                          selectPhotosMenu(), reUploadAction()]
        if UIDevice.current.userInterfaceIdiom == .phone {
            children.append(deleteMenu())
        }
        let menu = UIMenu(title: "", children: children.compactMap({$0}))
        if #available(iOS 26.0, *) {
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)
        } else {
            // Fallback on previous version
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // The deletion of photos already uploaded to a Piwigo server is performed with this trash button.
            trashBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteUploadedImages))
            trashBarButton.isEnabled = false
        } else {
            // Presents the number of photos selected and the Upload button in the toolbar
            navigationController?.isToolbarHidden = false
            legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
        }
        actionBarButton.accessibilityIdentifier = "Action"
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = PwgColor.background

        // Navigation bar appearance
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

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

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: Notification.Name.pwgUploadProgress, object: nil)
        
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
                // Reload collection with appropriate cell sizes
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
        queue.cancelAllOperations()

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
        // Unregister Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}
