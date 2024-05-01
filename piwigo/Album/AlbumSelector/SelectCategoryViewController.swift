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

protocol SelectCategoryDelegate: NSObjectProtocol {
    func didSelectCategory(withId category: Int32)
}

protocol SelectCategoryImageCopiedDelegate: NSObjectProtocol {
    func didCopyImage()
}

protocol SelectCategoryImageRemovedDelegate: NSObjectProtocol {
    func didRemoveImage()
}

class SelectCategoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: SelectCategoryDelegate?
    weak var imageCopiedDelegate: SelectCategoryImageCopiedDelegate?
    weak var imageRemovedDelegate: SelectCategoryImageRemovedDelegate?

    var wantedAction: pwgCategorySelectAction = .none  // Action to perform after category selection
    private var selectedCategoryId = Int32.min

    // MARK: - Core Data Objects
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
                  let imageIds = array[0] as? Set<Int64>,
                  let albumId = array[1] as? Int32 else {
                debugPrint("Input parameter expected to be of type [[NSNumber], Int32]")
                return false
            }
            // IDs of the selected images which will be copied/moved to the selected album
            inputImageIds = imageIds
            if inputImageIds.isEmpty {
                debugPrint("List of image IDs should not be empty")
                return false
            }
            inputImages = imageProvider.getImages(inContext: mainContext, withIds: imageIds)
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

    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?

    private var albumsShowingSubAlbums = Set<Int32>()

    
    // MARK: - Core Data Source
    lazy var userUploadRights: [Int32] = {
        // Case of Community user?
        if NetworkVars.userStatus != .normal { return [] }
        let userUploadRights = user.uploadRights
        return userUploadRights.components(separatedBy: ",").compactMap({ Int32($0) })
    }()
    
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        return andPredicates
    }()

    lazy var fetchRecentAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        var andPredicates = predicates
        var recentCatIds = Set(AlbumVars.shared.recentCategories.components(separatedBy: ",").compactMap({Int32($0)}))
        // Root album proposed for some actions, input album not proposed
        if [.setDefaultAlbum, .moveAlbum].contains(wantedAction) == false {
            recentCatIds.remove(Int32.zero)
        }
        // Removes current album
        recentCatIds.remove(self.inputAlbum.pwgID)
        // Removes parent album
        recentCatIds.remove(self.inputAlbum.parentId)
        andPredicates.append(NSPredicate(format: "pwgID IN %@", recentCatIds))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = 5
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

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Check that a root album exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(ofUser: user, withId: pwgSmartAlbum.root.rawValue) else {
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
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation "Cancel" button and identifier
        navigationItem.setRightBarButton(cancelBarButton, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Display albums
        categoriesTableView?.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Use the AlbumProvider to fetch album data recursively. On completion,
        // handle general UI updates and error alerts on the main queue.
        let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        NetworkUtilities.checkSession(ofUser: user) { [self] in
            // Fetch albums recursively
            albumProvider.fetchAlbums(forUser: user, inParentWithId: 0, recursively: true,
                                      thumbnailSize: thumnailSize) { [self] error in
                guard let error = error else { return }

                // Session logout required?
                if let pwgError = error as? PwgSessionError,
                   [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                    .contains(pwgError) {
                    ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                    return
                }

                // Report error
                let title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
                DispatchQueue.main.async { [self] in
                    dismissPiwigoError(withTitle: title, message: error.localizedDescription) { }
                }
            }
        } failure: { [self] error in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("internetErrorGeneral_title", comment: "Connection Error")
            DispatchQueue.main.async { [self] in
                dismissPiwigoError(withTitle: title, message: error.localizedDescription) { }
            }
        }
    }
    
    private func didFetchAlbumsWithError(error: Error) {
        
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
    

    // MARK: - UITableView - Header
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
            let title = inputImages.first?.title.string ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("categorySelection_setThumbnail", comment:"Please select the album which will use the photo \"%@\" as a thumbnail."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .setAutoUploadAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSettingsWidth),
                                 text: NSLocalizedString("settings_autoUploadDestinationInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            
        case .copyImage:
            let title = inputImages.first?.title.string ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("copySingleImage_selectAlbum", comment:"Please, select the album in which you wish to copy the photo \"%@\"."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .moveImage:
            let title = inputImages.first?.title.string ?? ""
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveSingleImage_selectAlbum", comment:"Please, select the album in which you wish to move the photo \"%@\"."), title.isEmpty ? inputImages.first?.fileName ?? "-?-" : title))

        case .copyImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                                 text: NSLocalizedString("copySeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        case .moveImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
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
                text = inputImages.first?.albums?.count ?? 0 > 1 ?
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
                title = (recentAlbums.fetchedObjects ?? []).count > 0 ?
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
            let objects = recentAlbums.fetchedObjects ?? []
            return 1 + (objects.isEmpty ? 0 : 1)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch wantedAction {
        case .setAlbumThumbnail:
            if section == 0 {
                return inputImages.first?.albums?.filter({$0.pwgID > 0}).count ?? 0
            } else {
                return (albums.fetchedObjects ?? []).count
            }
        default:    // Present recent albums if any
            if ((recentAlbums.fetchedObjects ?? []).count > 0) && (section == 0) {
                return (recentAlbums.fetchedObjects ?? []).count
            } else {
                return (albums.fetchedObjects ?? []).count
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
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).isEmpty == false
        switch indexPath.section {
        case 0:
            if wantedAction == .setAlbumThumbnail {
                // Albums in which this image belongs to
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(ofUser: user, withId: catId)!
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
        
        // No button if the user does not have upload rights
        var buttonState: pwgCategoryCellButtonState = .none
        let allAlbums: [Album] = albums.fetchedObjects ?? []
        let filteredCat = allAlbums.filter({ user.hasAdminRights ||
                                             userUploadRights.contains($0.pwgID) })
        if filteredCat.count > 0 {
            buttonState = albumsShowingSubAlbums.contains(albumData.pwgID) ? .hideSubAlbum : .showSubAlbum
        }

        // How should we present the category
        cell.delegate = self
        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            if albumData.pwgID == inputAlbum.pwgID {
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
                if inputAlbum.parentId == 0 {
                    // Yes => Change text colour
                    cell.albumLabel.textColor = .piwigoColorRightLabel()
                }
            }
            else if hasRecentAlbums && (indexPath.section == 0) {
                // Don't present sub-albums in Recent Albums section
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            }
            else if albumData.pwgID == inputAlbum.parentId {
                // This album is the parent of the input album => Change text colour
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            }
            else if albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputAlbum.pwgID) {
                // This album is a sub-album of the input album => No button
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
                cell.albumLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Not a parent of a sub-album of the input album
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .setAlbumThumbnail:
            // Don't present sub-albums in first section
            if indexPath.section == 0 {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .setAutoUploadAlbum:
            // Don't present sub-albums in Recent Albums section
            if hasRecentAlbums && (indexPath.section == 0) {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
        case .copyImage, .copyImages, .moveImage, .moveImages:
            // Don't present sub-albums in Recent Albums section
            if hasRecentAlbums && (indexPath.section == 0) {
                cell.configure(with: albumData, atDepth: depth, andButtonState: .none)
            } else {
                cell.configure(with: albumData, atDepth: depth, andButtonState: buttonState)
            }
            // Albums containing the image are not selectable
            if commonCatIDs.contains(albumData.pwgID) {
                cell.albumLabel.textColor = .piwigoColorRightLabel()
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
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(ofUser: user, withId: catId)!
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

        switch wantedAction {
        case .setDefaultAlbum:
            // The current default category is not selectable
            print("••> albums: \(albumData.pwgID) and \(inputAlbum.pwgID)")
            if albumData.pwgID == inputAlbum.pwgID {
                return false
            }
            
        case .moveAlbum:
            // Do nothing if this is the input category
            if albumData.pwgID == inputAlbum.pwgID {
                return false
            }
            // User cannot move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputAlbum.parentId == 0 {
                    return false
                }
            } else if (albumData.pwgID == inputAlbum.parentId) ||
                albumData.upperIds.components(separatedBy: ",")
                .compactMap({Int32($0)}).contains(inputAlbum.pwgID) {
                return false
            }
            
        case .setAlbumThumbnail:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }

        case .setAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }

        case .copyImage, .copyImages, .moveImage, .moveImages:
            // The root album is not selectable (should not be presented but in case…)
            if albumData.pwgID == 0 {
                return false
            }
            // Albums containing all the images are not selectable
            if commonCatIDs.contains(albumData.pwgID) {
                return false
            }

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
        let hasRecentAlbums = (recentAlbums.fetchedObjects ?? []).count > 0
        switch indexPath.section {
        case 0:
            // Provided album
            if wantedAction == .setAlbumThumbnail {
                var catId = inputAlbum.pwgID     // This album always exists in cache
                if let catIds = inputImages.first?.albums?.compactMap({$0.pwgID}).filter({$0 > 0}),
                   catIds.count > indexPath.row {
                    catId = catIds[indexPath.row]
                }
                albumData = albumProvider.getAlbum(ofUser: user, withId: catId)!
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
        
        // Remember the choice
        selectedCategoryId = albumData.pwgID

        // What should we do with this selection?
        switch wantedAction {
        case .setDefaultAlbum:
            // Do nothing if this is the current default category
            if (albumData.pwgID == Int32.min) ||
                (albumData.pwgID == inputAlbum.pwgID) { return }
            
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
            if albumData.pwgID == inputAlbum.pwgID { return }

            // User must not move album to current parent album or in itself
            if albumData.pwgID == 0 {  // upperCategories is nil for root
                if inputAlbum.parentId == 0 {
                    return
                }
            } else {
                let parentIds = albumData.upperIds.components(separatedBy: ",")
                if albumData.pwgID == inputAlbum.parentId ||
                    parentIds.contains(where: { Int32($0) == inputAlbum.pwgID}) {
                    return
                }
            }

            // Ask user to confirm
            let title = NSLocalizedString("moveCategory", comment: "Move Album")
            let message = String(format: NSLocalizedString("moveCategory_message", comment: "Are you sure you want to move \"%@\" into the album \"%@\"?"), inputAlbum.name, albumData.name)
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
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let imageTitle = inputImages.first?.title.string ?? ""
            let message = String(format: NSLocalizedString("copySingleImage_message", comment:"Are you sure you want to copy the photo \"%@\" to the album \"%@\"?"), imageTitle.isEmpty ? inputImages.first?.fileName ?? "-?-" : imageTitle, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("copySingleImageHUD_copying", comment:"Copying Photo…"))
                // Copy single image to selected album
                self.copyImages(toAlbum: albumData)
            })

        case .moveImage:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let imageTitle = inputImages.first?.title.string ?? ""
            let message = String(format: NSLocalizedString("moveSingleImage_message", comment:"Are you sure you want to move the photo \"%@\" to the album \"%@\"?"), imageTitle.isEmpty ? inputImages.first?.fileName ?? "-?-" : imageTitle, albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("moveSingleImageHUD_moving", comment:"Moving Photo…"))
                // Move single image to selected album
                self.moveImages(toAlbum: albumData)
            }

        case .copyImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySeveralImages_message", comment:"Are you sure you want to copy the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath, handler: { _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("copySeveralImagesHUD_copying", comment: "Copying Photos…"),
                             inMode: .determinate)
                // Copy several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.copyImages(toAlbum: albumData)
                }
            })

        case .moveImages:
            // Do nothing if this is the root album
            if albumData.pwgID == 0 { return }
            // Do nothing if the images already belong to the selected album
            if commonCatIDs.contains(albumData.pwgID) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSeveralImages_message", comment:"Are you sure you want to move the photos to the album \"%@\"?"), albumData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: albumData, at: indexPath) { _ in
                // Display HUD
                self.showHUD(withTitle: NSLocalizedString("moveSeveralImagesHUD_moving", comment: "Moving Photos…"),
                             inMode: .determinate)
                // Move several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.moveImages(toAlbum: albumData)
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

    func showError(_ error: Error?) {
        // Session logout required?
        if let pwgError = error as? PwgSessionError,
           [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
            .contains(pwgError) {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
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
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error?.localizedDescription ?? "") {
            // Forget the choice
            self.selectedCategoryId = Int32.min
            // Save changes if any
            do {
                try self.mainContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }
            // Dismiss the view
            self.dismiss(animated: true, completion: {})
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension SelectCategoryViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [recentAlbums, albums].contains(controller) == false ||
            (wantedAction == .setAlbumThumbnail && controller == recentAlbums) {
            return
        }
        // Begin the update
        categoriesTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        // Check that this update should be managed by this view controller
        if view.window == nil || [recentAlbums, albums].contains(controller) == false ||
            (wantedAction == .setAlbumThumbnail && controller == recentAlbums) {
            return
        }

        // Initialisation
        var hasAlbumsInSection1 = false
        if controller == albums, categoriesTableView.numberOfSections ==  2 {
            hasAlbumsInSection1 = true
        }

        // Collect operation changes
        switch type {
        case .insert:
            guard var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 { newIndexPath.section = 1 }
            debugPrint("••> Insert category item at \(newIndexPath)")
            categoriesTableView?.insertRows(at: [newIndexPath], with: .automatic)
        case .update:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            debugPrint("••> Update category item at \(indexPath)")
            categoriesTableView?.reloadRows(at: [indexPath], with: .automatic)
        case .move:
            guard var indexPath = indexPath,  var newIndexPath = newIndexPath else { return }
            if hasAlbumsInSection1 {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            debugPrint("••> Move category item from \(indexPath) to \(newIndexPath)")
            categoriesTableView?.moveRow(at: indexPath, to: newIndexPath)
        case .delete:
            guard var indexPath = indexPath else { return }
            if hasAlbumsInSection1 { indexPath.section = 1 }
            debugPrint("••> Delete category item at \(indexPath)")
            categoriesTableView?.deleteRows(at: [indexPath], with: .automatic)
        @unknown default:
            debugPrint("SelectCategoryViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if view.window == nil || [recentAlbums, albums].contains(controller) == false ||
            (wantedAction == .setAlbumThumbnail && controller == recentAlbums) {
            return
        }
        // End updates
        categoriesTableView.endUpdates()
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
        categoriesTableView.reloadData()
    }
}
