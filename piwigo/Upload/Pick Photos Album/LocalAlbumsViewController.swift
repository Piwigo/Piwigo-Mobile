//
//  LocalAlbumsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 3/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 13/04/2020
//

import Photos
import PhotosUI
import UIKit

@objc
protocol LocalAlbumsSelectorDelegate: NSObjectProtocol {
    func didSelectPhotoAlbum(withId: String)
}

@objc
class LocalAlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsProviderDelegate {

    @objc weak var delegate: LocalAlbumsSelectorDelegate?

    @IBOutlet var localAlbumsTableView: UITableView!
    
    @objc
    func setCategoryId(_ categoryId: Int) {
        _categoryId = categoryId
    }
    private var _categoryId: Int?
    private var categoryId: Int {
        get {
            return _categoryId ?? 0
        }
        set(categoryId) {
            _categoryId = categoryId
        }
    }

    // Actions to perform after selection
    private enum kPiwigoCategorySelectAction : Int {
        case none
        case presentLocalAlbum
        case setAutoUploadAlbum
    }
    private var wantedAction: kPiwigoCategorySelectAction = .none

    private var selectPhotoLibraryItemsButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var hasImagesInPasteboard: Bool = false

    
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
        var name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Register app becoming active for updating the pasteboard
        name = NSNotification.Name(UIApplication.didBecomeActiveNotification.rawValue)
        NotificationCenter.default.addObserver(self, selector: #selector(checkPasteboard), name: name, object: nil)

        // Use the LocalAlbumsProvider to fetch albums data.
        LocalAlbumsProvider.sharedInstance().fetchedLocalAlbumsDelegate = self
        LocalAlbumsProvider.sharedInstance().fetchLocalAlbums {
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
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()
                
        // Table view
        setTableViewMainHeader()
        localAlbumsTableView?.separatorColor = UIColor.piwigoColorSeparator()
        localAlbumsTableView?.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        localAlbumsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Determine what to do after selection
        if let caller = delegate {
            if caller.isKind(of: AutoUploadViewController.self) {
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
            if let indexSet = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"]),
               indexSet.count > 0, let _ = UIPasteboard.general.types(forItemSet: indexSet) {
                hasImagesInPasteboard = true
            }
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
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = localAlbumsTableView.visibleCells.first {
            if let indexPath = localAlbumsTableView.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { context in
                    self.setTableViewMainHeader()
                    self.localAlbumsTableView.reloadData()

                    // Scroll to previous position
                    self.localAlbumsTableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                })
            }
        }
    }

    @objc func checkPasteboard() {
        // Don't consider the pasteboard if the cateogry is null.
        if wantedAction == .setAutoUploadAlbum { return }
        
        // Are there images in the pasteboard?
        let testTypes = UIPasteboard.general.contains(pasteboardTypes: ["public.image", "public.movie"]) ? true : false
        let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"])?.count ?? 0
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

        // Unregister palette changes
        var name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Unregister app becoming active for updating the pasteboard
        name = NSNotification.Name(UIApplication.didBecomeActiveNotification.rawValue)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func setTableViewMainHeader() {
        let headerView = SelectCategoryHeaderView(frame: .zero)
        switch wantedAction {
        case .presentLocalAlbum:
            headerView.configure(width: min(localAlbumsTableView.frame.size.width, kPiwigoPadSettingsWidth),
                                 text: NSLocalizedString("imageUploadHeader", comment: "Please select the album or sub-album from which photos and videos of your device will be uploaded."))

        case .setAutoUploadAlbum:
            headerView.configure(width: min(localAlbumsTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("settings_autoUploadSourceInfo", comment:"Please select the album or sub-album from which photos and videos of your device will be auto-uploaded.")))

        default:
            fatalError("Action not configured in setTableViewMainHeader().")
        }
        localAlbumsTableView.tableHeaderView = headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // First section added for pasteboard?
        var activeSection = section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return 0.0
            default:
                activeSection -= 1
            }
        }

        // Title
        let titleString = LocalAlbumsProvider.sharedInstance().localAlbumHeaders[activeSection]
        let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(ceil(titleRect.size.height))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        // First section added for pasteboard?
        var activeSection = section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return nil
            default:
                activeSection -= 1
            }
        }

        // Title
        let titleString = LocalAlbumsProvider.sharedInstance().localAlbumHeaders[activeSection]
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = titleAttributedString

        // Header view
        let header = UIView()
        header.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        }

        return header
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // First section added for pasteboard?
        if hasImagesInPasteboard && (section == 0) { return }
        view.layer.zPosition = 0
    }

    
    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        // First section added for pasteboard if necessary
        return LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums.count +
            (hasImagesInPasteboard ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // First section added for pasteboard?
        var activeSection = section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return 1
            default:
                activeSection -= 1
            }
        }
        return LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums[activeSection] ? min(LocalAlbumsProvider.sharedInstance().maxNberOfAlbumsInSection, LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection].count) + 1 : LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // First section added for pasteboard?
        var activeSection = indexPath.section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a LocalAlbumsNoDatesTableViewCell!")
                    return LocalAlbumsNoDatesTableViewCell()
                }
                let title = NSLocalizedString("categoryUpload_pasteboard", comment: "Clipboard")
                let nberPhotos = UIPasteboard.general.itemSet(withPasteboardTypes: ["public.image", "public.movie"])?.count ?? NSNotFound
                cell.configure(with: title, nberPhotos: nberPhotos)
                cell.isAccessibilityElement = true
                return cell
            default:
                activeSection -= 1
            }
        }

        // Display [+] button at the bottom of section presenting a limited number of albums
        if indexPath.section < LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums.count,
           LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums[indexPath.section] == true,
            indexPath.row == LocalAlbumsProvider.sharedInstance().maxNberOfAlbumsInSection {
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsMoreTableViewCell", for: indexPath) as? LocalAlbumsMoreTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LocalAlbumsMoreTableViewCell!")
                return LocalAlbumsMoreTableViewCell()
            }
            cell.configure()
            cell.isAccessibilityElement = true
            return cell
        }
        
        // Case of an album
        let assetCollection = LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection][indexPath.row]
        let title = assetCollection.localizedTitle ?? "—> ? <——"
        let nberPhotos = assetCollection.estimatedAssetCount

        if let startDate = assetCollection.startDate, let endDate = assetCollection.endDate {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsTableViewCell", for: indexPath) as? LocalAlbumsTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LocalAlbumsTableViewCell!")
                return LocalAlbumsTableViewCell()
            }
            cell.configure(with: title, nberPhotos: nberPhotos, startDate: startDate, endDate: endDate)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if assetCollection.assetCollectionType == .smartAlbum && assetCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
        else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsNoDatesTableViewCell", for: indexPath) as? LocalAlbumsNoDatesTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LocalAlbumsNoDatesTableViewCell!")
                return LocalAlbumsNoDatesTableViewCell()
            }
            cell.configure(with: title, nberPhotos: nberPhotos)
            cell.accessoryType = wantedAction == .setAutoUploadAlbum ? .none : .disclosureIndicator
            if assetCollection.assetCollectionType == .smartAlbum && assetCollection.assetCollectionSubtype == .smartAlbumUserLibrary {
                cell.accessibilityIdentifier = "Recent"
            }
            cell.isAccessibilityElement = true
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // First section added for pasteboard?
        var activeSection = indexPath.section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return 44.0
            default:
                activeSection -= 1
            }
        }

        // Display [+] button at the bottom of section presenting a limited number of albums
        if LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums[activeSection] == true &&
            indexPath.row == LocalAlbumsProvider.sharedInstance().maxNberOfAlbumsInSection {
            return 36.0
        }
        
        // Case of an album
        let assetCollection = LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection][indexPath.row]
        if let _ = assetCollection.startDate, let _ = assetCollection.endDate {
            return 53.0
        } else {
            return 44.0
        }
    }

    
    // MARK: - UITableView - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // First section added for pasteboard?
        var activeSection = section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return 0.0
            default:
                activeSection -= 1
            }
        }

        // No footer by default (nil => 0 point)
        let footer = LocalAlbumsProvider.sharedInstance().localAlbumsFooters[activeSection]

        // Footer height?
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: context)

        return ceil(footerRect.size.height + 10.0)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // First section added for pasteboard?
        var activeSection = section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                return nil
            default:
                activeSection -= 1
            }
        }

        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.piwigoFontSmall()
        footerLabel.textColor = UIColor.piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping
        footerLabel.text = LocalAlbumsProvider.sharedInstance().localAlbumsFooters[activeSection]

        // Footer view
        let footer = UIView()
        footer.backgroundColor = UIColor.clear
        footer.addSubview(footerLabel)
        footer.addConstraint(NSLayoutConstraint.constraintView(fromTop: footerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[footer]-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        } else {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[footer]-15-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        }

        return footer
    }


    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // First section added for pasteboard?
        var activeSection = indexPath.section
        if hasImagesInPasteboard {
            switch activeSection {
            case 0:
                let pasteboardImagesSB = UIStoryboard(name: "PasteboardImagesViewController", bundle: nil)
                guard let localImagesVC = pasteboardImagesSB.instantiateViewController(withIdentifier: "PasteboardImagesViewController") as? PasteboardImagesViewController else { return }
                localImagesVC.setCategoryId(categoryId)
                navigationController?.pushViewController(localImagesVC, animated: true)
                return
            default:
                activeSection -= 1
            }
        }

        // Did tap [+] button at the bottom of section —> release remaining albums
        if LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums[activeSection] == true &&
            indexPath.row == LocalAlbumsProvider.sharedInstance().maxNberOfAlbumsInSection {
            // Release album list
            LocalAlbumsProvider.sharedInstance().hasLimitedNberOfAlbums[activeSection] = false
            // Add remaining albums
            let indexPaths: [IndexPath] = Array(LocalAlbumsProvider.sharedInstance().maxNberOfAlbumsInSection+1..<LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection].count).map { IndexPath.init(row: $0, section: activeSection)}
            tableView.insertRows(at: indexPaths, with: .automatic)
            // Replace button
            tableView.reloadRows(at: [indexPath], with: .automatic)
            return
        }
        
        // Case of an album
        let assetCollection = LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[activeSection][indexPath.row]
        let albumID = assetCollection.localIdentifier
        if wantedAction == .setAutoUploadAlbum {
            // Return the selected album ID
            delegate?.didSelectPhotoAlbum(withId: albumID)
            navigationController?.popViewController(animated: true)
        } else {
            // Presents local images of the selected album
            let localImagesSB = UIStoryboard(name: "LocalImagesViewController", bundle: nil)
            guard let localImagesVC = localImagesSB.instantiateViewController(withIdentifier: "LocalImagesViewController") as? LocalImagesViewController else { return }
            localImagesVC.setCategoryId(categoryId)
            localImagesVC.setImageCollectionId(albumID)
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
