//
//  AlbumViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import MessageUI
import UIKit
import piwigoKit
import uploadKit

enum pwgImageAction {
    case edit, delete, share
    case copyImages, moveImages
    case favorite, unfavorite
    case rotateImagesLeft, rotateImagesRight
}

protocol AlbumViewControllerDelegate: NSObjectProtocol {
    func didSelectCurrentCounter(value: Int64)
}

class AlbumViewController: UIViewController
{
    weak var albumDelegate: AlbumViewControllerDelegate?

    @IBOutlet weak var noAlbumLabel: UILabel!
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
    // Keep back button title smaller than 10 characters when width <= 440 points
    // i.e. smaller than iPhone 16 Pro Max screen width (https://iosref.com/res)
    let minWidthForDefaultBackButton: CGFloat = 440.0
    // Bar buttons for root album
    lazy var settingsBarButton: UIBarButtonItem = getSettingsBarButton()            // before iOS 26
    lazy var discoverBarButton: UIBarButtonItem = getDiscoverButton()
    lazy var addAlbumBarButton: UIBarButtonItem = getAddAlbumBarButton()            // since iOS 26
    lazy var addImageBarButton: UIBarButtonItem = getAddImageBarButton()            // since iOS 26
    var uploadQueueBarButton: UIBarButtonItem?                                      // since iOS 26
    // Bar buttons for other albums
    var actionBarButton: UIBarButtonItem?
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    var shareBarButton: UIBarButtonItem?
    var favoriteBarButton: UIBarButtonItem?
    // Bar buttons for image selection mode
    var selectBarButton: UIBarButtonItem?
    lazy var cancelBarButton: UIBarButtonItem = getCancelBarButton()
    
    
    // MARK: - Buttons
    // Exclusively before iOS 26
    let kRadius: CGFloat = 25.0
    let kDeg2Rad: CGFloat = 3.141592654 / 180.0
    
    lazy var addButton: UIButton = getAddButton()
    lazy var addButtonOrange: UIButton.Configuration = getAddButtonOrangeConfiguration()
    lazy var addButtonGray: UIButton.Configuration = getAddButtonGrayConfiguration()
    lazy var uploadQueueButton: UIButton = getUploadQueueButton()
    lazy var homeAlbumButton: UIButton = getHomeAlbumButton()
    
    lazy var createAlbumOrange:UIButton.Configuration = getCreateAlbumButtonConfiguration()
    lazy var createAlbumButton: UIButton = getCreateAlbumButton()
    var createAlbumAction: UIAlertAction!
    
    lazy var uploadImagesOrange: UIButton.Configuration = getUploadImagesButtonConfiguration()
    lazy var uploadImagesButton: UIButton = getUploadImagesButton()
    lazy var progressLayer: CAShapeLayer = getProgressLayer()
    lazy var nberOfUploadsLabel: UILabel = getNberOfUploadsLabel()
    
    
    // MARK: - Search
    var searchController: UISearchController?
    
    
    // MARK: Image Managemennt
    var indexOfImageToRestore = Int.min
    var inSelectionMode = false
    var touchedImageIDs = [Int64]()
    var selectedImageIDs = Set<Int64>()
    var selectedFavoriteIDs = Set<Int64>()
    var selectedVideosIDs = Set<Int64>()
    var selectedSections = [Int : SelectButtonState]()    // State of Select buttons
    
    
    // MARK: - Cached Values
    var timeCounter = CFAbsoluteTime(0)
    lazy var thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
    let defaultAlbumLabelsHeight: CGFloat = 50.0
    lazy var albumLabelsHeight: CGFloat = defaultAlbumLabelsHeight
    let defaultAlbumMaxWidth: CGFloat = 200.0
    lazy var albumMaxWidth: CGFloat = defaultAlbumMaxWidth
    let defaultOldAlbumHeight: CGFloat = 147.0
    lazy var oldAlbumHeight: CGFloat = defaultOldAlbumHeight
    lazy var imageSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
    let defaultImageHeaderHeight: CGFloat = 49.0
    lazy var imageHeaderHeight: CGFloat = defaultImageHeaderHeight
    
    var updateOperations = [BlockOperation]()
    lazy var hasFavorites: Bool = {
        // pwg.users.favorites… methods available from Piwigo version 2.10
        return user.canManageFavorites()
    }()
    
    lazy var prefersLargeTitles: Bool = {
        // Adopts large title only when showing the default album
        return categoryId == AlbumVars.shared.defaultCategory
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
    var oldImageIDs = Set<Int64>()
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
        return DataController.shared.mainContext
    }()
    lazy var albumBckgContext: NSManagedObjectContext = {
        return albumProvider.bckgContext
    }()
    
    
    // MARK: - Core Data Source
    typealias DataSource = UICollectionViewDiffableDataSource<String, NSManagedObjectID>
    typealias Snaphot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
    /// Stored properties cannot be marked potentially unavailable with '@available'.
    // "var diffableDataSource: DataSource!" replaced by below lines
    var _diffableDataSource: NSObject? = nil
    var diffableDataSource: DataSource {
        if _diffableDataSource == nil {
            _diffableDataSource = configDataSource()
        }
        return _diffableDataSource as! DataSource
    }
    
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
        let albums: NSFetchedResultsController<Album> = data.albums
        albums.delegate = self
        return albums
    }()
    lazy var images: NSFetchedResultsController<Image> = {
        let images: NSFetchedResultsController<Image> = data.images(sortedBy: sortOption)
        images.delegate = self
        return images
    }()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        debugPrint("••> viewDidLoad — Album #\(categoryId): \(albumData.name)")
        
        // Initialise album width and height
        updateContentSizes(for: traitCollection.preferredContentSizeCategory)
        
        // Register classes before using them
        collectionView?.isPrefetchingEnabled = true
        collectionView?.register(UINib(nibName: "AlbumHeaderReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeaderReusableView")
        collectionView?.register(UINib(nibName: "AlbumCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "AlbumCollectionViewCell")
        collectionView?.register(AlbumCollectionViewCellOld.self, forCellWithReuseIdentifier: "AlbumCollectionViewCellOld")
        collectionView?.register(UINib(nibName: "ImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ImageCollectionViewCell")
        collectionView?.register(UINib(nibName: "ImageHeaderReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ImageHeaderReusableView")
        collectionView?.register(ImageFooterReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooterReusableView")
        
        // Initialise "no album / no photo" label
        if albumData.pwgID == Int64.zero {
            noAlbumLabel.text = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
        } else {
            noAlbumLabel.text = NSLocalizedString("noImages", comment:"No Images")
        }

        // Add buttons above table view and other buttons
        if #unavailable(iOS 26.0) {
            view.insertSubview(addButton, aboveSubview: collectionView)
            uploadQueueButton.layer.addSublayer(progressLayer)
            uploadQueueButton.addSubview(nberOfUploadsLabel)
            view.insertSubview(uploadQueueButton, belowSubview: addButton)
            view.insertSubview(homeAlbumButton, belowSubview: addButton)
            view.insertSubview(createAlbumButton, belowSubview: addButton)
            view.insertSubview(uploadImagesButton, belowSubview: addButton)
        }
        
        // No sticky section headers
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.sectionHeadersPinToVisibleBounds = false
        }
        
        // Refresh view
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        collectionView?.refreshControl = refreshControl
        
        // Initialise dataSource
        _diffableDataSource = configDataSource()
        
        // Fetch data, setting up the initial snapshot
        do {
            if categoryId >= Int32.zero {
                try albums.performFetch()
            }
            try images.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }
        
        // Place search bar in navigation bar of root album, reset fetching album flags
        if categoryId == 0 {
            initSearchBar()
            AlbumVars.shared.isFetchingAlbumData = Set<Int32>()
        }
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        noAlbumLabel.textColor = PwgColor.header
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: prefersLargeTitles)
        setTitleViewFromAlbumData()
        
        // Search bar
        if categoryId == 0 {
            if let searchBar = searchController?.searchBar {
                searchBar.configAppearance()
                let placeholder = searchBar.searchTextField.attributedPlaceholder ?? NSAttributedString(string: "")
                let newPlaceholder = NSMutableAttributedString(attributedString: placeholder)
                let wholeRange = NSRange(location: 0, length: placeholder.length)
                let attributes = [
                    NSAttributedString.Key.foregroundColor: PwgColor.rightLabel
                ]
                newPlaceholder.addAttributes(attributes, range: wholeRange)
                searchBar.searchTextField.attributedPlaceholder = newPlaceholder
            }
        }

        // Buttons
        if #unavailable(iOS 26.0) {
            addButton.layer.shadowColor = PwgColor.shadow.cgColor
            createAlbumButton.layer.shadowColor = PwgColor.shadow.cgColor
            uploadImagesButton.layer.shadowColor = PwgColor.shadow.cgColor
            uploadQueueButton.layer.shadowColor = PwgColor.shadow.cgColor
            uploadQueueButton.configuration = getUploadQueueButtonConfiguration()
            nberOfUploadsLabel.textColor = PwgColor.background
            progressLayer.strokeColor = PwgColor.background.cgColor
            homeAlbumButton.configuration = getHomeAlbumConfiguration()
            homeAlbumButton.layer.shadowColor = PwgColor.shadow.cgColor
            
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
        }
        
        // Collection view
        collectionView?.backgroundColor = PwgColor.background
        collectionView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        (collectionView?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) ?? []).forEach { header in
            if let header = header as? AlbumHeaderReusableView {
                header.applyColorPalette(withDescription: self.attributedComment())
            }
            else if let header = header as? ImageHeaderReusableView {
                header.applyColorPalette(withDescription: self.attributedComment())
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
                footer.nberImagesLabel?.textColor = PwgColor.header
            }
        }
        
        // Refresh controller
        collectionView?.refreshControl?.backgroundColor = PwgColor.background
        collectionView?.refreshControl?.tintColor = PwgColor.header
        let attributesRefresh = [
            NSAttributedString.Key.foregroundColor: PwgColor.header,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)
        ]
        collectionView?.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("pullToRefresh", comment: "Reload Photos"), attributes: attributesRefresh)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        debugPrint("••> viewWillAppear — Album #\(categoryId): \(albumData.name)")
        
        // For testing…
//        timeCounter = CFAbsoluteTimeGetCurrent()
        
        // Always open this view with a navigation bar
        // (might have been hidden during Image Previewing)
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.largeTitleDisplayMode = prefersLargeTitles ? .always : .never
        navigationItem.backButtonDisplayMode = traitCollection.userInterfaceIdiom == .pad ? .generic : .minimal
        
        // Should we reload the collection view?
        if collectionView.visibleCells.first is AlbumCollectionViewCell {
            collectionView?.reloadData()
        } else if collectionView.visibleCells.first is AlbumCollectionViewCellOld {
            collectionView?.reloadData()
        }
        
        // Set colors, fonts, etc. and title view
        applyColorPalette()

        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        
        // Register fetch progress
        NotificationCenter.default.addObserver(self, selector: #selector(updateTitleView(_:)),
                                               name: Notification.Name.pwgFetchedImages, object: nil)
        
        // Register upload queue changes for reporting inability to upload and updating upload queue button
        NotificationCenter.default.addObserver(self, selector: #selector(updateNberOfUploads(_:)),
                                               name: Notification.Name.pwgLeftUploads, object: nil)
        
        // Register upload progress if displaying default album
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            NotificationCenter.default.addObserver(self, selector: #selector(updateUploadQueueButton(withProgress:)),
                                                   name: Notification.Name.pwgUploadProgress, object: nil)
        }
        
        // Set navigation bar and buttons
        initBarsInPreviewMode()
        if #unavailable(iOS 26.0) {
            relocateButtons()
            updateButtons()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        debugPrint("••> viewDidAppear — Album #\(categoryId): \(albumData.name)")
        
        // Speed and memory measurements with iPad Pro 11" in debug mode
        /// Old method —> 0 photo: 527 ms, 24 photos: 583 ms, 3020 photos: 15 226 ms (memory crash after repeating tests)
        /// hasFavorites  cached —> a very little quicker but less memory impacting (-195 MB transcient allocations for 3020 photos)
        /// placeHolder & size cached —> 0 photo: 526 ms, 24 photos: 585 ms, 3020 photos: 14 586 ms i.e. -6% (memory crash after repeating tests)
//        let duration = (CFAbsoluteTimeGetCurrent() - timeCounter)*1000
//        debugPrint("••> completed in \(duration.rounded()) ms")

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
        let nbImages = nberOfImages()
        let isSmartAlbum = self.categoryId < 0
        let expectedNbImages = self.albumData.nbImages
        let missingImages = (expectedNbImages > 0) && (nbImages < expectedNbImages / 2)
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty,
           isSmartAlbum || missingImages || lastLoad > TimeInterval(3600)
        {
            // Fetch album/image data after checking session
            self.startFetchingAlbumAndImages(withHUD: isSmartAlbum || missingImages)
        }
        
        // Display What's New in Piwigo if needed
        /// Next line to be used for dispalying What's New in Piwigo:
#if DEBUG
//if categoryId == Int32.zero {
//    AppVars.shared.didShowWhatsNewAppVersion = "3.2"
//}
#endif
        if let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            if AppVars.shared.didShowWhatsNewAppVersion.compare("3.5", options: .numeric) == .orderedAscending,
               appVersionString.compare(AppVars.shared.didShowWhatsNewAppVersion, options: .numeric) == .orderedDescending {
                // Display What's New in Piwigo
                let whatsNewSB = UIStoryboard(name: "WhatsNewViewController", bundle: nil)
                guard let whatsNewVC = whatsNewSB.instantiateViewController(withIdentifier: "WhatsNewViewController") as? WhatsNewViewController 
                else { preconditionFailure("Could not load WhatsNewViewController") }
                if view.traitCollection.userInterfaceIdiom == .phone {
                    whatsNewVC.modalPresentationStyle = .pageSheet
                    whatsNewVC.isModalInPresentation = true
                    if let sheet = whatsNewVC.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                        sheet.selectedDetentIdentifier = view.bounds.height < 750 ? .large : .medium
                        sheet.prefersGrabberVisible = true
                        sheet.preferredCornerRadius = 40
                    }
                    present(whatsNewVC, animated: true)
                }
                else {
                    whatsNewVC.modalTransitionStyle = .coverVertical
                    whatsNewVC.modalPresentationStyle = .pageSheet
                    whatsNewVC.isModalInPresentation = true
                    let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
                    if let sheet = whatsNewVC.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                        if orientation == .landscapeLeft || orientation == .landscapeRight {
                            sheet.selectedDetentIdentifier = .large
                        } else {
                            sheet.selectedDetentIdentifier = .medium
                        }
                        sheet.prefersGrabberVisible = false
                        sheet.preferredCornerRadius = 40
                    }
                    whatsNewVC.popoverPresentationController?.sourceRect = CGRect(
                        x: view.bounds.midX, y: view.bounds.midY,
                        width: 0, height: 0)
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
        if nberOfAlbums() > 2, user.hasAdminRights {
            if (AppVars.shared.didWatchHelpViews & 0b00000000_00000100) == 0 {
                displayHelpPagesWithID.append(3) // i.e. management of albums w/ description
            }
            if (AppVars.shared.didWatchHelpViews & 0b00000001_00000000) == 0 {
                displayHelpPagesWithID.append(9) // i.e. management of albums w/o description
            }
        }
        if albumData.upperIds.count > 3,
           (AppVars.shared.didWatchHelpViews & 0b00000000_10000000) == 0 {
            displayHelpPagesWithID.append(8) // i.e. back to parent album
        }
        if displayHelpPagesWithID.count > 0 {
            // Present unseen help views
            let helpVC = HelpUtilities.getHelpViewController(showingPagesWithIDs: displayHelpPagesWithID)
            if view.traitCollection.userInterfaceIdiom == .phone {
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Hide HUD if needded
        navigationController?.hideHUD { }
        
        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] _ in
            // Reload collection with appropriate cell sizes
            collectionView?.reloadData()

            // Update album view according to its position in the hierarchy
            let children = (self.navigationController?.viewControllers ?? [])
                .compactMap({ $0 as? AlbumViewController })
            let index = children.firstIndex(of: self) ?? -1
            switch index {
            case 0: // Root album
                // Update position of buttons (recalculated after device rotation)
                if #unavailable(iOS 26.0) {
                    addButton.frame = getAddButtonFrame()
                    createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                    uploadQueueButton.frame = getUploadQueueButtonFrame(isHidden: uploadQueueButton.isHidden)
                }

            case children.count - 2: // Parent of displayed album
                // Update position of buttons (recalculated after device rotation)
                if #unavailable(iOS 26.0) {
                    homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton.isHidden)
                    createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                    uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
                }
                
                // Reset title and back button
                setTitleViewFromAlbumData() // with or without update info below the name
                
            default: // Other albums including the visible one
                // Update position of buttons (recalculated after device rotation)
                if #unavailable(iOS 26.0) {
                    addButton.frame = getAddButtonFrame()
                    homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton.isHidden)
                    createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                    uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
                }
                
                // Reset title and back button
                setTitleViewFromAlbumData() // with or without update info below the name
            }
        })
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Should we update the user interface based on the appearance?
        let isSystemDarkModeActive = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        if AppVars.shared.isSystemDarkModeActive != isSystemDarkModeActive {
            AppVars.shared.isSystemDarkModeActive = isSystemDarkModeActive
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.screenBrightnessChanged()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        debugPrint("••> viewWillDisappear — Album #\(categoryId): \(albumData.name)")

        // Cancel remaining tasks
        let catIDstr = String(self.categoryId)
        PwgSession.shared.dataSession.getAllTasks { tasks in
            // Select tasks related with this album if any
            let tasksToCancel = tasks.filter({ $0.originalRequest?
                .value(forHTTPHeaderField: HTTPCatID) == catIDstr })
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                debugPrint("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel task \($0.taskIdentifier) related with album \(catIDstr)")
                $0.cancel()
            })
        }
        
        // Hide upload button during transition
        if #unavailable(iOS 26.0) {
            addButton.isHidden = true
        }
        
        // Hide HUD if still presented
        self.navigationController?.hideHUD { }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        debugPrint("••> viewDidDisappear — Album #\(categoryId): \(albumData.name)")

        // Make sure buttons are back to initial state
        if #unavailable(iOS 26.0) {
            didCancelTapAddButton()
        }
    }
    
    deinit {
        // Cancel all block operations
        for operation in updateOperations {
            autoreleasepool {
                operation.cancel()
            }
        }
        updateOperations.removeAll(keepingCapacity: false)

        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
        debugPrint("••> AlbumViewController released memory")
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
        if #unavailable(iOS 26.0) {
            updateBarsInPreviewMode()
        }
        setTitleViewFromAlbumData()
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
        self.setTitleViewFromAlbumData()
        
        // Display HUD while downloading album data
        if withHUD {
            self.navigationController?.showHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("severalImages", comment: "Photos"), minWidth: 200)
        }
        
        // Fetch album data and then image data
        PwgSession.checkSession(ofUser: self.user) { [self] in
            DispatchQueue.main.async { [self] in
                self.fetchAlbumsAndImages()
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                // End refreshing if needed
                self.collectionView?.refreshControl?.endRefreshing()
                
                // Session logout required?
                if error.requiresLogout {
                    ClearCache.closeSessionWithPwgError(from: self, error: error)
                    return
                }

                // Report error
                let title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
                self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) {
                    self.navigationController?.hideHUD { }
                }
            }
        }
    }

    @objc func refresh(_ refreshControl: UIRefreshControl?) {
        // Already being fetching album data?
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty == false {
            debugPrint("••> Still fetching data in albums with IDs: \(AlbumVars.shared.isFetchingAlbumData.debugDescription) (wanted \(categoryId))")
            // End animated refresh if needed
            self.collectionView?.refreshControl?.endRefreshing()
            return
        }
        
        // Check that the root album exists
        // (might have been deleted with a clear of the cache)
        if categoryId == Int32.zero {
            albumData = currentAlbumData()
        }
        
        // Fetch album/image data after checking session
        self.startFetchingAlbumAndImages(withHUD: true)
    }
    
    @objc func fetchCompleted() {
        DispatchQueue.main.async { [self] in
            // Hide HUD if needed
            self.navigationController?.hideHUD { }

            // Update title
            self.setTitleViewFromAlbumData()

            // Update number of images in footer
            self.updateNberOfImagesInFooter()

            // Set navigation bar buttons
            if self.inSelectionMode {
                self.updateBarsInSelectMode()
            } else {
                self.updateBarsInPreviewMode()
            }

            // End refreshing if needed
            self.collectionView?.refreshControl?.endRefreshing()
        }
        
        // Fetch favorites in the background if needed
        if hasFavorites, categoryId != pwgSmartAlbum.favorites.rawValue,
           "2.10.0".compare(NetworkVars.shared.pwgVersion, options: .numeric) != .orderedDescending,
           NetworkVars.shared.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending,
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
            UploadManager.shared.isExecutingBackgroundUploadTask = false
            UploadManager.shared.findNextImageToUpload()
        }
    }


    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Apply new content size
        guard let info = notification.userInfo,
              let contentSizeCategory = info[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory
        else { return }
        updateContentSizes(for: contentSizeCategory)
        
        // Apply changes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Search bar
            if let textField = self.searchController?.searchBar.searchTextField as? UITextField {
                textField.font = UIFont.preferredFont(forTextStyle: .body)
                self.searchController?.searchBar.invalidateIntrinsicContentSize()
                self.searchController?.searchBar.layer.setNeedsLayout()
                self.searchController?.searchBar.layoutIfNeeded()
            }

            // Invalidate layout to recalculate cell sizes
            self.collectionView.collectionViewLayout.invalidateLayout()
            
            // Reload visible cells, headers, and footers
            self.collectionView.reloadData()
            
            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: prefersLargeTitles)
            self.setTitleViewFromAlbumData()
        }
    }
    
    private func updateContentSizes(for contentSizeCategory: UIContentSizeCategory) {
        // Set cell size according to the selected category
        /// https://developer.apple.com/design/human-interface-guidelines/typography#Specifications
        switch contentSizeCategory {
        case .extraSmall:
            // Album w/o description: Headline 14 pnts + Footnote 12 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight - 3.0 - 1.0
            albumMaxWidth = defaultAlbumMaxWidth
            // Album w/ description: Headline 14 pnts + 4x Footnote 12 pnts + Caption2 11 pnts
            oldAlbumHeight = defaultOldAlbumHeight - 3.0 - 4 * 1.0 - 0.0
            // Image section header height: Subhead 12 pnts + Footnote 12 pnts
            imageHeaderHeight = defaultImageHeaderHeight - 3.0 - 1.0
        case .small:
            // Album w/o description: Headline 15 pnts + Footnote 12 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight - 2.0 - 1.0
            albumMaxWidth = defaultAlbumMaxWidth
            // Album w/ description: Headline 15 pnts + 4x Footnote 12 pnts + Caption2 11 pnts
            oldAlbumHeight = defaultOldAlbumHeight - 2.0 - 4 * 1.0 - 0.0
            // Image section header height: Subhead 13 pnts + Footnote 12 pnts
            imageHeaderHeight = defaultImageHeaderHeight - 2.0 - 1.0
        case .medium:
            // Album w/o description: Headline 16 pnts + Footnote 12 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight - 1.0 - 1.0
            albumMaxWidth = defaultAlbumMaxWidth
            // Album w/ description: Headline 16 pnts + 4x Footnote 12 pnts + Caption2 11 pnts
            oldAlbumHeight = defaultOldAlbumHeight - 1.0 - 4 * 1.0 - 0.0
            // Image section header height: Subhead 14 pnts + Footnote 12 pnts
            imageHeaderHeight = defaultImageHeaderHeight - 1.0 - 1.0
        case .large:    // default style
            // Album w/o description: Headline 17 pnts + Footnote 13 pnts (see XIB)
            albumLabelsHeight = defaultAlbumLabelsHeight
            albumMaxWidth = defaultAlbumMaxWidth
            // Album w/ description: Headline 17 pnts + 4x Footnote 13 pnts + Caption2 11 pnts (see XIB)
            oldAlbumHeight = defaultOldAlbumHeight
            // Image section header height: Subhead 15 pnts + Footnote 13 pnts
            imageHeaderHeight = defaultImageHeaderHeight
        case .extraLarge:
            // Album w/o description: Headline 19 pnts + Footnote 15 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 2.0 + 2.0
            albumMaxWidth = defaultAlbumMaxWidth + 16.0
            // Album w/ description: Headline 19 pnts + 4x Footnote 15 pnts + Caption2 13 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 2.0 + 4 * 2.0 + 2.0
            // Image section header height: Subhead 17 pnts + Footnote 15 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 2.0 + 2.0
        case .extraExtraLarge:
            // Album w/o description: Headline 21 pnts + Footnote 17 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 4.0 + 4.0
            albumMaxWidth = defaultAlbumMaxWidth + 32.0
            // Album w/ description: Headline 21 pnts + 4x Footnote 17 pnts + Caption2 15 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 4.0 + 4 * 4.0 + 4.0
            // Image section header height: Subhead 19 pnts + Footnote 17 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 4.0 + 4.0
        case .extraExtraExtraLarge:
            // Album w/o description: Headline 23 pnts + Footnote 19 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 6.0 + 6.0
            albumMaxWidth = defaultAlbumMaxWidth + 48.0
            // Album w/ description: Headline 23 pnts + 4x Footnote 19 pnts + Caption2 17 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 6.0 + 4 * 6.0 + 6.0
            // Image section header height: Subhead 21 pnts + Footnote 19 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 6.0 + 6.0
        case .accessibilityMedium:
            // Album w/o description: Headline 28 pnts + Footnote 23 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 11.0 + 10.0
            albumMaxWidth = defaultAlbumMaxWidth + 84.0
            // Album w/ description: Headline 28 pnts + 4x Footnote 23 pnts + Caption2 20 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 11.0 + 4 * 10.0 + 9.0
            // Image section header height: Subhead 25 pnts + Footnote 23 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 10.0 - 17.0
        case .accessibilityLarge:
            // Album w/o description: Headline 33 pnts + Footnote 27 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 16.0 + 14.0
            albumMaxWidth = defaultAlbumMaxWidth + 120.0
            // Album w/ description: Headline 33 pnts + 4x Footnote 27 pnts + Caption2 24 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 16.0 + 4 * 14.0 + 13.0
            // Image section header height: Subhead 30 pnts + Footnote 27 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 15.0 - 17.0
        case .accessibilityExtraLarge:
            // Album w/o description: Headline 40 pnts + Footnote 33 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 23.0 + 20.0
            albumMaxWidth = defaultAlbumMaxWidth + 172.0
            // Album w/ description: Headline 40 pnts + 4x Footnote 33 pnts + Caption2 29 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 23.0 + 4 * 20.0 + 18.0
            // Image section header height: Subhead 36 pnts + Footnote 33 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 21.0 - 17.0
        case .accessibilityExtraExtraLarge:
            // Album w/o description: Headline 47 pnts + Footnote 38 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 30.0 + 25.0
            albumMaxWidth = defaultAlbumMaxWidth + 220.0
            // Album w/ description: Headline 47 pnts + 4x Footnote 38 pnts + Caption2 34 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 30.0 + 4 * 25.0 + 23.0
            // Image section header height: Subhead 42 pnts + Footnote 38 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 27.0 - 17.0
        case .accessibilityExtraExtraExtraLarge:
            // Album w/o description: Headline 53 pnts + Footnote 44 pnts
            albumLabelsHeight = defaultAlbumLabelsHeight + 36.0 + 31.0
            albumMaxWidth = defaultAlbumMaxWidth + 268.0
            // Album w/ description: Headline 53 pnts + 4x Footnote 44 pnts + Caption2 40 pnts
            oldAlbumHeight = defaultOldAlbumHeight + 36.0 + 4 * 31.0 + 29.0
            // Image section header height: Subhead 49 pnts + Footnote 44 pnts
            imageHeaderHeight = defaultImageHeaderHeight + 34.0 - 17.0
        case .unspecified:
            fallthrough
        default:
            albumLabelsHeight = defaultAlbumLabelsHeight
            albumMaxWidth = defaultAlbumMaxWidth
            oldAlbumHeight = defaultOldAlbumHeight
            imageHeaderHeight = defaultImageHeaderHeight
        }
    }
    

    // MARK: - Utilities
    func nberOfAlbums() -> Int {
        var nberOfAlbums = Int.zero
        let snapshot = diffableDataSource.snapshot() as Snaphot
        if let _ = snapshot.indexOfSection(pwgAlbumGroup.none.sectionKey) {
            nberOfAlbums = snapshot.numberOfItems(inSection: pwgAlbumGroup.none.sectionKey)
        }
        return nberOfAlbums
    }
    
    func nberOfImages() -> Int {
        let snapshot = diffableDataSource.snapshot() as Snaphot
        var nberOfImages = diffableDataSource.snapshot().numberOfItems
        if let _ = snapshot.indexOfSection(pwgAlbumGroup.none.sectionKey) {
            nberOfImages -= snapshot.numberOfItems(inSection: pwgAlbumGroup.none.sectionKey)
        }
        return nberOfImages
    }
    
    @objc func setTableViewMainHeader() {
        // May be called by the notification center
//        DispatchQueue.main.async { [self] in
//            if albumImageTableView?.window == nil { return }
//            // Any upload request in the queue?
//            if UploadVars.shared.shared.nberOfUploadsToComplete == 0 {
//                albumImageTableView.tableHeaderView = nil
//                UIApplication.shared.isIdleTimerDisabled = false
//            }
//            else if !NetworkVars.shared.isConnectedToWiFi() && UploadVars.shared.wifiOnlyUploading {
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
        
        // Push album list, tag list, help view, etc.
        if #available(iOS 26.0, *) {
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                if (viewController is HelpViewController) ||
                   (viewController is ReleaseNotesViewController) {
                    viewController.modalTransitionStyle = .coverVertical
                    viewController.modalPresentationStyle = .popover
                    present(viewController, animated: true)
                }
                else {
                    let navController = UINavigationController(rootViewController: viewController)
                    navController.modalTransitionStyle = .coverVertical
                    navController.modalPresentationStyle = .popover
                    navController.popoverPresentationController?.sourceView = view
                    present(navController, animated: true)
                }
                
            case .pad:
                if (viewController is HelpViewController) ||
                    (viewController is ReleaseNotesViewController) {
                    viewController.modalTransitionStyle = .coverVertical
                    viewController.modalPresentationStyle = .formSheet
                    let windowBounds = view.window?.bounds ?? .zero
                    viewController.popoverPresentationController?.sourceRect = CGRect(
                        x: windowBounds.midX, y: windowBounds.midY,
                        width: 0, height: 0)
                    let minHeight = min(windowBounds.width, windowBounds.height)
                    viewController.preferredContentSize = CGSize(
                        width: pwgPadSettingsWidth,
                        height: ceil(minHeight * 2 / 3))
                    present(viewController, animated: true)
                }
                else {
                    let navController = UINavigationController(rootViewController: viewController)
                    navController.modalTransitionStyle = .coverVertical
                    navController.modalPresentationStyle = .formSheet
                    let windowBounds = view.window?.bounds ?? .zero
                    navController.popoverPresentationController?.sourceRect = CGRect(
                        x: windowBounds.midX, y: windowBounds.midY,
                        width: 0, height: 0)
                    let minHeight = min(windowBounds.width, windowBounds.height)
                    navController.preferredContentSize = CGSize(
                        width: pwgPadSettingsWidth,
                        height: ceil(minHeight * 2 / 3))
                    present(navController, animated: true)
                }
                
            default:
                preconditionFailure("!!! Interface not supported !!!")
            }
        }
        else {
            // Fallback on previous version
            switch view.traitCollection.userInterfaceIdiom {
            case .phone:
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalTransitionStyle = .coverVertical
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.sourceView = view
                present(navController, animated: true)
            
            case .pad:
                viewController.modalPresentationStyle = .popover
                if viewController is SelectCategoryViewController {
                    viewController.popoverPresentationController?.barButtonItem = actionBarButton
                    viewController.popoverPresentationController?.permittedArrowDirections = .up
                    present(viewController, animated: true)
                }
                else if viewController is TagSelectorViewController {
                    // Push tag selector view embedded in navigation controller
                    let navController = UINavigationController(rootViewController: viewController)
                    navController.modalPresentationStyle = .popover
                    navController.popoverPresentationController?.barButtonItem = discoverBarButton
                    navController.popoverPresentationController?.permittedArrowDirections = .up
                    present(navController, animated: true)
                }
                else if viewController is EditImageParamsViewController {
                    // Push Edit view embedded in navigation controller
                    let navController = UINavigationController(rootViewController: viewController)
                    navController.modalPresentationStyle = .popover
                    navController.popoverPresentationController?.barButtonItem = actionBarButton
                    navController.popoverPresentationController?.permittedArrowDirections = .up
                    present(navController, animated: true)
                }
            
            default:
                preconditionFailure("!!! Interface not supported !!!")
            }
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


// MARK: - MFMailComposeViewControllerDelegate
extension AlbumViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        dismiss(animated: true)
    }
}
