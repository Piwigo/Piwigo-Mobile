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
class PasteboardImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, UploadSwitchDelegate {
    
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
    private var pasteBoardIndexSet = IndexSet()                             // IndexSet of objects in pasteboard
    private var pasteBoardTypes = [[String]]()                              // Types of objects in pasteboard
    private var pasteBoardIdentifiers = [String]()                          // Identifiers of objects in pasteboard

    private let queue = OperationQueue()                                    // Queue used to cache things
    private var uploadsInQueue = [(String?,kPiwigoUploadState?)?]()         // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String?,kPiwigoUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    private var selectedImages = [UploadProperties?]()                      // Array of images to upload
    private var imagesBeingTouched = [IndexPath]()                          // Array of indexPaths of touched images
    
    private var actionBarButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    
    private var removeUploadedImages = false
    private var hudViewController: UIViewController?


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true

        // Get images and videos in pasteboard
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {
            pasteBoardIndexSet = indexSet
            pasteBoardTypes = types
        } else {
            pasteBoardIndexSet = IndexSet.init()
            pasteBoardTypes = [[String]]()
        }

        // At start, there is no image selected and iDs are not known
        pasteBoardIdentifiers = .init(repeating: "", count: pasteBoardIndexSet.count)
        selectedImages = .init(repeating: nil, count: pasteBoardIndexSet.count)
        
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
        localImagesCollection.accessibilityIdentifier = "CameraRoll"
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "LocalImagesNav"

        // Bar buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "list"), landscapeImagePhone: UIImage(named: "listCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        actionBarButton?.accessibilityIdentifier = "Sort"
        actionBarButton?.isEnabled = false
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        uploadBarButton = UIBarButtonItem(title: NSLocalizedString("tabBar_upload", comment: "Upload"), style: .done, target: self, action: #selector(didTapUploadButton))
        uploadBarButton?.isEnabled = false
        uploadBarButton?.accessibilityIdentifier = "Upload"
        
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

    @objc func checkPasteboard() {
        // Get images and videos in pasteboard
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {
            pasteBoardIndexSet = indexSet
            pasteBoardTypes = types
        } else {
            pasteBoardIndexSet = IndexSet.init()
            pasteBoardTypes = [[String]]()
        }

        // Prepare images for upload and cache images in upload queue in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.prepareImagesAndIndexUploads()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cancel operations if needed
        queue.cancelAllOperations()

        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false

        // Unregister palette changes
        var name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
        
        // Unregister upload progress
        name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Unregister app entering foreground for updating the pasteboard
        name = NSNotification.Name(UIApplication.willEnterForegroundNotification.rawValue)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Restart UploadManager activities
        if UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
            case 0:
                navigationItem.leftBarButtonItems = []
                // Do not show two buttons to provide enough space for title
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width <= 414 {
                    // i.e. smaller than iPhones 6,7 Plus screen width
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                } else {
                    navigationItem.rightBarButtonItems = [actionBarButton, uploadBarButton].compactMap { $0 }
                    uploadBarButton?.isEnabled = false
                }
                cancelBarButton?.isEnabled = false
                actionBarButton?.isEnabled = (queue.operationCount == 0)
                uploadBarButton?.isEnabled = false
                title = NSLocalizedString("selectImages", comment: "Select Photos")
            default:
                navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
                // Do not show two buttons to provide enough space for title
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width <= 414 {
                    // i.e. smaller than iPhones 6,7 Plus screen width
                    navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                } else {
                    navigationItem.rightBarButtonItems = [actionBarButton, uploadBarButton].compactMap { $0 }
                }
                cancelBarButton?.isEnabled = true
                actionBarButton?.isEnabled = (queue.operationCount == 0)
                uploadBarButton?.isEnabled = true
                title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
        }
    }

    
    // MARK: - Prepare Image files and cache of upload requests
    // Prepare image files for upload
    private func prepareImagesAndIndexUploads() -> Void {

        // Identify pasteboard images in one loop i.e. O(n)
        let prepareOperation = BlockOperation.init(block: {
            self.preparePasteBoardImages()
        })

        // Caching upload request indices
        let cacheOperation = BlockOperation.init(block: {
            self.cachingUploadIndicesIteratingPasteBoardImages()
        })
        cacheOperation.completionBlock = {
            // Allow action button
            DispatchQueue.main.async {
                self.actionBarButton?.isEnabled = true
            }
        }

        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = .max   // Make it a serial queue for debugging with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([prepareOperation, cacheOperation], waitUntilFinished: true)

        // Enable Select buttons
        DispatchQueue.main.async {
            self.localImagesCollection.reloadData()
        }
        
        // Restart UplaodManager activity if all images are already in the upload queue
        if self.indexedUploadsInQueue.compactMap({$0}).count == self.pasteBoardIndexSet.count,
           UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    private func preparePasteBoardImages() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()

        // (Re-)initialise the identifiers
        pasteBoardIdentifiers = .init(repeating: "", count: pasteBoardIndexSet.count)
        
        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = pasteBoardIndexSet.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop second operation in iteration \(i) ;-)")
                return
            }

            // Get types of all objects in pasteboard
            let firstIndex = i*step
            let lastIndex = min((i+1)*step, pasteBoardIndexSet.count)
            for index in firstIndex..<lastIndex {
                // IndexSet of current image
                let indexSet = IndexSet.init(integer: index)

                // Create pasteboard image identifier
                pasteBoardIdentifiers[index] = getIdentifierOfPasteBoardImage(at: index)

                // Save image/video data in Upload directory
                savePasteBoardImage(ofTypes: pasteBoardTypes[index], at:indexSet,
                                    withId: pasteBoardIdentifiers[index])
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   cached \(uploadsInQueue.count) images by iterating uploads in queue in \(diff) ms")
    }
    
    private func getIdentifierOfPasteBoardImage(at index:Int) -> String {
        let fileName = PhotosFetch.sharedInstance().getFileNameFomImageAsset(nil)
        return String(format: "PasteBoard-%@-%ld", fileName, index + 1)
    }
    
    private func savePasteBoardImage(ofTypes imageTypes:[String], at indexSet:IndexSet,
                                     withId identifier:String) -> (Void) {
        // PNG format in priority in case where JPEG is also available
        if imageTypes.contains("public.png"),
           let imageData = UIPasteboard.general.data(forPasteboardType: "public.png", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "png")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.tiff"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.tiff", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "tiff")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.jpeg-2000"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.jpeg-2000", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "jp2")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.jpeg"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "public.jpeg", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "jpg")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.adobe.photoshop-​image"),
            let imageData = UIPasteboard.general.data(forPasteboardType: "com.adobe.photoshop-​image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "psd")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.apple.quicktime-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.quicktime-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "qtif")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.apple.icns"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.icns", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "icns")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.apple.pict"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.pict", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "pict")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.apple.macpaint-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.macpaint-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "pntg")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.xbitmap-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.xbitmap-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "xbm")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.compuserve.gif"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.compuserve.gif", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "gif")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.microsoft.bmp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.bmp", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "bmp")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.microsoft.ico"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.ico", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "ico")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.truevision.tga-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.truevision.tga-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "tga")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.sgi.sgi-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.sgi.sgi-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "sgi")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.ilm.openexr-image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.ilm.openexr-image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "exr")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.kodak.flashpix.image"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.kodak.flashpix.image", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "fpx")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.apple.quicktime-movie"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.apple.quicktime-movie", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "mov")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.avi"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.avi", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "avi")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.mpeg"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "mpeg")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.mpeg-4"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.mpeg-4", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "mp4")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.3gpp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.3gpp", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "3gp")
            } catch {
                return
            }
        }
        else if imageTypes.contains("public.3gpp2"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "public.3gpp2", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "3g2")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.microsoft.windows-​media-wm"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.windows-​media-wm", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "wm")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.microsoft.windows-​media-wmv"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.windows-​media-wmv", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "wmv")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.microsoft.windows-​media-wmp"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.microsoft.windows-​media-wmp", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "wmp")
            } catch {
                return
            }
        }
        else if imageTypes.contains("com.real.realmedia"),
               let imageData = UIPasteboard.general.data(forPasteboardType: "com.real.realmedia", inItemSet: indexSet)?.first {
            do {
                try savePasteBoard(imageData: imageData, withId: identifier, fileExt: "rm")
            } catch {
                return
            }
        }
        else {
            // Unsupported image/video format
            
        }
    }
    
    private func savePasteBoard(imageData: Data, withId identifier:String, fileExt: String) throws {
        // Set file URL
        let fileURL = UploadManager.shared.applicationUploadsDirectory
            .appendingPathComponent(identifier).appendingPathExtension(fileExt)

        // Deletes temporary image file if exists (incomplete previous attempt?)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
        }

        // Store pasteboard image/video data into Piwigo/Uploads directory
        do {
            print("==>> Write imageData to \(fileURL)")
            try imageData.write(to: fileURL)
        } catch let error as NSError {
            // Disk full? —> to be managed…
            throw error
        }
    }
    
    private func cachingUploadIndicesIteratingPasteBoardImages() -> (Void) {
        // For debugging purposes
        let start = CFAbsoluteTimeGetCurrent()

        // Initialise cached indexed uploads
        indexedUploadsInQueue = .init(repeating: nil, count: pasteBoardIndexSet.count)

        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = pasteBoardIndexSet.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                indexedUploadsInQueue = []
                print("Stop second operation in iteration \(i) ;-)")
                return
            }

            for index in i*step..<min((i+1)*step,pasteBoardIndexSet.count) {
                // Get image identifier
                let imageId = getIdentifierOfPasteBoardImage(at: index)
                if let upload = uploadsInQueue.first(where: { $0?.0 == imageId }) {
                    indexedUploadsInQueue[index] = upload
                }
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   indexed \(pasteBoardIndexSet.count) images by iterating fetched images in \(diff) ms")
    }

    
    // MARK: - Action Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })
        alert.addAction(cancelAction)

        // Select all images
        if selectedImages.compactMap({$0}).count + indexedUploadsInQueue.compactMap({$0}).count < pasteBoardIndexSet.count {
            let selectAction = UIAlertAction(title: NSLocalizedString("selectAll", comment: "Select All"), style: .default) { (action) in
                // Loop over all images in section to select them
                // Here, we exploit the cached local IDs
                for index in 0..<self.selectedImages.count {
                    // Images in the upload queue cannot be selected
                    if self.indexedUploadsInQueue[index] == nil {
                        self.selectedImages[index] = UploadProperties.init(localIdentifier: self.pasteBoardIdentifiers[index], category: self.categoryId)
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
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        if selectedImages.compactMap({ $0 }).count == 0 { return }
        
        // Disable button
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false
        
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
        selectedImages = .init(repeating: nil, count: pasteBoardIndexSet.count)

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

    
    // MARK: - UICollectionView - Headers & Footers
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Pasteboard header
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "PasteboardImagesHeaderReusableView", for: indexPath) as? PasteboardImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            header.configure()
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
        return pasteBoardIndexSet.count
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
        
        // Configure cell with image in pasteboard (!!!!!!!!!!! or stored in Uploads directory!!!!!!!!!!!!!!!!!)
        let identifier = pasteBoardIdentifiers[indexPath.item]
        let indexSet = IndexSet.init(integer: indexPath.item)
        if let imageData: Data = UIPasteboard.general.data(forPasteboardType: "public.image", inItemSet: indexSet)?.first, let image = UIImage.init(data: imageData) {
            cell.configure(with: image, identifier: identifier, thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))
        }
        else
        if let imageData: Data = UIPasteboard.general.data(forPasteboardType: "public.movie", inItemSet: indexSet)?.first, let image = UIImage.init(data: imageData) {
            cell.configure(with: image, identifier: identifier, thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))
        }
        
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
           indexedUploadsInQueue.count == pasteBoardIndexSet.count {
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
            let imageId = pasteBoardIdentifiers[indexPath.item] // Don't use the cache which might not be ready
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
            let imageId = pasteBoardIdentifiers[indexPath.item] // Don't use the cache which might not be ready
            
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
