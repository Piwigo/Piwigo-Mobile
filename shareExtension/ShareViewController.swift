//
//  ShareViewController.swift
//  shareExtension
//
//  Created by Eddy Lelièvre-Berna on 09/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import UIKit
import UniformTypeIdentifiers
import piwigoKit
import uploadKit

class ShareViewController: UIViewController {
    
    var updateOperations = [BlockOperation]()

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
        var recentCatIds: [Int32] = CacheVars.shared.recentCategories.components(separatedBy: ",").compactMap({Int32($0)})
        // Limit the number of recent albums
        let nberExtraCats: Int = max(0, recentCatIds.count - CacheVars.shared.maxNberRecentCategories)
        andPredicates.append(NSPredicate(format: "pwgID IN %@", recentCatIds.dropLast(nberExtraCats)))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchLimit = CacheVars.shared.maxNberRecentCategories
        return fetchRequest
    }()
    
    lazy var recentAlbums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchRecentAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
//        albums.delegate = self
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
        return fetchRequest
    }()
    
    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
//        albums.delegate = self
        return albums
    }()

    
    
    
    // MARK: - View
    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?
    var albumsShowingSubAlbums = Set<Int32>()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register the CategoryTableViewCell before using it
//        categoriesTableView?.register(UINib(nibName: "CategoryTableViewCell", bundle: nil),
//                                      forCellReuseIdentifier: "CategoryTableViewCell")

        // Table view identifier
        categoriesTableView?.accessibilityIdentifier = "album selector"
        categoriesTableView?.rowHeight = UITableView.automaticDimension
//        categoriesTableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Retrieve user
        guard let user = try? userProvider.getUserAccount(inContext: mainContext)
        else {
            extensionContext?.cancelRequest(withError: URLError(.cancelled))
            return
        }
        self.user = user
        
        // Initialise data source
        do {
            try recentAlbums.performFetch()
            try albums.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "CancelSelect"
        
        // Title
        title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
        
        // Retrieve shared items
        Task {
            let context = extensionContext
            await copySharedItems(fromContext: context)
        }
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
//        view.backgroundColor = PwgColor.background

        // Navigation bar
//        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
//        setTableViewMainHeader()
//        categoriesTableView?.separatorColor = PwgColor.separator
//        categoriesTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation "Cancel" button and identifier
        navigationItem.setLeftBarButton(cancelBarButton, animated: true)
        
        // Register palette changes
//        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
//                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
//        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
//                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        
        // Display albums
        categoriesTableView?.reloadData()
    }

    @objc
    func cancelSelect() -> Void {
        extensionContext?.cancelRequest(withError: URLError(.cancelled))
    }
    
    
    // MARK: - Copy Shared Items to Uploads folder
    private nonisolated func copySharedItems(fromContext context: NSExtensionContext?) async {
        // Retrieve input item
        guard let context,
              let extensionItem = context.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments
        else {
            context?.cancelRequest(withError: URLError(.cancelled))
            return
        }
        
        // Get date of share
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        let sharedDateTime = dateFormatter.string(from: Date())
        
        // Loop over all shared items
        /// Shared items are identified with identifiers of the type "pwgShared-yyyyMMdd-HHmmssSSSS-typ-####" where:
        /// - "pwgShared" is a header telling that the image/video comes from the share extension (see kSharedPrefix)
        /// - "yyyyMMdd-HHmmssSSSS" is the date at which the items were shared
        /// - "typ" is "-img-" or "-mov-" depending on the nature of the object (see kImageSuffix, kMovieSuffix)
        /// - "####" is the index of the object being shared
        var sharedItems: [(identifier: String, fileName: String)] = []
        for (index, provider) in attachments.enumerated() {
            // Movies first because objects may contain both movies and images
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                if let (identifier, fileName) = await self.getSharedMovie(atIndex: index + 1, from: provider, on: sharedDateTime) {
                    sharedItems.append((identifier, fileName))
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let (identifier, fileName) = await self.getSharedImage(atIndex: index + 1, from: provider, on: sharedDateTime) {
                    sharedItems.append((identifier, fileName))
                }
            }
        }
        
//        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private nonisolated func getSharedImage(atIndex index: Int, from provider: NSItemProvider, on sharedDateTime: String) async -> (String, String)? {
        return await withCheckedContinuation { continuation in
            // Asynchronously writes a copy of the provided, typed data to a temporary file, returning a progress object.
            if #available(iOS 16.0, *) {
                _ = provider.loadFileRepresentation(for: .image, openInPlace: false) { url, _, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            } else {
                // Fallback on older version
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            }
        }
    }
    
    private nonisolated func getSharedMovie(atIndex index: Int, from provider: NSItemProvider, on sharedDateTime: String) async -> (String, String)? {
        return await withCheckedContinuation { continuation in
            // Asynchronously writes a copy of the provided, typed data to a temporary file, returning a progress object.
            if #available(iOS 16.0, *) {
                _ = provider.loadFileRepresentation(for: .movie, openInPlace: false) { url, _, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            } else {
                // Fallback on older version
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy video to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kMovieSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            }
        }
    }
}


// MARK: - CategoryCellDelegate Methods
extension ShareViewController: @MainActor CategoryCellDelegate {
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
