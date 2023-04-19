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

class PasteboardImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, PasteboardImagesHeaderDelegate, UploadSwitchDelegate {
    
    // MARK: - Core Data Providers
    var savingContext: NSManagedObjectContext!
    private lazy var uploadProvider: UploadProvider = {
        let provider = UploadProvider()
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
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        return fetchRequest
    }()

    public lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchUploadRequest,
                                                 managedObjectContext: self.savingContext,
                                                 sectionNameKeyPath: nil,
                                                 cacheName: nil)
        uploads.delegate = self
        return uploads
    }()
    

    // MARK: - View
    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var userHasUploadRights: Bool = false

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
    
    private let imagePlaceholder = UIImage(named: "placeholder")!
        
    // Collection of images in the pasteboard
    private var pbObjects = [PasteboardObject]()      // Objects in pasteboard

    // Cached data
    private let pendingOperations = PendingOperations()     // Operations in queue for preparing files and cache
    private var indexedUploadsInQueue = [(String?,String?,pwgUploadState?)?]()  // Arrays of uploads at indices of corresponding image
    
    // Selection data
    private var selectedImages = [UploadProperties?]()                  // Array of images to upload
    private var sectionState: SelectButtonState = .none                 // To remember the state of the section
    private var imagesBeingTouched = [IndexPath]()                      // Array of indexPaths of touched images
    
    // Buttons
    private var cancelBarButton: UIBarButtonItem!       // For cancelling the selection of images
    private var uploadBarButton: UIBarButtonItem!       // for uploading selected images
    private var actionBarButton: UIBarButtonItem!       // For allowing to re-upload images
    private var legendLabel = UILabel()                 // Legend presented in the toolbar on iPhone/iOS 14+
    private var legendBarItem: UIBarButtonItem!

    private var reUploadAllowed = false


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // We provide a non-indexed list of images in the upload queue
        // so that we can at least show images in upload queue at start
        // and prevent their selection
        do {
            try uploads.performFetch()
        } catch {
            print("Error: \(error)")
        }

        // Retrieve pasteboard object indexes and types, then create identifiers
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: [kUTTypeImage as String,
                                                                             kUTTypeMovie as String]),
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
                if UIPasteboard.general.contains(pasteboardTypes: [kUTTypeMovie as String], inItemSet: indexSet) {
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
        
        // Collection flow layout of images
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.sectionHeadersPinToVisibleBounds = true

        // Collection view identifier
        localImagesCollection.accessibilityIdentifier = "Pasteboard"
        
        // Navigation bar
        navigationController?.toolbar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.accessibilityIdentifier = "PasteboardImagesNav"

        // The cancel button is used to cancel the selection of images to upload (left side of navigation bar)
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
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar appearance
        let navigationBar = navigationController?.navigationBar
        navigationController?.view.backgroundColor = UIColor.piwigoColorBackground()
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = UIColor.piwigoColorOrange()

        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationBar?.titleTextAttributes = attributes
        navigationBar?.prefersLargeTitles = false

        if #available(iOS 13.0, *) {
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
            barAppearance.titleTextAttributes = attributes
            navigationItem.standardAppearance = barAppearance
            navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
            navigationItem.scrollEdgeAppearance = barAppearance
            navigationBar?.prefersLargeTitles = false
        }

        // Case of an iPhone
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
        }

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
                                               name: .pwgPaletteChanged, object: nil)
        
        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: .pwgUploadProgress, object: nil)
        
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
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
        
        // Unregister upload progress
        NotificationCenter.default.removeObserver(self, name: .pwgUploadProgress, object: nil)

        // Unregister app becoming active for updating the pasteboard
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
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
                    // The action button proposes:
                    /// - to allow/disallow  re-uploading photos,
                    if let submenu = getMenuForReuploadingPhotos() {
                        let menu = UIMenu(title: "", children: [submenu].compactMap({$0}))
                        actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
                        navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                    }

                    // Present the "Upload" button in the toolbar
                    legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                    legendBarItem = UIBarButtonItem(customView: legendLabel)
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
                    legendBarItem = UIBarButtonItem(customView: legendLabel)
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

    private func updateActionButton() {
        // Change button icon or content
        if #available(iOS 14, *) {
            // Update action button
            // The action button proposes:
            /// - to allow/disallow re-uploading photos,
            actionBarButton.menu = UIMenu(title: "", children: [getMenuForReuploadingPhotos()].compactMap({$0}))
        } else {
            // Fallback on earlier versions.
        }
    }

    
    // MARK: - Check Pasteboard Content
    /// Called by the notification center when the pasteboard content is updated
    @objc func checkPasteboard() {
        // Do nothing if the clipboard was emptied assuming that pasteboard objects are already stored
        if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: [kUTTypeImage as String, "public.movie"]),
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
                if UIPasteboard.general.contains(pasteboardTypes: [kUTTypeMovie as String], inItemSet: indexSet) {
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
            // Job done if operation was cancelled
            if preparer.isCancelled { return }

            // Operation completed
            self.pendingOperations.preparationsInProgress.removeValue(forKey: indexPath)

            // Update upload cache
            if let upload = (self.uploads.fetchedObjects ?? []).first(where: {$0.md5Sum == pbObject.md5Sum}) {
                self.indexedUploadsInQueue[indexPath.row] = (upload.localIdentifier, upload.md5Sum, upload.state)
            }

            // Update cell image if operation was successful
            switch (pbObject.state) {
            case .stored:
                // Refresh the thumbnail of the cell
                DispatchQueue.main.async {
                    if let cell = self.localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
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
                    if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
                        header.setButtonTitle(forState: .select)
                    }
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

    private func getUploadStateOfImage(at index: Int,
                                       for cell: LocalImageCollectionViewCell) -> pwgUploadState? {
        var state: pwgUploadState? = nil
        if pendingOperations.preparationsInProgress.isEmpty,
           index < indexedUploadsInQueue.count {
            // Indexed uploads available
            state = indexedUploadsInQueue[index]?.2
        } else {
            // Use non-indexed data (might be quite slow)
            state = (uploads.fetchedObjects ?? []).first(where: { $0.md5Sum == cell.md5sum })?.state
        }
        return state
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
                        self.selectedImages[index] = UploadProperties(localIdentifier: self.pbObjects[index].identifier,
                                                                      category: self.categoryId)
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
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
//        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }

    
    // MARK: - Re-upload Images

    @available(iOS 14, *)
    private func getMenuForReuploadingPhotos() -> UIMenu? {
        
        // Check if there are uploaded photos to re-upload
        if !canReUploadImages() { return nil }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: NSLocalizedString("localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { _ in
            self.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "Re-upload"

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
        if reUploadAllowed { return }
        
        // Deselect already uploaded photos if needed
        var didChangeSelection = false
        if pendingOperations.preparationsInProgress.isEmpty,
           selectedImages.count < indexedUploadsInQueue.count {
            for index in 0..<selectedImages.count {
                // Indexed uploads available
                if let upload = indexedUploadsInQueue[index],
                   [.finished, .moderated].contains(upload.2) {
                    // Deselect cell
                    selectedImages[index] = nil
                    didChangeSelection = true
                }
            }
        } else {
            // Use non-indexed data (might be quite slow)
            let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
            for index in 0..<selectedImages.count {
                if let localIdentifier = selectedImages[index]?.localIdentifier,
                   let _ = completed.firstIndex(where: { $0.localIdentifier == localIdentifier }) {
                    selectedImages[index] = nil
                    didChangeSelection = true
                }
            }
        }
        
        // Refresh collection view if necessary
        if didChangeSelection {
            self.updateNavBar()
            self.localImagesCollection.reloadData()
        }
    }
    
    private func canReUploadImages() -> Bool {
        // Don't provide access to the Trash button until the preparation work is not done
        if !pendingOperations.preparationsInProgress.isEmpty { return false }

        // Check if there are uploaded photos to delete
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let _ = completed.first(where: {$0.md5Sum == indexedUploads[index].1}) {
                return true
            }
        }
        return false
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

            // Can the user create tags?
            if NetworkVars.hasAdminRights || userHasUploadRights {
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
        // Clear list of selected images
        selectedImages = .init(repeating: nil, count: pbObjects.count)

        // Update navigation bar
        updateNavBar()

        // Deselect visible cells
        localImagesCollection.visibleCells.forEach { cell in
            if let cell = cell as? LocalImageCollectionViewCell {
                cell.update(selected: false)
            }
        }
        
        // Update button
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? PasteboardImagesHeaderReusableView {
                header.setButtonTitle(forState: .select)
            }
        }
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

            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Get upload state of image
                let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)

                // Update the selection state
                if let _ = selectedImages[indexPath.item] {
                    selectedImages[indexPath.item] = nil
                    cell.update(selected: false, state: uploadState)
                } else {
                    // Can we upload or re-upload this image?
                    if (uploadState == nil) || reUploadAllowed {
                        // Select the cell
                        selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                          category: categoryId)
                        cell.update(selected: true, state: uploadState)
                    }
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

    func updateSelectButton() {
        
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: 0)

        // Job done if there is no image presented
        if nberOfImagesInSection == 0 {
            sectionState = .none
            return
        }
        
        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages[0..<nberOfImagesInSection].compactMap{ $0 }.count
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            sectionState = .deselect
            return
        }

        // Can we calculate the number of images already in the upload queue?
        if pendingOperations.preparationsInProgress.isEmpty == false {
            // Keep Select button disabled
            sectionState = .none
            return
        }

        // Number of images already in the upload queue
        var nberOfImagesOfSectionInUploadQueue = 0
        if reUploadAllowed == false {
            nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue[0..<nberOfImagesInSection]
                                                    .compactMap{ $0 }.count
        }

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already downloaded
            sectionState = .none
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            sectionState = .deselect
        } else {
            // Not all images are either selected or in the upload queue
            sectionState = .select
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
            
            // Configure the header
            updateSelectButton()
            header.configure(with: sectionState)
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
        return UIEdgeInsets(top: 10, left: AlbumUtilities.kImageMarginsSpacing,
                            bottom: 10, right: AlbumUtilities.kImageMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .popup))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .popup))
    }

    
    // MARK: - UICollectionView - Rows
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Number of items depends on image sort type and date order
        return pbObjects.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(AlbumUtilities.imageSize(forView: collectionView, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: .popup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
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
        else if let data = UIPasteboard.general.data(forPasteboardType: kUTTypeImage as String,
                                                     inItemSet: IndexSet(integer: indexPath.row))?.first {
            image = UIImage(data: data) ?? imagePlaceholder
            cell.md5sum = ""
        }

        // Configure cell
        let thumbnailSize = AlbumUtilities.imageSize(forView: self.localImagesCollection, imagesPerRowInPortrait: AlbumVars.shared.thumbnailsPerRowInPortrait, collectionType: .popup)
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
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)
        cell.update(selected: selectedImages[indexPath.item] != nil, state: uploadState)

        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let visibleCells = localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
           let localIdentifier =  notification.userInfo?["localIdentifier"] as? String, !localIdentifier.isEmpty,
           let cell = visibleCells.first(where: {$0.localIdentifier == localIdentifier}),
           let progressFraction = notification.userInfo?["progressFraction"] as? Float {
            cell.setProgress(progressFraction, withAnimation: true)
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Get upload state of image
        let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)

        // Update cell and selection
        if let _ = selectedImages[indexPath.item] {
            // Deselect the cell
            selectedImages[indexPath.item] = nil
            cell.update(selected: false, state: uploadState)
        } else {
            // Can we upload or re-upload this image?
            if (uploadState == nil) || reUploadAllowed {
                // Select the image
                selectedImages[indexPath.item] = UploadProperties(localIdentifier: cell.localIdentifier,
                                                                  category: categoryId)
                cell.update(selected: true, state: uploadState)
            }
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton()
        if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
            header.setButtonTitle(forState: sectionState)
        }
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
                    selectedImages[index] = UploadProperties(localIdentifier: pbObjects[index].identifier,
                                                             category: self.categoryId)
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

        // Select or deselect visible cells (only one section shown)
        localImagesCollection.indexPathsForVisibleItems.forEach { indexPath in
            // Get cell at index path
            if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                // Select or deselect the cell
                let uploadState = getUploadStateOfImage(at: indexPath.item, for: cell)
                cell.update(selected: sectionState == .deselect, state: uploadState)
            }
        }
        
        // Update button (only one section shown)
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let header = header as? PasteboardImagesHeaderReusableView {
                header.setButtonTitle(forState: sectionState)
            }
        }
    }


    // MARK: - UploadSwitchDelegate Methods
    @objc func didValidateUploadSettings(with imageParameters: [String : Any], _ uploadParameters: [String:Any]) {
        // Retrieve common image parameters and upload settings
        for index in 0..<selectedImages.count {
            guard var updatedRequest = selectedImages[index] else { continue }
                
            // Image parameters
            if let imageTitle = imageParameters["title"] as? String {
                updatedRequest.imageTitle = imageTitle
            }
            if let author = imageParameters["author"] as? String {
                updatedRequest.author = author
            }
            if let privacy = imageParameters["privacy"] as? pwgPrivacy {
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
                } else {
                    updatedRequest.photoMaxSize = 5 // i.e. 4K
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
        
        // Add selected images to upload queue
        UploadManager.shared.backgroundQueue.async {
            self.uploadProvider.importUploads(from: self.selectedImages.compactMap({$0})) { error in
                guard let error = error else {
                    // Restart UploadManager activities
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.findNextImageToUpload()
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
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

extension PasteboardImagesViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            print("••> PasteboardImagesViewController: insert pending upload request…")
            // Add upload request to cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Get index of selected image, deselect it and add request to cache
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
                // Add upload request to cache
                indexedUploadsInQueue[index] = (upload.localIdentifier, upload.md5Sum, upload.state)
            }
            
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .delete:
            print("••> PasteboardImagesViewController: delete pending upload request…")
            // Delete upload request from cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Remove image from indexed upload queue
            if let index = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[index] = nil
            }
            // Remove image from selection if needed
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .move:
            assertionFailure("••> PasteboardImagesViewController: Unexpected move!")
        case .update:
            print("••• PasteboardImagesViewController controller:update...")
            // Update upload request and cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Update upload in indexed upload queue
            if let indexOfUploadedImage = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[indexOfUploadedImage]?.1 = upload.md5Sum
                indexedUploadsInQueue[indexOfUploadedImage]?.2 = upload.state
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        @unknown default:
            assertionFailure("••> PasteboardImagesViewController: unknown NSFetchedResultsChangeType!")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("••• PasteboardImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateNavBar()
    }

    func updateCellAndSectionHeader(for upload: Upload) {
        DispatchQueue.main.async {
            if let visibleCells = self.localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
               let cell = visibleCells.first(where: {$0.localIdentifier == upload.localIdentifier}) {
                // Update cell
                cell.update(selected: false, state: upload.state)
                cell.reloadInputViews()

                // The section will be refreshed only if the button content needs to be changed
                self.updateSelectButton()
                if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: 0)) as? PasteboardImagesHeaderReusableView {
                    header.setButtonTitle(forState: self.sectionState)
                }
            }
        }
    }
}


// MARK: -
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
