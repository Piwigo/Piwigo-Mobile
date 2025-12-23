//
//  LocalAlbumsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 13/04/2020
//

import CoreData
import MobileCoreServices
import Photos
import PhotosUI
import UIKit
import piwigoKit
import uploadKit

protocol LocalAlbumsSelectorDelegate: NSObjectProtocol {
    func didSelectPhotoAlbum(withId: String)
}

class LocalAlbumsViewController: UIViewController {
    
    weak var delegate: (any LocalAlbumsSelectorDelegate)?
    
    @IBOutlet var localAlbumsTableView: UITableView!
    
    var categoryId: Int32 = AlbumVars.shared.defaultCategory
    var categoryCurrentCounter: Int64 = UploadVars.shared.categoryCounterInit
    weak var albumDelegate: (any AlbumViewControllerDelegate)?
    
    // Actions to perform after selection
    enum pwgAlbumSelectAction : Int {
        case none
        case presentLocalAlbum
        case setAutoUploadAlbum
    }
    var wantedAction: pwgAlbumSelectAction = .none
    
    private var selectPhotoLibraryItemsButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    var hasImagesInPasteboard: Bool = false
    
    let maxNberOfAlbumsInSection = 23
    var hasLimitedNberOfAlbums: [LocalAlbumType : Bool] = [.pasteboard   : false,
                                                           .localAlbums  : false,
                                                           .eventsAlbums : false,
                                                           .syncedAlbums : false,
                                                           .facesAlbums  : false,
                                                           .sharedAlbums : false,
                                                           .mediaTypes   : false,
                                                           .otherAlbums  : false]
    lazy var pasteboardTypes : [String] = {
        return [UTType.image.identifier, UTType.movie.identifier]
    }()
    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("localAlbums", comment: "Photo Library")
        
        // Button for selecting Photo Library items (.limited access mode)
        selectPhotoLibraryItemsButton = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(selectPhotoLibraryItems))
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
                
        // Table view identifier
        localAlbumsTableView?.accessibilityIdentifier = "album selector"
        localAlbumsTableView?.rowHeight = UITableView.automaticDimension
        localAlbumsTableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        
        // Register app becoming active for updating the pasteboard
        NotificationCenter.default.addObserver(self, selector: #selector(checkPasteboard),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Use the LocalAlbumsProvider to fetch albums data.
        LocalAlbumsProvider.shared.fetchedLocalAlbumsDelegate = self
        LocalAlbumsProvider.shared.includingEmptyAlbums = (categoryId == Int32.min)
        LocalAlbumsProvider.shared.fetchLocalAlbums {
            // Set limiters
            if LocalAlbumsProvider.shared.localAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.localAlbums] = true
            }
            if LocalAlbumsProvider.shared.eventsAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.eventsAlbums] = true
            }
            if LocalAlbumsProvider.shared.syncedAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.syncedAlbums] = true
            }
            if LocalAlbumsProvider.shared.facesAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.facesAlbums] = true
            }
            if LocalAlbumsProvider.shared.sharedAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.sharedAlbums] = true
            }
            if LocalAlbumsProvider.shared.mediaTypes.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.mediaTypes] = true
            }
            if LocalAlbumsProvider.shared.otherAlbums.count > self.maxNberOfAlbumsInSection {
                self.hasLimitedNberOfAlbums[.otherAlbums] = true
            }
            
            // Reload albums
            self.localAlbumsTableView.reloadData()
        }
    }
    
    @objc func selectPhotoLibraryItems() {
        // Proposes to change the Photo Library selection
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar appearance
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        
        // Table view
        setTableViewMainHeader()
        localAlbumsTableView?.separatorColor = PwgColor.separator
        localAlbumsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        localAlbumsTableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Determine what to do after selection
        if let caller = delegate {
            if caller is AutoUploadViewController {
                wantedAction = .setAutoUploadAlbum
            } else {
                wantedAction = .none
            }
        } else {
            // The user wishes to upload photos
            wantedAction = .presentLocalAlbum
            
            // Navigation "Cancel" button and identifier
            navigationItem.setLeftBarButton(cancelBarButton, animated: true)
            navigationController?.navigationBar.accessibilityIdentifier = "LocalAlbumsNav"
            
            // Check if there are photos/videos in the pasteboard
            let testTypes = UIPasteboard.general.contains(pasteboardTypes: pasteboardTypes) ? true : false
            let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes)?.count ?? 0
            hasImagesInPasteboard = testTypes && (nberPhotos > 0)
        }
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Hide toolbar when returning from the LocalImages / PasteboardImages views
        navigationController?.isToolbarHidden = true
        
        // Navigation "Select Photo Library items" button
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
            navigationItem.setRightBarButton(selectPhotoLibraryItemsButton, animated: true)
        }
        
        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Save position of collection view
        if localAlbumsTableView.visibleCells.count > 0,
           let cell = localAlbumsTableView.visibleCells.first {
            if let indexPath = localAlbumsTableView.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { [self] _ in
                    self.setTableViewMainHeader()
                    self.localAlbumsTableView.reloadData()
                    
                    // Scroll to previous position
                    self.localAlbumsTableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                })
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update title of current scene (iPad only)
        view.window?.windowScene?.title = NSLocalizedString("tabBar_upload", comment: "Upload")
    }
    
    @objc func checkPasteboard() {
        DispatchQueue.main.async { [self] in
            // Don't consider the pasteboard if the cateogry is null.
            if wantedAction == .setAutoUploadAlbum { return }
            
            // Are there images in the pasteboard?
            let testTypes = UIPasteboard.general.contains(pasteboardTypes: pasteboardTypes) ? true : false
            let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes)?.count ?? 0
            hasImagesInPasteboard = testTypes && (nberPhotos > 0)
            
            // Reload tableView
            self.setTableViewMainHeader()
            localAlbumsTableView.reloadData()
        }
    }
    
    @objc func quitUpload() {
        switch wantedAction {
        case .setAutoUploadAlbum, .none:
            // Should never be called
            navigationController?.popViewController(animated: true)
        default:
            // Leave Upload action and return to albums/images collections
            dismiss(animated: true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // If user disallowed access to Photos, there is no album left for selection.
        // So in this case, we return an empty collection name as source for auto-uploading.
        if wantedAction == .setAutoUploadAlbum,
           LocalAlbumsProvider.shared.localAlbums.isEmpty,
           LocalAlbumsProvider.shared.eventsAlbums.isEmpty,
           LocalAlbumsProvider.shared.syncedAlbums.isEmpty,
           LocalAlbumsProvider.shared.facesAlbums.isEmpty,
           LocalAlbumsProvider.shared.sharedAlbums.isEmpty,
           LocalAlbumsProvider.shared.mediaTypes.isEmpty,
           LocalAlbumsProvider.shared.otherAlbums.isEmpty  {
            delegate?.didSelectPhotoAlbum(withId: "")
        }
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - UITableView - Header
    @MainActor
    @objc private func setTableViewMainHeader() {
        // May be called from the notification center
        DispatchQueue.main.async { [self] in
            let headerView = SelectCategoryHeaderView(frame: .zero)
            var text = String(localized: "settings_autoUploadSourceInfo",
                              comment: "Please select the album…")
            switch wantedAction {
            case .presentLocalAlbum:
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    text += "\r\r⚠️ " + NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled") + " ⚠️"
                } else if UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi {
                    text += "\r\r⚠️ " + NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection") + " ⚠️"
                }
                headerView.configure(width: min(localAlbumsTableView.frame.size.width, pwgPadSettingsWidth),
                                     text: text)
                
            case .setAutoUploadAlbum:
                headerView.configure(width: min(localAlbumsTableView.frame.size.width, pwgPadSubViewWidth),
                                     text: text)
                
            default:
                fatalError("Action not configured in setTableViewMainHeader().")
            }
            localAlbumsTableView.tableHeaderView = headerView
        }
    }
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Update content sizes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Update header
            self.setTableViewMainHeader()
            
            // Animated update for smoother experience
            self.localAlbumsTableView?.beginUpdates()
            self.localAlbumsTableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        }
    }
}


// MARK: - LocalAlbumsProviderDelegate Methods
extension LocalAlbumsViewController: LocalAlbumsProviderDelegate
{
    func didChangePhotoLibrary() {
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before updating the UI.
        DispatchQueue.main.sync {
            localAlbumsTableView.reloadData()
        }
    }
}
