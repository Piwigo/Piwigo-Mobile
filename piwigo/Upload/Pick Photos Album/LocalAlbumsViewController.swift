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

protocol LocalAlbumsSelectorDelegate: NSObjectProtocol {
    func didSelectPhotoAlbum(withId: String)
}

class LocalAlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsProviderDelegate {

    weak var delegate: LocalAlbumsSelectorDelegate?

    @IBOutlet var localAlbumsTableView: UITableView!
    
    var categoryId: Int32 = AlbumVars.shared.defaultCategory

    // Actions to perform after selection
    private enum pwgAlbumSelectAction : Int {
        case none
        case presentLocalAlbum
        case setAutoUploadAlbum
    }
    private var wantedAction: pwgAlbumSelectAction = .none

    private var selectPhotoLibraryItemsButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var hasImagesInPasteboard: Bool = false

    private let maxNberOfAlbumsInSection = 23
    private var hasLimitedNberOfAlbums: [LocalAlbumType : Bool] = [.pasteboard   : false,
                                                                   .localAlbums  : false,
                                                                   .eventsAlbums : false,
                                                                   .syncedAlbums : false,
                                                                   .facesAlbums  : false,
                                                                   .sharedAlbums : false,
                                                                   .mediaTypes   : false,
                                                                   .otherAlbums  : false]
    private lazy var pasteboardTypes : [String] = {
        if #available(iOS 14.0, *) {
            return [UTType.image.identifier, UTType.movie.identifier]
        } else {
            // Fallback on earlier version
            return [kUTTypeImage as String, kUTTypeMovie as String]
        }
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
        if #available(iOS 14.0, *) {
            selectPhotoLibraryItemsButton = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(selectPhotoLibraryItems))
        }
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
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

    @available(iOS 14, *)
    @objc func selectPhotoLibraryItems() {
        // Proposes to change the Photo Library selection
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar appearance
        let navigationBar = navigationController?.navigationBar
        navigationController?.view.backgroundColor = UIColor.piwigoColorBackground()
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = UIColor.piwigoColorOrange()

        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationBar?.titleTextAttributes = attributes
        navigationBar?.prefersLargeTitles = false

        if #available(iOS 13.0, *) {
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.9)
            barAppearance.titleTextAttributes = attributes
            navigationItem.standardAppearance = barAppearance
            navigationItem.compactAppearance = barAppearance // For iPhone small navigation bar in landscape.
            navigationItem.scrollEdgeAppearance = barAppearance
            navigationBar?.prefersLargeTitles = false
        }

        // Table view
        setTableViewMainHeader()
        localAlbumsTableView?.separatorColor = .piwigoColorSeparator()
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
        if #available(iOS 14, *) {
            if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited {
                navigationItem.setRightBarButton(selectPhotoLibraryItemsButton, animated: true)
            }
        }

        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
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
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = NSLocalizedString("tabBar_upload", comment: "Upload")
        }
    }

    @objc func checkPasteboard() {
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
    @objc private func setTableViewMainHeader() {
        DispatchQueue.main.async { [self] in
            let headerView = SelectCategoryHeaderView(frame: .zero)
            switch wantedAction {
            case .presentLocalAlbum:
                var text = NSLocalizedString("imageUploadHeader", comment: "Please select the album or sub-album from which photos and videos of your device will be uploaded.")
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    text += "\r\r⚠️ " + NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled") + " ⚠️"
                } else if UploadVars.wifiOnlyUploading && !NetworkVars.isConnectedToWiFi() {
                    text += "\r\r⚠️ " + NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection") + " ⚠️"
                }
                headerView.configure(width: min(localAlbumsTableView.frame.size.width, pwgPadSettingsWidth),
                                     text: text)
                
            case .setAutoUploadAlbum:
                headerView.configure(width: min(localAlbumsTableView.frame.size.width, pwgPadSubViewWidth),
                                     text: String(format: NSLocalizedString("settings_autoUploadSourceInfo", comment:"Please select the album or sub-album from which photos and videos of your device will be auto-uploaded.")))
                
            default:
                fatalError("Action not configured in setTableViewMainHeader().")
            }
            localAlbumsTableView.tableHeaderView = headerView
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Get title of section
        let albumType = albumTypeFor(section: section)
        let title = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Get title of section
        let albumType = albumTypeFor(section: section)
        let title = LocalAlbumsProvider.shared.titleForHeaderInSectionOf(albumType: albumType)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // First section added for pasteboard?
        if hasImagesInPasteboard && (section == 0) { return }
        view.layer.zPosition = 0
    }

    
    // MARK: - UITableView - Rows
    private func albumTypeFor(section: Int) -> LocalAlbumType {
        // First section added for pasteboard?
        var activeSection: Int = section
        if hasImagesInPasteboard {
            switch section {
            case 0:
                return .pasteboard
            default:
                activeSection -= 1
            }
        }

        var counter: Int = -1
        counter += LocalAlbumsProvider.shared.localAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .localAlbums }
        counter += LocalAlbumsProvider.shared.eventsAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .eventsAlbums }
        counter += LocalAlbumsProvider.shared.syncedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .syncedAlbums }
        counter += LocalAlbumsProvider.shared.facesAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .facesAlbums }
        counter += LocalAlbumsProvider.shared.sharedAlbums.isEmpty ? 0 : 1
        if activeSection == counter { return .sharedAlbums }
        counter += LocalAlbumsProvider.shared.mediaTypes.isEmpty ? 0 : 1
        if activeSection == counter { return .mediaTypes }
        counter += LocalAlbumsProvider.shared.otherAlbums.isEmpty ? 0 : 1
        return .otherAlbums
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        var count = Int.zero

        // Consider non-empty collections
        count += LocalAlbumsProvider.shared.localAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.eventsAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.syncedAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.facesAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.sharedAlbums.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.mediaTypes.isEmpty ? 0 : 1
        count += LocalAlbumsProvider.shared.otherAlbums.isEmpty ? 0 : 1
        
        // First section added for pasteboard if necessary
        return count + (hasImagesInPasteboard ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let albumType = albumTypeFor(section: section)
        var nberOfAlbums = 0
        switch albumType {
        case .pasteboard:
            return 1
        case .localAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.localAlbums.count
        case .eventsAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.eventsAlbums.count
        case .syncedAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.syncedAlbums.count
        case .facesAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.facesAlbums.count
        case .sharedAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.sharedAlbums.count
        case .mediaTypes:
            nberOfAlbums = LocalAlbumsProvider.shared.mediaTypes.count
        case .otherAlbums:
            nberOfAlbums = LocalAlbumsProvider.shared.otherAlbums.count
        }
        return hasLimitedNberOfAlbums[albumType]! ? min(maxNberOfAlbumsInSection, nberOfAlbums) + 1 : nberOfAlbums
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var assetCollection: PHAssetCollection?
        let albumType = albumTypeFor(section: indexPath.section)
        let isLimited = hasLimitedNberOfAlbums[albumType]!
        switch albumType {
        case .pasteboard:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell
            else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a LocalAlbumsNoDatesTableViewCell!") }
            let title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
            let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: pasteboardTypes)?.count ?? NSNotFound
            cell.configure(with: title, nberPhotos: Int64(nberPhotos))
            cell.isAccessibilityElement = true
            return cell
        case .localAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.localAlbums[indexPath.row]
            }
        case .eventsAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.eventsAlbums[indexPath.row]
            }
        case .syncedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.syncedAlbums[indexPath.row]
            }
        case .facesAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.facesAlbums[indexPath.row]
            }
        case .sharedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.sharedAlbums[indexPath.row]
            }
        case .mediaTypes:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.mediaTypes[indexPath.row]
            }
        case .otherAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.otherAlbums[indexPath.row]
            }
        }

        // Display [+] button at the bottom of section presenting a limited number of albums
        guard let aCollection = assetCollection else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsMoreTableViewCell", for: indexPath) as? LocalAlbumsMoreTableViewCell
            else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a LocalAlbumsMoreTableViewCell!") }
            cell.configure()
            cell.isAccessibilityElement = true
            return cell
        }
        
        // Case of an album
        let title = aCollection.localizedTitle ?? "—> ? <——"
        let nberPhotos = Int64(aCollection.estimatedAssetCount)

        if let startDate = aCollection.startDate, let endDate = aCollection.endDate {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsTableViewCell", for: indexPath) as? LocalAlbumsTableViewCell
            else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a LocalAlbumsTableViewCell!") }
            cell.configure(with: title, nberPhotos: nberPhotos, startDate: startDate, endDate: endDate)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if aCollection.assetCollectionType == .smartAlbum,
               aCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
        else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell
            else { preconditionFailure("Error: tableView.dequeueReusableCell does not return a LocalAlbumsNoDatesTableViewCell!") }
            cell.configure(with: title, nberPhotos: nberPhotos)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if aCollection.assetCollectionType == .smartAlbum,
               aCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var assetCollection: PHAssetCollection?
        let albumType = albumTypeFor(section: indexPath.section)
        let isLimited = hasLimitedNberOfAlbums[albumType]!
        switch albumType {
        case .pasteboard:
            return 44.0
        case .localAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.localAlbums[indexPath.row]
            }
        case .eventsAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.eventsAlbums[indexPath.row]
            }
        case .syncedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.syncedAlbums[indexPath.row]
            }
        case .facesAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.facesAlbums[indexPath.row]
            }
        case .sharedAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.sharedAlbums[indexPath.row]
            }
        case .mediaTypes:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.mediaTypes[indexPath.row]
            }
        case .otherAlbums:
            if !(isLimited && indexPath.row == maxNberOfAlbumsInSection) {
                assetCollection = LocalAlbumsProvider.shared.otherAlbums[indexPath.row]
            }
        }

        // Display [+] button at the bottom of section presenting a limited number of albums
        guard let aCollection = assetCollection else { return 36.0 }
        
        // Case of an album
        if let _ = aCollection.startDate, let _ = aCollection.endDate {
            return 53.0
        } else {
            return 44.0
        }
    }

    
    // MARK: - UITableView - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Get footer of section
        let albumType = albumTypeFor(section: section)
        let footer = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.shared.heightOfFooter(withText: footer,
                                                        width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Get footer of section
        let albumType = albumTypeFor(section: section)
        let footer = LocalAlbumsProvider.shared.titleForFooterInSectionOf(albumType: albumType)
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }


    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var assetCollections = [PHAssetCollection]()
        let albumType = albumTypeFor(section: indexPath.section)
        let isLimited = hasLimitedNberOfAlbums[albumType]!
        switch albumType {
        case .pasteboard:
            let pasteboardImagesSB = UIStoryboard(name: "PasteboardImagesViewController", bundle: nil)
            guard let pasteboardImagesVC = pasteboardImagesSB.instantiateViewController(withIdentifier: "PasteboardImagesViewController") as? PasteboardImagesViewController else { return }
            pasteboardImagesVC.categoryId = categoryId
            pasteboardImagesVC.user = user
            navigationController?.pushViewController(pasteboardImagesVC, animated: true)
            return
        case .localAlbums:
            assetCollections = LocalAlbumsProvider.shared.localAlbums
        case .eventsAlbums:
            assetCollections = LocalAlbumsProvider.shared.eventsAlbums
        case .syncedAlbums:
            assetCollections = LocalAlbumsProvider.shared.syncedAlbums
        case .facesAlbums:
            assetCollections = LocalAlbumsProvider.shared.facesAlbums
        case .sharedAlbums:
            assetCollections = LocalAlbumsProvider.shared.sharedAlbums
        case .mediaTypes:
            assetCollections = LocalAlbumsProvider.shared.mediaTypes
        case .otherAlbums:
            assetCollections = LocalAlbumsProvider.shared.otherAlbums
        }
        
        // Did tap [+] button at the bottom of section —> release remaining albums
        if isLimited && indexPath.row == maxNberOfAlbumsInSection {
            // Release album list
            hasLimitedNberOfAlbums[albumType] = false
            // Add remaining albums
            let indexPaths: [IndexPath] = Array(maxNberOfAlbumsInSection+1..<assetCollections.count)
                                                .map { IndexPath(row: $0, section: indexPath.section)}
            tableView.insertRows(at: indexPaths, with: .automatic)
            // Replace button
            tableView.reloadRows(at: [indexPath], with: .automatic)
            return
        }
        
        // Case of an album
        let albumID = assetCollections[indexPath.row].localIdentifier
        if wantedAction == .setAutoUploadAlbum {
            // Return the selected album ID
            delegate?.didSelectPhotoAlbum(withId: albumID)
            navigationController?.popViewController(animated: true)
        } else {
            // Presents local images of the selected album
            let localImagesSB = UIStoryboard(name: "LocalImagesViewController", bundle: nil)
            guard let localImagesVC = localImagesSB.instantiateViewController(withIdentifier: "LocalImagesViewController") as? LocalImagesViewController else { return }
            localImagesVC.categoryId = categoryId
            localImagesVC.imageCollectionId = albumID
            localImagesVC.user = user
            navigationController?.pushViewController(localImagesVC, animated: true)
        }
    }

    
    // MARK: - LocalAlbumsProviderDelegate Methods
    
    func didChangePhotoLibrary() {
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before updating the UI.
        DispatchQueue.main.sync {
            localAlbumsTableView.reloadData()
        }
    }
}
