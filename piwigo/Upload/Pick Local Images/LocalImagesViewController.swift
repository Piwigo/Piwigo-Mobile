//
//  LocalImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25 March 2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 18/04/2020
//

import Photos
import UIKit
import piwigoKit

enum SectionType: Int {
    case month
    case week
    case day
    case all
}

@objc
class LocalImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, LocalImagesHeaderDelegate, UploadSwitchDelegate {
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    

    // MARK: - View
    @objc func setCategoryId(_ categoryId: Int) {
        _categoryId = categoryId
    }
    private var _categoryId: Int?
    private var categoryId: Int {
        get {
            return _categoryId ?? AlbumVars.shared.defaultCategory
        }
        set(categoryId) {
            _categoryId = categoryId
        }
    }

    @objc func setImageCollectionId(_ imageCollectionId: String) {
        _imageCollectionId = imageCollectionId
    }
    private var _imageCollectionId: String?
    private var imageCollectionId: String {
        get {
            return _imageCollectionId ?? String()
        }
        set(imageCollectionId) {
            _imageCollectionId = imageCollectionId
        }
    }

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var sortOptionsView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private let queue = OperationQueue()                        // Queue used to sort and cache things
    private var fetchedImages: PHFetchResult<PHAsset>!          // Collection of images in selected non-empty local album
    private var sortType: SectionType = .all                    // [Months, Weeks, Days, All images in one section]
    private var indexOfImageSortedByMonth: [IndexSet] = []      // Indices of images sorted by month
    private var indexOfImageSortedByWeek: [IndexSet] = []       // Indices of images sorted week
    private var indexOfImageSortedByDay: [IndexSet] = []        // Indices of images sorted day

    private var uploadsInQueue = [(String,kPiwigoUploadState)?]()         // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String,kPiwigoUploadState,Bool)?]()  // Arrays of uploads at indices of fetched image
    private var selectedImages = [UploadProperties?]()                         // Array of images to upload
    private var selectedSections = [SelectButtonState]()                       // State of Select buttons
    private var imagesBeingTouched = [IndexPath]()                             // Array of indexPaths of touched images
    
    private var uploadIDsToDelete = [NSManagedObjectID]()
    private var imagesToDelete = [String]()
    
    private var cancelBarButton: UIBarButtonItem!       // For cancelling the selection of images
    private var uploadBarButton: UIBarButtonItem!       // for uploading selected images
    private var trashBarButton: UIBarButtonItem!        // For deleting uploaded images on iPhone until iOS 13
                                                        //                              on iPad (all iOS)
    private var actionBarButton: UIBarButtonItem!       // iPhone until iOS 13:
                                                        //  - for reversing the sort order
                                                        // iPhone as from iOS 14:
                                                        //  - for reversing the sort order
                                                        //  - for sorting by day, week or month (or not)
                                                        //  - for deleting uploaded images
                                                        //  - for selecting images in the Photo Library
                                                        // iPad until iOS 13:
                                                        //  - for reversing the sort order
                                                        // iPad as from iOS 14:
                                                        //  - for reversing the sort order
                                                        //  - for sorting by day, week or month (or not)
                                                        //  - for selecting images in the Photo Library
    private var legendLabel = UILabel()                 // Legend presented in the toolbar on iPhone/iOS 14+
    private var legendBarItem: UIBarButtonItem!

    private var reUploadAllowed = false
    private var hudViewController: UIViewController?


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true

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
        if let uploads = uploadsProvider.fetchedResultsController.fetchedObjects {
            uploadsInQueue = uploads.map {($0.localIdentifier, $0.state)}
        }
                                                                                        
        // Sort images in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.sortImagesAndIndexUploads()
        }
        
        // Collection flow layout of images
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.sectionHeadersPinToVisibleBounds = true

        // Collection view identifier
        localImagesCollection.accessibilityIdentifier = "CameraRoll"
        
        // Navigation bar
        navigationController?.toolbar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.accessibilityIdentifier = "LocalImagesNav"

        // The cancel button is used to cancel the selection of images to upload
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton.accessibilityIdentifier = "Cancel"
        
        // The upload button is available after having selecting images
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        uploadBarButton.isEnabled = false
        uploadBarButton.accessibilityIdentifier = "Upload"
        
        // Configure menus, segmented control, etc.
        if #available(iOS 14, *) {
            // Hide the segmented control
            sortOptionsView.isHidden = true

            // The action button proposes:
            /// - to swap between ascending and descending sort orders,
            /// - to choose one of the 4 sort options,
            /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library (iOS 14+),
            /// - to allow/disallow  re-uploading photos,
            /// - and to delete photos already uploaded to the Piwigo server on iPhone only.
            let menu = UIMenu(title: "", children: [getMenuForSorting(),
                                                    getMenuForSelectingPhotos(),
                                                    getMenuForDeletingPhotos()].compactMap({$0}))
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)

            if UIDevice.current.userInterfaceIdiom == .pad {
                // The deletion of photos already uploaded to a Piwigo server is performed with this trash button.
                trashBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteUploadedImages))
                trashBarButton.isEnabled = false
            } else {
                // Presents the number of photos selected and the Upload button in the toolbar
                navigationController?.isToolbarHidden = false
                legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
            }
        } else {
            // Fallback on earlier versions.
            // The action button simply proposes to swap between the two following sort options:
            ///     • "Date Created: old -> new"
            ///     • "Date Created: new -> old"
            /// It is presented with an icon which changes with the available option.
            actionBarButton = UIBarButtonItem(image: getSwapSortImage(),
                                              landscapeImagePhone: getSwapSortCompactImage(),
                                              style: .plain, target: self, action: #selector(self.swapSortOrder))
            actionBarButton.isEnabled = false

            // The deletion of photos already uploaded to a Piwigo server is requested with this trash button.
            trashBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(self.deleteUploadedImages))
            trashBarButton.isEnabled = false

            // The sort options are presented in a segmented bar on iPhone & iPad.
            // Segmented control (choice for presenting images by month, week, day or in a single collection)
            if #available(iOS 13.0, *) {
                segmentedControl.selectedSegmentTintColor = .piwigoColorOrange()
            } else {
                segmentedControl.tintColor = .piwigoColorOrange()
            }
            segmentedControl.selectedSegmentIndex = Int(sortType.rawValue)
            segmentedControl.setEnabled(false, forSegmentAt: SectionType.month.rawValue)
            segmentedControl.setEnabled(false, forSegmentAt: SectionType.week.rawValue)
            segmentedControl.setEnabled(false, forSegmentAt: SectionType.day.rawValue)
            segmentedControl.superview?.layer.cornerRadius = segmentedControl.layer.cornerRadius
            segmentedControl.accessibilityIdentifier = "sort";
        }
        actionBarButton.accessibilityIdentifier = "Action"
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()
        sortOptionsView.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Segmented control
        if #available(iOS 14, *) {
            // Toolbar
            legendLabel.textColor = .piwigoColorText()
            legendBarItem = UIBarButtonItem(customView: legendLabel)
            toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
            navigationController?.toolbar.barTintColor = .piwigoColorBackground()
            navigationController?.toolbar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        }
        else {
            // Fallback on earlier versions
            // Segmented control
            segmentedControl.superview?.backgroundColor = .piwigoColorBackground().withAlphaComponent(0.8)
            if #available(iOS 13.0, *) {
                // Keep standard background color
                segmentedControl.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
            } else {
                segmentedControl.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.08, alpha: 0.06666)
            }
        }

        // Collection view
        localImagesCollection.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        localImagesCollection.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true

        // Set colors, fonts, etc.
        applyColorPalette()

        // Update navigation bar and title
        updateNavBar()

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
        
        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: .pwgUploadProgress, object: nil)
        
        // Prevent device from sleeping if uploads are in progress
        let uploading: Array<kPiwigoUploadState> = [.waiting, .preparing, .prepared,
                                                    .uploading, .uploaded, .finishing]
        let uploadsToPerform:Int = uploadsProvider.fetchedResultsController
            .fetchedObjects?.map({ uploading.contains($0.state) ? 1 : 0}).reduce(0, +) ?? 0
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
                coordinator.animate(alongsideTransition: { context in
                    self.updateNavBar()
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

        // Restart UploadManager activities
        if UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }
    
    deinit {
        // Unregister Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
        
        // Unregister upload progress
        NotificationCenter.default.removeObserver(self, name: .pwgUploadProgress, object: nil)
    }

    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
        case 0:
            // Buttons
            cancelBarButton.isEnabled = false
            actionBarButton.isEnabled = (queue.operationCount == 0)
            uploadBarButton.isEnabled = false

            // Display "Back" button on the left side
            navigationItem.leftBarButtonItems = []

            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                if #available(iOS 14, *) {
                    // Presents a single action menu
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                    
                    // Present the "Upload" button in the toolbar
                    legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                    legendBarItem = UIBarButtonItem(customView: legendLabel)
                    toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
                } else {
                    // Title
                    title = NSLocalizedString("selectImages", comment: "Select Photos")

                    // Present buttons according to the context
                    if canDeleteUploadedImages() {
                        trashBarButton.isEnabled = true
                        navigationItem.rightBarButtonItems = [actionBarButton, trashBarButton].compactMap { $0 }
                    } else {
                        trashBarButton.isEnabled = false
                        var orientation: UIInterfaceOrientation = .portrait
                        if #available(iOS 13.0, *) {
                            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                        } else {
                            orientation = UIApplication.shared.statusBarOrientation
                        }
                        if orientation.isLandscape {
                            navigationItem.rightBarButtonItems = [actionBarButton, trashBarButton].compactMap { $0 }
                        } else {
                            navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                        }
                    }
                }
            }
        
        default:
            // Buttons
            cancelBarButton.isEnabled = true
            actionBarButton.isEnabled = (queue.operationCount == 0)
            uploadBarButton.isEnabled = true

            // Display "Cancel" button on the left side
            navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }

            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                if #available(iOS 14, *) {
                    // Update the number of selected photos in the toolbar
                    legendLabel.text = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                    legendBarItem = UIBarButtonItem(customView: legendLabel)
                    toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]

                    // Presents a single action menu
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                } else {
                    // Update the number of selected photos in the navigation bar
                    title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

                    // Presents a single action menu
                    navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                }
            }
        }

        // Set buttons on the right side on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Update the number of selected photos in the navigation bar
            title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

            if canDeleteUploadedImages() {
                trashBarButton.isEnabled = true
                navigationItem.rightBarButtonItems = [uploadBarButton,
                                                      actionBarButton,
                                                      trashBarButton].compactMap { $0 }
            } else {
                trashBarButton.isEnabled = false
                navigationItem.rightBarButtonItems = [uploadBarButton,
                                                      actionBarButton].compactMap { $0 }
            }
        }
    }
    
    private func updateActionButton() {
        // Change button icon or content
        if #available(iOS 14, *) {
            // Update action button
            // The action button proposes:
            /// - to swap between ascending and descending sort orders,
            /// - to choose one of the 4 sort options
            /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library (iOS 14+),
            /// - to allow/disallow re-uploading photos,
            /// - to delete photos already uploaded to the Piwigo server on iPhone only.
            actionBarButton.menu = UIMenu(title: "", children: [getMenuForSorting(),
                                                                getMenuForSelectingPhotos(),
                                                                getMenuForDeletingPhotos()].compactMap({$0}))
        } else {
            // Fallback on earlier versions.
            // The action button simply proposes to swap between the two following sort options:
            ///     • "Date Created: old -> new"
            ///     • "Date Created: new -> old"
            /// It is presented with an icon which changes with the available option.
            actionBarButton = UIBarButtonItem(image: getSwapSortImage(),
                                              landscapeImagePhone: getSwapSortCompactImage(),
                                              style: .plain, target: self, action: #selector(self.swapSortOrder))
        }
    }

    
    // MARK: - Fetch and Sort Images
    
    func fetchImagesByCreationDate() -> Void {
        /**
         Fetch non-empty collection previously selected by user.
         We fetch a specific path of the Photo Library to reduce the workload and store the fetched collection for future use.
         The fetch is performed with ascending creation date.
         */
        // Next line for testing
//        let start = CFAbsoluteTimeGetCurrent()

        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Fetch image collection
        let assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil)
        
        // Display album name on iPhone as from iOS 14
        if #available(iOS 14.0, *), UIDevice.current.userInterfaceIdiom == .phone {
            title = assetCollections.firstObject!.localizedTitle
        }
        
        // Fetch images in album
        fetchedImages = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)

        // Next 2 lines for testing
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Fetched \(fetchedImages.count) assets in \(diff) ms")
        // => Fetched 70331 assets in 205.949068069458 ms with hidden assets
        // => Fetched 70331 assets in 216.99798107147217 ms with option "includeHiddenAssets = false"
    }
    
    // Sorts images by months, weeks and days in the background,
    // initialise the array of selected sections and enable the choices
    private func sortImagesAndIndexUploads() -> Void {

        // Operations are organised to reduce time
        // Sort 70588 images by days, weeks and months in 5.2 to 6.7 s with iPhone 11 Pro
        // The above duration is multiplied by 4 when the iPhone is not powered.
        // and index 70588 uploads in about the same if there is no upload request already stored.
        // but index 70588 uploads in 69.1 s if there are already 520 stored upload requests

        // Sort all images in one loop i.e. O(n)
        let sortOperation = BlockOperation(block: {
            self.indexOfImageSortedByDay = []
            self.indexOfImageSortedByWeek = []
            self.indexOfImageSortedByMonth = []
            if self.fetchedImages.count > 0 {
                // Sort images by months, weeks and days in the background
                if self.selectedImages.compactMap({$0}).isEmpty {
                    self.sortByMonthWeekDay(images: self.fetchedImages)
                } else {
                    self.sortByMonthWeekDayAndUpdateSelection(images: self.fetchedImages)
                }
            } else {
                self.selectedImages = []
                self.selectedSections = [.none]
            }
        })
        sortOperation.completionBlock = {
            // Allow sort options and refresh section headers
            DispatchQueue.main.async {
                if #available(iOS 14, *) {
                    // NOP
                } else {
                    // Enable segments
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.month.rawValue)
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.week.rawValue)
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.day.rawValue)
                    self.segmentedControl.selectedSegmentIndex = Int(self.sortType.rawValue)
                }
            }
        }
        
        // Caching upload request indices
        let cacheOperation = BlockOperation()
        if fetchedImages.count > 10 * uploadsInQueue.count {
            // By iterating uploads in queue
            cacheOperation.addExecutionBlock {
                self.cachingUploadIndicesIteratingUploadsInQueue()
            }
        } else {
            // By iterating fetched images
            cacheOperation.addExecutionBlock {
                self.cachingUploadIndicesIteratingFetchedImages()
            }
        }

        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = .max   // Make it a serial queue for debugging with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([sortOperation, cacheOperation], waitUntilFinished: true)

        // Hide HUD when Photo Library motifies changes
        DispatchQueue.main.async {
            if self.isShowingPiwigoHUD() {
                self.updatePiwigoHUDwithSuccess {
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                        self.didFinishSorting()
                        self.localImagesCollection.reloadData()
                    }
                }
            } else {
                self.didFinishSorting()
            }
        }
    }
    
    private func didFinishSorting() {
        // Enable Select buttons
        self.updateActionButton()
        self.updateNavBar()

        // Restart UplaodManager activity if all images are already in the upload queue
        if self.indexedUploadsInQueue.compactMap({$0}).count == self.fetchedImages.count,
           UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    private func sortByMonthWeekDay(images: PHFetchResult<PHAsset>) -> (Void)  {

        // Empty selection, re-initialise cache for managing selected images
        selectedImages = .init(repeating: nil, count: images.count)

        // Initialisation
        let start = CFAbsoluteTimeGetCurrent()
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images[0].creationDate ?? Date())
        var firstIndexOfSameDay = 0

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images[0].creationDate ?? Date())
        var firstIndexOfSameWeek = 0

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images[0].creationDate ?? Date())
        var firstIndexOfSameMonth = 0
        
        // Sort imageAssets
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = images.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop first operation in iteration \(i) ;-)")
                indexOfImageSortedByDay = [IndexSet]()
                indexOfImageSortedByWeek = [IndexSet]()
                indexOfImageSortedByMonth = [IndexSet]()
                return
            }

            for index in i*step..<min((i+1)*step,images.count) {
                // Get day of current image
                let creationDate = images[index].creationDate ?? Date()
                let newDayComponents = calendar.dateComponents(byDays, from: creationDate)

                // Image taken the same day?
                if newDayComponents == dayComponents {
                    // Same date -> Next image
                    continue
                } else {
                    // Append section to collection by days
                    indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<index))

                    // Initialise for next day
                    firstIndexOfSameDay = index
                    dayComponents = calendar.dateComponents(byDays, from: creationDate)

                    // Get week of year of new image
                    let newWeekComponents = calendar.dateComponents(byWeeks, from: creationDate)

                    // What should we do with this new image?
                    if newWeekComponents != weekComponents {
                        // Append section to collection by weeks
                        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<index))

                        // Initialise for next week
                        firstIndexOfSameWeek = index
                        weekComponents = newWeekComponents
                    }

                    // Get month of new image
                    let newMonthComponents = calendar.dateComponents(byMonths, from: creationDate)

                    // What should we do with this new image?
                    if newMonthComponents != monthComponents {
                        // Append section to collection by months
                        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<index))

                        // Initialise for next month
                        firstIndexOfSameMonth = index
                        monthComponents = newMonthComponents
                    }
                }
            }
        }

        // Append last section to collection
        indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<images.count))
        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<images.count))
        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<images.count))
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   sorted \(fetchedImages.count) images by days, weeks and months in \(diff) ms")
    }
    
    private func sortByMonthWeekDayAndUpdateSelection(images: PHFetchResult<PHAsset>) -> (Void)  {

        // Store current selection and re-select images after data source change
        let oldSelection = selectedImages.compactMap({$0})
        selectedImages = .init(repeating: nil, count: fetchedImages.count)

        // Initialisation
        let start = CFAbsoluteTimeGetCurrent()
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images[0].creationDate ?? Date())
        var firstIndexOfSameDay = 0

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images[0].creationDate ?? Date())
        var firstIndexOfSameWeek = 0

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images[0].creationDate ?? Date())
        var firstIndexOfSameMonth = 0
        
        // Sort imageAssets
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = images.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop first operation in iteration \(i) ;-)")
                indexOfImageSortedByDay = [IndexSet]()
                indexOfImageSortedByWeek = [IndexSet]()
                indexOfImageSortedByMonth = [IndexSet]()
                return
            }

            for index in i*step..<min((i+1)*step,images.count) {
                // Get localIdentifier of current image
                let imageID = images[index].localIdentifier
                if let indexOfSelection = oldSelection.firstIndex(where: {$0.localIdentifier == imageID}) {
                    selectedImages[index] = oldSelection[indexOfSelection]
                }
                
                // Get day of current image
                let creationDate = images[index].creationDate ?? Date()
                let newDayComponents = calendar.dateComponents(byDays, from: creationDate)

                // Image taken the same day?
                if newDayComponents == dayComponents {
                    // Same date -> Next image
                    continue
                } else {
                    // Append section to collection by days
                    indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<index))

                    // Initialise for next day
                    firstIndexOfSameDay = index
                    dayComponents = calendar.dateComponents(byDays, from: creationDate)

                    // Get week of year of new image
                    let newWeekComponents = calendar.dateComponents(byWeeks, from: creationDate)

                    // What should we do with this new image?
                    if newWeekComponents != weekComponents {
                        // Append section to collection by weeks
                        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<index))

                        // Initialise for next week
                        firstIndexOfSameWeek = index
                        weekComponents = newWeekComponents
                    }

                    // Get month of new image
                    let newMonthComponents = calendar.dateComponents(byMonths, from: creationDate)

                    // What should we do with this new image?
                    if newMonthComponents != monthComponents {
                        // Append section to collection by months
                        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<index))

                        // Initialise for next month
                        firstIndexOfSameMonth = index
                        monthComponents = newMonthComponents
                    }
                }
            }
        }

        // Append last section to collection
        indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<images.count))
        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<images.count))
        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<images.count))
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   sorted \(fetchedImages.count) images by days, weeks and months and updated selection in \(diff) ms")
    }
    
    // Return image index from indexPath
    private func getImageIndex(for indexPath:IndexPath) -> Int {
        switch sortType {
        case .month:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByMonth[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByMonth.endIndex - 1
                if let index = indexOfImageSortedByMonth[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .week:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByWeek[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByWeek.endIndex - 1
                if let index = indexOfImageSortedByWeek[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .day:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByDay[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByDay.endIndex - 1
                if let index = indexOfImageSortedByDay[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .all:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                return indexPath.row
            case .dateCreatedAscending:
                return max(0, fetchedImages.count - 1 - indexPath.row)
            default:
                return 0
            }
        }
    }

    private func cachingUploadIndicesIteratingFetchedImages() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()
        
        // Initialise cached indexed uploads
        indexedUploadsInQueue = .init(repeating: nil, count: fetchedImages.count)

        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000
        let iterations = fetchedImages.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                indexedUploadsInQueue = []
                print("Stop second operation in iteration \(i) ;-)")
                return
            }
            
            // Caching indexed uploads and resetting image selection
            for index in i*step..<min((i+1)*step,fetchedImages.count) {
                // Get image identifier
                let imageId = fetchedImages[index].localIdentifier
                if let upload = uploadsInQueue.first(where: { $0?.0 == imageId }) {
                    let cachedObject = (upload!.0, upload!.1, fetchedImages[index].canPerform(.delete))
                    indexedUploadsInQueue[index] = cachedObject
                }
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   indexed \(fetchedImages.count) images by iterating fetched images in \(diff) ms")
    }

    private func cachingUploadIndicesIteratingUploadsInQueue() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()
        
        // Initialise cached indexed uploads
        indexedUploadsInQueue = .init(repeating: nil, count: fetchedImages.count)

        // Determine fetched images already in upload queue
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false

        // Operation done if no stored upload requests
        if uploadsInQueue.count > 0 {
            // Check if this operation was cancelled every 100 iterations
            let step = 1_00
            let iterations = uploadsInQueue.count / step
            for i in 0...iterations {
                // Continue with this operation?
                if queue.operations.first!.isCancelled {
                    indexedUploadsInQueue = []
                    print("Stop second operation in iteration \(i) ;-)")
                    return
                }

                // Caching fetched images already in upload queue
                if i*step >= min((i+1)*step,uploadsInQueue.count) { break }
                for index in i*step..<min((i+1)*step,uploadsInQueue.count) {
                    // Get image identifier
                    if index < uploadsInQueue.count, let imageId = uploadsInQueue[index]?.0 {
                        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", imageId)
                        if let asset = PHAsset.fetchAssets(with: fetchOptions).firstObject {
                            let idx = fetchedImages.index(of: asset)
                            if idx != NSNotFound {
                                let cachedObject = (imageId, uploadsInQueue[index]!.1, asset.canPerform(.delete))
                                if idx >= indexedUploadsInQueue.count {
                                    let newElements:[(String,kPiwigoUploadState,Bool)?] = .init(repeating: nil, count: indexedUploadsInQueue.count + 1 - idx)
                                    indexedUploadsInQueue.append(contentsOf: newElements)
                                }
                            	indexedUploadsInQueue[idx] = cachedObject
                                }
						    }
					    }
				    }
        	}
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   cached \(uploadsInQueue.count) images by iterating uploads in queue in \(diff) ms")
    }
    
    private func getUploadStateOfImage(at index: Int,
                                       for cell: LocalImageCollectionViewCell) -> kPiwigoUploadState? {
        var state: kPiwigoUploadState? = nil
        if queue.operationCount == 0, index < indexedUploadsInQueue.count {
            // Indexed uploads available
            state = indexedUploadsInQueue[index]?.1
        } else {
            // Use non-indexed data (might be quite slow)
            state = uploadsInQueue.first(where: { $0?.0 == cell.localIdentifier })??.1
        }
        return state
    }

    
    // MARK: - Sort Images
    /// Icons used on iPhone and iPad on iOS 13 and earlier
    private func getSwapSortImage() -> UIImage {
        switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
        case .dateCreatedAscending:
            if #available(iOS 13.0, *) {
                return UIImage(named: "dateDescending")!
            } else {
                return UIImage(named: "dateDescendingLight")!
            }
        case .dateCreatedDescending:
            if #available(iOS 13.0, *) {
                return UIImage(named: "dateAscending")!
            } else {
                return UIImage(named: "dateAscendingLight")!
            }
        default:
            return UIImage(named: "action")!
        }
    }

    /// Icons used on iPhone and iPad on iOS 13 and earlier
    private func getSwapSortCompactImage() -> UIImage {
        switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
        case .dateCreatedAscending:
            if #available(iOS 13.0, *) {
                return UIImage(named: "dateDescendingCompact")!
            } else {
                return UIImage(named: "dateDescendingLightCompact")!
            }
        case .dateCreatedDescending:
            if #available(iOS 13.0, *) {
                return UIImage(named: "dateAscendingCompact")!
            } else {
                return UIImage(named: "dateAscendingLightCompact")!
            }
        default:
            return UIImage(named: "actionCompact")!
        }
    }

    @available(iOS 14, *)
    private func getMenuForSorting() -> UIMenu {
        // Initialise menu items
        let swapOrder: UIAction!
        switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
        case .dateCreatedAscending:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.up"), handler: { _ in self.swapSortOrder()})
        case .dateCreatedDescending:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: UIImage(systemName: "arrow.down"), handler: { _ in self.swapSortOrder()})
        default:
            swapOrder = UIAction(title: NSLocalizedString("Date", comment: "Date"),
                                 image: nil, handler: { _ in self.swapSortOrder()})
        }
        swapOrder.accessibilityIdentifier = "Date"
        let sortByDay = UIAction(title: NSLocalizedString("Days", comment: "Days"),
                                 image: UIImage(named: "imageDay"), handler: { _ in
            // Did select new sort option "Days"
            self.sortType = .day
            
            // Refresh collection (may be called from background queue)
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()
            }
        })
        sortByDay.accessibilityIdentifier = "Days"
        let sortByWeek = UIAction(title: NSLocalizedString("Weeks", comment: "Weeks"),
                                  image: UIImage(named: "imageWeek"), handler: { _ in
            // Did select new sort option "Weeks""
            self.sortType = .week
            
            // Refresh collection (may be called from background queue)
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()
            }
        })
        sortByWeek.accessibilityIdentifier = "Weeks"
        let sortByMonth = UIAction(title: NSLocalizedString("Months", comment: "Months"),
                                   image: UIImage(named: "imageMonth"), handler: { _ in
            // Did select new sort option "Months""
            self.sortType = .month
            
            // Refresh collection (may be called from background queue)
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()
            }
        })
        sortByMonth.accessibilityIdentifier = "Months"
        let noSort = UIAction(title: NSLocalizedString("All Photos", comment: "All Photos"),
                              image: nil, handler: { _ in
            // Did select new sort option "All""
            self.sortType = .all
            
            // Refresh collection (may be called from background queue)
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()
            }
        })
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.localImages.action"),
                      options: .displayInline,
                      children: [swapOrder, sortByDay, sortByWeek, sortByMonth, noSort])
    }

    @objc func swapSortOrder() {
        // Swap between the two sort options
        switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
        case .dateCreatedDescending:
            UploadVars.localImagesSort = kPiwigoSort.dateCreatedAscending.rawValue
        case .dateCreatedAscending:
            UploadVars.localImagesSort = kPiwigoSort.dateCreatedDescending.rawValue
        default:
            return
        }

        // Change button icon and refresh collection
        DispatchQueue.main.async {
            self.updateActionButton()
            self.updateNavBar()
            self.localImagesCollection.reloadData()
        }
    }
    
    @IBAction func didChangeSortOption(_ sender: UISegmentedControl) {
        // Did select new sort option [Months, Weeks, Days, All in one section]
        sortType = SectionType(rawValue: sender.selectedSegmentIndex) ?? .all
                
        // Refresh collection (may be called from background queue)
        DispatchQueue.main.async {
            // Refresh collection view
            self.localImagesCollection.reloadData()
        }
    }
        

    // MARK: - Select Camera Roll Images

    @available(iOS 14, *)
    private func getMenuForSelectingPhotos() -> UIMenu? {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            // Proposes to change the Photo Library selection
            let selector = UIAction(title: NSLocalizedString("localAlbums_accessible", comment: "Accessible Photos"),
                                    image: UIImage(systemName: "camera"), handler: { _ in
                // Proposes to change the Photo Library selection
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            })
            return UIMenu(title: "", image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.localImages.selector"),
                          options: .displayInline,
                          children: [selector])
        }
        return nil
    }
    

    // MARK: - Re-upload & Delete Camera Roll Images

    @available(iOS 14, *)
    private func getMenuForDeletingPhotos() -> UIMenu? {
        // Check if there are uploaded photos
        if let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects,
           allUploads.filter({ ($0.state == .finished) || ($0.state == .moderated) }).isEmpty {
            return nil
        }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: NSLocalizedString("localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { _ in
            self.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "Re-upload"

        // Are there uploaded photos to delete (trash icon presented on iPad)?
        if UIDevice.current.userInterfaceIdiom == .phone,
           canDeleteUploadedImages() {
            // Proposes to change the Photo Library selection
            let delete = UIAction(title: NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"),
                                  image: UIImage(systemName: "trash"), attributes: .destructive, handler: { _ in
                // Delete uploaded photos from the camera roll
                self.deleteUploadedImages()
            })
            return UIMenu(title: "", image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.localImages.delete"),
                          options: .displayInline,
                          children: [reUpload, delete])
        }
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.localImages.reupload"),
                      options: .displayInline,
                      children: [reUpload])
    }
    
    private func swapReuploadOption() {
        // Swap "Re-upload" option
        reUploadAllowed = !(self.reUploadAllowed)
        updateActionButton()

        // No further operation if re-uploading is allowed
        if reUploadAllowed {
            // Refresh collection view
            DispatchQueue.main.async {
                self.localImagesCollection.reloadData()
            }
            return
        }

        // Deselect already uploaded photos if needed
        for index in 0..<selectedImages.count {
            if selectedImages[index] == nil { continue }
            // Can we select this image?
            if (queue.operationCount == 0) && (index < indexedUploadsInQueue.count) {
                // Indexed uploads available
                if indexedUploadsInQueue[index] != nil {
                    // Deselect cell
                    selectedImages[index] = nil
                }
            } else {
                // Use non-indexed data (might be quite slow)
                if let localIdentifier = selectedImages[index]?.localIdentifier,
                   let _ = uploadsInQueue.firstIndex(where: { $0?.0 == localIdentifier }) {
                    selectedImages[index] = nil
                }
            }
        }
        
        // Refresh collection view
        self.updateNavBar()
        self.localImagesCollection.reloadData()
    }
    
    private func canDeleteUploadedImages() -> Bool {
        // Don't provide access to the Trash button until the preparation work is not done
        if queue.operationCount > 0 { return false }
        
        // Check if there are uploaded photos to delete
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        if let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects {
            let completedUploads = allUploads.filter({ ($0.state == .finished) || ($0.state == .moderated) })
            for index in 0..<indexedUploads.count {
                if let _ = completedUploads.first(where: {$0.localIdentifier == indexedUploads[index].0}),
                   indexedUploads[index].2 {
                    return true
                }
            }
        }
        return false
    }
    
    @objc func deleteUploadedImages() {
        // Delete uploaded images (fetched on the main queue)
        uploadIDsToDelete = [NSManagedObjectID](); imagesToDelete = [String]()
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        if let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects {
            let completedUploads = allUploads.filter({ ($0.state == .finished) || ($0.state == .moderated) })
            for index in 0..<indexedUploads.count {
                if let upload = completedUploads.first(where: {$0.localIdentifier == indexedUploads[index].0}),
                   indexedUploads[index].2 {
                    uploadIDsToDelete.append(upload.objectID)
                    imagesToDelete.append(indexedUploads[index].0)
                }
            }
            if imagesToDelete.count > 0 {
                // Are you sure?
                let title = NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll")
                let message = NSLocalizedString("localImages_deleteMessage", comment: "Message explaining what will happen")
                let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                    style: .cancel, handler: { action in })
                let deleteAction = UIAlertAction(title: title, style: .destructive, handler: { action in
                    // Delete uploaded images
                    UploadManager.shared.delete(uploadedImages: self.imagesToDelete, with: self.uploadIDsToDelete)
                })
                alert.addAction(defaultAction)
                alert.addAction(deleteAction)
                alert.view.tintColor = .piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                self.present(alert, animated: true) {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = .piwigoColorOrange()
                }
            }
        }
    }
    

    // MARK: - Upload Images

    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        if selectedImages.compactMap({ $0 }).isEmpty { return }
        
        // Disable buttons
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false
        trashBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        if let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController {
            uploadSwitchVC.delegate = self

            // Will we propose to delete images after upload?
            if let firstLocalIdentifer = selectedImages.compactMap({ $0 }).first?.localIdentifier {
                if let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [firstLocalIdentifer], options: nil).firstObject {
                    // Only local images can be deleted
                    if imageAsset.sourceType != .typeCloudShared {
                        // Will allow user to delete images after upload
                        uploadSwitchVC.canDeleteImages = true
                    }
                }
            }
            
            // Can the user create tags?
            let albumData = CategoriesData.sharedInstance()?.getCategoryById(categoryId)
            if NetworkVars.hasAdminRights ||
                (NetworkVars.hasNormalRights && albumData?.hasUploadRights ?? false) {
                uploadSwitchVC.hasTagCreationRights = true
            }
            
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
    

    // MARK: - Select Images
    
    @objc func cancelSelect() {
        // Clear list of selected sections
        selectedSections = .init(repeating: .select, count: fetchedImages.count)

        // Clear list of selected images
        selectedImages = .init(repeating: nil, count: fetchedImages.count)

        // Update navigation bar
        updateNavBar()

        // Update collection
        localImagesCollection.reloadData()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Will interpret touches only in horizontal direction
        if (gestureRecognizer is UIPanGestureRecognizer) {
            let gPR = gestureRecognizer as? UIPanGestureRecognizer
            let translation = gPR?.translation(in: localImagesCollection)
            if abs(translation?.x ?? 0.0) > abs(translation?.y ?? 0.0) {
                return true
            }
        }
        return false
    }

    @objc func touchedImages(_ gestureRecognizer: UIPanGestureRecognizer?) {
        // To prevent a crash
        if gestureRecognizer?.view == nil {
            return
        }

        // Point and direction
        let point = gestureRecognizer?.location(in: localImagesCollection)

        // Get index path at touch position
        guard let indexPath = localImagesCollection.indexPathForItem(at: point ?? CGPoint.zero) else {
            return
        }

        // Select/deselect the cell or scroll the view
        if (gestureRecognizer?.state == .began) || (gestureRecognizer?.state == .changed) {

            // Get cell at touch position
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
                return
            }

            // Get index and upload state of image
            let index = getImageIndex(for: indexPath)
            let uploadState = getUploadStateOfImage(at: index, for: cell)

            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Update the selection state
                if let _ = selectedImages[index] {
                    selectedImages[index] = nil
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we re-upload this image?
                    if uploadState != nil {
                        if !reUploadAllowed { return }
                        if ![.finished, .moderated].contains(uploadState) { return }
                    }
                    
                    // Select the cell
                    selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                             category: categoryId)
                    cell.update(selected: true, state: uploadState)
                }

                // Update navigation bar
                updateNavBar()

                // Refresh cell
                cell.reloadInputViews()
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizer?.state == .ended {
            // Clear list of touched images
            imagesBeingTouched = []

            // Update state of Select button if needed
            updateSelectButton(ofSection: indexPath.section, completion: {
                self.localImagesCollection.reloadSections(IndexSet(integer: indexPath.section))
            })
        }
    }

    func updateSelectButton(ofSection section: Int, completion: @escaping () -> Void) {
        
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
        if nberOfImagesInSection == 0 {
            if section < selectedSections.count,
               selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
            return
        }

        // Get start and last indices of section
        let firstIndex: Int, lastIndex: Int
        if UploadVars.localImagesSort == kPiwigoSort.dateCreatedDescending.rawValue {
            firstIndex = getImageIndex(for: IndexPath(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: 0, section: section))
        }
        
        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages.count > lastIndex ?
            selectedImages[firstIndex...lastIndex].compactMap{ $0 }.count : 0
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            if section < selectedSections.count,
               selectedSections[section] != .deselect {
                selectedSections[section] = .deselect
                completion()
            }
            return
        }

        // Can we calculate the number of images already in the upload queue?
        if queue.operationCount != 0 {
            // Keep Select button disabled
            if section < selectedSections.count,
               selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
            return
        }

        // Number of images already in the upload queue
        var nberOfImagesOfSectionInUploadQueue = 0
        if reUploadAllowed == false {
            nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue.count > lastIndex ?  indexedUploadsInQueue[firstIndex...lastIndex].compactMap{ $0 }.count : 0
        }

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already uploaded
            if section < selectedSections.count,
               selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            if section < selectedSections.count,
               selectedSections[section] != .deselect {
                selectedSections[section] = .deselect
                completion()
            }
        } else {
            // Not all images are either selected or in the upload queue
            if section < selectedSections.count,
               selectedSections[section] != .select {
                selectedSections[section] = .select
                completion()
            }
        }
    }
    
    
    // MARK: - UICollectionView - Headers & Footers
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Images sorted by month, week or day
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "LocalImagesHeaderReusableView", for: indexPath) as? LocalImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
                
            // Update section if available data
            updateSelectButton(ofSection: indexPath.section, completion: {})
            
            // Determine place names from first images
            var imageAssets: [PHAsset] = []
            for row in 0..<min(localImagesCollection.numberOfItems(inSection: indexPath.section), 20) {
                let index = getImageIndex(for: IndexPath(item: row, section: indexPath.section))
                imageAssets.append(fetchedImages[index])
            }
            
            let selectState = queue.operationCount == 0 ? selectedSections[indexPath.section] : .none
            header.configure(with: imageAssets, section: indexPath.section, selectState: selectState)
            header.headerDelegate = self
            return header
        }
        else if kind == UICollectionView.elementKindSectionFooter {
            // Footer with number of images
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "LocalImagesFooterReusableView", for: indexPath) as? LocalImagesFooterReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            footer.configure(with: localImagesCollection.numberOfItems(inSection: indexPath.section))
            return footer
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    
    // MARK: - UICollectionView - Sections
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // Number of sections depends on image sort type
        switch sortType {
        case .month:
            return indexOfImageSortedByMonth.count
        case .week:
            return indexOfImageSortedByWeek.count
        case .day:
            return indexOfImageSortedByDay.count
        case .all:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: kImageMarginsSpacing, bottom: 10, right: kImageMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(ImagesCollection.imageCellVerticalSpacing(for: kImageCollectionPopup))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(ImagesCollection.imageCellHorizontalSpacing(for: kImageCollectionPopup))
    }

    
    // MARK: - UICollectionView - Rows
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Number of items depends on image sort type and date order
        switch sortType {
        case .month:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                return indexOfImageSortedByMonth[section].count
            case .dateCreatedAscending:
                return indexOfImageSortedByMonth[indexOfImageSortedByMonth.count - 1 - section].count
            default:
                return 0
            }
        case .week:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                return indexOfImageSortedByWeek[section].count
            case .dateCreatedAscending:
                return indexOfImageSortedByWeek[indexOfImageSortedByWeek.count - 1 - section].count
            default:
                return 0
            }
        case .day:
            switch kPiwigoSort(rawValue: UploadVars.localImagesSort) {
            case .dateCreatedDescending:
                return indexOfImageSortedByDay[section].count
            case .dateCreatedAscending:
                return indexOfImageSortedByDay[indexOfImageSortedByDay.count - 1 - section].count
            default:
                return 0
            }
        case .all:
            return fetchedImages.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        
        // Get image asset, upload state and index which depends on image sort type and date order
        let index = getImageIndex(for: indexPath)
        let imageAsset = fetchedImages[index]
        let uploadState = getUploadStateOfImage(at: index, for: cell)

        // Configure cell with image asset
        cell.configure(with: imageAsset, thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))
        cell.update(selected: selectedImages[index] != nil, state: uploadState)

        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let localIdentifier =  notification.userInfo?["localIdentifier"] as? String,
           localIdentifier.count > 0,
           let progressFraction = notification.userInfo?["progressFraction"] as? Float {
            let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
            for indexPath in indexPathsForVisibleItems {
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell,
                   cell.localIdentifier == localIdentifier {
                    cell.setProgress(progressFraction, withAnimation: true)
                    return
                }
            }
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }
        
        // Get index and upload state of image
        let index = getImageIndex(for: indexPath)
        let uploadState = getUploadStateOfImage(at: index, for: cell)

        // Update cell and selection
        if let _ = selectedImages[index] {
            // Deselect the cell
            selectedImages[index] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we  re-upload this image?
            if uploadState != nil {
                if !reUploadAllowed { return }
                if ![.finished, .moderated].contains(uploadState) { return }
            }

            // Select the image
            selectedImages[index] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                     category: categoryId)
            cell.update(selected: true, state: uploadState)
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton(ofSection: indexPath.section, completion: {
            self.localImagesCollection.reloadSections(IndexSet(integer: indexPath.section))
        })
    }


    // MARK: - LocalImagesHeaderReusableView Delegate Methods
    
    func didSelectImagesOfSection(_ section: Int) {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
        let firstIndex: Int, lastIndex: Int
        if UploadVars.localImagesSort == kPiwigoSort.dateCreatedDescending.rawValue {
            firstIndex = getImageIndex(for: IndexPath(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath(item: 0, section: section))
        }
//        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            // Loop over all images in section to select them (70356 images takes 150.6 ms with iPhone 11 Pro)
            // Here, we exploit the cached local IDs
            for index in firstIndex...lastIndex {
                // Images in the upload queue cannot be selected
                if (indexedUploadsInQueue[index] == nil) || (reUploadAllowed) {
                    selectedImages[index] = UploadProperties(localIdentifier: self.fetchedImages[index].localIdentifier,
                                                             category: self.categoryId)
                }
            }
            // Change section button state
            selectedSections[section] = .deselect
        } else {
            // Deselect images of section (70356 images takes 52.2 ms with iPhone 11 Pro)
            selectedImages[firstIndex...lastIndex] = .init(repeating: nil, count: lastIndex - firstIndex + 1)
            // Change section button state
            selectedSections[section] = .select
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")

        // Update navigation bar
        self.updateNavBar()

        // Update collection
        self.localImagesCollection.reloadSections(IndexSet(integer: section))
    }


    // MARK: - UploadSwitchDelegate Methods
    @objc func didValidateUploadSettings(with imageParameters: [String : Any], _ uploadParameters: [String:Any]) {
        // Retrieve common image parameters and upload settings
        for index in 0..<selectedImages.count {
            if let request = selectedImages[index] {
                var updatedRequest = request
                
                // Image parameters
                if let imageTitle = imageParameters["title"] as? String {
                    updatedRequest.imageTitle = imageTitle
                }
                if let author = imageParameters["author"] as? String {
                    updatedRequest.author = author
                }
                if let privacy = imageParameters["privacy"] as? kPiwigoPrivacy {
                    updatedRequest.privacyLevel = privacy
                }
                if let tagIds = imageParameters["tagIds"] as? String {
                    updatedRequest.tagIds = tagIds
                }
                if let comment = imageParameters["comment"] as? String {
                    updatedRequest.comment = comment
                }
                
                // Upload settings
                if let stripGPSdataOnUpload = uploadParameters["stripGPSdataOnUpload"] as? Bool {
                    updatedRequest.stripGPSdataOnUpload = stripGPSdataOnUpload
                }
                if let resizeImageOnUpload = uploadParameters["resizeImageOnUpload"] as? Bool {
                    updatedRequest.resizeImageOnUpload = resizeImageOnUpload
                    if resizeImageOnUpload {
                        if let photoMaxSize = uploadParameters["photoMaxSize"] as? Int16 {
                            updatedRequest.photoMaxSize = photoMaxSize
                        }
                        if let videoMaxSize = uploadParameters["videoMaxSize"] as? Int16 {
                            updatedRequest.videoMaxSize = videoMaxSize
                        }
                    } else {    // No downsizing
                        updatedRequest.photoMaxSize = 0
                        updatedRequest.videoMaxSize = 0
                    }
                }
                if let compressImageOnUpload = uploadParameters["compressImageOnUpload"] as? Bool {
                    updatedRequest.compressImageOnUpload = compressImageOnUpload
                }
                if let photoQuality = uploadParameters["photoQuality"] as? Int16 {
                    updatedRequest.photoQuality = photoQuality
                }
                if let prefixFileNameBeforeUpload = uploadParameters["prefixFileNameBeforeUpload"] as? Bool {
                    updatedRequest.prefixFileNameBeforeUpload = prefixFileNameBeforeUpload
                }
                if let defaultPrefix = uploadParameters["defaultPrefix"] as? String {
                    updatedRequest.defaultPrefix = defaultPrefix
                }
                if let deleteImageAfterUpload = uploadParameters["deleteImageAfterUpload"] as? Bool {
                    updatedRequest.deleteImageAfterUpload = deleteImageAfterUpload
                }

                selectedImages[index] = updatedRequest
            }
        }
        
        // Add selected images to upload queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadsProvider.importUploads(from: self.selectedImages.compactMap{ $0 }) { error in
                // Show an alert if there was an error.
                guard let error = error else {
                    // Restart UploadManager activities
                    if UploadManager.shared.isPaused {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.findNextImageToUpload()
                        }
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."), message: error.localizedDescription) { }
                }
            }
        }
    }
    
    @objc func uploadSettingsDidDisappear() {
        // Update the navigation bar
        updateNavBar()
        
        // Determine which help pages should be presented
        var displayHelpPagesWithIndex: [Int] = []
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00010000) == 0 {
            displayHelpPagesWithIndex.append(4)     // i.e. submit upload requests and let it go
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00001000) == 0 {
            displayHelpPagesWithIndex.append(3)     // i.e. remove images from camera roll
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00100000) == 0 {
            displayHelpPagesWithIndex.append(5)     // i.e. manage upload requests in queue
        }
        if #available(iOS 13, *),
           (AppVars.shared.didWatchHelpViews & 0b00000000_00000010) == 0 {
            displayHelpPagesWithIndex.append(1)     // i.e. use background uploading
        }
        if #available(iOS 14, *),
           (AppVars.shared.didWatchHelpViews & 0b00000000_01000000) == 0 {
            displayHelpPagesWithIndex.append(6)     // i.e. use auto-uploading
        }
        if displayHelpPagesWithIndex.count > 0 {
            // Present unseen upload management help views
            let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
            let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
            if let helpVC = helpVC {
                helpVC.displayHelpPagesWithIndex = displayHelpPagesWithIndex
                if UIDevice.current.userInterfaceIdiom == .phone {
                    helpVC.popoverPresentationController?.permittedArrowDirections = .up
                    navigationController?.present(helpVC, animated:true)
                } else {
                    helpVC.modalPresentationStyle = .formSheet
                    helpVC.modalTransitionStyle = .coverVertical
                    helpVC.popoverPresentationController?.sourceView = view
                    navigationController?.present(helpVC, animated: true)
                }
            }
        }
    }
}


// MARK: - Changes occured in the Photo library
/// Changes are not returned as expected (iOS 14.3 provides objects, not their indexes).
/// The image selection is therefore updated during the sort.
extension LocalImagesViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes
        guard let changes = changeInstance.changeDetails(for: self.fetchedImages)
            else { return }

        // This method may be called on a background queue; use the main queue to update the UI.
        DispatchQueue.main.async {
            // Show HUD during update, preventing touches
            self.showPiwigoHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"))

            // Update fetched asset collection
            self.fetchedImages = changes.fetchResultAfterChanges

            // Disable sort options and actions before sorting and caching
            self.actionBarButton?.isEnabled = false
            self.uploadBarButton?.isEnabled = false
            if #available(iOS 14, *) {
                // NOP
            } else {
                // Disable segmented control
                self.segmentedControl.setEnabled(false, forSegmentAt: SectionType.month.rawValue)
                self.segmentedControl.setEnabled(false, forSegmentAt: SectionType.week.rawValue)
                self.segmentedControl.setEnabled(false, forSegmentAt: SectionType.day.rawValue)
            }

            // Sort images in background, reset cache and image selection
            DispatchQueue.global(qos: .userInitiated).async {
                self.sortImagesAndIndexUploads()
            }
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate
extension LocalImagesViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
//            print("••• LocalImagesViewController controller:insert...")
            // Add upload request to cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }
            
            // Append upload to non-indexed upload queue
            let newUpload = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)!)
            if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                uploadsInQueue[index] = newUpload
            } else {
                uploadsInQueue.append(newUpload)
            }
            
            // Get index of selected image and deselect it
            if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                // Deselect image
                selectedImages[indexOfUploadedImage] = nil
            }
            
            // Get index of image and update request in cache
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeHiddenAssets = false
            fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", upload.localIdentifier)
            if let asset = PHAsset.fetchAssets(with: fetchOptions).firstObject {
                let idx = fetchedImages.index(of: asset)
                if idx != NSNotFound {
                    let cachedObject = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)!, asset.canPerform(.delete))
                    if idx >= indexedUploadsInQueue.count {
                        let newElements:[(String,kPiwigoUploadState,Bool)?] = .init(repeating: nil, count: indexedUploadsInQueue.count + 1 - idx)
                        indexedUploadsInQueue.append(contentsOf: newElements)
                    }
                    indexedUploadsInQueue[idx] = cachedObject
                }
            }

            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)

        case .delete:
//            print("••• LocalImagesViewController controller:delete...")
            // Delete upload request from cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }
            
            // Remove upload from non-indexed upload queue
            if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                uploadsInQueue.remove(at: index)
            }
            // Remove image from indexed upload queue
            if let index = indexedUploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                indexedUploadsInQueue[index] = nil
            }
            // Remove image from selection if needed
            if let index = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                // Deselect image
                selectedImages[index] = nil
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)

        case .move:
//            print("••• LocalImagesViewController controller:move...")
            break
        case .update:
//            print("••• LocalImagesViewController controller:update...")
            // Update upload request and cell
            guard let upload:Upload = anObject as? Upload else { return }
            
            // Update upload in non-indexed upload queue
            if let indexInQueue = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                uploadsInQueue[indexInQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)!)
            }
            // Update upload in indexed upload queue
            if let indexOfUploadedImage = indexedUploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                indexedUploadsInQueue[indexOfUploadedImage]?.1 = kPiwigoUploadState(rawValue: upload.requestState)!
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)

        @unknown default:
            fatalError("LocalImagesViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("••• LocalImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateActionButton()
        updateNavBar()
    }

    func updateCellAndSectionHeader(for upload: Upload) {
        DispatchQueue.main.async {
            // Get indices of visible items
            let indexPathsForVisibleItems = self.localImagesCollection.indexPathsForVisibleItems
            
            // Loop over the visible items
            for indexPath in indexPathsForVisibleItems {
                // Identify cell to be updated (if presented)
                if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell,
                   cell.localIdentifier == upload.localIdentifier {
                    // Update cell
                    cell.update(selected: false, state: upload.state)
                    cell.reloadInputViews()
                    // The section will be refreshed only if the button content needs to be changed
                    self.updateSelectButton(ofSection: indexPath.section, completion: {
                        self.localImagesCollection.reloadSections(IndexSet(integer: indexPath.section))
                    })
                    return
                }
            }
        }
    }
}
