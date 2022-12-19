//
//  SelectCategoryViewController
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit
import piwigoKit
import CoreData
import CoreMedia

enum pwgCategorySelectAction {
    case none
    case setDefaultAlbum, moveAlbum, setAlbumThumbnail, setAutoUploadAlbum
    case copyImage, moveImage, copyImages, moveImages
}

@objc
protocol SelectCategoryDelegate: NSObjectProtocol {
    func didSelectCategory(withId category: Int32)
}

@objc
protocol SelectCategoryAlbumMovedDelegate {
    func didMoveCategory()
}

@objc
protocol SelectCategoryImageCopiedDelegate: NSObjectProtocol {
    func didCopyImage(withData imageData: PiwigoImageData)
}

@objc
protocol SelectCategoryImageRemovedDelegate {
    func didRemoveImage(withId imageId: Int)
}

class SelectCategoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @objc weak var delegate: SelectCategoryDelegate?
    @objc weak var albumMovedDelegate: SelectCategoryAlbumMovedDelegate?
    @objc weak var imageCopiedDelegate: SelectCategoryImageCopiedDelegate?
    @objc weak var imageRemovedDelegate: SelectCategoryImageRemovedDelegate?

    var userProvider: UserProvider!
    var albumProvider: AlbumProvider!
    var imageProvider: ImageProvider!
    var savingContext: NSManagedObjectContext!
    
    private var wantedAction: pwgCategorySelectAction = .none  // Action to perform after category selection
    private var inputCategoryId: Int32 = Int32.min
    private var inputCategoryData: Album!
    private var inputImageData: Image!
    private var inputImageIds: [Int64]!
    private var inputImagesData = [Image]()
    private var totalNumberOfImages = Int.zero
    private var selectedCategoryId = Int32.min

    func setInput(parameter:Any?, for action:pwgCategorySelectAction) -> Bool {
        wantedAction = action
        switch action {
        case .setDefaultAlbum, .setAutoUploadAlbum:
            guard let albumId = parameter as? Int32 else {
                debugPrint("Input parameter expected to be an Int32.")
                return false
            }
            // Actual default album or actual album in which photos are auto-uploaded
            // to be replaced by the selected one
            inputCategoryId = albumId
            inputCategoryData = albumProvider?.getAlbum(inContext: savingContext, withId: albumId)
            
        case .moveAlbum:
            guard let albumData = parameter as? Album else {
                debugPrint("Input parameter expected to be of Album type.")
                return false
            }
            // Album which will be moved into the selected one
            inputCategoryId = albumData.pwgID
            inputCategoryData = albumData
            
        case .setAlbumThumbnail:
            guard let array = parameter as? [Any],
                  let categoryId = array[0] as? Int32,
                  let imageData = array[1] as? Image else {
                debugPrint("Input parameter expected to be of type [Int32, Image].")
                return false
            }
            // Image which will be set thumbnail of the selected album
            inputCategoryId = categoryId
            inputImageData = imageData
            
        case .copyImage:
            guard let array = parameter as? [Any],
                  let imageData = array[0] as? Image,
                  let categoryId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [Image, Int32].")
                return false
            }
            // Image of the category ID which will be copied to the selected album
//            inputImageData = imageData
//            inputCategoryId = categoryId

        case .moveImage:
            guard let array = parameter as? [Any],
                  let imageData = array[0] as? Image,
                  let categoryId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [Image, Int32]")
                return false
            }
            // Image of the category ID which will be moved to the selected album
//            inputImageData = imageData
//            inputCategoryId = categoryId

        case .copyImages:
            guard let array = parameter as? [Any],
                  let imageIds = array[0] as? [NSNumber],
                  let categoryId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [[NSNumber], Int32]")
                return false
            }
            // Image IDs of the category ID which will be copied to the selected album
//            inputImageIds = imageIds.map({$0.intValue}).filter({ $0 != Int64.min})
            if inputImageIds.isEmpty {
                debugPrint("List of image IDs should not be empty")
                return false
            }
//            inputImageData = CategoriesData.sharedInstance().getImageForCategory(categoryId, andId: inputImageIds[0])
            if inputImageData == nil {
                debugPrint("No available image data in cache")
                return false
            }
            inputCategoryId = categoryId

        case .moveImages:
            guard let array = parameter as? [Any],
                  let imageIds = array[0] as? [NSNumber],
                  let categoryId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [[NSNumber], Int32]")
                return false
            }
            // Image IDs of the category ID which will be moved to the selected album
//            inputImageIds = imageIds.map({$0.intValue}).filter({ $0 != Int64.min})
            if inputImageIds.isEmpty {
                debugPrint("List of image IDs should not be empty")
                return false
            }
//            inputImageData = CategoriesData.sharedInstance().getImageForCategory(categoryId, andId: inputImageIds[0])
            if inputImageData == nil {
                debugPrint("No available image data in cache")
                return false
            }
//            inputCategoryId = categoryId

        default:
            debugPrint("Called setParameter before setting wanted action")
            return false
        }
        
        return true
    }

    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?

    private var updateOperations: [BlockOperation] = [BlockOperation]()
    private var albumsShowingSubAlbums = Set<Int32>()
    private var nberOfSelectedImages = Float(0)

    
    // MARK: - Core Data Source
    lazy var user = userProvider?.getUserAccount(inContext: savingContext)
    
    lazy var userUploadRights: [Int32] = {
        // Case of Community user?
        if NetworkVars.userStatus != .normal { return [] }
        let userUploadRights = user?.uploadRights ?? ""
        return userUploadRights.components(separatedBy: ",").compactMap({ Int32($0) })
    }()
    
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY users.username == %@", NetworkVars.username))
        return andPredicates
    }()

    lazy var fetchRecentAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        var andPredicates = predicates
        var recentCatIds = AlbumVars.shared.recentCategories.components(separatedBy: ",").compactMap({Int32($0)})
        // Root album proposed for some actions, input album not proposed
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) == false {
            recentCatIds.removeAll(where: {$0 == Int32.zero})
        }
        recentCatIds.removeAll(where: {($0 == self.inputCategoryId) || ($0 == self.inputCategoryData?.parentId ?? 0)})
        andPredicates.append(NSPredicate(format: "pwgID IN %@", recentCatIds))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = 5
        return fetchRequest
    }()

    lazy var recentAlbums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchRecentAlbumsRequest,
                                                managedObjectContext: self.savingContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()

    lazy var fetchAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        
        // Only show albums at the root at start
        let nonSmartAlbumPredicate = NSPredicate(format: "pwgID > 0")
        var orPredicates = [NSPredicate(format: "parentId == 0")]
        for albumId in albumsShowingSubAlbums {
            orPredicates.append(NSPredicate(format: "parentId == %ld", albumId))
        }
        let parentPredicates = NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        let albumPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: [nonSmartAlbumPredicate, parentPredicates])

        // The root album is proposed for some actions
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) {
            let rootPredicate = NSPredicate(format: "pwgID == 0")
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [rootPredicate, albumPredicates])
        } else {
            fetchRequest.predicate = albumPredicates
        }
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: self.savingContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Check that a root album exists in cache (create it if necessary)
        guard let _ = albumProvider?.getAlbum(inContext: savingContext,
                                              withId: pwgSmartAlbum.root.rawValue) else {
            return
        }
        
        // Initialise data source
        do {
            try recentAlbums.performFetch()
            try albums.performFetch()
        } catch {
            print("Error: \(error)")
        }

        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "CancelSelect"

        // Register CategoryTableViewCell
        categoriesTableView.register(UINib(nibName: "CategoryTableViewCell", bundle: nil),
                                     forCellReuseIdentifier: "CategoryTableViewCell")

        // Set title and buttons
        switch wantedAction {
        case .setDefaultAlbum:
            title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
        
        case .moveAlbum:
            title = NSLocalizedString("moveCategory", comment:"Move Album")
        
        case .setAlbumThumbnail:
            title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")

        case .setAutoUploadAlbum:
            title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
            
        case .copyImage, .copyImages:
            title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            
        case .moveImage, .moveImages:
            title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            
        default:
            title = ""
        }
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        setTableViewMainHeader()
        categoriesTableView.separatorColor = .piwigoColorSeparator()
        categoriesTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
//        buildCategoryArray {
//            self.categoriesTableView.reloadData()
//        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation "Cancel" button and identifier
        navigationItem.setRightBarButton(cancelBarButton, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
        
        // Retrieve image data if needed
        if [.copyImages, .moveImages].contains(wantedAction) {
            totalNumberOfImages = inputImageIds.count
            if totalNumberOfImages > 1 {
                showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment:"Loading…"), inMode: .annularDeterminate)
            } else {
                showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment:"Loading…"), inMode: .indeterminate)
            }
            inputImagesData = []
            retrieveImageData()
        }

        // Display albums
        categoriesTableView?.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Use the AlbumProvider to fetch album data recursively. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        albumProvider?.fetchAlbums(inParentWithId: 0, recursively: true,
                                   thumbnailSize: thumnailSize) { [self] error in
            guard let error = error else {
                // No error ► Done
                return
            }
            
            // Show the error
            DispatchQueue.main.async { [self] in
                dismissPiwigoError(withTitle: NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error"), message: error.localizedDescription) { }
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { context in

            // On iPad, the Settings section is presented in a centered popover view
            if UIDevice.current.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                self.popoverPresentationController?.sourceRect = CGRect(x: mainScreenBounds.midX,
                                                                        y: mainScreenBounds.midY,
                                                                        width: 0, height: 0)
                switch self.wantedAction {
                case .setDefaultAlbum, .setAutoUploadAlbum:
                    self.preferredContentSize = CGSize(width: kPiwigoPadSettingsWidth,
                                                       height: ceil(mainScreenBounds.height*2/3));
                default:
                    self.preferredContentSize = CGSize(width: kPiwigoPadSubViewWidth,
                                                       height: ceil(mainScreenBounds.height*2/3));
                }
            }

            // Reload table view
            self.setTableViewMainHeader()
            self.categoriesTableView?.reloadData()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Re-enable toolbar items in image preview mode
        if [.setAlbumThumbnail,
            .copyImage, .copyImages,
            .moveImage, .moveImages].contains(wantedAction) {
            self.delegate?.didSelectCategory(withId: selectedCategoryId)
        }
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
    
    @objc
    func cancelSelect() -> Void {
        switch wantedAction {
        case .setDefaultAlbum, .setAutoUploadAlbum:
            // Return to Settings
            navigationController?.popViewController(animated: true)

        default:
            // Return to Album/Images collection
            dismiss(animated: true)
        }
    }
    
    
    // MARK: - Retrieve Image Data
    private func retrieveImageData() {
        // Job done?
        if inputImageIds.count == 0 {
            self.hidePiwigoHUD { self.categoriesTableView.reloadData() }
            return
        }
        
        // Check list of IDs
        if inputImageIds.last == Int64.min {
            inputImageIds.removeLast()
            retrieveImageData()
        }
        
        // Image data are not complete when retrieved using pwg.categories.getImages
        // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
        guard let imageId = inputImageIds.last else {
            self.hidePiwigoHUD {
                self.dismissPiwigoError(withTitle: NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")) {
                    self.dismiss(animated: true) { }
                }
            }
            return
        }
        imageProvider.getInfos(forID: imageId,
                               inCategoryId: inputCategoryId) { [self] in
            // Store image data
//            self.inputImagesData.append(imageData)
//
//            // Determine in which albums all images belong to
//            let set1:NSMutableSet = NSMutableSet(array: self.inputImageData.categoryIds.map { $0.intValue })
//            let set2 = Set(imageData.categoryIds.map { $0.intValue })
//            set1.intersect(set2)
//            self.inputImageData.categoryIds = set1.allObjects.map { NSNumber(integerLiteral: $0 as! Int) }

            // Image info retrieved
            self.inputImageIds.removeLast()
            
            // Update HUD
            self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImageIds.count) / Float(self.totalNumberOfImages))
            
            // Next image
            self.retrieveImageData()
            
        } failure: { [unowned self] error in
            let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
            var message = NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed\nTry again?")
            dismissRetryPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription, dismiss: {
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    retrieveImageData()
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { }
                }
            })
        }
    }
    

    // MARK: - UITableView - Header
    private func setTableViewMainHeader() {
        let headerView = SelectCategoryHeaderView(frame: .zero)
        switch wantedAction {
        case .setDefaultAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSettingsWidth),
                                 text: NSLocalizedString("setDefaultCategory_select", comment: "Please select an album or sub-album which will become the new root album."))

        case .moveAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveCategory_select", comment:"Please select an album or sub-album to move album \"%@\" into."), inputCategoryData.name))

        case .setAlbumThumbnail:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("categorySelection_setThumbnail", comment:"Please select the album which will use the photo \"%@\" as a thumbnail."), inputImageData.title.string.isEmpty ? inputImageData.fileName : inputImageData.title.string))

        case .setAutoUploadAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSettingsWidth),
                                 text: NSLocalizedString("settings_autoUploadDestinationInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            
        case .copyImage:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("copySingleImage_selectAlbum", comment:"Please, select the album in which you wish to copy the photo \"%@\"."), inputImageData.title.string.isEmpty ? inputImageData.fileName : inputImageData.title))

        case .moveImage:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveSingleImage_selectAlbum", comment:"Please, select the album in which you wish to move the photo \"%@\"."), inputImageData.title.string.isEmpty ? inputImageData.fileName : inputImageData.title))

        case .copyImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: NSLocalizedString("copySeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        case .moveImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: NSLocalizedString("moveSeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        default:
            fatalError("Action not configured in setTableViewMainHeader().")
        }
        categoriesTableView.tableHeaderView = headerView
    }

    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        var title = "", text = ""
        switch wantedAction {
        case .setAlbumThumbnail:
            // 1st section —> Albums containing image
            if section == 0 {
                // Title
                title = String(format: "%@\n", NSLocalizedString("tabBar_albums", comment:"Albums"))
                text = inputImageData.albums?.count ?? 0 > 1 ?
                    NSLocalizedString("categorySelection_one", comment:"Select one of the albums containing this image") :
                    NSLocalizedString("categorySelection_current", comment:"Select the current album for this image")
            } else {
                // Text
                text = NSLocalizedString("categorySelection_other", comment:"or select another album for this image")
            }

        default:
            // 1st section —> Recent albums
            if section == 0 {
                // Do we have recent albums to show?
                title = recentAlbums.fetchedObjects?.count ?? 0 > 0 ?
                    NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums") :
                    NSLocalizedString("tabBar_albums", comment: "Albums")
            } else {
                // 2nd section
                title = NSLocalizedString("categorySelection_allAlbums", comment: "All Albums")
            }
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }

    
    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        switch wantedAction {
        case .setAlbumThumbnail:
            return 2
        default:    // Present recent albums if any
            let objects = recentAlbums.fetchedObjects
            return 1 + (objects?.count ?? 0 > 0 ? 1 : 0)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch wantedAction {
        case .setAlbumThumbnail:
            if section == 0 {
                return inputImageData.albums?.filter({$0.pwgID > 0}).count ?? 0
            } else {
                return albums.fetchedObjects?.count ?? 0
            }
        default:    // Present recent albums if any
            if (recentAlbums.fetchedObjects?.count ?? 0 > 0) && (section == 0) {
                return recentAlbums.fetchedObjects?.count ?? 0
            } else {
                return albums.fetchedObjects?.count ?? 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0;
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryTableViewCell", for: indexPath) as? CategoryTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a CategoryTableViewCell!")
            return CategoryTableViewCell()
        }

        var depth = 0
        let albumData: Album
        let hasRecentAlbums = recentAlbums.fetchedObjects?.count ?? 0 > 0
        switch indexPath.section {
        case 0:
            if wantedAction == .setAlbumThumbnail {
                // Albums in which this image belongs to
                var catId = inputCategoryId     // This album always exists in cache
                if let catIds = inputImageData.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(inContext: savingContext, withId: catId)!
            } else if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
                if albumData.parentId > 0 {
                    depth += albumData.upperIds.components(separatedBy: ",")
                        .filter({ Int32($0) != albumData.pwgID }).count
                }
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
            if albumData.parentId > 0 {
                depth += albumData.upperIds.components(separatedBy: ",")
                    .filter({ Int32($0) != albumData.pwgID }).count
            }
        }
        
//        if (indexPath.section == 0) && (wantedAction == .setAlbumThumbnail) {
//            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
//            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
//        }
//        else if (recentAlbums.fetchedObjects?.count ?? 0 > 0) && (indexPath.section == 0) {
//            albumData = recentAlbums.object(at: indexPath)
//        }
//        else {
//            // Determine the depth before setting up the cell
//            albumData = categories[indexPath.row]
//            if albumData.parentId != 0 {
//                depth += albumData.upperIds.components(separatedBy: ",").filter({ Int32($0) != albumData.pwgID }).count
//            }
//        }
        
        // No button if the user does not have upload rights
        var buttonState: pwgCategoryCellButtonState = .none
        let allAlbums: [Album] = albums.fetchedObjects ?? []
        let filteredCat = allAlbums.filter({ NetworkVars.hasAdminRights ||
                                                userUploadRights.contains($0.pwgID) })
        if filteredCat.count > 0 {
            buttonState = albumsShowingSubAlbums.contains(albumData.pwgID) ? .hideSubAlbum : .showSubAlbum
        }

        // How should we present the category
        cell.delegate = self
        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            if albumData.pwgID == inputCategoryId {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if hasRecentAlbums && (indexPath.section == 0) {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                } else {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case .moveAlbum:
            // User cannot move album to current parent album or in itself
            if albumData.pwgID == 0 {  // Special case: upperCategories is nil for root
                // Root album => No button
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                // Is the root album parent of the input album?
                if inputCategoryData.parentId == 0 {
                    // Yes => Change text colour
                    cell.albumLabel.textColor = .piwigoColorRightLabel()
                }
            }
            else if hasRecentAlbums && (indexPath.section == 0) {
                // Don't present sub-albums in Recent Albums section
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            }
            else if albumData.pwgID == inputCategoryData.parentId {
                // This album is the parent of the input album => Change text colour
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            }
            else if albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputCategoryId) {
                // This album is a sub-album of the input album => No button
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Not a parent of a sub-album of the input album
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .setAlbumThumbnail:
            // The root album is not available
            if indexPath.section == 0 {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
            if albumData.pwgID == 0 {
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            }
        case .setAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if hasRecentAlbums && (indexPath.section == 0) {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                } else {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case .copyImage, .copyImages, .moveImage, .moveImages:
            // User cannot copy/move the image to the root album or in albums it already belongs to
            if albumData.pwgID == 0 {  // Should not be presented but in case…
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if hasRecentAlbums && (indexPath.section == 0) {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                } else {
                    cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                }
                // Albums containing the image are not selectable
                if let albums = inputImageData.albums,
                   albums.contains(where: { $0.pwgID == albumData.pwgID }) {
                    cell.albumLabel.textColor = .piwigoColorRightLabel()
                }
            }

        default:
            break
        }

        cell.isAccessibilityElement = true
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Retrieve album data
        let albumData: Album
        let hasRecentAlbums = recentAlbums.fetchedObjects?.count ?? 0 > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputCategoryId     // This album always exists in cache
                if let catIds = inputImageData.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(inContext: savingContext, withId: catId)!
            } else if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
        }

//        if (indexPath.section == 0) && (wantedAction == .setAlbumThumbnail) {
//            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
//            albumData = CategoriesData.sharedInstance().getCategoryById(categoryId)
//        }
//        else if hasRecentAlbums && (indexPath.section == 0) {
//            albumData = recentCategories[indexPath.row]
//        } else {
//            albumData = categories[indexPath.row]
//        }
        
        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            if albumData.pwgID == inputCategoryId { return false }
            
        case .moveAlbum:
            // Do nothing if this is the input category
            if albumData.pwgID == inputCategoryId { return false }
            // User cannot move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputCategoryData.parentId == 0 { return false }
            } else if (albumData.pwgID == inputCategoryData.parentId) ||
                albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputCategoryId) { return false }
            
        case .setAlbumThumbnail:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 { return false }

        case .setAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 { return false }

        case .copyImage, .copyImages, .moveImage, .moveImages:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 { return false }
            // Albums containing all the images are not selectable
            if let albums = inputImageData.albums,
               albums.contains(where: { $0.pwgID == albumData.pwgID}) { return false }

        default:
            return false
        }
        return true;
    }

    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let albumData: Album
        let hasRecentAlbums = recentAlbums.fetchedObjects?.count ?? 0 > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputCategoryId     // This album always exists in cache
                if let catIds = inputImageData.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(inContext: savingContext, withId: catId)!
            } else if hasRecentAlbums {
                // Recent albums
                albumData = recentAlbums.object(at: indexPath)
            } else {
                // All albums
                albumData = albums.object(at: indexPath)
            }
        default:
            let albumIndexPath = IndexPath(item: indexPath.item, section: 0)
            albumData = albums.object(at: albumIndexPath)
        }

//        if (indexPath.section == 0) && (wantedAction == .setAlbumThumbnail) {
//            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
//            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
//        }
//        else if (indexPath.section == 0), !recentCategories.isEmpty {
//            albumData = recentCategories[indexPath.row]
//        } else {
//            albumData = categories[indexPath.row]
//        }
        
        // Remember the choice
        selectedCategoryId = albumData.pwgID

        // What should we do with this selection?
        switch wantedAction {
        case .setDefaultAlbum:
            // Do nothing if this is the current default category
            if (albumData.pwgID == Int32.min) ||
               (albumData.pwgID == inputCategoryId) { return }
            
            // Ask user to confirm
            let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
            let message:String
            if albumData.pwgID == 0 {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), NSLocalizedString("categorySelection_root", comment: "Root Album"))
            } else {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), albumData.name)
            }
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Set new Default Album
                self.delegate?.didSelectCategory(withId: albumData.pwgID)
                // Return to Settings
                self.navigationController?.popViewController(animated: true)
            })

        case .moveAlbum:
            // Do nothing if this is the current default category
            if albumData.pwgID == inputCategoryId { return }

            // User must not move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputCategoryData.parentId == 0 { return }
            } else if (albumData.pwgID == inputCategoryData.parentId) ||
                        albumData.upperIds.components(separatedBy: ",").contains(where: { Int32($0) == inputCategoryId}) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveCategory", comment: "Move Album")
            let message = String(format: NSLocalizedString("moveCategory_message", comment: "Are you sure you want to move \"%@\" into the album \"%@\"?"), inputCategoryData.name, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Move album to selected category
                self.moveCategory(intoCategory: albumData)
            })

        case .setAlbumThumbnail:
            // Ask user to confirm
            let title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")
            let message = String(format: NSLocalizedString("categoryImageSet_message", comment:"Are you sure you want to set this image for the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Add category to list of recent albums
                self.setRepresentative(for: albumData)
            })

        case .setAutoUploadAlbum:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            
            // Return the selected album ID
            delegate?.didSelectCategory(withId: albumData.pwgID)
            navigationController?.popViewController(animated: true)
            
        case .copyImage:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if let albums = inputImageData.albums,
               albums.contains(where: { $0.pwgID == albumData.pwgID}) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySingleImage_message", comment:"Are you sure you want to copy the photo \"%@\" to the album \"%@\"?"), inputImageData.title.string.isEmpty ? inputImageData.fileName : inputImageData.title, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Copy single image to selected album
                self.copySingleImage(toCategory: albumData)
            })

        case .moveImage:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the image already belongs to the selected album
//            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSingleImage_message", comment:"Are you sure you want to move the photo \"%@\" to the album \"%@\"?"), inputImageData.title.string.isEmpty ? inputImageData.fileName : inputImageData.title, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { _ in
                // Move single image to selected album
                self.moveSingleImage(toCategory: albumData)
            }

        case .copyImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if let albums = inputImageData.albums,
               albums.contains(where: { $0.pwgID == albumData.pwgID }) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySeveralImages_message", comment:"Are you sure you want to copy the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Initialise counter and display HUD
                self.nberOfSelectedImages = Float(self.inputImagesData.count)
                self.showPiwigoHUD(withTitle: NSLocalizedString("copySeveralImagesHUD_copying", comment: "Copying Photos…"),
                                   inMode: .annularDeterminate)

                // Copy several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.copySeveralImages(toCategory: albumData)
                }
            })

        case .moveImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if let albums = inputImageData.albums,
               albums.contains(where: { $0.pwgID == albumData.pwgID }) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSeveralImages_message", comment:"Are you sure you want to move the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { _ in
                // Initialise counter and display HUD
                self.nberOfSelectedImages = Float(self.inputImagesData.count)
                self.showPiwigoHUD(withTitle: NSLocalizedString("moveSeveralImagesHUD_moving", comment: "Moving Photos…"),
                                   inMode: .annularDeterminate)
                
                // Move several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.moveSeveralImages(toCategory: albumData)
                }
            }

        default:
            break
        }
    }
    
    private func requestConfirmation(withTitle title:String, message:String,
                                     forCategory albumData: Album, at indexPath:IndexPath,
                                     handler:((UIAlertAction) -> Void)? = nil) -> Void {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: {_ in 
                                            // Forget the choice
                                            self.selectedCategoryId = Int32.min
                                         })
        let performAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler:handler)
    
        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(performAction)

        // Present popover view
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = categoriesTableView
        alert.popoverPresentationController?.sourceRect = categoriesTableView.rectForRow(at: indexPath)
        alert.popoverPresentationController?.permittedArrowDirections = [.left, .right]
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        })
    }

    private func showError(with error:String = "") {
        // Title and message
        let title:String
        var message:String
        switch wantedAction {
        case .moveAlbum:
            title = NSLocalizedString("moveCategoryError_title", comment:"Move Fail")
            message = NSLocalizedString("moveCategoryError_message", comment:"Failed to move your album")
        case .setAlbumThumbnail:
            title = NSLocalizedString("categoryImageSetError_title", comment:"Image Set Error")
            message = NSLocalizedString("categoryImageSetError_message", comment:"Failed to set the album image")
        case .copyImage:
            title = NSLocalizedString("copyImageError_title", comment:"Copy Fail")
            message = NSLocalizedString("copySingleImageError_message", comment:"Failed to copy your photo")
        case .copyImages:
            title = NSLocalizedString("copyImageError_title", comment:"Copy Fail")
            message = NSLocalizedString("copySeveralImagesError_message", comment:"Failed to copy some photos")
        case .moveImage:
            title = NSLocalizedString("moveImageError_title", comment:"Move Fail")
            message = NSLocalizedString("moveSingleImageError_message", comment:"Failed to copy your photo")
        case .moveImages:
            title = NSLocalizedString("moveImageError_title", comment:"Move Fail")
            message = NSLocalizedString("moveSeveralImagesError_message", comment:"Failed to move some photos")
        default:
            return
        }
        
        // Present alert
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error) {
            // Forget the choice
            self.selectedCategoryId = Int32.min
            // Dismiss the view
            self.dismiss(animated: true, completion: {})
        }
    }
    

    // MARK: - Move Category Methods
    private func moveCategory(intoCategory parentData: Album) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))

        DispatchQueue.global(qos: .userInitiated).async {
            // Add category to list of recent albums
            let userInfo = ["categoryId": parentData.pwgID]
            NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

            // Move album
            AlbumUtilities.move(self.inputCategoryId,
                                intoCategoryWithId: parentData.pwgID) { [self] in
                // Update cached old parent categories, except root album
                let oldParentIds = self.inputCategoryData.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
                for oldParentId in oldParentIds {
                    // Check that it is not the root album, nor the moved album
                    if (oldParentId == 0) || (oldParentId == self.inputCategoryId) { continue }

                    // Remove number of moved sub-categories and images
                    if let parent = albums.fetchedObjects?.first(where: {$0.pwgID == oldParentId}) {
                        parent.nbSubAlbums -= self.inputCategoryData.nbSubAlbums + 1
                        parent.totalNbImages -= self.inputCategoryData.totalNbImages
                    }
                }

                // Update cached new parent categories, except root album
                var newUpperCategories = [Int32]()
                if parentData.pwgID != 0 {
                    // Parent category in which we moved the category
                    newUpperCategories = parentData.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
                    for newParentId in newUpperCategories {
                        // Check that it is not the root album, nor the moved album
                        if (newParentId == 0) || (newParentId == self.inputCategoryId) { continue }
                        
                        // Add number of moved sub-categories and images
                        if let newParent = albums.fetchedObjects?.first(where: {$0.pwgID == newParentId}) {
                            newParent.nbSubAlbums += self.inputCategoryData.nbSubAlbums + 1
                            newParent.totalNbImages += self.inputCategoryData.totalNbImages
                        }
                    }
                }

                // Update upperCategories of moved sub-categories
                let upperCatToRemove = oldParentIds.filter({$0 != self.inputCategoryId})
                if self.inputCategoryData.nbSubAlbums > 0 {
                    let subCategories: [Album] = albums.fetchedObjects?.filter({$0.parentId == self.inputCategoryId}) ?? []
                    for subCategory in subCategories {
                        // Replace list of upper categories
                        var upperCategories = subCategory.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
                        upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                        upperCategories.append(contentsOf: newUpperCategories)
                        subCategory.upperIds = String(upperCategories.map({"\($0),"}).reduce("", +).dropLast(1))
                    }
                }

                // Replace upper category of moved album
                var upperCategories = oldParentIds
                upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                upperCategories.append(contentsOf: newUpperCategories)
                self.inputCategoryData.upperIds = String(upperCategories.map({"\($0),"}).reduce("", +).dropLast(1))
                self.inputCategoryData.parentId = parentData.pwgID

                // Save updated albums
                do {
                    try savingContext?.save()
                } catch let error as NSError {
                    print("Could not fetch \(error), \(error.userInfo)")
                }

                // Hide HUD, swipe and view then remove category from the album/images collection view
                self.updatePiwigoHUDwithSuccess() {
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                        self.dismiss(animated: true) {
                            self.albumMovedDelegate?.didMoveCategory()
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Set Album Thumbnail Methods
    private func setRepresentative(for categoryData: Album) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        
        // Set image as representative
        DispatchQueue.global(qos: .userInitiated).async {
            AlbumUtilities.setRepresentative(self.inputCategoryId, with: self.inputImageData)
            {
                DispatchQueue.main.async { [self] in
                    // Save changes
                    do {
                        try self.savingContext.save()
                    } catch let error as NSError {
                        print("Could not fetch \(error), \(error.userInfo)")
                    }

                    // Close HUD
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                }
            } failure: { [unowned self] error in
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Copy Images Methods
    private func copySingleImage(toCategory albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Check image data
        guard let imageData = self.inputImageData else {
            self.showError()
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("copySingleImageHUD_copying", comment:"Copying Photo…"))
        
        // Copy image to selected album
        DispatchQueue.global(qos: .userInitiated).async {
//            self.copyImage(imageData, toCategory: categoryData) { didSucceed in
//                if didSucceed {
//                    // Close HUD
//                    self.updatePiwigoHUDwithSuccess() {
//                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
//                            self.dismiss(animated: true)
//                        }
//                    }
//                } else {
//                    // Close HUD and inform user
//                    self.hidePiwigoHUD { self.showError() }
//                }
//            } onFailure: { error in
//                // Close HUD and inform user
//                self.hidePiwigoHUD {
//                    guard let error = error as NSError? else {
//                        self.showError()
//                        return
//                    }
//                    self.showError(with: error.localizedDescription)
//                }
//            }
        }
    }
    
    private func copySeveralImages(toCategory albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Jobe done?
        if inputImagesData.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true)
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImagesData.last else {
            // Close HUD and inform user
            self.hidePiwigoHUD { self.showError() }
            return
        }

        // Copy next image to seleted album
//        self.copyImage(imageData, toCategory: categoryData) { didSucceed in
//            if didSucceed {
//                // Next image…
//                self.inputImagesData.removeLast()
//                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImagesData.count) / self.nberOfSelectedImages)
//                self.copySeveralImages(toCategory: categoryData)
//            } else {
//                // Close HUD and inform user
//                self.hidePiwigoHUD { self.showError() }
//            }
//        } onFailure: { error in
//            // Close HUD and inform user
//            self.hidePiwigoHUD {
//                guard let error = error as NSError? else {
//                    self.showError()
//                    return
//                }
//                self.showError(with: error.localizedDescription)
//            }
//        }
    }
    
    private func copyImage(_ imageData:PiwigoImageData, toCategory categoryData:PiwigoAlbumData,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard var categoryIds = imageData.categoryIds else {
            self.showError()
            return
        }
        categoryIds.append(NSNumber(value: categoryData.albumId))

        // Prepare parameters for copying the image/video to the selected category
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            imageData.categoryIds = categoryIds
            // Add image to selected category and update corresponding Album/Images collection
            CategoriesData.sharedInstance().addImage(imageData)
            
            // Update image data in current view (ImageDetailImage view or Album/Images collection)
            DispatchQueue.main.async {
                self.imageCopiedDelegate?.didCopyImage(withData: imageData)
            }
            completion(true)
        } failure: { error in
            fail(error)
        }
    }
    
    // MARK: - Move Images Methods
    private func moveSingleImage(toCategory albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Check image data
        guard let imageData = self.inputImageData else {
            self.showError()
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("moveSingleImageHUD_moving", comment:"Moving Photo…"))
        
        // Move image to selected album
        DispatchQueue.global(qos: .userInitiated).async {
//            self.moveImage(imageData, toCategory: categoryData) { didSucceed in
//                if didSucceed {
//                    // Close HUD
//                    self.updatePiwigoHUDwithSuccess() {
//                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
//                            self.dismiss(animated: true)
//                        }
//                    }
//                } else {
//                    // Close HUD and inform user
//                    self.hidePiwigoHUD { self.showError() }
//                }
//            } onFailure: { error in
//                // Close HUD and inform user
//                self.hidePiwigoHUD {
//                    guard let error = error as NSError? else {
//                        self.showError()
//                        return
//                    }
//                    self.showError(with: error.localizedDescription)
//                }
//            }
        }
    }
    
    private func moveSeveralImages(toCategory albumData: Album) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": albumData.pwgID]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Jobe done?
        if inputImagesData.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true)
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImagesData.last else {
            // Close HUD and inform user
            self.hidePiwigoHUD { self.showError() }
            return
        }

        // Move next image to seleted album
//        moveImage(imageData, toCategory: categoryData) { didSucceed in
//            if didSucceed {
//                // Next image…
//                self.inputImagesData.removeLast()
//                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImagesData.count) / self.nberOfSelectedImages)
//                self.moveSeveralImages(toCategory: categoryData)
//            } else {
//                // Close HUD and inform user
//                self.hidePiwigoHUD { self.showError() }
//            }
//        } onFailure: { error in
//            // Close HUD and inform user
//            self.hidePiwigoHUD {
//                guard let error = error as NSError? else {
//                    self.showError()
//                    return
//                }
//                self.showError(with: error.localizedDescription)
//            }
//        }
    }
    
    private func moveImage(_ imageData:PiwigoImageData, toCategory categoryData:PiwigoAlbumData,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard var categoryIds = imageData.categoryIds else {
            self.showError()
            return
        }
        categoryIds.append(NSNumber(value: categoryData.albumId))
        
        // Remove current categoryId from image category list
        categoryIds.removeAll(where: {$0 == NSNumber(value: inputCategoryId)} )

        // Prepare parameters for moving the image/video to the selected category
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            imageData.categoryIds = categoryIds
            // Add image to selected category
            CategoriesData.sharedInstance().addImage(imageData, toCategory: String(categoryData.albumId))

            // Remove image from current category if needed
            CategoriesData.sharedInstance().removeImage(imageData, fromCategory: String(self.inputCategoryId))
                            
            // Remove image from ImageDetailImage view
            DispatchQueue.main.async {
                self.imageRemovedDelegate?.didRemoveImage(withId: imageData.imageId)
            }
            completion(true)
        } failure: { error in
            fail(error)
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension SelectCategoryViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        updateOperations.removeAll(keepingCapacity: false)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Initialisation
        var hasAlbumsInSection1 = false
        if controller == albums,
           wantedAction == .setAlbumThumbnail || recentAlbums.fetchedObjects?.count ?? 0 > 0 {
            hasAlbumsInSection1 = true
        }

        // Collect operation changes
        switch type {
        case .insert:
            guard var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 { newIndexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
                print("••> Insert imagesCollection item at \(newIndexPath)")
                self?.categoriesTableView?.insertRows(at: [newIndexPath], with: .automatic)
            })
        case .update:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Update imagesCollection item at \(indexPath)")
                self?.categoriesTableView?.reloadRows(at: [indexPath], with: .automatic)
            })
        case .move:
            guard var indexPath = indexPath,  var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Move imagesCollection item from \(indexPath) to \(newIndexPath)")
                self?.categoriesTableView?.moveRow(at: indexPath, to: newIndexPath)
            })
        case .delete:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Delete imagesCollection item at \(indexPath)")
                self?.categoriesTableView?.deleteRows(at: [indexPath], with: .automatic)
            })
        @unknown default:
            fatalError("AlbumViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Do not update items if the album is not presented.
        if view.window == nil { return }
        
        // Any update to perform?
        if updateOperations.isEmpty || view.window == nil { return }

        // Perform all updates
        categoriesTableView?.performBatchUpdates({ () -> Void  in
            for operation: BlockOperation in self.updateOperations {
                operation.start()
            }
        })
    }
}


// MARK: - CategoryCellDelegate Methods
extension SelectCategoryViewController: CategoryCellDelegate {
    // Called when the user taps a sub-category button
    func tappedDisclosure(of parentAlbum: Album) {
        // Update list of albums showing sub-albums
        if albumsShowingSubAlbums.contains(parentAlbum.pwgID) {
            // Remove first level of sub-albums of the tapped album
            albumsShowingSubAlbums.remove(parentAlbum.pwgID)
            
            // Removes remaining levels of sub-albums of the tapped album
            for album in albums.fetchedObjects ?? [] {
                if album.upperIds.components(separatedBy: ",").compactMap({Int32($0)})
                    .contains(parentAlbum.pwgID) {
                    albumsShowingSubAlbums.remove(album.pwgID)
                }
            }
        } else {
            // Adds first level of sub-albums of the tapped album
            albumsShowingSubAlbums.insert(parentAlbum.pwgID)
        }

        // Show albums at the root + those demanded
        let nonSmartAlbumPredicate = NSPredicate(format: "pwgID > 0")
        var orPredicates = [NSPredicate(format: "parentId == 0")]
        for albumId in albumsShowingSubAlbums {
            orPredicates.append(NSPredicate(format: "parentId == %ld", albumId))
        }
        let parentPredicates = NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
        let albumPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: [nonSmartAlbumPredicate, parentPredicates])

        // The root album is proposed for some actions
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) {
            let rootPredicate = NSPredicate(format: "pwgID == 0")
            fetchAlbumsRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [rootPredicate, albumPredicates])
        } else {
            fetchAlbumsRequest.predicate = albumPredicates
        }

        // Perform a new fetch
        try? albums.performFetch()

        // Shows albums and sub-albums
        categoriesTableView.reloadData()
    }
}
