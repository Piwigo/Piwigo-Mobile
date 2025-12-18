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
import CoreData
import CoreMedia
import piwigoKit
import uploadKit

enum pwgCategorySelectAction {
    case none
    case setDefaultAlbum, moveAlbum, setAlbumThumbnail, setAutoUploadAlbum
    case copyImage, moveImage, copyImages, moveImages
}

protocol SelectCategoryDelegate: NSObjectProtocol {
    func didSelectCategory(withId category: Int32)
}

protocol SelectCategoryImageCopiedDelegate: NSObjectProtocol {
    func didCopyImage()
}

protocol SelectCategoryImageRemovedDelegate: NSObjectProtocol {
    func didRemoveImage()
}

class SelectCategoryViewController: UIViewController {

    weak var delegate: SelectCategoryDelegate?
    weak var imageCopiedDelegate: SelectCategoryImageCopiedDelegate?
    weak var imageRemovedDelegate: SelectCategoryImageRemovedDelegate?

    var wantedAction: pwgCategorySelectAction = .none  // Action to perform after category selection
    var selectedCategoryId = Int32.min
    var updateOperations = [BlockOperation]()

    // MARK: - MARK: - Core Data Object Contexts
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    
    // MARK: - Core Data Providers
    lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()

    lazy var imageProvider: ImageProvider = {
        let provider : ImageProvider = ImageProvider.shared
        return provider
    }()

    
    // MARK: - Core Data Source
    typealias DataSource = UITableViewDiffableDataSource<String, NSManagedObjectID>
    /// Stored properties cannot be marked potentially unavailable with '@available'.
    // "private var diffableDataSource: DataSource!" replaced by below lines
//    private var _diffableDataSource: NSObject? = nil
//    @available(iOS 13.0, *)
//    var diffableDataSource: DataSource {
//        if _diffableDataSource == nil {
//            _diffableDataSource = configDataSource()
//        }
//        return _diffableDataSource as! DataSource
//    }

    lazy var userUploadRights: [Int32] = {
        // Case of Community user?
        if NetworkVars.shared.userStatus != .normal { return [] }
        let userUploadRights = user.uploadRights
        return userUploadRights.components(separatedBy: ",").compactMap({ Int32($0) })
    }()
    
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.user))
        return andPredicates
    }()

    lazy var fetchRecentAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        var andPredicates = predicates
        var recentCatIds: [Int32] = AlbumVars.shared.recentCategories.components(separatedBy: ",").compactMap({Int32($0)})
        // Root album proposed for some actions, input album not proposed
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) == false {
            recentCatIds.removeAll(where: { $0 == Int32.zero })
        }
        // Removes current album
        recentCatIds.removeAll(where: { $0 == self.inputAlbum.pwgID })
        // Removes parent album
        recentCatIds.removeAll(where: { $0 == self.inputAlbum.parentId })
        // Limit the number of recent albums
        let nberExtraCats: Int = max(0, recentCatIds.count - AlbumVars.shared.maxNberRecentCategories)
        andPredicates.append(NSPredicate(format: "pwgID IN %@", recentCatIds.dropLast(nberExtraCats)))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = AlbumVars.shared.maxNberRecentCategories
        return fetchRequest
    }()

    lazy var recentAlbums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchRecentAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()

    lazy var fetchAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        
        // Don't show smart albums
        var andPredicates = predicates
        andPredicates.append(NSPredicate(format: "pwgID > 0"))

        // Show sub-albums of deployed albums
        var parentIDs = albumsShowingSubAlbums
        parentIDs.insert(Int32.zero)
        andPredicates.append(NSPredicate(format: "parentId IN %@", parentIDs))
        let albumPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // The root album is proposed for some actions
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) {
            var andPredicates = predicates
            andPredicates.append(NSPredicate(format: "pwgID == 0"))
            let rootPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [rootPredicates, albumPredicates])
        } else {
            fetchRequest.predicate = albumPredicates
        }
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()

    
    // MARK: - Input Parameters
    var inputAlbum: Album!
    var inputImageIds = Set<Int64>()
    var inputImages = Set<Image>()
    var commonCatIDs = Set<Int32>()
    var nberOfImages = Int64.zero

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
            guard let album = albumProvider.getAlbum(ofUser: user, withId: albumId) else {
                return false
            }
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            inputAlbum = album
            
        case .moveAlbum:
            guard let albumData = parameter as? Album else {
                debugPrint("Input parameter expected to be of Album type.")
                return false
            }
            // Album which will be moved into the selected one
            inputAlbum = albumData
            
        case .setAlbumThumbnail, .copyImage, .moveImage:
            guard let array = parameter as? [Any],
                  let imageData = array[0] as? Image,
                  let albumId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [Image, Int32].")
                return false
            }
            // Image which will be set as thumbnail of the selected album
            // or image of the category ID which will be copied/moved to the selected album
            commonCatIDs = Set((imageData.albums ?? Set<Album>()).map({$0.pwgID}))
            inputImages = Set([imageData])
            // Album from which the image has been selected
            guard let album = albumProvider.getAlbum(ofUser: user, withId: albumId) else {
                return false
            }
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            inputAlbum = album

        case .copyImages, .moveImages:
            guard let array = parameter as? [Any],
                  let imageIDs = array[0] as? Set<Int64>,
                  let albumId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [[NSNumber], Int32]")
                return false
            }
            // IDs of the selected images which will be copied/moved to the selected album
            inputImageIds = imageIDs
            if inputImageIds.isEmpty {
                debugPrint("List of image IDs should not be empty")
                return false
            }
            inputImages = imageProvider.getImages(inContext: mainContext, withIds: imageIDs)
            nberOfImages = Int64(inputImages.count)
            if inputImages.isEmpty {
                debugPrint("No image in cache with these IDs: \(inputImageIds)")
                return false
            }
            // Album from which the images have been selected
            guard let album = albumProvider.getAlbum(ofUser: user, withId: albumId) else {
                return false
            }
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            inputAlbum = album
            // Albums to which images already belong to
            self.inputImages.forEach { image in
                let catIDs = Set((image.albums ?? Set<Album>()).map({$0.pwgID}))
                if commonCatIDs.isEmpty {
                    commonCatIDs = catIDs
                } else {
                    commonCatIDs = commonCatIDs.intersection(catIDs)
                }
            }

        default:
            debugPrint("Called setParameter before setting wanted action")
            return false
        }
        
        return true
    }

    
    // MARK: - View
    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?
    var albumsShowingSubAlbums = Set<Int32>()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register the CategoryTableViewCell before using it
        categoriesTableView?.register(UINib(nibName: "CategoryTableViewCell", bundle: nil),
                                      forCellReuseIdentifier: "CategoryTableViewCell")

        // Table view identifier
        categoriesTableView?.accessibilityIdentifier = "album selector"
        categoriesTableView?.rowHeight = UITableView.automaticDimension
        categoriesTableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Check that a root album exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.root.rawValue) else {
            return
        }
        
        // Initialise data source
        do {
            try recentAlbums.performFetch()
            try albums.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }

        // Button for returning to albums/images collections
        if wantedAction != .setDefaultAlbum {
            cancelBarButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelSelect))
            cancelBarButton?.accessibilityIdentifier = "CancelSelect"
        }

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

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background

        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        setTableViewMainHeader()
        categoriesTableView?.separatorColor = PwgColor.separator
        categoriesTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation "Cancel" button and identifier
        navigationItem.setLeftBarButton(cancelBarButton, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        
        // Display albums
        categoriesTableView?.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Display HUD during fetch after the app launch or if data was fetched more than an hour ago
        if AppVars.shared.dateOfLatestRecursiveAlbumDataFetch.timeIntervalSinceNow < -3600 {
            navigationController?.showHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"))
            AppVars.shared.dateOfLatestRecursiveAlbumDataFetch = Date()
        }
        
        // Use the AlbumProvider to fetch album data recursively. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        PwgSession.checkSession(ofUser: user) { [self] in
            // Fetch albums recursively
            albumProvider.fetchAlbums(forUser: user, inParentWithId: 0, recursively: true,
                                      thumbnailSize: thumnailSize) { [self] error in
                DispatchQueue.main.async { [self] in
                    guard let error = error
                    else {
                        navigationController?.hideHUD { }
                        return
                    }
                    didFetchAlbumsWithError(error: error)
                }
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                didFetchAlbumsWithError(error: error)
            }
        }
    }
    
    @MainActor
    private func didFetchAlbumsWithError(error: PwgKitError) {
        navigationController?.hideHUD { [self] in
            // Session logout required?
            if error.requiresLogout {
                ClearCache.closeSessionWithPwgError(from: self, error: error)
                return
            }
            
            // Report error
            let title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
            dismissPiwigoError(withTitle: title, message: error.localizedDescription) { }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] _ in

            // On iPad, the view is presented in a centered popover view
            if view.traitCollection.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                self.popoverPresentationController?.sourceRect = CGRect(x: mainScreenBounds.midX,
                                                                        y: mainScreenBounds.midY,
                                                                        width: 0, height: 0)
                switch self.wantedAction {
                case .setDefaultAlbum, .setAutoUploadAlbum:
                    self.preferredContentSize = CGSize(width: pwgPadSettingsWidth,
                                                       height: ceil(mainScreenBounds.height*2/3));
                default:
                    self.preferredContentSize = CGSize(width: pwgPadSubViewWidth,
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
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
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


    // MARK: - TableView Main Header
    private func setTableViewMainHeader() {
        let headerView = SelectCategoryHeaderView(frame: .zero)
        switch wantedAction {
        case .setDefaultAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSettingsWidth),
                                 text: NSLocalizedString("setDefaultCategory_select", comment: "Please select an album or sub-album which will become the new root album."))

        case .moveAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveCategory_select", comment:"Please select an album or sub-album to move album \"%@\" into."), inputAlbum.name))

        case .setAlbumThumbnail:
            let title = inputImages.first?.titleStr ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("categorySelection_setThumbnail", comment:"Please select the album which will use the photo \"%@\" as a thumbnail."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .setAutoUploadAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSettingsWidth),
                                 text: String(localized: "settings_autoUploadDestinationInfo", comment: "Please select the album…"))
            
        case .copyImage:
            let title = inputImages.first?.titleStr ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("copySingleImage_selectAlbum", comment:"Please, select the album in which you wish to copy the photo \"%@\"."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .moveImage:
            let title = inputImages.first?.titleStr ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveSingleImage_selectAlbum", comment:"Please, select the album in which you wish to move the photo \"%@\"."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .copyImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: NSLocalizedString("copySeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        case .moveImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: NSLocalizedString("moveSeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        default:
            preconditionFailure("Action not configured in setTableViewMainHeader().")
        }
        categoriesTableView?.tableHeaderView = headerView
    }

    // For presenting errors returned by Albums/Images actions
    @MainActor
    func showError(_ error: PwgKitError) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }
        
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
        
        // Report error
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { [self] in
            // Forget the choice
            self.selectedCategoryId = Int32.min
            // Save changes if any
            self.mainContext.saveIfNeeded()
            // Dismiss the view
            self.dismiss(animated: true, completion: {})
        }
    }
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update header
            self.setTableViewMainHeader()

            // Animated update for smoother experience
            self.categoriesTableView?.beginUpdates()
            self.categoriesTableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        }
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

        // Don't show smart albums
        var andPredicates = predicates
        andPredicates.append(NSPredicate(format: "pwgID > 0"))

        // Show sub-albums of deployed albums
        var parentIDs = albumsShowingSubAlbums
        parentIDs.insert(Int32.zero)
        andPredicates.append(NSPredicate(format: "parentId IN %@", parentIDs))
        let albumPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)

        // The root album is proposed for some actions
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) {
            var andPredicates = predicates
            andPredicates.append(NSPredicate(format: "pwgID == 0"))
            let rootPredicates = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
            fetchAlbumsRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [rootPredicates, albumPredicates])
        } else {
            fetchAlbumsRequest.predicate = albumPredicates
        }

        // Perform a new fetch
        try? albums.performFetch()

        // Shows albums and sub-albums
        categoriesTableView?.reloadData()
    }
}
