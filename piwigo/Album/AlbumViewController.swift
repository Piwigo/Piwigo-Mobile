//
//  AlbumViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit
import uploadKit

enum pwgImageAction {
    case edit, delete, share
    case copyImages, moveImages
    case addToFavorites, removeFromFavorites
    case rotateImagesLeft, rotateImagesRight
}

class AlbumViewController: UIViewController
{
    @IBOutlet weak var collectionView: UICollectionView!
    
    var categoryId = Int32.zero
    lazy var sortOption: pwgImageSort = {
        switch categoryId {
        case pwgSmartAlbum.visits.rawValue:
            // As with the web UI, uses the below sort option w/o possibility to change it.
            // Note: 'visits' is always accessible
            return pwgImageSort.visitsDescending
        case pwgSmartAlbum.best.rawValue:
            // As with the web UI, uses the below sort option w/o possibility to change it.
            // Note: 'ratingScore' is not always accessible (only returned by pwg.images.getInfo)
            // so the image collection might not be sorted as with the web UI.
            return pwgImageSort.ratingScoreDescending
        case pwgSmartAlbum.search.rawValue:
            // pwg.images.search returns: 'isFavorite', 'datePosted', 'dateCreated', 'visits'
            // The webUI proposes all sort options, so we do the same even if the result may be different.
            fallthrough
        case pwgSmartAlbum.favorites.rawValue:
            // pwg.users.favorites.getList returns: 'datePosted', 'dateCreated', 'visits'
            // The webUI proposes all sort options, so we do the same even if the result may be different.
            fallthrough
        case pwgSmartAlbum.tagged.rawValue:
            // pwg.tags.getImages returns: 'datePosted', 'dateCreated'
            // The webUI proposes all sort options, so we do the same even if the result may be different.
            fallthrough
        case pwgSmartAlbum.recent.rawValue:
            // Adopts sort option used by pwg.category.getImages
            // Note: 'datePosted' can be unknown and defaults to 01/01/1900 in such situation
            fallthrough
        default:  // Sorting option chosen by user
            return AlbumVars.shared.defaultSort
        }
    }()
    
    // MARK: - Bar Buttons
    lazy var settingsBarButton: UIBarButtonItem = getSettingsBarButton()
    lazy var discoverBarButton: UIBarButtonItem = getDiscoverButton()
    var actionBarButton: UIBarButtonItem?
    lazy var moveBarButton: UIBarButtonItem = getMoveBarButton()
    lazy var shareBarButton: UIBarButtonItem = getShareBarButton()
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    var favoriteBarButton: UIBarButtonItem?
    
    var selectBarButton: UIBarButtonItem?
    lazy var cancelBarButton: UIBarButtonItem = getCancelBarButton()
    
    
    // MARK: - Buttons
    let kRadius: CGFloat = 25.0
    let kDeg2Rad: CGFloat = 3.141592654 / 180.0
    
    lazy var addButton: UIButton = getAddButton()
    lazy var uploadQueueButton: UIButton = getUploadQueueButton()
    lazy var homeAlbumButton: UIButton = getHomeButton()
    lazy var createAlbumButton: UIButton = getCreateAlbumButton()
    var createAlbumAction: UIAlertAction!
    
    lazy var uploadImagesButton: UIButton = getUploadImagesButton()
    lazy var progressLayer: CAShapeLayer = getProgressLayer()
    lazy var nberOfUploadsLabel: UILabel = getNberOfUploadsLabel()
    
    
    // MARK: - Search
    var searchController: UISearchController?
    
    
    // MARK: Image Managemennt
    var imageOfInterest = IndexPath(item: 0, section: 0)
    var indexOfImageToRestore = Int.min
    var isSelect = false
    var touchedImageIds = [Int64]()
    var selectedImageIds = Set<Int64>()
    var selectedImageIdsLoop = Set<Int64>()
    var selectedFavoriteIds = Set<Int64>()
    var selectedVideosIds = Set<Int64>()
    var totalNumberOfImages = 0
    var selectedSections = [Int : SelectButtonState]()    // State of Select buttons


    // MARK: - Cached Values
    var timeCounter = CFAbsoluteTime(0)
    lazy var thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
    lazy var albumCellSize: CGSize = getAlbumCellSize()
    lazy var albumPlaceHolder = UIImage(named: "placeholder")!
    lazy var imageSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
    lazy var imageCellSize: CGSize = getImageCellSize()
    lazy var imagePlaceHolder = UIImage(named: "unknownImage")!

    var updateOperations = [BlockOperation]()
    lazy var hasFavorites: Bool = {
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending,
           NetworkVars.userStatus != .guest { return true }
        return false
    }()

    // MARK: - Image Animated Transitioning
    // See https://medium.com/@tungfam/custom-uiviewcontroller-transitions-in-swift-d1677e5aa0bf
    var animatedCell: ImageCollectionViewCell?
    var albumViewSnapshot: UIView?
    var cellImageViewSnapshot: UIView?
    var navBarSnapshot: UIView?
    var imageAnimator: ImageAnimatedTransitioning?
    
    
    // MARK: - Fetch
    // Number of images to download per page
    var oldImageIds = Set<Int64>()
    var onPage = 0, lastPage = 0
    lazy var perPage: Int = {
        return max(AlbumUtilities.numberOfImagesToDownloadPerPage(), 100)
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        return UserProvider.shared
    }()
    lazy var albumProvider: AlbumProvider = {
        return AlbumProvider.shared
    }()
    lazy var imageProvider: ImageProvider = {
        return ImageProvider.shared
    }()
    
    
    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()
    lazy var bckgContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.newTaskContext()
        return context
    }()
    
    
    // MARK: - Core Data Source
    lazy var user: User = {
        guard let user = userProvider.getUserAccount(inContext: mainContext) else {
            // Unknown user instance! ► Back to login view
            ClearCache.closeSession()
            return User()
        }
        // User available ► Job done
        if user.isFault {
            // The user is not fired yet.
            user.willAccessValue(forKey: nil)
            user.didAccessValue(forKey: nil)
        }
        return user
    }()
    
    lazy var albumData: Album = {
        return currentAlbumData()
    }()
    func currentAlbumData() -> Album {
        // Did someone delete this album?
        if let album = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
            // Album available ► Job done
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            return album
        }
        
        // Album not available anymore ► Back to default album?
        categoryId = AlbumVars.shared.defaultCategory
        if let defaultAlbum = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
            changeAlbumID()
            if defaultAlbum.isFault {
                // The default album is not fired yet.
                defaultAlbum.willAccessValue(forKey: nil)
                defaultAlbum.didAccessValue(forKey: nil)
            }
            return defaultAlbum
        }
        
        // Default album deleted ► Back to root album
        categoryId = Int32.zero
        guard let rootAlbum = albumProvider.getAlbum(ofUser: user, withId: Int32.zero)
        else { fatalError("••> Could not create root album!") }
        if rootAlbum.isFault {
            // The root album is not fired yet.
            rootAlbum.willAccessValue(forKey: nil)
            rootAlbum.didAccessValue(forKey: nil)
        }
        changeAlbumID()
        return rootAlbum
    }
    
    lazy var data = AlbumViewData(withAlbum: albumData)
    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = data.albums
        albums.delegate = self
        return albums
    }()
    lazy var images: NSFetchedResultsController<Image> = {
        let images = data.images(sortedBy: sortOption)
        images.delegate = self
        return images
    }()
    

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("--------------------------------------------------")
        print("••> viewDidLoad in AlbumViewController: Album #\(categoryId)")

        // Initialise data source
        do {
            if categoryId >= Int32.zero {
                try albums.performFetch()
            }
            try images.performFetch()
        } catch {
            print("Error: \(error)")
        }
        
        // Place search bar in navigation bar of root album
        if categoryId == 0 {
            initSearchBar()
        }
        
        // Add buttons above table view and other buttons
        view.insertSubview(addButton, aboveSubview: collectionView)
        uploadQueueButton.layer.addSublayer(progressLayer)
        uploadQueueButton.addSubview(nberOfUploadsLabel)
        view.insertSubview(uploadQueueButton, belowSubview: addButton)
        view.insertSubview(homeAlbumButton, belowSubview: addButton)
        view.insertSubview(createAlbumButton, belowSubview: addButton)
        view.insertSubview(uploadImagesButton, belowSubview: addButton)
        
        // Register classes
        collectionView?.isPrefetchingEnabled = true
        collectionView?.register(AlbumHeaderReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeaderReusableView")
        collectionView?.register(UINib(nibName: "AlbumCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "AlbumCollectionViewCell")
        collectionView?.register(AlbumCollectionViewCellOld.self, forCellWithReuseIdentifier: "AlbumCollectionViewCellOld")
        collectionView?.register(UINib(nibName: "ImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ImageCollectionViewCell")
        collectionView?.register(UINib(nibName: "ImageHeaderReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageHeaderReusableView")
        collectionView?.register(UINib(nibName: "ImageOldHeaderReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageOldHeaderReusableView")
        collectionView?.register(ImageFooterReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView")

        // Sticky section headers
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = true
        }
        
        // Refresh view
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        collectionView?.refreshControl = refreshControl
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar title
        let isFetching = AlbumVars.shared.isFetchingAlbumData.contains(categoryId)
        setTitleViewFromAlbumData(whileUpdating: isFetching)
        navigationController?.navigationBar.prefersLargeTitles = (categoryId == AlbumVars.shared.defaultCategory)
        
        // Buttons appearance
        addButton.layer.shadowColor = UIColor.piwigoColorShadow().cgColor
        
        createAlbumButton.layer.shadowColor = UIColor.piwigoColorShadow().cgColor
        uploadImagesButton.layer.shadowColor = UIColor.piwigoColorShadow().cgColor
        
        uploadQueueButton.layer.shadowColor = UIColor.piwigoColorShadow().cgColor
        uploadQueueButton.backgroundColor = UIColor.piwigoColorRightLabel()
        nberOfUploadsLabel.textColor = UIColor.piwigoColorBackground()
        progressLayer.strokeColor = UIColor.piwigoColorBackground().cgColor
        
        homeAlbumButton.layer.shadowColor = UIColor.piwigoColorShadow().cgColor
        homeAlbumButton.backgroundColor = UIColor.piwigoColorRightLabel()
        homeAlbumButton.tintColor = UIColor.piwigoColorBackground()
        
        if AppVars.shared.isDarkPaletteActive {
            addButton.layer.shadowRadius = 1.0
            addButton.layer.shadowOffset = CGSize.zero
            
            createAlbumButton.layer.shadowRadius = 1.0
            createAlbumButton.layer.shadowOffset = CGSize.zero
            uploadImagesButton.layer.shadowRadius = 1.0
            uploadImagesButton.layer.shadowOffset = CGSize.zero
            
            uploadQueueButton.layer.shadowRadius = 1.0
            uploadQueueButton.layer.shadowOffset = CGSize.zero
            
            homeAlbumButton.layer.shadowRadius = 1.0
            homeAlbumButton.layer.shadowOffset = CGSize.zero
        } else {
            addButton.layer.shadowRadius = 3.0
            addButton.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
            
            createAlbumButton.layer.shadowRadius = 3.0
            createAlbumButton.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
            uploadImagesButton.layer.shadowRadius = 3.0
            uploadImagesButton.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
            
            uploadQueueButton.layer.shadowRadius = 3.0
            uploadQueueButton.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
            
            homeAlbumButton.layer.shadowRadius = 3.0
            homeAlbumButton.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
        }
        
        // Collection view
        collectionView?.backgroundColor = UIColor.piwigoColorBackground()
        collectionView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        (collectionView?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) ?? []).forEach { header in
            if let header = header as? AlbumHeaderReusableView {
                header.commentLabel?.attributedText = attributedComment()
                header.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
            }
            else if let header = header as? ImageHeaderReusableView {
                header.applyColorPalette()
                header.selectButton.setTitle(forState: selectedSections[header.section] ?? .none)
            }
            else if let header = header as? ImageOldHeaderReusableView {
                header.applyColorPalette()
                header.selectButton.setTitle(forState: selectedSections[header.section] ?? .none)
            }
        }
        (collectionView?.visibleCells ?? []).forEach { cell in
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.applyColorPalette()
            }
            else if let albumCell = cell as? AlbumCollectionViewCellOld {
                albumCell.applyColorPalette()
            }
            else if let imageCell = cell as? ImageCollectionViewCell {
                imageCell.applyColorPalette()
            }
        }
        (collectionView?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter) ?? []).forEach { footer in
            if let footer = footer as? ImageFooterReusableView {
                footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
            }
        }

        // Refresh controller
        collectionView?.refreshControl?.backgroundColor = UIColor.piwigoColorBackground()
        collectionView?.refreshControl?.tintColor = UIColor.piwigoColorHeader()
        let attributesRefresh = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)
        ]
        collectionView?.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("pullToRefresh", comment: "Reload Photos"), attributes: attributesRefresh)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("••> viewWillAppear in AlbumViewController: Album #\(categoryId)")
        
        // For testing…
//        timeCounter = CFAbsoluteTimeGetCurrent()

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Always open this view with a navigation bar
        // (might have been hidden during Image Previewing)
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        // Set navigation bar and buttons
        initBarsInPreviewMode()
        initButtons()
        updateButtons()
        
        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        
        // Register upload queue changes for reporting inability to upload and updating upload queue button
        NotificationCenter.default.addObserver(self, selector: #selector(updateNberOfUploads(_:)),
                                               name: Notification.Name.pwgLeftUploads, object: nil)
        
        // Register upload progress if displaying default album
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            NotificationCenter.default.addObserver(self, selector: #selector(updateUploadQueueButton(withProgress:)),
                                                   name: Notification.Name.pwgUploadProgress, object: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("••> viewDidAppear in AlbumViewController: Album #\(categoryId)")
        
        // Speed and memory measurements with iPad Pro 11" in debug mode
        /// Old method —> 0 photo: 527 ms, 24 photos: 583 ms, 3020 photos: 15 226 ms (memory crash after repeating tests)
        /// hasFavorites  cached —> a very little quicker but less memory impacting (-195 MB transcient allocations for 3020 photos)
        /// placeHolder & size cached —> 0 photo: 526 ms, 24 photos: 585 ms, 3020 photos: 14 586 ms i.e. -6% (memory crash after repeating tests)
//        let duration = (CFAbsoluteTimeGetCurrent() - timeCounter)*1000
//        print("••> completed in \(duration.rounded()) ms")

        // The user may have cleared the cached data
        // Display an empty root album in that case
        if categoryId == Int32.zero, albumData.isFault {
            return
        }
        
        // Header informing user on network status
        setTableViewMainHeader()
        
        // Hide the search bar when scrolling
        navigationItem.hidesSearchBarWhenScrolling = true
        
        // Check conditions before loading album and image data
        let lastLoad = Date.timeIntervalSinceReferenceDate - albumData.dateGetImages
        let nbImages = (images.fetchedObjects ?? []).count
        let noSmartAlbumData = (self.categoryId < 0) && (nbImages == 0)
        let expectedNbImages = self.albumData.nbImages
        let missingImages = (expectedNbImages > 0) && (nbImages < expectedNbImages / 2)
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty,
           noSmartAlbumData || missingImages || lastLoad > TimeInterval(3600)
        {
            // Fetch album/image data after checking session
            self.startFetchingAlbumAndImages(withHUD: noSmartAlbumData || missingImages)
        }
        
        // Should we highlight the image of interest?
        if nbImages > 0 {
            revealImageOfInteret()
        }
        
        // Inform user why the app crashed at start
        if CacheVars.shared.couldNotMigrateCoreDataStore {
            dismissPiwigoError(
                withTitle: NSLocalizedString("CoreDataStore_WarningTitle", comment: "Warning"),
                message: NSLocalizedString("CoreDataStore_WarningMessage", comment: "A serious application error occurred…"),
                errorMessage: "") {
                    // Reset flag
                    CacheVars.shared.couldNotMigrateCoreDataStore = false
                }
            return
        }
        
        // Display What's New in Piwigo if needed
        /// Next line to be used for dispalying What's New in Piwigo:
        //        AppVars.shared.didShowWhatsNewAppVersion = "3.0.2"
        if let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            if AppVars.shared.didShowWhatsNewAppVersion.compare("3.2", options: .numeric) == .orderedAscending,
               appVersionString.compare(AppVars.shared.didShowWhatsNewAppVersion, options: .numeric) == .orderedDescending {
                // Display What's New in Piwigo
                let whatsNewSB = UIStoryboard(name: "WhatsNewViewController", bundle: nil)
                guard let whatsNewVC = whatsNewSB.instantiateViewController(withIdentifier: "WhatsNewViewController") as? WhatsNewViewController 
                else { preconditionFailure("Couldd not load WhatsNewViewController") }
                if UIDevice.current.userInterfaceIdiom == .phone {
                    whatsNewVC.popoverPresentationController?.permittedArrowDirections = .up
                    present(whatsNewVC, animated: true)
                } else {
                    whatsNewVC.modalTransitionStyle = .coverVertical
                    whatsNewVC.modalPresentationStyle = .formSheet
                    let mainScreenBounds = UIScreen.main.bounds
                    whatsNewVC.popoverPresentationController?.sourceRect = CGRect(
                        x: mainScreenBounds.midX, y: mainScreenBounds.midY,
                        width: 0, height: 0)
                    whatsNewVC.preferredContentSize = CGSize(
                        width: pwgPadSettingsWidth,
                        height: ceil(CGFloat(mainScreenBounds.size.height) * 2 / 3))
                    present(whatsNewVC, animated: true)
                }
                return
            } else {
                // Store current version for future use
                AppVars.shared.didShowWhatsNewAppVersion = appVersionString
            }
        }
        
        // Display help views only when showing regular albums
        // and less than once a day
        let dateOfLastHelpView = AppVars.shared.dateOfLastHelpView
        let diff = Date().timeIntervalSinceReferenceDate - dateOfLastHelpView
        if categoryId <= 0 || diff > TimeInterval(86400) { return }
        
        // Determine which help pages should be presented
        var displayHelpPagesWithID = [UInt16]()
        if nbImages > 5,
           (AppVars.shared.didWatchHelpViews & 0b00000000_00000001) == 0 {
            displayHelpPagesWithID.append(1) // i.e. multiple selection of images
        }
        if (albums.fetchedObjects ?? []).count > 2,
           user.hasAdminRights,
           (AppVars.shared.didWatchHelpViews & 0b00000000_00000100) == 0 {
            displayHelpPagesWithID.append(3) // i.e. management of albums
        }
        if albumData.upperIds.count > 3,
           (AppVars.shared.didWatchHelpViews & 0b00000000_10000000) == 0 {
            displayHelpPagesWithID.append(8) // i.e. back to parent album
        }
        if displayHelpPagesWithID.count > 0 {
            // Present unseen help views
            let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
            guard let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
            else { preconditionFailure("Could not load HelpViewController") }
            helpVC.displayHelpPagesWithID = displayHelpPagesWithID
            if UIDevice.current.userInterfaceIdiom == .phone {
                helpVC.popoverPresentationController?.permittedArrowDirections = .up
                present(helpVC, animated: true)
            } else {
                helpVC.modalPresentationStyle = UIModalPresentationStyle.formSheet
                helpVC.modalTransitionStyle = UIModalTransitionStyle.coverVertical
                present(helpVC, animated: true)
            }
        }
        
        // Replace iRate as from v2.1.5 (75) — See https://github.com/nicklockwood/iRate
        // Tells StoreKit to ask the user to rate or review the app, if appropriate.
        //#if !defined(DEBUG)
        //    if (NSClassFromString(@"SKStoreReviewController")) {
        //        [SKStoreReviewController requestReview];
        //    }
        //#endif
    }
    
    func revealImageOfInteret() {
        if imageOfInterest.item != 0 {
            // Highlight the cell of interest
            let indexPathsForVisibleItems = collectionView?.indexPathsForVisibleItems
            if indexPathsForVisibleItems?.contains(imageOfInterest) ?? false {
                // Thumbnail is already visible and is highlighted
                if let cell = collectionView?.cellForItem(at: imageOfInterest),
                   let imageCell = cell as? ImageCollectionViewCell {
                    imageCell.highlight() {
                        self.imageOfInterest = IndexPath(item: 0, section: 0)
                    }
                } else {
                    self.imageOfInterest = IndexPath(item: 0, section: 0)
                }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Hide HUD if needded
        navigationController?.hideHUD { }
        
        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Reload collection with appropriate cell sizes
            albumCellSize = getAlbumCellSize()
            imageCellSize = getImageCellSize()
            collectionView?.reloadData()

            // Update buttons
            if isSelect {
                initBarsInSelectMode()
            } else {
                // Update position of buttons (recalculated after device rotation)
                addButton.frame = getAddButtonFrame()
                homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton.isHidden)
                uploadQueueButton.frame = getUploadQueueButtonFrame(isHidden: uploadQueueButton.isHidden)
                createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
            }
            
            // Update parent collection layouts
            (navigationController?.viewControllers ?? []).forEach { viewController in
                // Look for AlbumImagesViewControllers
                if let albumController = viewController as? AlbumViewController, albumController != self {
                    // Is this the view controller of the default album?
                    albumController.albumCellSize = albumCellSize
                    albumController.imageCellSize = imageCellSize
                }
            }
        })
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Should we update user interface based on the appearance?
        if #available(iOS 13.0, *) {
            let isSystemDarkModeActive = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            if AppVars.shared.isSystemDarkModeActive != isSystemDarkModeActive {
                AppVars.shared.isSystemDarkModeActive = isSystemDarkModeActive
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if #available(iOS 15, *) {
            // Keep title
        } else {
            // Do not show album title in backButtonItem of child view to provide enough space for image title
            // See https://iosref.com/res
            if view.bounds.size.width <= 430 {
                // i.e. smaller than iPhone 14 Pro Max screen width
                title = ""
            }
        }
        
        // Cancel remaining tasks
        let catIDstr = String(self.categoryId)
        PwgSession.shared.dataSession.getAllTasks { tasks in
            // Select tasks related with this album if any
            let tasksToCancel = tasks.filter({ $0.originalRequest?
                .value(forHTTPHeaderField: NetworkVars.HTTPCatID) == catIDstr })
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel task \($0.taskIdentifier) related with album \(self.categoryId)")
                $0.cancel()
            })
        }
        
        // Hide upload button during transition
        addButton.isHidden = true
        
        // Hide HUD if still presented
        self.navigationController?.hideHUD { }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Make sure buttons are back to initial state
        didCancelTapAddButton()
    }
    
    deinit {
        // Cancel all block operations
        for operation in updateOperations {
            operation.cancel()
        }
        updateOperations.removeAll(keepingCapacity: false)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Album Data
    func changeAlbumID() {
        // Add/remove search bar
        if categoryId == 0 {
            // Initialise search bar
            initSearchBar()
        } else {
            // Remove search bar from the navigation bar
            navigationItem.searchController = nil
        }

        // Reset predicates and reload albums and images
        resetPredicatesAndPerformFetch()

        // Reload album
        collectionView?.reloadData()
        
        // Reset buttons and menus
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
    }
    
    func resetPredicatesAndPerformFetch() {
        // Update album content
        data.switchToAlbum(withID: categoryId)
        try? albums.performFetch()
        try? images.performFetch()
    }

    func startFetchingAlbumAndImages(withHUD: Bool) {
        // Remember that the app is uploading this album data
        AlbumVars.shared.isFetchingAlbumData.insert(categoryId)
        
        // Display "loading" in title view
        self.setTitleViewFromAlbumData(whileUpdating: true)
        
        // Display HUD while downloading album data
        if withHUD {
            self.navigationController?.showHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("severalImages", comment: "Photos"), minWidth: 200)
        }
        
        // Fetch album data and then image data
        PwgSession.checkSession(ofUser: self.user) {
            self.fetchAlbumsAndImages { [self] in
                self.fetchCompleted()
            }
        } failure: { error in
            DispatchQueue.main.async {
                // End refreshing if needed
                self.collectionView?.refreshControl?.endRefreshing()
                
                // Session logout required?
                if let pwgError = error as? PwgSessionError,
                   [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                    .contains(pwgError) {
                    ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                    return
                }

                // Report error
                let title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
                self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) {}
            }
        }
    }

    @objc func refresh(_ refreshControl: UIRefreshControl?) {
        // Already being fetching album data?
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty == false { return }
                
        // Check that the root album exists
        // (might have been deleted with a clear of the cache)
        if categoryId == Int32.zero {
            albumData = currentAlbumData()
        }
        
        // Fetch album/image data after checking session
        self.startFetchingAlbumAndImages(withHUD: true)
    }
    
    func fetchCompleted() {
        DispatchQueue.main.async { [self] in
            // Hide HUD if needed
            self.navigationController?.hideHUD { }

            // Update title
            self.setTitleViewFromAlbumData(whileUpdating: false)

            // Update number of images in footer
            self.updateNberOfImagesInFooter()

            // Set navigation bar buttons
            if self.isSelect {
                self.updateBarsInSelectMode()
            } else {
                self.updateBarsInPreviewMode()
            }

            // End refreshing if needed
            self.collectionView?.refreshControl?.endRefreshing()
        }
        
        // Fetch favorites in the background if needed
        if NetworkVars.userStatus != .guest,
           categoryId != pwgSmartAlbum.favorites.rawValue,
           "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending,
           NetworkVars.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending,
           AlbumVars.shared.isFetchingAlbumData.contains(pwgSmartAlbum.favorites.rawValue) == false,
           let favAlbum = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue),
           Date.timeIntervalSinceReferenceDate - favAlbum.dateGetImages > TimeInterval(86400) { // i.e. a day
            // Remember that the app is fetching favorites
            AlbumVars.shared.isFetchingAlbumData.insert(pwgSmartAlbum.favorites.rawValue)
            // Fetch favorites in the background
            DispatchQueue.global(qos: .background).async { [self] in
                self.loadFavoritesInBckg()
            }
        }

        // Resume upload operations in background queue
        // and update badge and upload button of album navigator
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.isPaused = false
            UploadManager.shared.findNextImageToUpload()
        }
    }


    // MARK: - Utilities
    @objc func setTableViewMainHeader() {
        // Update table header only if being displayed
//        if albumImageTableView?.window == nil { return }
//        DispatchQueue.main.async { [self] in
//            // Any upload request in the queue?
//            if UploadManager.shared.nberOfUploadsToComplete == 0 {
//                albumImageTableView.tableHeaderView = nil
//                UIApplication.shared.isIdleTimerDisabled = false
//            }
//            else if !NetworkVars.isConnectedToWiFi() && UploadVars.wifiOnlyUploading {
//                // No Wi-Fi and user wishes to upload only on Wi-Fi
//                let headerView = TableHeaderView(frame: .zero)
//                headerView.configure(width: albumImageTableView.frame.size.width,
//                                     text: NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection"))
//                albumImageTableView.tableHeaderView = headerView
//                UIApplication.shared.isIdleTimerDisabled = false
//            }
//            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
//                // Low Power mode enabled
//                let headerView = TableHeaderView(frame: .zero)
//                headerView.configure(width: albumImageTableView.frame.size.width,
//                                     text: NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled"))
//                albumImageTableView.tableHeaderView = headerView
//                UIApplication.shared.isIdleTimerDisabled = false
//            } else {
//                // Uploads in progress ► Prevents device to sleep
//                albumImageTableView.tableHeaderView = nil
//                UIApplication.shared.isIdleTimerDisabled = true
//            }
//        }
    }

    func pushView(_ viewController: UIViewController?) {
        guard let viewController = viewController
        else { return }
        
        // Push album list or tag list
        if UIDevice.current.userInterfaceIdiom == .pad {
            viewController.modalPresentationStyle = .popover
            if viewController is SelectCategoryViewController {
                if #available(iOS 14.0, *) {
                    viewController.popoverPresentationController?.barButtonItem = actionBarButton
                } else {
                    viewController.popoverPresentationController?.barButtonItem = moveBarButton
                }
                viewController.popoverPresentationController?.permittedArrowDirections = .up
                navigationController?.present(viewController, animated: true)
            }
            else if viewController is TagSelectorViewController {
                viewController.popoverPresentationController?.barButtonItem = discoverBarButton
                viewController.popoverPresentationController?.permittedArrowDirections = .up
                navigationController?.present(viewController, animated: true)
            }
            else if viewController is EditImageParamsViewController {
                // Push Edit view embedded in navigation controller
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.barButtonItem = actionBarButton
                navController.popoverPresentationController?.permittedArrowDirections = .up
                navigationController?.present(navController, animated: true)
            }
        } else {
            let navController = UINavigationController(rootViewController: viewController)
            navController.modalPresentationStyle = .popover
            navController.popoverPresentationController?.sourceView = view
            navController.modalTransitionStyle = .coverVertical
            navigationController?.present(navController, animated: true)
        }
    }
    
    @objc func returnToDefaultCategory() {
        // Does the default album view controller already exists?
        var cur = 0, index = 0
        var rootAlbumViewController: AlbumViewController? = nil
        for viewController in navigationController?.viewControllers ?? []
        {
            // Look for AlbumImagesViewControllers
            if let thisViewController = viewController as? AlbumViewController
            {
                // Is this the view controller of the default album?
                if thisViewController.categoryId == AlbumVars.shared.defaultCategory {
                    // The view controller of the parent category already exist
                    rootAlbumViewController = thisViewController
                }

                // Is this the current view controller?
                if thisViewController.categoryId == categoryId {
                    // This current view controller will become the child view controller
                    index = cur
                }
            }
            cur = cur + 1
        }

        // The view controller of the default album does not exist yet
        if rootAlbumViewController == nil {
            let defaultAlbumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let defaultAlbum = defaultAlbumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            defaultAlbum.categoryId = AlbumVars.shared.defaultCategory
            rootAlbumViewController = defaultAlbum
            
            if let rootAlbumViewController = rootAlbumViewController,
               var arrayOfVC = navigationController?.viewControllers {
                arrayOfVC.insert(rootAlbumViewController, at: index)
                navigationController?.viewControllers = arrayOfVC
            }
        }

        // Present the root album
        if let rootAlbumViewController = rootAlbumViewController {
            navigationController?.popToViewController(rootAlbumViewController, animated: true)
        }
    }
}
