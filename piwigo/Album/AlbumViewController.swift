//
//  AlbumViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 11/06/2022
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit
//import StoreKit

let kRadius: CGFloat = 25.0
let kDeg2Rad: CGFloat = 3.141592654 / 180.0

enum pwgImageAction {
    case edit, delete, share
    case copyImages, moveImages
    case addToFavorites, removeFromFavorites
}

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIToolbarDelegate, UIScrollViewDelegate, ImageDetailDelegate, AlbumCollectionViewCellDelegate, SelectCategoryDelegate, ChangedSettingsDelegate
{
    var categoryId = Int32.zero
    var totalNumberOfImages = 0
    var selectedImageIds = Set<Int64>()
    var selectedImageIdsLoop = Set<Int64>()
    var selectedFavoriteIds = Set<Int64>()

    var imagesCollection: UICollectionView?
    var searchController: UISearchController?
    private var imageOfInterest = IndexPath(item: 0, section: 1)
    
    lazy var settingsBarButton: UIBarButtonItem = getSettingsBarButton()
    lazy var discoverBarButton: UIBarButtonItem = getDiscoverButton()
    var actionBarButton: UIBarButtonItem?
    lazy var moveBarButton: UIBarButtonItem = getMoveBarButton()
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    lazy var shareBarButton: UIBarButtonItem = getShareBarButton()
    lazy var favoriteBarButton: UIBarButtonItem = getFavoriteBarButton()

    var pauseSearch = false
    var oldImageIds = Set<Int64>()
    var onPage = 0, lastPage = 0

    var isSelect = false
    var touchedImageIds = [Int64]()
    lazy var cancelBarButton: UIBarButtonItem = getCancelBarButton()
    lazy var selectBarButton: UIBarButtonItem = getSelectBarButton()

    lazy var addButton: UIButton = getAddButton()
    lazy var createAlbumButton: UIButton = getCreateAlbumButton()
    var createAlbumAction: UIAlertAction!
    lazy var homeAlbumButton: UIButton = getHomeButton()
    lazy var uploadImagesButton: UIButton = getUploadImagesButton()
    lazy var uploadQueueButton: UIButton = getUploadQueueButton()
    lazy var progressLayer: CAShapeLayer = getProgressLayer()
    lazy var nberOfUploadsLabel: UILabel = getNberOfUploadsLabel()

    var imageDetailView: ImageViewController?
    private var updateOperations = [BlockOperation]()

    // See https://medium.com/@tungfam/custom-uiviewcontroller-transitions-in-swift-d1677e5aa0bf
//@property (nonatomic, strong) ImageCollectionViewCell *selectedCell;    // Cell that was selected
//@property (nonatomic, strong) UIView *selectedCellImageViewSnapshot;    // Snapshot of the image view
//@property (nonatomic, strong) ImageAnimatedTransitioning *animator;     // Image cell animator
    
    init(albumId: Int32) {
        super.init(nibName: nil, bundle: nil)
        
        // Store album ID
        categoryId = albumId
        
        // Place search bar in navigation bar of root album
        if albumId == 0 {
            initSearchBar()
        }
        
        // Initialise selection mode
        isSelect = false

        // Hide toolbar
        navigationController?.isToolbarHidden = true

        // Collection of images
        imagesCollection = UICollectionView(frame: view.frame, collectionViewLayout: UICollectionViewFlowLayout())
        imagesCollection?.translatesAutoresizingMaskIntoConstraints = false
        imagesCollection?.alwaysBounceVertical = true
        imagesCollection?.showsVerticalScrollIndicator = true
        imagesCollection?.backgroundColor = UIColor.clear
        imagesCollection?.dataSource = self
        imagesCollection?.delegate = self

        // Refresh view
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        imagesCollection?.refreshControl = refreshControl

        imagesCollection?.register(UINib(nibName: "ImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ImageCollectionViewCell")
        imagesCollection?.register(AlbumCollectionViewCell.self, forCellWithReuseIdentifier: "AlbumCollectionViewCell")
        imagesCollection?.register(AlbumHeaderReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "CategoryHeader")
        imagesCollection?.register(NberImagesFooterCollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "NberImagesFooterCollection")
        if let imagesCollection = imagesCollection {
            view.addSubview(imagesCollection)
            view.addConstraints(NSLayoutConstraint.constraintFillSize(imagesCollection)!)
        }
        imagesCollection?.contentInsetAdjustmentBehavior = .always

        // Add buttons above collection view and other buttons
        if let imagesCollection = imagesCollection {
            view.insertSubview(addButton, aboveSubview: imagesCollection)
        }
        uploadQueueButton.layer.addSublayer(progressLayer)
        uploadQueueButton.addSubview(nberOfUploadsLabel)
        view.insertSubview(uploadQueueButton, belowSubview: addButton)
        view.insertSubview(homeAlbumButton, belowSubview: addButton)
        view.insertSubview(createAlbumButton, belowSubview: addButton)
        view.insertSubview(uploadImagesButton, belowSubview: addButton)
    }

    // Number of images to download per page
    lazy var perPage: Int = {
        return max(AlbumUtilities.numberOfImagesToDownloadPerPage(), 100)
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

    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        let provider : UserProvider = UserProvider.shared
        return provider
    }()

    lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()

    lazy var imageProvider: ImageProvider = {
        let provider : ImageProvider = ImageProvider.shared
        return provider
    }()

    
    // MARK: - Core Data Source
    lazy var user: User = {
        guard let user = userProvider.getUserAccount(inContext: mainContext) else {
            // Unknown user instance! —> Back to login view
            ClearCache.closeSession { }
            return User()
        }
        return user
    }()
    
    lazy var albumData: Album = {
        return currentAlbumData()
    }()
    private func currentAlbumData() -> Album {
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
        guard let rootAlbum = albumProvider.getAlbum(ofUser: user, withId: Int32.zero) else {
            fatalError("••> Could not create root album!")
        }
        if rootAlbum.isFault {
            // The root album is not fired yet.
            rootAlbum.willAccessValue(forKey: nil)
            rootAlbum.didAccessValue(forKey: nil)
        }
        changeAlbumID()
        return rootAlbum
    }
    
    lazy var albumPredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "parentId == $catId"))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    lazy var fetchAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        fetchRequest.predicate = albumPredicate.withSubstitutionVariables(["catId" : categoryId])
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()
    
    lazy var imagePredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY albums.pwgID == $catId"))
        andPredicates.append(NSPredicate(format: "ANY albums.user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    lazy var fetchImagesRequest: NSFetchRequest = {
        // Sort images according to default settings
        // PS: Comparator blocks are not supported with Core Data
        let fetchRequest = Image.fetchRequest()
        let sortByIdDesc = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: false)
        let sortByIdAsc = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)
        switch categoryId {
        case pwgSmartAlbum.search.rawValue:
            // 'datePosted' is always accessible (returned by pwg.images.search)
            let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: false)
            fetchRequest.sortDescriptors = [sortByPosted, sortByIdDesc]

        case pwgSmartAlbum.visits.rawValue:
            // 'visits' is always accessible (returned by pwg.category.getImages)
            let sortByVisits = NSSortDescriptor(key: #keyPath(Image.visits), ascending: false)
            fetchRequest.sortDescriptors = [sortByVisits, sortByIdDesc]
        
        case pwgSmartAlbum.best.rawValue:
            // 'ratingScore' is not always accessible (returned by pwg.images.getInfo)
            // so the image list might not be identical to the one returned by the web UI.
            let sortByRateScore = NSSortDescriptor(key: #keyPath(Image.ratingScore), ascending: false)
            fetchRequest.sortDescriptors = [sortByRateScore, sortByIdDesc]
            
        case pwgSmartAlbum.recent.rawValue:
            // 'datePosted' can be unknown and defaults to 01/01/1900 in such situation
            let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: false)
            fetchRequest.sortDescriptors = [sortByPosted, sortByIdDesc]

        default:    // Sorting option chosen by user
            switch AlbumVars.shared.defaultSort {
            // Use the string version of 'title' because
            case .nameAscending:
                let sortByName = NSSortDescriptor(key: #keyPath(Image.titleStr), ascending: true,
                                                  selector: #selector(NSString.localizedCaseInsensitiveCompare))
                fetchRequest.sortDescriptors = [sortByName, sortByIdAsc]
            case .nameDescending:
                let sortByName = NSSortDescriptor(key: #keyPath(Image.titleStr), ascending: false,
                                                  selector: #selector(NSString.localizedCaseInsensitiveCompare))
                fetchRequest.sortDescriptors = [sortByName, sortByIdDesc]
            
            // 'dateCreated' can be unknown and defaults to 01/01/1900 in such situation
            case .dateCreatedDescending:
                let sortByCreated = NSSortDescriptor(key: #keyPath(Image.dateCreated), ascending: false)
                fetchRequest.sortDescriptors = [sortByCreated, sortByIdDesc]
            case .dateCreatedAscending:
                let sortByCreated = NSSortDescriptor(key: #keyPath(Image.dateCreated), ascending: true)
                fetchRequest.sortDescriptors = [sortByCreated, sortByIdAsc]
            
            // 'datePosted' can be unknown and defaults to 01/01/1900 in such situation
            case .datePostedDescending:
                let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: false)
                fetchRequest.sortDescriptors = [sortByPosted, sortByIdDesc]
            case .datePostedAscending:
                let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: true)
                fetchRequest.sortDescriptors = [sortByPosted, sortByIdAsc]
            
            // 'fileName' is generally accessible but can be "" (returned by pwg.category.getImages)
            case .fileNameAscending:
                let sortByFileName = NSSortDescriptor(key: #keyPath(Image.fileName), ascending: true,
                                                      selector: #selector(NSString.localizedStandardCompare))
                fetchRequest.sortDescriptors = [sortByFileName, sortByIdAsc]
            case .fileNameDescending:
                let sortByFileName = NSSortDescriptor(key: #keyPath(Image.fileName), ascending: false,
                                                      selector: #selector(NSString.localizedStandardCompare))
                fetchRequest.sortDescriptors = [sortByFileName, sortByIdDesc]

            // 'ratingScore' is not always accessible (only returned by pwg.images.getInfo)
            // so the image list might not be identical to the one returned by the web UI.
            // It can also be unknown and defaults to -1.0 in such situation
            case .ratingScoreDescending:
                let sortByRatingScore = NSSortDescriptor(key: #keyPath(Image.ratingScore), ascending: false)
                fetchRequest.sortDescriptors = [sortByRatingScore, sortByIdDesc]
            case .ratingScoreAscending:
                let sortByRatingScore = NSSortDescriptor(key: #keyPath(Image.ratingScore), ascending: true)
                fetchRequest.sortDescriptors = [sortByRatingScore, sortByIdAsc]
            
            // 'visits' is always accessible (returned by pwg.category.getImages)
            case .visitsDescending:
                let sortByVisits = NSSortDescriptor(key: #keyPath(Image.visits), ascending: false)
                fetchRequest.sortDescriptors = [sortByVisits, sortByIdDesc]
            case .visitsAscending:
                let sortByVisits = NSSortDescriptor(key: #keyPath(Image.visits), ascending: true)
                fetchRequest.sortDescriptors = [sortByVisits, sortByIdAsc]
            
            // 'rankManual' is set by the iOS app when fetching album images (not returned by API)
            case .manual:
                let sortByRank = NSSortDescriptor(key: #keyPath(Image.rankManual), ascending: true)
                fetchRequest.sortDescriptors = [sortByRank]
                
            // 'rankRandom' is set by the iOS app.
            case .random:
                let sortByRank = NSSortDescriptor(key: #keyPath(Image.rankRandom), ascending: true)
                fetchRequest.sortDescriptors = [sortByRank]
            }
        }
        fetchRequest.predicate = imagePredicate.withSubstitutionVariables(["catId" : categoryId])
        fetchRequest.fetchBatchSize = self.perPage
        return fetchRequest
    }()

    lazy var images: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        images.delegate = self
        return images
    }()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("===============================")
        print("••> viewDidLoad       => ID:\(categoryId)")

        // Initialise data source
        do {
            if categoryId >= Int32.zero {
                try albums.performFetch()
            }
            try images.performFetch()
        } catch {
            print("Error: \(error)")
        }

        // Register palette changes
        NotificationCenter.default.addObserver(self,selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "AlbumImagesNav"
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Refresh controller
        imagesCollection?.refreshControl?.backgroundColor = UIColor.piwigoColorBackground()
        imagesCollection?.refreshControl?.tintColor = UIColor.piwigoColorHeader()
        let attributesRefresh = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)
        ]
        imagesCollection?.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("pullToRefresh", comment: "Reload Photos"), attributes: attributesRefresh)

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

        // Collection view
        imagesCollection?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        let headers = imagesCollection?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        if (headers?.count ?? 0) > 0 {
            let header = headers?.first as? AlbumHeaderReusableView
            header?.commentLabel?.textColor = UIColor.piwigoColorHeader()
            header?.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
        for cell in imagesCollection?.visibleCells ?? [] {
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.applyColorPalette()
                continue
            }
            if let imageCell = cell as? ImageCollectionViewCell {
                imageCell.applyColorPalette()
                continue
            }
        }
        let footers = imagesCollection?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter)
        if let footer = footers?.first as? NberImagesFooterCollectionReusableView {
            footer.noImagesLabel?.textColor = UIColor.piwigoColorHeader()
            footer.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("••> viewWillAppear    => ID:\(categoryId)")

        // Set colors, fonts, etc.
        applyColorPalette()

        // Always open this view with a navigation bar
        // (might have been hidden during Image Previewing)
        navigationController?.setNavigationBarHidden(false, animated: true)

        // Set navigation bar buttons
        initButtonsInPreviewMode()
        updateButtonsInPreviewMode()

        // Register upload changes and progress if displaying default album
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            NotificationCenter.default.addObserver(self, selector: #selector(updateNberOfUploads(_:)),
                                                   name: .pwgLeftUploads, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(updateUploadQueueButton(withProgress:)),
                                                   name: .pwgUploadProgress, object: nil)
        }
        
        // Display albums and images
        imagesCollection?.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("••> viewDidAppear     => ID:\(categoryId)")

        // The user may have cleared the cached data
        // Display an empty root album in that case
        if categoryId == Int32.zero, albumData.isFault {
            return
        }
        
        // Check conditions before loading album and image data
        let lastLoad = albumData.dateGetImages
        let nbImages = (images.fetchedObjects ?? []).count
        let noSmartAlbumData = (self.categoryId < 0) && (nbImages == 0)
        let expectedNbImages = self.albumData.nbImages
        let missingImages = (expectedNbImages > 0) && (nbImages < expectedNbImages / 2)
        if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) == false,
           noSmartAlbumData || missingImages || lastLoad.timeIntervalSinceNow < TimeInterval(-3600) {
            NetworkUtilities.checkSession(ofUser: user) {
                self.startFetchingAlbumAndImages(withHUD: noSmartAlbumData || missingImages)
            } failure: { error in
                print("••> Error \(error.code): \(error.localizedDescription)")
                // TO DO…
            }
        }

        // Should we highlight the image of interest?
        if categoryId != 0, nbImages > 0,
           imageOfInterest.item != 0 {
            // Highlight the cell of interest
            let indexPathsForVisibleItems = imagesCollection?.indexPathsForVisibleItems
            if indexPathsForVisibleItems?.contains(imageOfInterest) ?? false {
                // Thumbnail is already visible and is highlighted
                if let cell = imagesCollection?.cellForItem(at: imageOfInterest),
                   let imageCell = cell as? ImageCollectionViewCell {
                    imageCell.highlight() {
                        self.imageOfInterest = IndexPath(item: 0, section: 1)
                    }
                } else {
                    self.imageOfInterest = IndexPath(item: 0, section: 1)
                }
            }
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
        if AppVars.shared.didShowWhatsNewAppVersion.compare("3.0", options: .numeric) == .orderedAscending,
           let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
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
                    height: ceil(mainScreenBounds.size.height * 2 / 3))
                present(whatsNewVC, animated: true)
            }
            return
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
        if (albums.fetchedObjects ?? []).count > 2, user.hasAdminRights,
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

        // Hide HUD is needded
        navigationController?.hidePiwigoHUD { }
        
        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Reload collection
            imagesCollection?.reloadData()

            // Update buttons
            if isSelect {
                initButtonsInSelectionMode()
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
        PwgSession.shared.dataSession.getAllTasks { tasks in
            // Select tasks related with this album if any
            let tasksToCancel = tasks.filter({ $0.originalRequest?
                .value(forHTTPHeaderField: NetworkVars.HTTPCatID) == String(self.categoryId) })
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel task \($0.taskIdentifier) related with album \(self.categoryId)")
                $0.cancel()
            })
        }
        ImageSession.shared.dataSession.getAllTasks { tasks in
            // Select tasks related with this album if any
            let tasksToCancel = tasks.filter({ $0.originalRequest?
                .value(forHTTPHeaderField: NetworkVars.HTTPCatID) == String(self.categoryId) })
            // Cancel remaining tasks related with this completed upload request
            tasksToCancel.forEach({
                print("\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)) > Cancel task \($0.taskIdentifier) related with album \(self.categoryId)")
                $0.cancel()
            })
        }

        // Hide upload button during transition
        addButton.isHidden = true
        
        // Hide HUD if still presented
        self.navigationController?.hidePiwigoHUD { }
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

        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)

        // Unregister upload changes and progress if was displaying default album
        if [0, AlbumVars.shared.defaultCategory].contains(categoryId) {
            NotificationCenter.default.removeObserver(self, name: .pwgLeftUploads, object: nil)
            NotificationCenter.default.removeObserver(self, name: .pwgUploadProgress, object: nil)
        }
    }

    
    // MARK: - Category Data
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
        imagesCollection?.reloadData()
        
        // Reset buttons and menus
        initButtonsInPreviewMode()
        updateButtonsInPreviewMode()
    }
    
    func resetPredicatesAndPerformFetch() {
        // Update albums
        fetchAlbumsRequest.predicate = albumPredicate.withSubstitutionVariables(["catId" : categoryId])
        try? albums.performFetch()

        // Update images
        fetchImagesRequest.predicate = imagePredicate.withSubstitutionVariables(["catId" : categoryId])
        try? images.performFetch()
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
            self.navigationController?.showPiwigoHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("severalImages", comment: "Photos"),
                buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        }
        
        // Fetch album data and then image data
        fetchAlbumsAndImages { [self] in
            fetchCompleted()
        }
    }

    @objc func refresh(_ refreshControl: UIRefreshControl?) {
        // Already being fetching album data?
        if AlbumVars.shared.isFetchingAlbumData.contains(categoryId) { return }
        
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
                self.imagesCollection?.refreshControl?.endRefreshing()
            }
            print("••> Error \(error.code): \(error.localizedDescription)")
        }
    }
    
    func fetchCompleted() {
        DispatchQueue.main.async { [self] in
            // Hide HUD
            self.navigationController?.hidePiwigoHUD { }

            // Update title
            self.setTitleViewFromAlbumData(whileUpdating: false)

            // Set navigation bar buttons
            if isSelect {
                self.updateButtonsInSelectionMode()
            } else {
                self.updateButtonsInPreviewMode()
            }

            // Update number of images in footer
            self.updateNberOfImagesInFooter()

            // End refreshing if needed
            self.imagesCollection?.refreshControl?.endRefreshing()
        }
        
        // Fetch favorites in the background if needed
        if NetworkVars.userStatus != .guest,
           categoryId != pwgSmartAlbum.favorites.rawValue,
           "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending,
           NetworkVars.pwgVersion.compare("13.0.0", options: .numeric) == .orderedAscending,
           AlbumVars.shared.isFetchingAlbumData.contains(pwgSmartAlbum.favorites.rawValue) == false,
           let favAlbum = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.favorites.rawValue),
           favAlbum.dateGetImages.timeIntervalSinceNow < TimeInterval(-86400) {     // i.e. a day
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
    

    // MARK: - Default Category Management
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
            rootAlbumViewController = AlbumViewController(albumId: AlbumVars.shared.defaultCategory)
            
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

    
    // MARK: - Upload Actions
    @objc func didTapUploadImagesButton() {
        // Check autorisation to access Photo Library before uploading
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: PHAccessLevel.readWrite, for: self, onAccess: { [self] in
                // Open local albums view controller in new navigation controller
                self.presentLocalAlbums()
            }, onDeniedAccess: { })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(self, onAuthorizedAccess: { [self] in
                // Open local albums view controller in new navigation controller
                self.presentLocalAlbums()
            }, onDeniedAccess: { })
        }

        // Hide CreateAlbum and UploadImages buttons
        didCancelTapAddButton()
    }
    
    private func presentLocalAlbums() {
        // Open local albums view controller in new navigation controller
        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController else {
            fatalError("No LocalAlbumsViewController!")
        }
        localAlbumsVC.categoryId = categoryId
        localAlbumsVC.user = user
        let navController = UINavigationController(rootViewController: localAlbumsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .pageSheet
        present(navController, animated: true)
    }

    @objc func didTapUploadQueueButton() {
        // Open upload queue controller in new navigation controller
        var navController: UINavigationController? = nil
        if #available(iOS 13.0, *) {
            let uploadQueueSB = UIStoryboard(name: "UploadQueueViewController", bundle: nil)
            guard let uploadQueueVC = uploadQueueSB.instantiateViewController(withIdentifier: "UploadQueueViewController") as? UploadQueueViewController else {
                fatalError("No UploadQueueViewController!")
            }
            navController = UINavigationController(rootViewController: uploadQueueVC)
        }
        else {
            // Fallback on earlier versions
            let uploadQueueSB = UIStoryboard(name: "UploadQueueViewControllerOld", bundle: nil)
            guard let uploadQueueVC = uploadQueueSB.instantiateViewController(withIdentifier: "UploadQueueViewControllerOld") as? UploadQueueViewControllerOld else {
                fatalError("No UploadQueueViewControllerOld!")
            }
            navController = UINavigationController(rootViewController: uploadQueueVC)
        }
        navController?.modalTransitionStyle = .coverVertical
        navController?.modalPresentationStyle = .formSheet
        if let navController = navController {
            present(navController, animated: true)
        }
    }

    
    // MARK: - UICollectionView Headers & Footers
    func getImageCount() -> String {
        // Get total number of images
        var totalCount = Int64.zero
        if categoryId == 0 {
            // Root Album only contains albums  => calculate total number of images
            (albums.fetchedObjects ?? []).forEach({ album in
                totalCount += album.totalNbImages
            })
        } else {
            // Number of images in current album
            totalCount = albumData.nbImages
        }
        
        // Build footer content
        var legend = ""
        if totalCount == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if totalCount == Int64.zero {
            // Not loading and no images
            if categoryId == Int64.zero {
                legend = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
            } else {
                legend = NSLocalizedString("noImages", comment:"No Images")
            }
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: totalCount)) {
                let format:String = totalCount > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        switch indexPath.section {
        case 0 /* Section 0 — Album collection */:
            var header: AlbumHeaderReusableView? = nil
            if kind == UICollectionView.elementKindSectionHeader {
                header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "CategoryHeader", for: indexPath) as? AlbumHeaderReusableView
                let desc = NSMutableAttributedString(attributedString: albumData.comment)
                let wholeRange = NSRange(location: 0, length: desc.string.count)
                let style = NSMutableParagraphStyle()
                style.alignment = NSTextAlignment.center
                let attributes = [
                    NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
                    NSAttributedString.Key.paragraphStyle: style
                ]
                desc.addAttributes(attributes, range: wholeRange)
                header?.commentLabel?.attributedText = desc
                return header!
            }
        case 1 /* Section 1 — Image collection */:
            if kind == UICollectionView.elementKindSectionFooter {
                // Get number of images and status
                guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "NberImagesFooterCollection", for: indexPath) as? NberImagesFooterCollectionReusableView else {
                    fatalError("No NberImagesFooterCollectionReusableView!")
                }
                footer.noImagesLabel?.textColor = UIColor.piwigoColorHeader()
                footer.noImagesLabel?.text = getImageCount()
                return footer
            }
        default:
            break
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) ||
            (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
            view.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        switch section {
        case 0 /* Section 0 — Album collection */:
            // Header height?
            guard !albumData.comment.string.isEmpty else {
                return CGSize.zero
            }
            let desc = NSMutableAttributedString(attributedString: albumData.comment)
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)

            if collectionView.frame.size.width - 30.0 > 0 {
                let context = NSStringDrawingContext()
                context.minimumScaleFactor = 1.0
                let headerRect = desc.boundingRect(with: CGSize(width: collectionView.frame.size.width - 30.0,
                                                                height: CGFloat.greatestFiniteMagnitude),
                                                   options: .usesLineFragmentOrigin, context: context)
                return CGSize(width: collectionView.frame.size.width - 30.0,
                              height: ceil(headerRect.size.height))
            }
        default:
            break
        }

        return CGSize.zero
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        switch section {
        case 1 /* Section 1 — Image collection */:
            // Get number of images and status
            let footer = getImageCount()
            if footer.count > 0,
               collectionView.frame.size.width - 30.0 > 0 {
                let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .light)]
                let context = NSStringDrawingContext()
                context.minimumScaleFactor = 1.0
                let footerRect = footer.boundingRect(
                    with: CGSize(width: collectionView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    attributes: attributes, context: context)
                return CGSize(width: collectionView.frame.size.width - 30.0, height: ceil(footerRect.size.height))
            }
        default:
            break
        }

        return CGSize.zero
    }

    
    // MARK: - UICollectionView - Rows
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0 /* Albums */:
            let objects = albums.fetchedObjects
            return objects?.count ?? 0
        
        default /* Images */:
            let objects = images.fetchedObjects
            return objects?.count ?? 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        // Avoid unwanted spaces
        switch section {
        case 0 /* Albums */:
            if collectionView.numberOfItems(inSection: section) == 0 {
                return UIEdgeInsets(top: 0, left: AlbumUtilities.kAlbumMarginsSpacing,
                                    bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
            } else if categoryId == 0 {
                if #available(iOS 13.0, *) {
                    return UIEdgeInsets(top: 0, left: AlbumUtilities.kAlbumMarginsSpacing,
                                        bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
                } else {
                    return UIEdgeInsets(top: 10, left: AlbumUtilities.kAlbumMarginsSpacing,
                                        bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
                }
            } else {
                return UIEdgeInsets(top: 10, left: AlbumUtilities.kAlbumMarginsSpacing, bottom: 0,
                                    right: AlbumUtilities.kAlbumMarginsSpacing)
            }
        default /* Images */:
            if collectionView.numberOfItems(inSection: section) == 0 {
                return UIEdgeInsets(top: 0, left: AlbumUtilities.kImageMarginsSpacing,
                                    bottom: 0, right: AlbumUtilities.kImageMarginsSpacing)
            } else if albumData.comment.string.isEmpty {
                return UIEdgeInsets(top: 4, left: AlbumUtilities.kImageMarginsSpacing,
                                    bottom: 4, right: AlbumUtilities.kImageMarginsSpacing)
            } else {
                return UIEdgeInsets(top: 10, left: AlbumUtilities.kImageMarginsSpacing,
                                    bottom: 4, right: AlbumUtilities.kImageMarginsSpacing)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            return 0.0
        
        default /* Images */:
            return CGFloat(AlbumUtilities.imageCellVerticalSpacing(forCollectionType: .full))
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch section {
        case 0 /* Albums */:
            return AlbumUtilities.kAlbumCellSpacing
        
        default /* Images */:
            return AlbumUtilities.imageCellHorizontalSpacing(forCollectionType: .full)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch indexPath.section {
        case 0 /* Albums (see XIB file) */:
            let size = AlbumUtilities.albumSize(forView: collectionView, maxWidth: 384.0)
            return CGSize(width: size, height: 156.5)
        
        default /* Images */:
            // Calculates size of image cells
            let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait
            let size = AlbumUtilities.imageSize(forView: imagesCollection, imagesPerRowInPortrait: nbImages)
            return CGSize(width: size, height: size)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0 /* Albums (see XIB file) */:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCell", for: indexPath) as? AlbumCollectionViewCell else {
                fatalError("No AlbumCollectionViewCell!")
            }

            // Configure cell with album data
            let albumCell = albums.object(at: indexPath)
            if albumCell.isFault {
                // The album is not fired yet.
                albumCell.willAccessValue(forKey: nil)
                albumCell.didAccessValue(forKey: nil)
            }
            cell.albumData = albumCell
            cell.categoryDelegate = self

            // Disable category cells in Image selection mode
            if isSelect {
                cell.contentView.alpha = 0.5
                cell.isUserInteractionEnabled = false
            } else {
                cell.contentView.alpha = 1.0
                cell.isUserInteractionEnabled = true
            }

            return cell
            
        default /* Images */:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCollectionViewCell", for: indexPath) as? ImageCollectionViewCell else {
                fatalError("No ImageCollectionViewCell!")
            }

            // Create cell from Piwigo data
            let imageIndexPath = IndexPath(item: indexPath.item, section: 0)
            let image = images.object(at: imageIndexPath)
            cell.config(with: image, inCategoryId: categoryId)
            cell.isSelection = selectedImageIds.contains(image.pwgID)

            // pwg.users.favorites… methods available from Piwigo version 2.10
            if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                cell.isFavorite = (image.albums ?? Set<Album>())
                    .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
            }

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
    }

    
    // MARK: - UICollectionViewDelegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0 /* Albums */:
            break
        
        default /* Images */:
            // Check data
            guard let selectedCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
                  indexPath.item >= 0, indexPath.item < (images.fetchedObjects ?? []).count else {
                return
            }

            // Action depends on mode
            if isSelect {
                // Check image ID
                guard let imageId = selectedCell.imageData?.pwgID, imageId != 0 else {
                    return
                }
                
                // Selection mode active => add/remove image from selection
                if !selectedImageIds.contains(imageId) {
                    selectedImageIds.insert(imageId)
                    selectedCell.isSelection = true
                    if selectedCell.isFavorite {
                        selectedFavoriteIds.insert(imageId)
                    }
                } else {
                    selectedCell.isSelection = false
                    selectedImageIds.remove(imageId)
                    selectedFavoriteIds.remove(imageId)
                }
                
                // and update nav buttons
                updateButtonsInSelectionMode()
                return
            }
            
            // Display the image in fullscreen mode
            if AppVars.shared.inSingleDisplayMode {

                // Add category to list of recent albums
                let userInfo = ["categoryId": NSNumber(value: categoryId)]
                NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

                // Selection mode not active => display full screen image
                let imageDetailSB = UIStoryboard(name: "ImageViewController", bundle: nil)
                imageDetailView = imageDetailSB.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController
                imageDetailView?.imageIndex = indexPath.item
                imageDetailView?.categoryId = categoryId
                imageDetailView?.images = images
                imageDetailView?.user = user
                imageDetailView?.imgDetailDelegate = self
                imageDetailView?.hidesBottomBarWhenPushed = true
                imageDetailView?.modalPresentationCapturesStatusBarAppearance = true
//                self.imageDetailView.transitioningDelegate = self;
//                self.selectedCellImageViewSnapshot = [self.selectedCell.cellImage snapshotViewAfterScreenUpdates:NO];
                if let imageDetailView = imageDetailView {
                    navigationController?.pushViewController(imageDetailView, animated: true)
                }
            } else {
                // Check image data
                guard let imageData = selectedCell.imageData else {
                    return
                }
                
                // Present image on external screen
                if #available(iOS 13.0, *) {
                    var wantedRole: UISceneSession.Role!
                    for scene in UIApplication.shared.connectedScenes {
                        if #available(iOS 16.0, *) {
                            wantedRole = .windowExternalDisplayNonInteractive
                        } else {
                            // Fallback on earlier versions
                            wantedRole = .windowExternalDisplay
                        }
                        if scene.session.role == wantedRole,
                           let windowScene = scene as? UIWindowScene,
                           let imageVC = windowScene.rootViewController() as? ExternalDisplayViewController {
                            imageVC.dismissVideoPlayerIfNeeded()
                            imageVC.imageData = imageData
                            imageVC.configImage()
                        }
                    }
                }
                
                // Shows which image was tapped
//                if let oldCell = collectionView.cellForItem(at: imageOfInterest) as? ImageCollectionViewCell {
//                    oldCell.darkenView.isHidden = true
//                }
//                selectedCell.darkenView.isHidden = false
            }
            
            // Remember that user did tap this image
            imageOfInterest = indexPath
        }
    }

    
    // MARK: - ImageDetailDelegate Methods
    func didSelectImage(atIndex imageIndex: Int) {
        // Scroll view to center image
        if (imagesCollection?.numberOfItems(inSection: 1) ?? 0) > imageIndex {
            let indexPath = IndexPath(item: imageIndex, section: 1)
            imageOfInterest = indexPath
            imagesCollection?.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
    }

    
    // MARK: - SelectCategoryDelegate Methods
    func didSelectCategory(withId category: Int32) {
        if category == Int32.min {
            setEnableStateOfButtons(true)
        } else {
            cancelSelect()
        }
    }

    
    // MARK: - ChangedSettingsDelegate Methods
    func didChangeDefaultAlbum() {
        // Change default album
        categoryId = AlbumVars.shared.defaultCategory
        albumData = currentAlbumData()
        changeAlbumID()
    }

    func didChangeRecentPeriod() {
        // Reload album
        imagesCollection?.reloadData()
    }

    
    // MARK: - AlbumCollectionViewCellDelegate Methods (+ PushView:)
    func didDeleteCategory(withError error: NSError?, viewController topViewController: UIViewController?) {
        guard let error = error else {
            // Remember that the app is fetching all album data
            AlbumVars.shared.isFetchingAlbumData.insert(0)

            // Use the AlbumProvider to fetch album data. On completion,
            // handle general UI updates and error alerts on the main queue.
            let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
            albumProvider.fetchAlbums(forUser: user, inParentWithId: 0, recursively: true,
                                      thumbnailSize: thumnailSize) { [self] error in
                // ► Remove current album from list of album being fetched
                AlbumVars.shared.isFetchingAlbumData.remove(0)
                
                // Check error
                guard let error = error as? NSError else {
                    // No error ► Hide HUD, update
                    DispatchQueue.main.async { [self] in
                        topViewController?.updatePiwigoHUDwithSuccess() {
                            topViewController?.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                                // Update number of images in footer
                                self.updateNberOfImagesInFooter()
                            }
                        }
                    }
                    return
                }
                
                // Show the error
                DispatchQueue.main.async { [self] in
                    topViewController?.hidePiwigoHUD {
                        // Display error alert after trying to share image
                        self.deleteCategoryError(error, viewController: topViewController)
                    }
                }
            }
            return
        }

        // Show the error
        DispatchQueue.main.async { [self] in
            topViewController?.hidePiwigoHUD {
                // Display error alert after trying to share image
                self.deleteCategoryError(error, viewController: topViewController)
            }
        }
    }

    private func deleteCategoryError(_ error: NSError, viewController topViewController: UIViewController?) {
        DispatchQueue.main.async {
            let title = NSLocalizedString("loadingHUD_label", comment: "Loading…")
            let message = NSLocalizedString("CoreDataFetch_AlbumError", comment: "Fetch albums error!")
            topViewController?.hidePiwigoHUD() {
                topViewController?.dismissPiwigoError(withTitle: title, message: message,
                                                      errorMessage: error.localizedDescription) {
                }
            }
        }
    }

    @objc
    func pushCategoryView(_ viewController: UIViewController?,
                          completion: @escaping (Bool) -> Void) {
        guard let viewController = viewController else {
            return
        }

        // Push sub-album, Discover or Favorites album
        if viewController is AlbumViewController {
            // Push sub-album view
            navigationController?.pushViewController(viewController, animated: true)
        }
        else {
            // Push album list
            if UIDevice.current.userInterfaceIdiom == .pad {
                viewController.modalPresentationStyle = .popover
                viewController.popoverPresentationController?.sourceView = imagesCollection
                viewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
                navigationController?.present(viewController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
            }
            else {
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.sourceView = view
                navController.modalTransitionStyle = .coverVertical
                navigationController?.present(navController, animated: true) {
                    // Hide swipe commands
                    completion(true)
                }
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


    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navBarHeight = (navigationController?.navigationBar.frame.origin.y ?? 0.0) + (navigationController?.navigationBar.frame.size.height ?? 0.0)
        //    NSLog(@"==>> %f", scrollView.contentOffset.y + navBarHeight);
        if (roundf(Float(scrollView.contentOffset.y + navBarHeight)) > 1) ||
            (categoryId != AlbumVars.shared.defaultCategory) {
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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension AlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [images, albums].contains(controller) == false { return }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Check that this update should be managed by this view controller
        guard let fetchDelegate = controller.delegate as? AlbumViewController else { return }
        if view.window == nil || [images, albums].contains(controller) == false { return }

        // Collect operation changes
        switch type.rawValue {
        case NSFetchedResultsChangeType.delete.rawValue:
            guard var indexPath = indexPath else { return }
            if let image = anObject as? Image {
                indexPath.section = 1
                selectedImageIds.remove(image.pwgID)
            }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Delete item of album #\(fetchDelegate.categoryId) at \(indexPath)")
                self?.imagesCollection?.deleteItems(at: [indexPath])
            })
            // Disable menu if this is the last deleted image
            if albumData.nbImages == 0 {
                updateOperations.append( BlockOperation { [weak self] in
                    print("••> Last removed image ► disable menu")
                    self?.isSelect = false
                    self?.updateButtonsInPreviewMode()
                })
            }
        case NSFetchedResultsChangeType.update.rawValue:
            guard let indexPath = indexPath else { return }
            if let image = anObject as? Image {
                let cellIndexPath = IndexPath(item: indexPath.item, section: 1)
                updateOperations.append( BlockOperation {  [weak self] in
                    print("••> Update image at \(cellIndexPath) of album #\(fetchDelegate.categoryId)")
                    if let cell = self?.imagesCollection?.cellForItem(at: cellIndexPath) as? ImageCollectionViewCell {
                        // Re-configure image cell
                        cell.config(with: image, inCategoryId: fetchDelegate.categoryId)
                        // pwg.users.favorites… methods available from Piwigo version 2.10
                        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                            cell.isFavorite = (image.albums ?? Set<Album>())
                                .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                        }
                    }
                })
            } else if let album = anObject as? Album {
                updateOperations.append( BlockOperation {  [weak self] in
                    print("••> Update album at \(indexPath) of album #\(fetchDelegate.categoryId)")
                    if let cell = self?.imagesCollection?.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                        // Re-configure album cell
                        cell.albumData = album
                    }
                })
            }
        case NSFetchedResultsChangeType.insert.rawValue:
            guard var newIndexPath = newIndexPath else { return }
            if anObject is Image { newIndexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
                print("••> Insert item of album #\(fetchDelegate.categoryId) at \(newIndexPath)")
                self?.imagesCollection?.insertItems(at: [newIndexPath])
            })
            // Enable menu if this is the first added image
            if albumData.nbImages == 1 {
                updateOperations.append( BlockOperation { [weak self] in
                    print("••> First added image ► enable menu")
                    self?.updateButtonsInPreviewMode()
                })
            }
        case NSFetchedResultsChangeType.move.rawValue:
            guard var indexPath = indexPath,
                  var newIndexPath = newIndexPath,
                  indexPath != newIndexPath else { return }
            if anObject is Image {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Move item of album #\(fetchDelegate.categoryId) from \(indexPath) to \(newIndexPath)")
                self?.imagesCollection?.moveItem(at: indexPath, to: newIndexPath)
            })
        default:
            fatalError("AlbumViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [images, albums].contains(controller) == false || updateOperations.isEmpty { return }

        // Update objects
        imagesCollection?.performBatchUpdates({ [weak self] in
            self?.updateOperations.forEach({ $0.start()})
        }) { [weak self] _ in
            // Update footer
            self?.updateNberOfImagesInFooter()
        }
    }
}
