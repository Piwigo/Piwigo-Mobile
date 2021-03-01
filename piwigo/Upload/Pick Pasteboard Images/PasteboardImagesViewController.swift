//
//  PasteboardImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 6 December 2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

let kClipboardPrefix = "Clipboard-"
let kClipboardImageSuffix = "-img-"
let kClipboardMovieSuffix = "-mov-"

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
    
    private let imagePlaceholder = UIImage(named: "placeholder")!
        
    // Collection of images in the pasteboard
    private var pbObjects = [PasteboardObject]()      // Objects in pasteboard

    // Cached data
    private let pendingOperations = PendingOperations()     // Operations in queue for preparing files and cache
    private var uploadsInQueue = [(String?,kPiwigoUploadState?)?]()         // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String?,kPiwigoUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    
    // Selection data
    private var selectedImages = [UploadProperties?]()                      // Array of images to upload
    private var sectionState: SelectButtonState = .none                     // To remember the state of the section
    private var imagesBeingTouched = [IndexPath]()                          // Array of indexPaths of touched images
    
    // Buttons
    private var cancelBarButton: UIBarButtonItem!       // For cancelling the selection of images
    private var uploadBarButton: UIBarButtonItem!       // for uploading selected images
    private var legendLabel = UILabel.init()            // Legend presented in the toolbar on iPhone/iOS 14+
    private var legendBarItem: UIBarButtonItem!

    private var removeUploadedImages = false


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true
        
        // We collect a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        if let uploads = uploadsProvider.fetchedResultsController.fetchedObjects {
            uploadsInQueue = uploads.map {($0.md5Sum, $0.state)}
        }
                                                                                        
        // Retrieve pasteboard object indexes and types, then create identifiers
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
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
                if UIPasteboard.general.contains(pasteboardTypes: ["public.movie"], inItemSet: indexSet) {
                    identifier = String(format: "%@%@%@%ld", kClipboardPrefix, pbDateTime, kClipboardMovieSuffix, idx)
                } else {
                    identifier = String(format: "%@%@%@%ld", kClipboardPrefix, pbDateTime, kClipboardImageSuffix, idx)
                }
                let newObject = PasteboardObject(identifier: identifier, types: types[idx])
                pbObjects.append(newObject)
                
                // Retrieve data, store in Upload folder and update cache
                startOperations(for: newObject, at: IndexPath(item: idx, section: 0))
            }
        }

        // At start, there is no image selected
        selectedImages = .init(repeating: nil, count: pbObjects.count)
        
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
        
        // Configure toolbar
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
        
        // Register app becoming active for updating the pasteboard
        name = NSNotification.Name(UIApplication.didBecomeActiveNotification.rawValue)
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
        pendingOperations.preparationQueue.cancelAllOperations()

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

        // Unregister app becoming active for updating the pasteboard
        name = NSNotification.Name(UIApplication.didBecomeActiveNotification.rawValue)
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

    
    // MARK: - Check Pasteboard Content
    /// Called by the notification center when the pasteboard content is updated
    @objc func checkPasteboard() {
        // Do nothing if the clipboard was emptied assuming that pasteboard objects are already stored
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
           let types = UIPasteboard.general.types(forItemSet: indexSet) {

            // Reinitialise cached indexed uploads, deselect images
            pbObjects = []
            indexedUploadsInQueue = .init(repeating: nil, count: indexSet.count)
            selectedImages = .init(repeating: nil, count: indexSet.count)

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
                // Movies first because objects may contain both movies and images
                if UIPasteboard.general.contains(pasteboardTypes: ["public.movie"], inItemSet: indexSet) {
                    identifier = String(format: "%@%@%@%ld", kClipboardPrefix, pbDateTime, kClipboardMovieSuffix, idx)
                } else {
                    identifier = String(format: "%@%@%@%ld", kClipboardPrefix, pbDateTime, kClipboardImageSuffix, idx)
                }
                let newObject = PasteboardObject(identifier: identifier, types: types[idx])
                pbObjects.append(newObject)
                
                // Retrieve data, store in Upload folder and update cache
                startOperations(for: newObject, at: IndexPath(item: idx, section: 0))
            }
        }
    }
    
    
    // MARK: - Prepare Image Files and Cache of Upload Requests
    private func startOperations(for pbObject: PasteboardObject, at indexPath: IndexPath) {
        switch (pbObject.state) {
        case .new:
            startPreparation(of: pbObject, at: indexPath)
        default:
            print("Do nothing")
        }
    }

    private func startPreparation(of pbObject: PasteboardObject, at indexPath: IndexPath) {
        // Has the preparation of this object already started?
        guard pendingOperations.preparationsInProgress[indexPath] == nil else {
            return
        }

        // Create an instance of the preparation method
        let preparer = ObjectPreparation(pbObject, at: indexPath.row)
      
        // Refresh the thumbnail of the cell and update upload cache
        preparer.completionBlock = {
            // Job done is operation was cancelled
            if preparer.isCancelled { return }

            // Operation completed
            self.pendingOperations.preparationsInProgress.removeValue(forKey: indexPath)

            // Update upload cache
            if let upload = self.uploadsInQueue.first(where: { $0?.0 == pbObject.md5Sum }) {
                self.indexedUploadsInQueue[indexPath.row] = upload
            }

            // Update cell image if operation was successful
            switch (pbObject.state) {
            case .stored:
                // Refresh the thumbnail of the cell
                DispatchQueue.main.async {
                    if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell {
                        cell.cellImage.image = pbObject.image
                        self.reloadInputViews()
                    }
                }
            case .failed:
                if self.pendingOperations.preparationsInProgress.isEmpty {
                    var newSetOfObjects = [PasteboardObject]()
                    for index in 0..<self.pbObjects.count {
                        switch self.pbObjects[index].state {
                        case .stored, .ready:
                            newSetOfObjects.append(self.pbObjects[index])
                        case .failed:
                            self.indexedUploadsInQueue.remove(at: index)
                        default:
                            print("Do nothing")
                        }
                    }
                    self.pbObjects = newSetOfObjects
                }
            default:
              NSLog("do nothing")
            }
                
            // If all images are ready:
            /// - refresh section to display the select button
            /// - restart UplaodManager activity
            if self.pendingOperations.preparationsInProgress.isEmpty {
                DispatchQueue.main.async {
                    self.localImagesCollection.reloadSections([0])
                }
                if UploadManager.shared.isPaused {
                    UploadManager.shared.isPaused = false
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.findNextImageToUpload()
                    }
                }
            }
        }
        
        // Add the operation to help keep track of things
        pendingOperations.preparationsInProgress[indexPath] = preparer
        
        // Add the operation to the download queue
        pendingOperations.preparationQueue.addOperation(preparer)
    }

    
    // MARK: - Actions Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })
        alert.addAction(cancelAction)

        // Select all images
        if selectedImages.compactMap({$0}).count + indexedUploadsInQueue.compactMap({$0}).count < pbObjects.count {
            let selectAction = UIAlertAction(title: NSLocalizedString("selectAll", comment: "Select All"), style: .default) { (action) in
                // Loop over all images in section to select them
                // Here, we exploit the cached local IDs
                for index in 0..<self.selectedImages.count {
                    // Images in the upload queue cannot be selected
                    if self.indexedUploadsInQueue[index] == nil {
                        self.selectedImages[index] = UploadProperties.init(localIdentifier: self.pbObjects[index].identifier, category: self.categoryId)
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
        selectedImages = .init(repeating: nil, count: pbObjects.count)

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
                    if indexedUploadsInQueue.count < indexPath.item + 1 {
                        // Use non-indexed data (might be quite slow)
                        if let _ = uploadsInQueue.firstIndex(where: { $0?.0 == cell.md5sum }) { return }
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
        if !pendingOperations.preparationsInProgress.isEmpty {
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
            let selectState = pendingOperations.preparationsInProgress.isEmpty ? sectionState : .none
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
        return pbObjects.count
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
        let identifier = pbObjects[indexPath.item].identifier

        // Get thumbnail of image if available
        var image: UIImage! = imagePlaceholder
        if [.stored, .ready].contains(pbObjects[indexPath.row].state) {
            image = pbObjects[indexPath.row].image
            cell.md5sum = pbObjects[indexPath.row].md5Sum
        }
        else if let data = UIPasteboard.general.data(forPasteboardType: "public.image",
                                                       inItemSet: IndexSet.init(integer: indexPath.row))?.first {
            image = UIImage.init(data: data) ?? imagePlaceholder
            cell.md5sum = ""
        }

        // Configure cell
        let thumbnailSize = ImagesCollection.imageSize(for: self.localImagesCollection, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)
        cell.configure(with: image, identifier: identifier, thumbnailSize: CGFloat(thumbnailSize))
        
        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        // Cell state
        if pendingOperations.preparationsInProgress.isEmpty,
           indexedUploadsInQueue.count == pbObjects.count {
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
            let md5Sum = pbObjects[indexPath.item].md5Sum
            if let upload = uploadsInQueue.first(where: { $0?.0 == md5Sum }) {
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
        let localIdentifier =  (notification.userInfo?["localIdentifier"] ?? "") as! String
        let progressFraction = (notification.userInfo?["progressFraction"] ?? Float(0.0)) as! Float
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        for indexPath in indexPathsForVisibleItems {
            if let cell = localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell,
               cell.localIdentifier == localIdentifier {
                cell.setProgress(progressFraction, withAnimation: true)
                return
            }
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell else {
            return
        }

        // Images in the upload queue cannot be selected
        if indexedUploadsInQueue.count < indexPath.item + 1 {
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

        // Update state of Select button if needed
        updateSelectButton(completion: {
            self.localImagesCollection.reloadSections(IndexSet(integer: 0))
        })
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
                    selectedImages[index] = UploadProperties.init(localIdentifier: pbObjects[index].identifier, category: self.categoryId)
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
                        if let photoResize = uploadParameters["photoResize"] as? Int16 {
                            updatedRequest.photoResize = photoResize
                        }
                    } else {
                        updatedRequest.photoResize = 100
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
        }
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
            // Add upload request to cache and update cell
            if let upload:Upload = anObject as? Upload {
                // Append upload to non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[index] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                } else {
                    uploadsInQueue.append((upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)))
                }
                
                // Get index of selected image, deselect it and add request to cache
                if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                    // Deselect image
                    selectedImages[indexOfUploadedImage] = nil
                    // Add upload request to cache
                    indexedUploadsInQueue[indexOfUploadedImage] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                
                // Update corresponding cell
                updateCell(for: upload)
            }
        case .delete:
//            print("••• LocalImagesViewController controller:delete...")
            // Delete upload request from cache and update cell
            if let upload:Upload = anObject as? Upload {
                // Remove upload from non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue.remove(at: index)
                }
                // Remove image from indexed upload queue
                if let indexOfUploadedImage = indexedUploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
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
            // Update upload request and cell
            if let upload:Upload = anObject as? Upload {
                // Update upload in non-indexed upload queue
                if let indexInQueue = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[indexInQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update upload in indexed upload queue
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
        DispatchQueue.main.async {
            // Get indices of visible items
            let indexPathsForVisibleItems = self.localImagesCollection.indexPathsForVisibleItems
            
            // Loop over the visible items
            for indexPath in indexPathsForVisibleItems {
                // Identify cell to be updated (if presented)
                if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? PasteboardImageCollectionViewCell,
                   cell.localIdentifier == upload.localIdentifier {
                    // Update cell
                    cell.selectedImage.isHidden = true
                    switch upload.state {
                    case .waiting, .preparing, .prepared:
                        cell.cellWaiting = true
                    case .uploading, .uploaded, .finishing:
                        cell.cellUploading = true
                    case .finished, .moderated:
                        cell.cellUploaded = true
                    case .preparingFail, .preparingError, .formatError, .uploadingError, .finishingError:
                        cell.cellFailed = true
                    }
                    cell.reloadInputViews()
                    // The section will be refreshed only if the button content needs to be changed
                    self.updateSelectButton(completion: {
                        self.localImagesCollection.reloadSections(IndexSet(integer: 0))
                    })
                    return
                }
            }
        }
    }
}


extension AVURLAsset {
    func extractedImage() -> UIImage! {
        var image: UIImage! = UIImage(named: "placeholder")!
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
