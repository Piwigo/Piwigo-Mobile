//
//  AlbumImageTableViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit
import uploadKit
//import StoreKit

let kRadius: CGFloat = 25.0
let kDeg2Rad: CGFloat = 3.141592654 / 180.0

class AlbumImageTableViewController: UIViewController
{
    var categoryId = Int32.zero
    var indexOfImageToRestore = Int.min
    
    @IBOutlet weak var albumImageTableView: UITableView!

    // Create album collection view controller from storyboard
    lazy var albumCollectionVC: AlbumCollectionViewController = {
        guard let albumVC = storyboard?.instantiateViewController(withIdentifier: "AlbumCollectionViewController") as? AlbumCollectionViewController
        else { fatalError("No AlbumCollectionViewController!") }
        albumVC.user = user
        albumVC.albumData = albumData
        return albumVC
    }()
    weak var albumCollectionCell: UITableViewCell?

    // Create image collection view controller from storyboard
    lazy var imageCollectionVC: ImageCollectionViewController = {
        guard let imageVC = storyboard?.instantiateViewController(withIdentifier: "ImageCollectionViewController") as? ImageCollectionViewController
        else { fatalError("No ImageCollectionViewController!") }
        imageVC.user = user
        imageVC.albumData = albumData
        imageVC.albumProvider = albumProvider
        imageVC.imageProvider = imageProvider
        imageVC.imageSelectionDelegate = self
        imageVC.indexOfImageToRestore = indexOfImageToRestore
        if #available(iOS 14, *) {
            imageVC.imageCollectionDelegate = self
        }
        return imageVC
    }()
    weak var imageCollectionCell: UITableViewCell?
    
    
    // MARK: - Bar Buttons
    lazy var settingsBarButton: UIBarButtonItem = getSettingsBarButton()
    lazy var discoverBarButton: UIBarButtonItem = getDiscoverButton()
    var actionBarButton: UIBarButtonItem?
    lazy var moveBarButton: UIBarButtonItem? = imageCollectionVC.getMoveBarButton()
    lazy var shareBarButton: UIBarButtonItem? = imageCollectionVC.getShareBarButton()
    lazy var deleteBarButton: UIBarButtonItem? = imageCollectionVC.getDeleteBarButton()
    var favoriteBarButton: UIBarButtonItem?

    var selectBarButton: UIBarButtonItem?
    lazy var cancelBarButton: UIBarButtonItem = getCancelBarButton()

    
    // MARK: - Buttons
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
    var pauseSearch = false

    
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
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("===============================")
        print("••> viewDidLoad albumImage: \(categoryId)")

        // Place search bar in navigation bar of root album
        if categoryId == 0 {
            initSearchBar()
        }
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "AlbumImagesNav"
        
        // Hide toolbar
        navigationController?.isToolbarHidden = true
        
        // Add buttons above table view and other buttons
        view.insertSubview(addButton, aboveSubview: albumImageTableView)
        uploadQueueButton.layer.addSublayer(progressLayer)
        uploadQueueButton.addSubview(nberOfUploadsLabel)
        view.insertSubview(uploadQueueButton, belowSubview: addButton)
        view.insertSubview(homeAlbumButton, belowSubview: addButton)
        view.insertSubview(createAlbumButton, belowSubview: addButton)
        view.insertSubview(uploadImagesButton, belowSubview: addButton)

        // Refresh view
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        albumImageTableView.refreshControl = refreshControl

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Navigation bar appearance
        let navigationBar = navigationController?.navigationBar
        navigationController?.view.backgroundColor = UIColor.piwigoColorBackground()
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = UIColor.piwigoColorOrange()
        setTitleViewFromAlbumData(whileUpdating: false)
        
        // Toolbar appearance
        let toolbar = navigationController?.toolbar
        toolbar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        toolbar?.tintColor = UIColor.piwigoColorOrange()
        
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        let attributesLarge = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 28, weight: .black)
        ]
        if categoryId == AlbumVars.shared.defaultCategory {
            // Title
            navigationBar?.largeTitleTextAttributes = attributesLarge
            navigationBar?.prefersLargeTitles = true
            
            // Search bar
            let searchBar = navigationItem.searchController?.searchBar
            searchBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
            if #available(iOS 13.0, *) {
                searchBar?.searchTextField.textColor = UIColor.piwigoColorLeftLabel()
                searchBar?.searchTextField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .light
            }
        } else {
            navigationBar?.titleTextAttributes = attributes
            navigationBar?.prefersLargeTitles = false
        }
        
        if #available(iOS 13.0, *) {
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
            barAppearance.titleTextAttributes = attributes
            barAppearance.largeTitleTextAttributes = attributesLarge
            if categoryId != AlbumVars.shared.defaultCategory {
                barAppearance.shadowColor = AppVars.shared.isDarkPaletteActive ? UIColor(white: 1.0, alpha: 0.15) : UIColor(white: 0.0, alpha: 0.3)
            }
            navigationItem.standardAppearance = barAppearance
            navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
            navigationItem.scrollEdgeAppearance = barAppearance
            
            let toolbarAppearance = UIToolbarAppearance(barAppearance: barAppearance)
            toolbar?.standardAppearance = toolbarAppearance
            if #available(iOS 15.0, *) {
                /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
                /// which by default produces a transparent background, to all navigation bars.
                toolbar?.scrollEdgeAppearance = toolbarAppearance
            }
        } else {
            navigationBar?.barTintColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
        }
        
        // Refresh controller
        albumImageTableView.refreshControl?.backgroundColor = UIColor.piwigoColorBackground()
        albumImageTableView.refreshControl?.tintColor = UIColor.piwigoColorHeader()
        let attributesRefresh = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)
        ]
        albumImageTableView.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("pullToRefresh", comment: "Reload Photos"), attributes: attributesRefresh)

        // Table view
        albumImageTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black

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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("••> viewWillAppear albumImage: \(categoryId)")

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

        // Display albums and images
        albumImageTableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("••> viewDidAppear albumImage => ID:\(categoryId)")
        
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
        let nbImages = (imageCollectionVC.images.fetchedObjects ?? []).count
        let noSmartAlbumData = (self.categoryId < 0) && (nbImages == 0)
        let expectedNbImages = self.albumData.nbImages
        let missingImages = (expectedNbImages > 0) && (nbImages < expectedNbImages / 2)
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty,
           noSmartAlbumData || missingImages || lastLoad > TimeInterval(3600) {
            NetworkUtilities.checkSession(ofUser: user) {
                self.startFetchingAlbumAndImages(withHUD: noSmartAlbumData || missingImages)
            } failure: { error in
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

        // Should we highlight the image of interest?
        if categoryId != 0, nbImages > 0 {
            imageCollectionVC.revealImageOfInteret()
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
            if AppVars.shared.didShowWhatsNewAppVersion.compare("3.1", options: .numeric) == .orderedAscending,
               appVersionString.compare(AppVars.shared.didShowWhatsNewAppVersion, options: .numeric) == .orderedDescending {
                // Display What's New in Piwigo
                let whatsNewSB = UIStoryboard(name: "WhatsNewViewController", bundle: nil)
                guard let whatsNewVC = whatsNewSB.instantiateViewController(withIdentifier: "WhatsNewViewController") as? WhatsNewViewController else {
                    fatalError("No WhatsNewViewController available!")
                }
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
        if (albumCollectionVC.albums.fetchedObjects ?? []).count > 2,
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
            guard let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController else {
                fatalError("No HelpViewController available!")
            }
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

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Hide HUD if needded
        navigationController?.hideHUD { }
        
        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Reload collection
            albumImageTableView.reloadData()

            // Update buttons
            if imageCollectionVC.isSelect {
                initBarsInSelectMode()
            } else {
                // Update position of buttons (recalculated after device rotation)
                addButton.frame = getAddButtonFrame()
                homeAlbumButton.frame = getHomeAlbumButtonFrame(isHidden: homeAlbumButton.isHidden)
                uploadQueueButton.frame = getUploadQueueButtonFrame(isHidden: uploadQueueButton.isHidden)
                createAlbumButton.frame = getCreateAlbumButtonFrame(isHidden: createAlbumButton.isHidden)
                uploadImagesButton.frame = getUploadImagesButtonFrame(isHidden: uploadImagesButton.isHidden)
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
        ImageSession.shared.dataSession.getAllTasks { tasks in
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
        albumImageTableView.reloadData()
        
        // Reset buttons and menus
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
    }
    
    func resetPredicatesAndPerformFetch() {
        // Update albums
        albumCollectionVC.albumData = albumData
        albumCollectionVC.resetPredicateAndPerformFetch()

        // Update images
        imageCollectionVC.albumData = albumData
        imageCollectionVC.resetPredicateAndPerformFetch()
    }

    func startFetchingAlbumAndImages(withHUD: Bool) {
        // Remember that the app is uploading this album data
        AlbumVars.shared.isFetchingAlbumData.insert(categoryId)
        
        // Inform user
        DispatchQueue.main.async { [self] in
            // Display "loading" in title view
            self.setTitleViewFromAlbumData(whileUpdating: true)

            // Display HUD when loading images for the first time
            // or when we have less than half of the images in cache
            if withHUD == false { return }
            
            // Display HUD while downloading album data
            self.navigationController?.showHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("severalImages", comment: "Photos"), minWidth: 200)
        }
        
        // Fetch album data and then image data
        fetchAlbumsAndImages { [self] in
            fetchCompleted()
        }
    }

    @objc func refresh(_ refreshControl: UIRefreshControl?) {
        // Already being fetching album data?
        if AlbumVars.shared.isFetchingAlbumData.intersection([0, categoryId]).isEmpty == false { return }
        
        // Pause upload manager
        UploadManager.shared.isPaused = true
        
        // Check that the root album exists
        // (might have been deleted with a clear of the cache)
        if categoryId == Int32.zero {
            albumData = currentAlbumData()
        }
        
        // Re-login and then fetch album and image data
        NetworkUtilities.checkSession(ofUser: user) {
            self.startFetchingAlbumAndImages(withHUD: true)
        } failure: { error in
            // End refreshing anyway
            DispatchQueue.main.async {
                self.albumImageTableView.refreshControl?.endRefreshing()
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
    
    func fetchCompleted() {
        DispatchQueue.main.async { [self] in
            // Hide HUD
            self.navigationController?.hideHUD { }

            // Update title
            self.setTitleViewFromAlbumData(whileUpdating: false)

            // Update number of images in footer
            self.albumCollectionVC.updateNberOfImagesInFooter()

            // End refreshing if needed
            self.albumImageTableView.refreshControl?.endRefreshing()
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
        // and update badge, upload button of album navigator
        if UploadManager.shared.isPaused {
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeAll()
            }
        }
    }


    // MARK: - Utilities
    @objc func setTableViewMainHeader() {
        // Update table header only if being displayed
        if albumImageTableView?.window == nil { return }
        DispatchQueue.main.async { [self] in
            // Any upload request in the queue?
            if UploadManager.shared.nberOfUploadsToComplete == 0 {
                albumImageTableView.tableHeaderView = nil
                UIApplication.shared.isIdleTimerDisabled = false
            }
            else if !NetworkVars.isConnectedToWiFi() && UploadVars.wifiOnlyUploading {
                // No Wi-Fi and user wishes to upload only on Wi-Fi
                let headerView = TableHeaderView(frame: .zero)
                headerView.configure(width: albumImageTableView.frame.size.width,
                                     text: NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection"))
                albumImageTableView.tableHeaderView = headerView
                UIApplication.shared.isIdleTimerDisabled = false
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Low Power mode enabled
                let headerView = TableHeaderView(frame: .zero)
                headerView.configure(width: albumImageTableView.frame.size.width,
                                     text: NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled"))
                albumImageTableView.tableHeaderView = headerView
                UIApplication.shared.isIdleTimerDisabled = false
            } else {
                // Uploads in progress ► Prevents device to sleep
                albumImageTableView.tableHeaderView = nil
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func pushView(_ viewController: UIViewController?) {
        guard let viewController = viewController else {
            return
        }
        
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
        var rootAlbumViewController: AlbumImageTableViewController? = nil
        for viewController in navigationController?.viewControllers ?? []
        {
            // Look for AlbumImagesViewControllers
            if let thisViewController = viewController as? AlbumImageTableViewController
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
            let defaultAlbumSB = UIStoryboard(name: "AlbumImageTableViewController", bundle: nil)
            guard let defaultAlbum = defaultAlbumSB.instantiateViewController(withIdentifier: "AlbumImageTableViewController") as? AlbumImageTableViewController else {
                fatalError("!!! No AlbumImageTableViewController !!!")
            }
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


// MARK: - UITableViewDatasource
extension AlbumImageTableViewController: UITableViewDataSource
{
    func hasAlbumDataToShow() -> Bool {
        // Album data to show in sub-album?
        if albumData.comment.string.isEmpty,
           albumCollectionVC.nberSubAlbums == 0 {
            return false
        }
        return true
    }
    
    private func activeRow(_ row: Int) -> Int {
        // Only albums in root album
        if categoryId == 0 {
            return row
        }
        
        // Album data to show in sub-album?
        return hasAlbumDataToShow() ? row : row+1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if categoryId == 0 {
            return 1    // Only albums in root album
        } else {
            return hasAlbumDataToShow() ? 2 : 1    // Albums and images
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch activeRow(indexPath.row) {
        case 0:
            // Initialise album collection view cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumCollectionTableViewCell", for: indexPath) as? AlbumCollectionTableViewCell
            else { preconditionFailure("Failed to load AlbumCollectionTableViewCell") }
            
            // Add album view controller to container view controller
            cell.albumVC = albumCollectionVC
            if cell.subviews.contains(albumCollectionVC.view) == false {
                // Add view controller to container view controller
                add(asChildViewController: albumCollectionVC, toCell: cell)
            }
            
            // For auto-sizing the cell after collection view layouting
            albumCollectionCell = cell
            return cell
            
        default:
            // Initialise image collection view cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCollectionTableViewCell", for: indexPath) as? ImageCollectionTableViewCell
            else { preconditionFailure("Failed to laod ImageCollectionTableViewCell") }

            // Add view controller to container view controller
            cell.imageVC = imageCollectionVC
            if cell.subviews.contains(imageCollectionVC.view) == false {
                add(asChildViewController: imageCollectionVC, toCell: cell)
            }

            // For auto-sizing the cell after collection view layouting
            imageCollectionCell = cell
            return cell
        }
    }
    
    private func add(asChildViewController viewController: UIViewController, toCell cell: UIView) {
        // Add child view controller
        addChild(viewController)

        // Add child view as subview
        cell.addSubview(viewController.view)

        // Define Constraints
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewController.view.topAnchor.constraint(equalTo: cell.topAnchor),
            viewController.view.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            viewController.view.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            viewController.view.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
        ])

        // Notify child view Controller
        viewController.didMove(toParent: self)
    }
}


// MARK: - UITableViewDelegate
extension AlbumImageTableViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}


// MARK: - UIScrollViewDelegate
extension AlbumImageTableViewController
{
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if round(scrollView.contentOffset.y) > 0 {
            // Show navigation bar border
            if #available(iOS 13.0, *) {
                let navBar = navigationItem
                let barAppearance = navBar.standardAppearance
                let shadowColor = AppVars.shared.isDarkPaletteActive ? UIColor(white: 1.0, alpha: 0.15) : UIColor(white: 0.0, alpha: 0.3)
                if barAppearance?.shadowColor != shadowColor {
                    barAppearance?.shadowColor = shadowColor
                    navBar.scrollEdgeAppearance = barAppearance
                }
            }
        } else {
            // Hide navigation bar border
            if #available(iOS 13.0, *) {
                let navBar = navigationItem
                let barAppearance = navBar.standardAppearance
                if barAppearance?.shadowColor != UIColor.clear {
                    barAppearance?.shadowColor = UIColor.clear
                    navBar.scrollEdgeAppearance = barAppearance
                }
            }
        }
    }
}
