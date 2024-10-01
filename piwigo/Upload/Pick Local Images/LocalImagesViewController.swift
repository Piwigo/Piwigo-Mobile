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
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
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

    private var uploadsToDelete = [Upload]()
    lazy var imageCellSize: CGSize = getImageCellSize()
    

    // MARK: - View
    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var imageCollectionId: String = String()

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
    
    @IBOutlet weak var sortOptionsView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    
    var cancelBarButton: UIBarButtonItem!           // For cancelling the selection of images
    var uploadBarButton: UIBarButtonItem!           // for uploading selected images
    var trashBarButton: UIBarButtonItem!            // For deleting uploaded images on iPhone until iOS 13
                                                    //                              on iPad (all iOS)
    var actionBarButton: UIBarButtonItem!           // iPhone until iOS 13:
                                                    //  - for reversing the sort order
                                                    // iPhone as from iOS 14:
                                                    //  - for reversing the sort order
                                                    //  - for grouping by day, week or month (or not)
                                                    //  - for deleting uploaded images
                                                    //  - for selecting images in the Photo Library
                                                    //  - for allowing to re-upload images
                                                    // iPad until iOS 13:
                                                    //  - for reversing the sort order
                                                    // iPad as from iOS 14:
                                                    //  - for reversing the sort order
                                                    //  - for grouping by day, week or month (or not)
                                                    //  - for selecting images in the Photo Library
                                                    //  - for allowing to re-upload images
    private var legendLabel = UILabel()             // Legend presented in the toolbar on iPhone/iOS 14+
    private var legendBarItem: UIBarButtonItem!

    var reUploadAllowed = false


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

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
        
        // Collection view
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.sectionHeadersPinToVisibleBounds = true
        localImagesCollection?.register(UINib(nibName: "LocalImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "LocalImageCollectionViewCell")
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
            /// - to choose one of the 4 grouping options,
            /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library (iOS 14+),
            /// - to allow/disallow re-uploading photos,
            /// - and to delete photos already uploaded to the Piwigo server on iPhone only.
            var children: [UIMenuElement?] = [swapOrderAction(), groupMenu(),
                                              selectPhotosMenu(), reUploadAction()]
            if UIDevice.current.userInterfaceIdiom == .phone {
                children.append(deleteMenu())
            }
            let menu = UIMenu(title: "", children: children.compactMap({$0}))
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
                coordinator.animate(alongsideTransition: { context in
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
            UploadManager.shared.findNextImageToUpload()
        }
    }
    
    deinit {
        // Unregister Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Navigation Bar & Buttons
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
                    updateActionButton()
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                    
                    // Present the "Upload" button in the toolbar
                    legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                    legendBarItem = UIBarButtonItem(customView: legendLabel)
                    toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
                } else {
                    // Title
                    title = NSLocalizedString("selectImages", comment: "Select Photos")

                    // Present the button for swaping the sort order
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
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
                    updateActionButton()
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                } else {
                    // Update the number of selected photos in the navigation bar
                    title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

                    // Present buttons according to the context
                    if canDeleteUploadedImages() || canDeleteSelectedImages() {
                        trashBarButton.isEnabled = true
                        navigationItem.rightBarButtonItems = [uploadBarButton, trashBarButton].compactMap { $0 }
                    } else {
                        trashBarButton.isEnabled = false
                        navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                    }
                }
            }
        }

        // Set buttons on the right side on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Update the number of selected photos in the navigation bar
            title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))

            if canDeleteUploadedImages() || canDeleteSelectedImages() {
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
    
    func updateActionButton() {
        // Change button icon or content
        if #available(iOS 14, *) {
            // Update action button
            // The action button proposes:
            /// - to swap between ascending and descending sort orders,
            /// - to choose one of the 4 sort options
            /// - to select new photos in the Photo Library if the user did not grant full access to the Photo Library (iOS 14+),
            /// - to allow/disallow re-uploading photos,
            /// - to delete photos already uploaded to the Piwigo server on iPhone only.
            var children: [UIMenuElement?] = [swapOrderAction(), groupMenu(),
                                              selectPhotosMenu(), reUploadAction()]
            if UIDevice.current.userInterfaceIdiom == .phone {
                children.append(deleteMenu())
            }
            let updatedMenu = actionBarButton?.menu?.replacingChildren(children.compactMap({$0}))
            actionBarButton?.menu = updatedMenu
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

    
    // MARK: - Swap Sort Order
    /// Icons used on iPhone and iPad on iOS 13 and earlier
    private func getSwapSortImage() -> UIImage {
        switch UploadVars.localImagesSort {
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
        switch UploadVars.localImagesSort {
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
    func swapOrderAction() -> UIAction {
        // Initialise menu items
        let swapOrder: UIAction!
        switch UploadVars.localImagesSort {
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
        return swapOrder
    }

    @objc func swapSortOrder() {
        // Swap between the two sort options
        switch UploadVars.localImagesSort {
        case .dateCreatedDescending:
            UploadVars.localImagesSort = .dateCreatedAscending
        case .dateCreatedAscending:
            UploadVars.localImagesSort = .dateCreatedDescending
        default:
            return
        }

        // Change button icon and refresh collection
        reloadCollectionAndUpdateMenu()
    }
    
    private func reloadCollectionAndUpdateMenu() {
        // May be called from background queue
        DispatchQueue.main.async {
            self.updateActionButton()
            self.updateNavBar()
            self.localImagesCollection.reloadData()
        }
    }

    
    // MARK: - Group Images
    @available(iOS 14, *)
    func groupMenu() -> UIMenu {
        // Create a menu for selecting how to group images
        let children = [byDayAction(), byWeekAction(), byMonthAction(), byNoneAction()].compactMap({$0})
        return UIMenu(title: NSLocalizedString("categoryView_group", comment: "Group Images By…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.images.group.main"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    @available(iOS 14, *)
    func byDayAction() -> UIAction {
        let isActive = sortType == .day
        let action = UIAction(title: NSLocalizedString("Day", comment: "Day"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.day"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .day
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByDay"
        return action
    }
    
    @available(iOS 14, *)
    func byWeekAction() -> UIAction {
        let isActive = sortType == .week
        let action = UIAction(title: NSLocalizedString("Week", comment: "Week"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.week"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .week
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByWeek"
        return action
    }
    
    @available(iOS 14, *)
    func byMonthAction() -> UIAction {
        let isActive = sortType == .month
        let action = UIAction(title: NSLocalizedString("Month", comment: "Month"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.month"),
                              handler: { [self] action in
            // Should sorting be changed?
            if isActive { return }
            
            // Should image grouping be changed?
            self.sortType = .month
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByMonth"
        return action
    }
    
    @available(iOS 14, *)
    func byNoneAction() -> UIAction {
        let isActive = sortType == .none
        let action = UIAction(title: NSLocalizedString("None", comment: "None"),
                              image: isActive ? UIImage(systemName: "checkmark") : nil,
                              identifier: UIAction.Identifier("org.piwigo.images.group.none"),
                              handler: { [self] action in
            // Should image grouping be changed?
            if isActive { return }
            
            // Change image grouping
            self.sortType = .none
            self.reloadCollectionAndUpdateMenu()
        })
        action.accessibilityIdentifier = "groupByNone"
        return action
    }

    @IBAction func didChangeGroupOption(_ sender: UISegmentedControl) {
        // Did select new group option [Day, Week, Month, None in one section]
        sortType = SectionType(rawValue: sender.selectedSegmentIndex) ?? .none
                
        // Change button icon and refresh collection
        reloadCollectionAndUpdateMenu()
    }
    

    // MARK: - Select Camera Roll Images
    @available(iOS 14, *)
    private func selectPhotosMenu() -> UIMenu? {
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
    

    // MARK: - Re-Upload Photos
    @available(iOS 14, *)
    private func reUploadAction() -> UIAction? {
        // Check if there are already uploaded photos
        if !canDeleteUploadedImages() { return nil }
        
        // Propose option for re-uploading photos
        let reUpload = UIAction(title: NSLocalizedString("localImages_reUploadTitle", comment: "Re-upload"),
                                image: reUploadAllowed ? UIImage(systemName: "checkmark") : nil, handler: { _ in
            self.swapReuploadOption()
        })
        reUpload.accessibilityIdentifier = "org.piwigo.reupload"
        return reUpload
    }
    
    private func swapReuploadOption() {
        // Swap "Re-upload" option
        reUploadAllowed = !(self.reUploadAllowed)
        updateActionButton()

        // Refresh section buttons if re-uploading is allowed
        if reUploadAllowed == false {
            // Get visible cells
            let visibleCells = localImagesCollection.visibleCells as? [LocalImageCollectionViewCell]

            // Deselect already uploaded photos if needed
            if (queue.operationCount == 0) && (selectedImages.count < indexedUploadsInQueue.count) {
                // Indexed uploads available
                for index in 0..<selectedImages.count {
                    if let upload = indexedUploadsInQueue[index],
                       [.finished, .moderated].contains(upload.1) {
                        // Deselect cell
                        selectedImages[index] = nil
                        if let cells = visibleCells,
                           let cell = cells.first(where: {$0.localIdentifier == upload.0}) {
                            cell.update(selected: false, state: upload.1)
                        }
                    }
                }
            } else {
                // Use non-indexed data (might be quite slow)
                let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
                for index in 0..<selectedImages.count {
                    if let localIdentifier = selectedImages[index]?.localIdentifier,
                       let upload = completed.first(where: {$0.localIdentifier == localIdentifier}) {
                        selectedImages[index] = nil
                        if let cells = visibleCells,
                           let cell = cells.first(where: {$0.localIdentifier == upload.localIdentifier}) {
                            cell.update(selected: false, state: upload.state)
                        }
                    }
                }
            }
        }
        
        // Update section buttons
        let headers = localImagesCollection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        headers.forEach { header in
            if let sectionHeader = header as? LocalImagesHeaderReusableView {
                let selectState = updateSelectButton(ofSection: sectionHeader.section)
                sectionHeader.selectButton.setTitle(forState: selectState)
            }
        }
        self.updateNavBar()
    }
        

    // MARK: - Delete Camera Roll Images
    @available(iOS 14.0, *)
    private func deleteMenu() -> UIMenu? {
        // Check if there are already uploaded photos that can be deleted
        if canDeleteUploadedImages() == false,
           canDeleteSelectedImages() == false { return nil }
        
        // Propose option for deleting photos
        let delete = UIAction(title: NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll"),
                              image: UIImage(systemName: "trash"), attributes: .destructive, handler: { _ in
            // Delete uploaded photos from the camera roll
            self.deleteUploadedImages()
        })
        let menuId = UIMenu.Identifier("org.piwigo.removeFromCameraRoll")
        return UIMenu(identifier: menuId, options: UIMenu.Options.displayInline, children: [delete])
    }
    
    @objc func deleteUploadedImages() {
        // Delete uploaded images (fetched on the main queue)
        uploadsToDelete = [Upload]()
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let upload = completed.first(where: {$0.localIdentifier == indexedUploads[index].0}),
               indexedUploads[index].2 {
                uploadsToDelete.append(upload)
            }
        }
        
        // Delete selected images
        let assetsToDelete = selectedImages.compactMap({$0?.localIdentifier}).compactMap({$0})
        
        // Anything to delete? (should always be true)
        if assetsToDelete.isEmpty, uploadsToDelete.isEmpty {
            return
        }
        
        // Ask for confirmation
        let title = NSLocalizedString("localImages_deleteTitle", comment: "Remove from Camera Roll")
        let message = NSLocalizedString("localImages_deleteMessage", comment: "Message explaining what will happen")
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { action in })
        let deleteAction = UIAlertAction(title: title, style: .destructive, handler: { action in
            // Delete images and upload requests
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.deleteAssets(associatedToUploads: self.uploadsToDelete, and: assetsToDelete)
            }
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
    
    private func canDeleteUploadedImages() -> Bool {
        // Don't provide access to the Trash button until the preparation work is not done
        if queue.operationCount > 0 { return false }
        
        // Check if there are uploaded photos to delete
        let indexedUploads = self.indexedUploadsInQueue.compactMap({$0})
        let completed = (uploads.fetchedObjects ?? []).filter({[.finished, .moderated].contains($0.state)})
        for index in 0..<indexedUploads.count {
            if let _ = completed.first(where: {$0.localIdentifier == indexedUploads[index].0}),
               indexedUploads[index].2 {
                return true
            }
        }
        return false
    }
    
    private func canDeleteSelectedImages() -> Bool {
        var hasImagesToDelete = false
        let imageIDs = selectedImages.compactMap({ $0?.localIdentifier })
        PHAsset.fetchAssets(withLocalIdentifiers: imageIDs, options: nil)
            .enumerateObjects(options: .concurrent) { asset, _ , stop in
            if asset.canPerform(.delete) {
                hasImagesToDelete = true
                stop.pointee = true
            }
        }
        return hasImagesToDelete
    }
    

    // MARK: - Show Upload Options
    @objc func didTapUploadButton() {
        // Avoid potential crash (should never happen, but…)
        uploadRequests = selectedImages.compactMap({ $0 })
        if uploadRequests.isEmpty { return }
        
        // Disable buttons
        cancelBarButton?.isEnabled = false
        uploadBarButton?.isEnabled = false
        actionBarButton?.isEnabled = false
        trashBarButton?.isEnabled = false
        
        // Show upload parameter views
        let uploadSwitchSB = UIStoryboard(name: "UploadSwitchViewController", bundle: nil)
        if let uploadSwitchVC = uploadSwitchSB.instantiateViewController(withIdentifier: "UploadSwitchViewController") as? UploadSwitchViewController {
            uploadSwitchVC.delegate = self
            uploadSwitchVC.user = user

            // Will we propose to delete images after upload?
            if let firstLocalID = uploadRequests.first?.localIdentifier {
                if let imageAsset = PHAsset.fetchAssets(withLocalIdentifiers: [firstLocalID], options: nil).firstObject {
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
}
