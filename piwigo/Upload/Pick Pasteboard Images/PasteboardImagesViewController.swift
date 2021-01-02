//
//  PasteboardImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 6 December 2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@objc
class PasteboardImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, PasteboardImagesHeaderDelegate, UploadSwitchDelegate {
    
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
            return _categoryId ?? Model.sharedInstance().defaultCategory
        }
        set(categoryId) {
            _categoryId = categoryId
        }
    }

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
        
    // Collection of images in the pasteboard
    private var pbIndexSet = IndexSet()             // IndexSet of objects in pasteboard
    private var pbTypes = [[String]]()              // Types of objects in pasteboard
    private var pbIdentifiers = [String]()          // Identifiers (see below)
    private var pbFileExtensions = [String]()       // Extension of filenames

    private let queue = OperationQueue()                                    // Queue used to cache things
    private var uploadsInQueue = [(String?,kPiwigoUploadState?)?]()         // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String?,kPiwigoUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    private var selectedImages = [UploadProperties?]()                      // Array of images to upload
    private var sectionState: SelectButtonState = .none                     // To remember the state of the section
    private var imagesBeingTouched = [IndexPath]()                          // Array of indexPaths of touched images
    
    private var cancelBarButton: UIBarButtonItem!       // For cancelling the selection of images
    private var uploadBarButton: UIBarButtonItem!       // for uploading selected images
    private var legendLabel = UILabel.init()            // Legend presented in the toolbar on iPhone/iOS 14+
    private var legendBarItem: UIBarButtonItem!

    private var removeUploadedImages = false
    private var hudViewController: UIViewController?


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true
        
        // Retrieve pasteboard object indexes and types, then create identifiers
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {
            setPasteboardIDs(from: indexSet, types: types)
        } else {
            pbIndexSet = IndexSet.init()
            pbTypes = [[String]]()
            pbIdentifiers = [String]()
        }

        // At start, there is no image selected
        selectedImages = .init(repeating: nil, count: pbIndexSet.count)
        
        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        if let uploads = uploadsProvider.fetchedResultsController.fetchedObjects {
            uploadsInQueue = uploads.map {($0.localIdentifier, $0.state)}
        }
                                                                                        
        // Prepare images for upload and cache images in upload queue in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepareImagesAndIndexUploads()
        }
        
        // Collection flow layout of images
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.sectionHeadersPinToVisibleBounds = true

        // Collection view identifier
        localImagesCollection.accessibilityIdentifier = "Pasteboard"
        
        // Navigation bar
        navigationController?.toolbar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.accessibilityIdentifier = "PasteboardImagesNav"

        // The cancel button is used to cancel the selection of images to upload
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton.accessibilityIdentifier = "Cancel"
        
        // The upload button is available after having selecting images
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        uploadBarButton.isEnabled = false
        uploadBarButton.accessibilityIdentifier = "Upload"
        
        // Configure menus, segmented control, etc.
        if #available(iOS 14, *) {
            // Initialise buttons, toolbar and segmented control
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Title
                title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")

                // Presents the number of photos selected and the Upload button in the toolbar
                navigationController?.isToolbarHidden = false
                legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
            }
        } else {
            // Fallback on earlier versions.
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            // Title
            title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
        }
        
        // Show images in upload queue by default
        removeUploadedImages = false
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Case of an iPhone
        if #available(iOS 14, *) {
            // Toolbar
            legendLabel.textColor = UIColor.piwigoColorText()
            legendBarItem = UIBarButtonItem.init(customView: legendLabel)
            toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
            navigationController?.toolbar.barTintColor = UIColor.piwigoColorBackground()
            navigationController?.toolbar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        }
        else {
            // Fallback on earlier versions
        }

        // Collection view
        localImagesCollection.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
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

        // Register palette changes
        var name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Register upload progress
        name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress), name: name, object: nil)
        
        // Register app entering foreground for updating the pasteboard
        name = NSNotification.Name(UIApplication.willEnterForegroundNotification.rawValue)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPasteboard), name: name, object: nil)

        // Prevent device from sleeping if uploads are in progress
        let uploadsToPerform = uploadsProvider.fetchedResultsController.fetchedObjects?.map({
            ($0.state == .waiting) || ($0.state == .preparing) || ($0.state == .prepared) ||
            ($0.state == .uploading) || ($0.state == .finishing) ? 1 : 0}).reduce(0, +) ?? 0
        if uploadsToPerform > 0 {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = localImagesCollection.visibleCells.first {
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
        // Unregister palette changes
        var name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
        
        // Unregister upload progress
        name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Unregister app entering foreground for updating the pasteboard
        name = NSNotification.Name(UIApplication.willEnterForegroundNotification.rawValue)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
        case 0:
            // Buttons
            cancelBarButton.isEnabled = false
            uploadBarButton.isEnabled = false

            // Display "Back" button on the left side
            navigationItem.leftBarButtonItems = []

            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                if #available(iOS 14, *) {
                    // Present the "Upload" button in the toolbar
                    legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                    legendBarItem = UIBarButtonItem.init(customView: legendLabel)
                    toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
                } else {
                    // Title
                    title = NSLocalizedString("selectImages", comment: "Select Photos")
                }
            }

        default:
            // Buttons
            cancelBarButton.isEnabled = true
            uploadBarButton.isEnabled = true

            // Display "Cancel" button on the left side
            navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }

            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                if #available(iOS 14, *) {
                    // Update the number of selected photos in the toolbar
                    legendLabel.text = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                    legendBarItem = UIBarButtonItem.init(customView: legendLabel)
                    toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
                } else {
                    // Update the number of selected photos in the navigation bar
                    title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

                    // Presents a single action menu
                    navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                }
            }
            
            // Set buttons on the right side on iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Update the number of selected photos in the navigation bar
                title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

                // Update status of buttons
                navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
            }
        }
    }

    
    // MARK: - Check pasteboard content
    /// Called by the notification center when the pasteboard content is updated
    @objc func checkPasteboard() {
        // Do nothing if the clipboard was emptied
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {
            // Retrieve pasteboard object indexes and types, then create identifiers
            setPasteboardIDs(from: indexSet, types: types)

            // Prepare images for upload and cache images in upload queue in background
            DispatchQueue.global(qos: .userInitiated).async {
                self.prepareImagesAndIndexUploads()
            }
        }
    }
    
    /// Pasteboard images are identified with identifiers of the type "Clipboard-yyyyMMdd-HHmmssSSSS-typ-#" where:
    /// - "Clipboard" is a header telling that the image/video comes from the pasteboard
    /// - "yyyyMMdd-HHmmssSSSS" is the date at which the objects were retrieved
    /// - "typ" is "img" or "mov" depending on the nature of the object
    /// - "#" is the index of the object in the pasteboard
    private func setPasteboardIDs(from indexSet: IndexSet, types: [[String]]) {
        // Get date of retrieve
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        let pbDateTime = dateFormatter.string(from: Date())

        // Retrieve pasteboard object indexes and types, then create identifiers
        pbIndexSet = indexSet       // e.g. 0..<4
        pbTypes = types             // e.g. [["public.jpeg", "public.png"], ["public.jpeg"], ...]
        pbIdentifiers = [String]()
        for idx in indexSet {
            if UIPasteboard.general.contains(pasteboardTypes: ["public.image"], inItemSet: IndexSet.init(integer: idx)) {
                pbIdentifiers.append(String(format: "Clipboard-%@-img-%ld", pbDateTime, idx))
            } else {
                pbIdentifiers.append(String(format: "Clipboard-%@-mov-%ld", pbDateTime, idx))
            }
        }
    }

    
    // MARK: - Prepare Image files and cache of upload requests
    private func prepareImagesAndIndexUploads() -> Void {

        // Store pasteboard images in one loop i.e. O(n)
        let prepareOperation = BlockOperation.init(block: {
            // (Re-)initialise file extensions
            self.pbFileExtensions = .init(repeating: "", count: self.pbIndexSet.count)

            // Retrieve objects from pasteboard
            self.preparePasteboardImages()
        })

        // Caching upload request indices
        let cacheOperation = BlockOperation.init(block: {
            self.cachingUploadIndicesIteratingPasteBoardImages()
        })

        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = 1   // Make it a serial queue with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([prepareOperation, cacheOperation], waitUntilFinished: true)

        // Reload image collection
        DispatchQueue.main.async {
            self.localImagesCollection.reloadData()
        }
        
        // Restart UplaodManager activity if all images are already in the upload queue
        if self.indexedUploadsInQueue.compactMap({$0}).count == self.pbIndexSet.count,
           UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    private func preparePasteboardImages() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()

        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = pbIndexSet.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop second operation in iteration \(i) ;-)")
                return
            }

            // Get types of all objects in pasteboard
            let firstIndex = pbIndexSet.first! + i*step
            let lastIndex = min(pbIndexSet.first! + (i+1)*step, pbIndexSet.count)
            for index in firstIndex..<lastIndex {
                // IndexSet of current image
                let indexSet = IndexSet.init(integer: index)

                // Get image data and file extension
                guard let (imageData, fileExt) = getDataOfPasteboardImage(at: indexSet) else {
                    // Forget that image… to be coded
                    pbFileExtensions[index] = "unknown"
                    continue
                }

                // Store file extension
                pbFileExtensions[index] = fileExt
                
                // Set file URL
                let fileURL = UploadManager.shared.applicationUploadsDirectory
                    .appendingPathComponent(pbIdentifiers[index]).appendingPathExtension(fileExt)

                // Delete file if it already exists (incomplete previous attempt?)
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {
                }

                // Store pasteboard image/video data into Piwigo/Uploads directory
                do {
                    print("==>> Write imageData to \(fileURL)")
                    try imageData.write(to: fileURL)
                }
                catch let error as NSError {
                    // Disk full? —> to be managed…
                    print("could not save image file: \(error)")
                }
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   stored \(pbIndexSet.count) images on disk in \(diff) ms")
    }
    
    /// https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/system_declared_types
    private func getDataOfPasteboardImage(at indexSet:IndexSet) -> (imageData: Data, fileExt: String)? {
        // Images
        // PNG format in priority in case where JPEG is also available
        if pbTypes[indexSet.first!].contains("public.png"),
           let imageData = UIPasteboard.general.data(forPasteboardType: "public.png", inItemSet: indexSet)?.first {
            return (imageData, "png")
        }
        else if pbTypes[indexSet.first!].contains("public.heic"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.heic", inItemSet: indexSet)?.first {
            return (imageData, "heic")
        }
        else if pbTypes[indexSet.first!].contains("public.heif"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.heif", inItemSet: indexSet)?.first {
            return (imageData, "heif")
        }
        else if pbTypes[indexSet.first!].contains("public.tiff"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.tiff", inItemSet: indexSet)?.first {
            return (imageData, "tiff")
        }
        else if pbTypes[indexSet.first!].contains("public.jpeg"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "public.jpeg", inItemSet: indexSet)?.first {
            return (imageData, "jpg")
        }
        else if pbTypes[indexSet.first!].contains("public.camera-raw-image"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "public.camera-raw-image", inItemSet: indexSet)?.first {
            return (imageData, "raw")
        }
        else if pbTypes[indexSet.first!].contains("com.google.webp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.google.webp", inItemSet: indexSet)?.first {
            return (imageData, "webp")
        }
        else if pbTypes[indexSet.first!].contains("com.compuserve.gif"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif", inItemSet: indexSet)?.first {
            return (imageData, "gif")
        }
        else if pbTypes[indexSet.first!].contains("com.microsoft.bmp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.bmp", inItemSet: indexSet)?.first {
            return (imageData, "bmp")
        }
        else if pbTypes[indexSet.first!].contains("com.microsoft.ico"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.ico", inItemSet: indexSet)?.first {
            return (imageData, "ico")
        }
        // Movies
        else if pbTypes[indexSet.first!].contains("com.apple.quicktime-movie"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.quicktime-movie", inItemSet: indexSet)?.first {
            return (imageData, "mov")
        }
        else if pbTypes[indexSet.first!].contains("public.mpeg"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg", inItemSet: indexSet)?.first {
            return (imageData, "mpeg")
        }
        else if pbTypes[indexSet.first!].contains("public.mpeg-2-video"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg-2-video", inItemSet: indexSet)?.first {
            return (imageData, "mpeg2")
        }
        else if pbTypes[indexSet.first!].contains("public.mpeg-4"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg-4", inItemSet: indexSet)?.first {
            return (imageData, "mp4")
        }
        else if pbTypes[indexSet.first!].contains("public.avi"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.avi", inItemSet: indexSet)?.first {
            return (imageData, "avi")
        }
        else {
            // Unknown image/video format
            return nil
        }
    }
    
    private func cachingUploadIndicesIteratingPasteBoardImages() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()

        // Initialise cached indexed uploads
        indexedUploadsInQueue = .init(repeating: nil, count: pbIndexSet.count)

        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = pbIndexSet.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                indexedUploadsInQueue = []
                print("Stop second operation in iteration \(i) ;-)")
                return
            }

            for index in i*step..<min((i+1)*step,pbIndexSet.count) {
                // Get image identifier
                let imageId = pbIdentifiers[i]
                if let upload = uploadsInQueue.first(where: { $0?.0 == imageId }) {
                    indexedUploadsInQueue[index] = upload
                }
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   indexed \(pbIndexSet.count) images by iterating pasteboard images in \(diff) ms")
    }

    
    // MARK: - Actions Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })
        alert.addAction(cancelAction)

        // Select all images
        if selectedImages.compactMap({$0}).count + indexedUploadsInQueue.compactMap({$0}).count < pbIndexSet.count {
            let selectAction = UIAlertAction(title: NSLocalizedString("selectAll", comment: "Select All"), style: .default) { (action) in
                // Loop over all images in section to select them
                // Here, we exploit the cached local IDs
                for index in 0..<self.selectedImages.count {
                    // Images in the upload queue cannot be selected
                    if self.indexedUploadsInQueue[index] == nil {
                        self.selectedImages[index] = UploadProperties.init(localIdentifier: self.pbIdentifiers[index], category: self.categoryId)
                    }
                }
                // Reload collection while updating section buttons
                self.updateNavBar()
                self.localImagesCollection.reloadData()
            }
            alert.addAction(selectAction)
        } else {
            let deselectAction = UIAlertAction(title: NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect"), style: .default) { (action) in
                self.cancelSelect()
            }
            alert.addAction(deselectAction)
        }
        
        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
//        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    
    // MARK: - Upload Images

    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        if selectedImages.compactMap({ $0 }).count == 0 { return }
        
        // Disable button
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        if let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController {
            uploadSwitchVC.delegate = self
            uploadSwitchVC.canDeleteImages = false

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
        // Clear list of selected images
        selectedImages = .init(repeating: nil, count: pbIndexSet.count)

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
            if abs(Float(translation?.x ?? 0.0)) > abs(Float(translation?.y ?? 0.0)) {
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
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell else {
                return
            }

            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Update the selection state
                if let _ = selectedImages[indexPath.item] {
                    selectedImages[indexPath.item] = nil
                    cell.cellSelected = false
                } else {
                    // Can we select this image?
                    if indexedUploadsInQueue.count < indexPath.item {
                        // Use non-indexed data (might be quite slow)
                        if let _ = uploadsInQueue.firstIndex(where: { $0?.0 == cell.localIdentifier }) { return }
                    } else {
                        // Indexed uploads available
                        if indexedUploadsInQueue[indexPath.item] != nil { return }
                    }

                    // Select the cell
                    selectedImages[indexPath.item] = UploadProperties.init(localIdentifier: cell.localIdentifier,
                                                                  category: categoryId)
                    cell.cellSelected = true
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
        }
    }

    func updateSelectButton(completion: @escaping () -> Void) {
        
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: 0)

        // Job done if there is no image presented
        if nberOfImagesInSection == 0 {
            sectionState = .none
            completion()
            return
        }
        
        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages[0..<nberOfImagesInSection].compactMap{ $0 }.count
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            if sectionState != .deselect {
                sectionState = .deselect
                completion()
            }
            return
        }

        // Can we calculate the number of images already in the upload queue?
        if queue.operationCount != 0 {
            // Keep Select button disabled
            if sectionState != .none {
                sectionState = .none
                completion()
            }
            return
        }

        // Number of images already in the upload queue
        let nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue[0..<nberOfImagesInSection].compactMap{ $0 }.count

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already downloaded
            if sectionState != .none {
                sectionState = .none
                completion()
            }
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            if sectionState != .deselect {
                sectionState = .deselect
                completion()
            }
        } else {
            // Not all images are either selected or in the upload queue
            if sectionState != .select {
                sectionState = .select
                completion()
            }
        }
    }

    
    // MARK: - UICollectionView - Headers & Footers
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Pasteboard header
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "PasteboardImagesHeaderReusableView", for: indexPath) as? PasteboardImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            
            // Update section if available data
            updateSelectButton(completion: {})
            
            // Configure the header
            let selectState = queue.operationCount == 0 ? sectionState : .none
            header.configure(with: selectState)
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
        return 1
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
        return pbIndexSet.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PasteboardImageCollectionViewCell", for: indexPath) as? PasteboardImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a PasteboardImageCollectionViewCell!")
            return PasteboardImageCollectionViewCell()
        }
        
        // Configure cell with image in pasteboard or stored in Uploads directory
        // (the content of the pasteboard may not last forever)
        let identifier = pbIdentifiers[indexPath.item]
        var image: UIImage!
        if queue.operationCount == 0 {
            // Did complete preparation of images => get content of file to upload
            let fileURL = UploadManager.shared.applicationUploadsDirectory
                .appendingPathComponent(pbIdentifiers[indexPath.item])
                .appendingPathExtension(pbFileExtensions[indexPath.item])
            
            // Photo or video?
            if identifier.contains("img") {
                do {
                    try image = UIImage(data:(NSData (contentsOf: fileURL) as Data))
                }
                catch {
                    image = UIImage(named: "placeholder")!
                }
            }
            else {
                let asset = AVURLAsset(url: fileURL, options: nil)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                do {
                    image = UIImage(cgImage: try imageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil))
                } catch {
                    image = UIImage(named: "placeholder")!
                }
            }
        } else {
            // Did not complete preparation of images => get pasteboard content
            let indexSet = IndexSet.init(integer: indexPath.item)
            if let imageData: Data = UIPasteboard.general.data(forPasteboardType: "public.image", inItemSet: indexSet)?.first {
                image = UIImage.init(data: imageData) ?? UIImage(named: "placeholder")!
            }
            else {
                // The thumbnail of the video will later be extracted from the stored file
                image = UIImage(named: "placeholder")!
            }
        }
        if image == nil { image = UIImage(named: "placeholder")! }
        cell.configure(with: image, identifier: identifier,
                       thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))
        
        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        // Cell state
        if queue.operationCount == 0,
           indexedUploadsInQueue.count == pbIndexSet.count {
            // Use indexed data
            if let state = indexedUploadsInQueue[indexPath.item]?.1 {
                switch state {
                case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                    cell.cellWaiting = true
                case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                    cell.cellUploading = true
                case .finished, .moderated:
                    cell.cellUploaded = true
                }
            } else {
                cell.cellSelected = selectedImages[indexPath.item] != nil
            }
        } else {
            // Use non-indexed data
            if let upload = uploadsInQueue.first(where: { $0?.0 == identifier }) {
                switch upload?.1 {
                case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                    cell.cellWaiting = true
                case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                    cell.cellUploading = true
                case .finished, .moderated:
                    cell.cellUploaded = true
                case .none:
                    cell.cellSelected = false
                }
            } else {
                cell.cellSelected = selectedImages[indexPath.item] != nil
            }
        }
        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        let localIdentifier =  (notification.userInfo?["localIndentifier"] ?? "") as! String
        let progressFraction = (notification.userInfo?["progressFraction"] ?? Float(0.0)) as! Float
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        for indexPath in indexPathsForVisibleItems {
            let imageId = pbIdentifiers[indexPath.item] // Don't use the cache which might not be ready
            if imageId == localIdentifier {
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell {
                    cell.setProgress(progressFraction, withAnimation: true)
                    break
                }
            }
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell else {
            return
        }

        // Images in the upload queue cannot be selected
        if indexedUploadsInQueue.count < indexPath.item {
            // Use non-indexed data (might be quite slow)
            if let _ = uploadsInQueue.first(where: { $0?.0 == cell.localIdentifier }) { return }
        } else {
            // Indexed uploads available
            if indexedUploadsInQueue[indexPath.item] != nil { return }
        }

        // Update cell and selection
        if let _ = selectedImages[indexPath.item] {
            // Deselect the cell
            selectedImages[indexPath.item] = nil
            cell.cellSelected = false
        } else {
            // Select the cell
            selectedImages[indexPath.item] = UploadProperties.init(localIdentifier: cell.localIdentifier,
                                                                   category: categoryId)
            cell.cellSelected = true
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()
    }


    // MARK: - PasteboardImagesHeaderReusableView Delegate Methods
    
    func didSelectImagesOfSection() {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: 0)
        if sectionState == .select {
            // Loop over all images in section to select them (70356 images takes 150.6 ms with iPhone 11 Pro)
            // Here, we exploit the cached local IDs
            for index in 0..<nberOfImagesInSection {
                // Images in the upload queue cannot be selected
                if indexedUploadsInQueue[index] == nil {
                    selectedImages[index] = UploadProperties.init(localIdentifier: pbIdentifiers[index], category: self.categoryId)
                }
            }
            // Change section button state
            sectionState = .deselect
        } else {
            // Deselect images of section (70356 images takes 52.2 ms with iPhone 11 Pro)
            selectedImages[0..<nberOfImagesInSection] = .init(repeating: nil, count: nberOfImagesInSection)
            // Change section button state
            sectionState = .select
        }

        // Update navigation bar
        self.updateNavBar()

        // Update collection
        self.localImagesCollection.reloadSections(IndexSet.init(integer: 0))
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
                        if let photoResize = uploadParameters["photoResize"] as? Int {
                            updatedRequest.photoResize = photoResize
                        }
                    } else {
                        updatedRequest.photoResize = 100
                    }
                }
                if let compressImageOnUpload = uploadParameters["compressImageOnUpload"] as? Bool {
                    updatedRequest.compressImageOnUpload = compressImageOnUpload
                }
                if let photoQuality = uploadParameters["photoQuality"] as? Int {
                    updatedRequest.photoQuality = photoQuality
                }
                if let prefixFileNameBeforeUpload = uploadParameters["prefixFileNameBeforeUpload"] as? Bool {
                    updatedRequest.prefixFileNameBeforeUpload = prefixFileNameBeforeUpload
                }
                if let defaultPrefix = uploadParameters["defaultPrefix"] {
                    updatedRequest.defaultPrefix = defaultPrefix as? String
                }
                if let deleteImageAfterUpload = uploadParameters["deleteImageAfterUpload"] as? Bool {
                    updatedRequest.deleteImageAfterUpload = deleteImageAfterUpload
                }

                selectedImages[index] = updatedRequest
            }
        }
        
        // Add selected images to upload queue
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
                let alert = UIAlertController(title: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."),
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"),
                                              style: .default, handler: nil))
                alert.view.tintColor = UIColor.piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                self.present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = UIColor.piwigoColorOrange()
                })
            }
        }
        
        // Clear selection
        cancelSelect()
    }
    
    @objc func uploadSettingsDidDisappear() {
        // Update the navigation bar
        updateNavBar()
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

extension PasteboardImagesViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
//            print("••• LocalImagesViewController controller:insert...")
            // Image added to upload queue
            if let upload:Upload = anObject as? Upload {
                // Append upload to non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[index] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                } else {
                    uploadsInQueue.append((upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)))
                }
                // Get index of uploaded image
                if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                    // Deselect image
                    selectedImages[indexOfUploadedImage] = nil
                    // Add image to indexed upload queue
                    indexedUploadsInQueue[indexOfUploadedImage] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        case .delete:
//            print("••• LocalImagesViewController controller:delete...")
            // Image removed from upload queue
            if let upload:Upload = anObject as? Upload {
                // Remove upload from non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue.remove(at: index)
                }
                // Get index of uploaded image
                if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                    // Deselect image
                    selectedImages[indexOfUploadedImage] = nil
                    // Remove image from indexed upload queue
                    indexedUploadsInQueue[indexOfUploadedImage] = nil
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        case .move:
//            print("••• LocalImagesViewController controller:move...")
            break
        case .update:
//            print("••• LocalImagesViewController controller:update...")
            // Image removed from upload queue
            if let upload:Upload = anObject as? Upload {
                // Update upload in non-indexed upload queue
                if let indexInQueue = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[indexInQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update image in indexed upload queue
                if let indexInIndexedQueue = indexedUploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    indexedUploadsInQueue[indexInIndexedQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        @unknown default:
            fatalError("LocalImagesViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("••• LocalImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateNavBar()
    }

    func updateCell(for upload: Upload) {
        // Get indices of visible items
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        
        // Loop over the visible items
        for indexPath in indexPathsForVisibleItems {
            
            // Get the corresponding index and local identifier
            let imageId = pbIdentifiers[indexPath.item] // Don't use the cache which might not be ready
            
            // Identify cell to be updated (if presented)
            if imageId == upload.localIdentifier {
                // Update visible cell
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell {
                    cell.selectedImage.isHidden = true
                    switch upload.state {
                    case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                        cell.cellWaiting = true
                    case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                        cell.cellUploading = true
                    case .finished, .moderated:
                        cell.cellUploaded = true
                    }
                    cell.reloadInputViews()
                    return
                }
            }
        }
    }
}
