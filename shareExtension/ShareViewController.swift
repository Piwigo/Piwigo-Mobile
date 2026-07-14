//
//  ShareViewController.swift
//  shareExtension
//
//  Created by Eddy Lelièvre-Berna on 09/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import os
import CoreData
import UIKit
import UniformTypeIdentifiers
import PwgKit
import PwgCacheKit
import PwgUIKit
import PwgUploadKit

final class ShareViewController: UIViewController {
    
    // Logs share activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    let logger = PwgLogger(subsystem: "org.piwigo.shareExtension", category: String(describing: ShareViewController.self))

    var context: NSExtensionContext?        // Context of the extension
    lazy var shareDate: String = {          // Date of the share included in file names and deep link
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        return dateFormatter.string(from: Date())
    }()
    
    
    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        return DataController.shared.mainContext
    }()
    
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        return UserProvider()
    }()
    
    
    // MARK: - Core Data Source
    var user: User!
    var migrationRequired: Bool = false
    lazy var userUploadRights: [Int32] = {
        // Case of Community user?
        if ServerVars.shared.userStatus != .normal { return [] }
        let userUploadRights = user.uploadRights
        return userUploadRights.components(separatedBy: ",").compactMap({ Int32($0) })
    }()
    
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", ServerVars.shared.user))
        return andPredicates
    }()
    
    lazy var fetchRecentAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        var andPredicates = predicates
        var recentCatIds: [Int32] = CacheVars.shared.recentCategories.components(separatedBy: ",").compactMap({Int32($0)})
        recentCatIds.removeAll(where: { $0 == Int32.zero })
        // Limit the number of recent albums
        let nberExtraCats: Int = max(0, recentCatIds.count - CacheVars.shared.maxNberRecentCategories)
        andPredicates.append(NSPredicate(format: "pwgID IN %@", recentCatIds.dropLast(nberExtraCats)))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = CacheVars.shared.maxNberRecentCategories
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        return fetchRequest
    }()
    
    lazy var recentAlbums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchRecentAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
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
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 20
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.shouldRefreshRefetchedObjects = true
        return fetchRequest
    }()
    
    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        return albums
    }()

    
    // MARK: - View
    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?
    var albumsShowingSubAlbums = Set<Int32>()


    // MARK: - Shared Items Copy
    // Task copying the shared items to the Uploads folder, returning the number of copied items
    // and the number of PDF files skipped because the Piwigo server does not accept them
    var copyItemsTask: Task<(copied: Int, skippedPdfs: Int), Never>?
    var itemsAreReady = false               // True once all shared items have been copied

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        logger.notice("Share extension starting...")
        
        // Table view identifier
        categoriesTableView?.accessibilityIdentifier = "album selector"
        categoriesTableView?.rowHeight = UITableView.automaticDimension
        categoriesTableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Title
        title = String(localized: "uploadToAlbum_title", comment:"Upload to Album")
        
        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            migrationRequired = true
            logger.notice("Migration required...")
            return
        }
        
        // Retrieve user and check that a root album exists in cache (create it if necessary)
        // When this fails, the user is asked to log in and create a first album when the view appears.
        guard let user = try? userProvider.getUserAccount(inContext: mainContext),
              let _ = try? AlbumProvider().getAlbum(ofUser: user, withId: pwgSmartAlbum.root.rawValue),
              AlbumProvider().getObjectCount(inContext: mainContext) > 0
        else {
            logger.notice("No albums in cache")
            return
        }
        self.user = user
        
        // Initialise data source
        do {
            try recentAlbums.performFetch()
            try albums.performFetch()
        } catch {
            logger.notice("Perform fetch error: \(error)")
        }
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "CancelSelect"
        
        // Retrieve shared items
        self.context = extensionContext
        copyItemsTask = Task { @MainActor [weak self] in
            guard let self else { return (0, 0) }
            let context = self.extensionContext
            let shareDate = self.shareDate
            let result = await self.copyItems(fromContext: context, sharedAt: shareDate)
            self.itemsAreReady = true
            return result
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
        categoriesTableView?.backgroundColor = PwgColor.background
        categoriesTableView?.separatorColor = PwgColor.separator
        categoriesTableView?.indicatorStyle = InterfaceVars.shared.isDarkPaletteActive ? .white : .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Did the user change system settings?
        InterfaceManager.shared.applyColorPalette(for: traitCollection.userInterfaceStyle)
        
        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation "Cancel" button and identifier
        navigationItem.setLeftBarButton(cancelBarButton, animated: true)
        
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        
        // Display albums
        categoriesTableView?.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Ask the user to open the app and perform the migration
        if migrationRequired {
            presentShareFailAlert(withMessage: Localized.migrationRequired)
            return
        }
        
        // Ask the user to log in and create an album
        if user == nil {
            let message = String(localized: "shareFailError_noAlbum",
                                 comment: "Please open the Piwigo app and create an album before sharing photos or videos.")
            presentShareFailAlert(withMessage: message)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func cancelSelect() -> Void {
        // Stop copying shared items, if not already done
        copyItemsTask?.cancel()
        Task { @MainActor in
            // Wait for the in-flight item copy to complete
            _ = await copyItemsTask?.value

            // Delete the files of this share before closing the share sheet
            deleteSharedItems(sharedAt: shareDate)
            extensionContext?.cancelRequest(withError: URLError(.cancelled))
        }
    }
    
    
    // MARK: - TableView Main Header
    private func setTableViewMainHeader() {
        let headerView = ShareViewHeaderView(frame: .zero)
        headerView.configure(width: min(categoriesTableView.frame.size.width, pwgPadSubViewWidth),
                             text: String(localized: "uploadSeveralImages_selectAlbum", comment: "Please, select the album in which you wish to upload the photos."))
        categoriesTableView?.tableHeaderView = headerView
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
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        }
    }
    
    
    // MARK: - Copy Shared Items to Uploads folder
    private nonisolated func copyItems(fromContext context: NSExtensionContext?,
                                       sharedAt shareDate: String) async -> (copied: Int, skippedPdfs: Int) {
        // Retrieve input item
        guard let context,
              let extensionItem = context.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments
        else { return (0, 0) }
        
        // Loop over all shared items
        /// Shared items are identified with identifiers of the type "pwgShared-yyyyMMdd-HHmmssSSSS-typ-####" where:
        /// - "pwgShared" is a header telling that the image/video comes from the share extension (see kSharedPrefix)
        /// - "yyyyMMdd-HHmmssSSSS" is the date at which the items were shared
        /// - "typ" is "-img-", "-mov-" or "-pdf-" depending on the nature of the object (see kImageSuffix, kMovieSuffix, kPdfSuffix)
        /// - "####" is the index of the object being shared
        var sharedItemCount = 0
        var skippedPdfCount = 0
        for (index, provider) in attachments.enumerated() {
            // Stop when the user cancelled the share
            if Task.isCancelled { break }

            // Movies first because objects may contain both movies and images
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                if await self.getSharedItem(atIndex: index, ofType: .movie, from: provider, on: shareDate) {
                    sharedItemCount += 1
                }
            }
            // PDF before image so that the original file is preferred to a possible image rendition
            else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                // Accept PDF files only when the Piwigo server accepts them
                if ServerVars.shared.serverFileTypes.contains("pdf") == false {
                    self.logger.notice("PDF files not accepted by the server —> file skipped")
                    skippedPdfCount += 1
                }
                else if await self.getSharedItem(atIndex: index, ofType: .pdf, from: provider, on: shareDate) {
                    sharedItemCount += 1
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if await self.getSharedItem(atIndex: index, ofType: .image, from: provider, on: shareDate) {
                    sharedItemCount += 1
                }
            }
        }
        self.logger.notice("Copied \(sharedItemCount) shared items to Uploads folder, skipped \(skippedPdfCount) PDF files")
        return (sharedItemCount, skippedPdfCount)
    }
    
    private nonisolated func getSharedItem(atIndex index: Int, ofType type: UTType, from provider: NSItemProvider,
                                           on shareDate: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Called with the URL of the temporary copy created by the provider,
            // which is deleted when this handler returns.
            let handleLoadedFile: @Sendable (URL?, (any Error)?) -> Void = { url, error in
                var success = false
                defer { continuation.resume(returning: success) }

                guard let url else {
                    self.logger.notice("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                // Suffix and fallback file extension depending on the nature of the item
                let suffix: String, fileExt: String
                switch type {
                case .movie:
                    (suffix, fileExt) = (kMovieSuffix, "mov")
                case .pdf:
                    (suffix, fileExt) = (kPdfSuffix, "pdf")
                default:
                    (suffix, fileExt) = (kImageSuffix, "jpeg")
                }

                // Prepare file name
                var fileName = url.lastPathComponent
                if url.pathExtension.isEmpty {
                    let fileType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType) ?? UTType.data
                    fileName = fileName.appending("." + (fileType.preferredFilenameExtension ?? fileExt))
                }

                // Store our own copy for a future upload
                let identifier = kSharedPrefix + shareDate + suffix + String(index + 1)
                let fileURL = DataDirectories.appUploadsDirectory.appendingPathComponent(identifier)
                do {
                    try FileManager.default.copyItem(at: url, to: fileURL)
                    self.writeJSONfile(at: fileURL, withIdentifier: identifier, fileName: fileName)
                    success = true
                } catch {
                    self.logger.notice("Failed to copy shared item: \(error.localizedDescription)")
                }
            }

            // Asynchronously writes a copy of the provided,
            // typed data to a temporary file, returning a progress object.
            if #available(iOS 16.0, *) {
                _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, error in
                    handleLoadedFile(url, error)
                }
            } else {
                // Fallback on older version
                _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    handleLoadedFile(url, error)
                }
            }
        }
    }
    
    // Deletes the media files and JSON sidecars of the share performed at the given date
    nonisolated func deleteSharedItems(sharedAt shareDate: String) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: DataDirectories.appUploadsDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        else { return }
        for file in files where file.lastPathComponent.hasPrefix(kSharedPrefix + shareDate) {
            try? fileManager.removeItem(at: file)
        }
    }

    private nonisolated func writeJSONfile(at fileURL: URL, withIdentifier identifier: String, fileName: String) {
        do {
            let uploadInfo: [String: String] = [
                "identifier"  : identifier,
                "fileName"    : fileName
            ]
            let JSONdata = try JSONEncoder().encode(uploadInfo)
            try JSONdata.write(to: fileURL.appendingPathExtension("json"))
        }
        catch {
            self.logger.notice("Failed to write shared item JSON file: \(error.localizedDescription)")
        }
    }
}


// MARK: - CategoryCellDelegate Methods
extension ShareViewController: @MainActor ShareCellDelegate {
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
        fetchAlbumsRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        
        // Perform a new fetch
        try? albums.performFetch()
        
        // Shows albums and sub-albums
        categoriesTableView?.reloadData()
    }
}
