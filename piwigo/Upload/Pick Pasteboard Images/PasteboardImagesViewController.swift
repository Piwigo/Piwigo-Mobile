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

    // Collection of images in the pasteboard
    @objc func setPasteBoardImages(_ pasteboardImages: [UIImage]) {
        _pasteBoardImages = pasteboardImages
    }
    private var _pasteBoardImages = [UIImage]()
    private var pasteBoardImages: [UIImage] {
        get {
            return _pasteBoardImages
        }
        set(pasteBoardImages) {
            _pasteBoardImages = pasteBoardImages
        }
    }

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
        
    private let queue = OperationQueue()                                    // Queue used to cache things
    private var uploadsInQueue = [(String?,kPiwigoUploadState?)?]()         // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String?,kPiwigoUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    private var selectedImages = [UploadProperties?]()                                  // Array of images to upload
    private var imagesBeingTouched = [IndexPath]()                                      // Array of indexPaths of touched images
    
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

        // At start, there is no image selected
        selectedImages = .init(repeating: nil, count: pasteBoardImages.count)
        
        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        if let uploads = uploadsProvider.fetchedResultsController.fetchedObjects {
            uploadsInQueue = uploads.map {($0.localIdentifier, $0.state)}
        }
                                                                                        
        // Cache images in upload queue in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.indexUploads()
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
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Register upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress), name: name2, object: nil)
        
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

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
        
        // Unregister upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name2, object: nil)

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

    
    // MARK: - Caching Images in Upload Queue
    
    // Sorts images by months, weeks and days in the background,
    // initialise the array of selected sections and enable the choices
    private func indexUploads() -> Void {

        // Caching upload request indices
        let cacheOperation = BlockOperation()
        if pasteBoardImages.count > 10 * uploadsInQueue.count {
            // By iterating uploads in queue
            cacheOperation.addExecutionBlock {
                self.cachingUploadIndicesIteratingUploadsInQueue()
            }
        } else {
            // By iterating fetched images
            cacheOperation.addExecutionBlock {
                self.cachingUploadIndicesIteratingPasteBoardImages()
            }
        }
        cacheOperation.completionBlock = {
            // Allow action button
            DispatchQueue.main.async {
                self.actionBarButton?.isEnabled = true
            }
        }

        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = .max   // Make it a serial queue for debugging with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([cacheOperation], waitUntilFinished: true)

        // Enable Select buttons
        DispatchQueue.main.async {
            self.localImagesCollection.reloadData()
        }
        
        // Restart UplaodManager activity if all images are already in the upload queue
        if self.indexedUploadsInQueue.compactMap({$0}).count == self.pasteBoardImages.count,
           UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    private func cachingUploadIndicesIteratingPasteBoardImages() -> (Void) {
        // Loop over all images
        let start = CFAbsoluteTimeGetCurrent()
        indexedUploadsInQueue = .init(repeating: nil, count: pasteBoardImages.count)
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = pasteBoardImages.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                indexedUploadsInQueue = []
                print("Stop second operation in iteration \(i) ;-)")
                return
            }

//            for index in i*step..<min((i+1)*step,pasteBoardImages.count) {
//                // Get image identifier
//                let imageId = pasteBoardImages[index].localIdentifier
//                if let upload = uploadsInQueue.first(where: { $0?.0 == imageId }) {
//                    indexedUploadsInQueue[index] = upload
//                }
//            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   indexed \(pasteBoardImages.count) images by iterating fetched images in \(diff) ms")
    }

    private func cachingUploadIndicesIteratingUploadsInQueue() -> (Void) {
        // Loop over all images
        let start = CFAbsoluteTimeGetCurrent()
        indexedUploadsInQueue = .init(repeating: nil, count: pasteBoardImages.count)

        // Determine fetched images already in upload queue
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false

        // Caching fetched images already in upload queue
        if uploadsInQueue.count > 0 {
            let step = 1_00    // Check if this operation was cancelled every 100 iterations
            let iterations = uploadsInQueue.count / step
            for i in 0...iterations {
                // Continue with this operation?
                if queue.operations.first!.isCancelled {
                    indexedUploadsInQueue = []
                    print("Stop second operation in iteration \(i) ;-)")
                    return
                }

                for index in i*step..<min((i+1)*step,uploadsInQueue.count) {
                    // Get image identifier
                    if let imageId = uploadsInQueue[index]?.0 {
                        fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", imageId)
//                        if let asset = PHAsset.fetchAssets(with: fetchOptions).firstObject {
//                            let idx = pasteBoardImages.index(of: asset)
//                            indexedUploadsInQueue[idx] = uploadsInQueue[index]
//                        }
                    }
                }
            }
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("   cached \(uploadsInQueue.count) images by iterating uploads in queue in \(diff) ms")
    }

    
    // MARK: - Action Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })
        alert.addAction(cancelAction)

        // Select all images
        if selectedImages.compactMap({$0}).count + indexedUploadsInQueue.compactMap({$0}).count < pasteBoardImages.count {
            let selectAction = UIAlertAction(title: NSLocalizedString("selectAll", comment: "Select All"), style: .default) { (action) in
                // Loop over all images in section to select them (Select 70356 images of section 0 took 150.6 ms)
                // Here, we exploit the cached local IDs
                for index in 0..<self.selectedImages.count {
                    // Images in the upload queue cannot be selected
                    if self.indexedUploadsInQueue[index] == nil {
//                        self.selectedImages[index] = UploadProperties.init(localIdentifier: self.pasteBoardImages[index].localIdentifier, category: self.categoryId)
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
        
        // Delete uploaded photos
        let completedUploads = indexedUploadsInQueue.compactMap({$0}).count
        if completedUploads > 0 {
            let titleDelete = completedUploads > 1 ? String(format: NSLocalizedString("deleteCategory_allImages", comment: "Delete %@ Photos"), NumberFormatter.localizedString(from: NSNumber.init(value: completedUploads), number: .decimal)) : NSLocalizedString("deleteSingleImage_title", comment: "Delete Photo")
            let deleteAction = UIAlertAction(title: titleDelete, style: .destructive, handler: { action in
                // Delete uploaded images (fetch on the main queue)
                let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
                if let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects {
                    let completedUploads = allUploads.filter({ ($0.state == .finished) || ($0.state == .moderated) })
                    var uploadIDsToDelete = [NSManagedObjectID](), imagesToDelete = [String]()
                    for index in 0..<indexedUploads.count {
                        if let upload = completedUploads.first(where: {$0.localIdentifier == indexedUploads[index].0}) {
                            uploadIDsToDelete.append(upload.objectID)
                            imagesToDelete.append(indexedUploads[index].0!)
                        }
                    }
                    UploadManager.shared.delete(uploadedImages: imagesToDelete, with: uploadIDsToDelete)
                }
            })
            alert.addAction(deleteAction)
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
        selectedImages = .init(repeating: nil, count: pasteBoardImages.count)

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
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
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
        return pasteBoardImages.count
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
            return LocalImageCollectionViewCell()
        }
        
        // Get image asset, index depends on image sort type and date order
        let imageAsset = pasteBoardImages[indexPath.item].imageAsset

        // Configure cell with image asset
        cell.configure(with: pasteBoardImages[indexPath.item], identifier: "test", thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))

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
           indexedUploadsInQueue.count == pasteBoardImages.count {
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
//            if let upload = uploadsInQueue.first(where: { $0?.0 == imageAsset.localIdentifier }) {
//                switch upload?.1 {
//                case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
//                    cell.cellWaiting = true
//                case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
//                    cell.cellUploading = true
//                case .finished, .moderated:
//                    cell.cellUploaded = true
//                case .none:
//                    cell.cellSelected = false
//                }
//            } else {
//                cell.cellSelected = selectedImages[index] != nil
//            }
        }
        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        let localIdentifier =  (notification.userInfo?["localIndentifier"] ?? "") as! String
        let progressFraction = (notification.userInfo?["progressFraction"] ?? Float(0.0)) as! Float
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        for indexPath in indexPathsForVisibleItems {
//            let index = getImageIndex(for: indexPath)
//            let imageId = pasteBoardImages[index].localIdentifier // Don't use the cache which might not be ready
//            if imageId == localIdentifier {
//                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
//                    cell.setProgress(progressFraction, withAnimation: true)
//                    break
//                }
//            }
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
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
//            let indexOfUploadedImage = getImageIndex(for: indexPath)
//            let imageId = pasteBoardImages[indexOfUploadedImage].localIdentifier // Don't use the cache which might not be ready
            
            // Identify cell to be updated (if presented)
//            if imageId == upload.localIdentifier {
//                // Update visible cell
//                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
//                    cell.selectedImage.isHidden = true
//                    switch upload.state {
//                    case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
//                        cell.cellWaiting = true
//                    case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
//                        cell.cellUploading = true
//                    case .finished, .moderated:
//                        cell.cellUploaded = true
//                    }
//                    cell.reloadInputViews()
//                    return
//                }
//            }
        }
    }
}
