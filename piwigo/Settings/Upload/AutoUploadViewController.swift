//
//  AutoUploadViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit

class AutoUploadViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsSelectorDelegate, SelectCategoryDelegate, TagsViewControllerDelegate, UITextViewDelegate {

    @IBOutlet var autoUploadTableView: UITableView!
    
    var user: User!
    var albumProvider: AlbumProvider!
    lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        return provider
    }()
    var savingContext: NSManagedObjectContext!

    private lazy var hasTagCreationRights: Bool = {
        // Depends on the user's rights
        switch NetworkVars.userStatus {
        case .guest, .generic:
            return false
        case .admin, .webmaster:
            return true
        case .normal:
            // Community user with upload rights?
            if user.uploadRights.components(separatedBy: ",")
                .contains(String(UploadVars.autoUploadCategoryId)) {
                return true
            }
        }
        return false
    }()


    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
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
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        autoUploadTableView.separatorColor = .piwigoColorSeparator()
        autoUploadTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        autoUploadTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)

        // Register auto-upload option disabler
        NotificationCenter.default.addObserver(self, selector: #selector(disableAutoUpload),
                                               name: .pwgAutoUploadChanged, object: nil)
        
        // Pause UploadManager while changing settings
        UploadManager.shared.isPaused = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Check if the user is going to select a local album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is LocalAlbumsViewController { return }
            
        // Check if the user is going to select a Piwigo album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is SelectCategoryViewController { return }

        // Check if the user is going to select/deselect tags
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is TagsViewController { return }

        // Restart UploadManager activities
        if UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
        
        // Unregister auto-upload option disabler
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> String {
        var title = ""
        switch section {
        case 0:
            title = NSLocalizedString("settings_autoUpload>414px", comment: "Auto Upload Photos")
        case 1:
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        case 2:
            title = NSLocalizedString("imageDetailsView_title", comment: "Properties")
        default:
            title = ""
        }
        return title
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title)
    }


    // MARK: - UITableView - Rows
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        case 2:
            return 2
        default:
            fatalError("Unknown section")
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 44.0
        switch indexPath.section {
        case 2:
            switch indexPath.row {
            case 0:
                height = 78.0
            case 1:
                height = 428.0
            default:
                break
            }
        default:
            break
        }
        return height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        
        switch indexPath.section {
        case 0:     // Auto-Upload On/Off
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            let title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
            cell.configure(with: title)
            cell.cellSwitch.setOn(UploadVars.isAutoUploadActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Enable/disable auto-upload option
                UploadManager.shared.backgroundQueue.async {
                    if switchState {
                        // Enable auto-uploading
                        UploadVars.isAutoUploadActive = true
                        UploadManager.shared.appendAutoUploadRequests()
                        // Update Settings tableview
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .pwgAutoUploadChanged, object: nil, userInfo: nil)
                        }
                    } else {
                        // Disable auto-uploading
                        UploadManager.shared.disableAutoUpload()
                    }
                }
            }
            tableViewCell = cell
            
        case 1:     // Source & destination albums
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a LabelTableViewCell!")
                return LabelTableViewCell()
            }
            
            var title = "", detail = ""
            switch indexPath.row {
            case 0 /* Select Photos Library album */ :
                title = NSLocalizedString("settings_autoUploadSource", comment: "Source")
                let collectionID = UploadVars.autoUploadAlbumId
                if collectionID.isEmpty == false,
                   let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject {
                    detail = collection.localizedTitle ?? ""
                } else {
                    // Did not find the Photo Library album
                    UploadVars.autoUploadAlbumId = ""
                    UploadVars.isAutoUploadActive = false
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell

            case 1 /* Select Piwigo album*/ :
                title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
                let categoryId = UploadVars.autoUploadCategoryId
                if let albumData = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
                    detail = albumData.name
                } else {
                    // Did not find the Piwigo album
                    UploadVars.autoUploadCategoryId = Int32.min
                    UploadVars.isAutoUploadActive = false
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell
            default:
                break
            }
            cell.configure(with: title, detail: detail)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            tableViewCell = cell

        case 2:     // Properties
            switch indexPath.row {
            case 0 /* Tags */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
                    return EditImageTagsTableViewCell()
                }
                // Retrieve tags and switch to old cache data format
                let tags = tagProvider.getTags(withIDs: UploadVars.autoUploadTagIds, taskContext: savingContext)
                cell.config(withList: tags, inColor: UIColor.piwigoColorRightLabel())
                tableViewCell = cell

            case 1 /* Comments */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
                    return EditImageTextViewTableViewCell()
                }
                cell.config(withText: NSAttributedString(string: UploadVars.autoUploadComments),
                            inColor: UIColor.piwigoColorRightLabel())
                cell.textView.delegate = self
                tableViewCell = cell

            default:
                break
            }

        default:
            break
        }

        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()
        return tableViewCell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0:
            return false
        case 2:
            switch indexPath.row {
            case 1:
                return false
            default:
                break
            }
        default:
            return true
        }
        return true
    }
    
    
    // MARK: - UITableView - Footer
    private func getContentOfFooter(inSection section: Int) -> String {
        var footer = ""
        switch section {
        case 0:
            if UploadVars.isAutoUploadActive {
                if UploadVars.serverFileTypes.contains("mp4") {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfoAll", comment: "Photos and videos will be automatically uploaded to your Piwigo.")
                } else {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfo", comment: "Photos will be automatically uploaded to your Piwigo.")
                }
            } else {
                footer = NSLocalizedString("settings_autoUploadDisabledInfo", comment: "Photos will not be automatically uploaded to your Piwigo.")
            }
        default:
            footer = " "
        }
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 1:
            switch indexPath.row {
            case 0 /* Select Photos Library album */ :
                // Check autorisation to access Photo Library before uploading
                if #available(iOS 14, *) {
                    PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: .readWrite, for: self) {
                        // Open local albums view controller
                        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
                        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController else { return }
                        localAlbumsVC.categoryId = Int32.min
                        localAlbumsVC.userHasUploadRights = false
                        localAlbumsVC.delegate = self
                        self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                    } onDeniedAccess: {
                        PhotosFetch.shared.requestPhotoLibraryAccess(in: self)
                    }
                } else {
                    // Fallback on earlier versions
                    PhotosFetch.shared.checkPhotoLibraryAccessForViewController(self) {
                        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
                        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController else { return }
                        localAlbumsVC.categoryId = Int32.min
                        localAlbumsVC.userHasUploadRights = false
                        localAlbumsVC.delegate = self
                        self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                    } onDeniedAccess: {
                        PhotosFetch.shared.requestPhotoLibraryAccess(in: self)
                    }
                }

            case 1 /* Select Piwigo album*/ :
                let categorySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
                categoryVC.albumProvider = albumProvider
                categoryVC.savingContext = savingContext
                if categoryVC.setInput(parameter: UploadVars.autoUploadCategoryId,
                                       for: .setAutoUploadAlbum) {
                    categoryVC.delegate = self
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
                
            default:
                break
            }
            
        case 2:
            switch indexPath.row {
            case 0 /* Select Tags */ :
                // Create view controller
                let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
                if let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController {
                    tagsVC.delegate = self
                    tagsVC.savingContext = savingContext
                    tagsVC.setPreselectedTagIds(Set(UploadVars.autoUploadTagIds
                                                        .components(separatedBy: ",")
                                                        .map { Int32($0) ?? nil }.compactMap {$0}))
                    tagsVC.setTagCreationRights(hasTagCreationRights)
                    navigationController?.pushViewController(tagsVC, animated: true)
                }

            default:
                break
            }
            
        default:
            break
        }
    }
    
    
    // MARK: - Auto-Upload option disabled during execution
    
    @objc func disableAutoUpload(_ notification: Notification) {
        // Change switch button state
        autoUploadTableView?.reloadSections(IndexSet(integer: 0), with: .automatic)
        
        // Inform user if an error was reported
        if let title = notification.userInfo?["title"] as? String, title.isEmpty == false,
           let message = notification.userInfo?["message"] as? String {
            dismissPiwigoError(withTitle: title, message: message) { }
        }
    }
}


// MARK: - LocalAlbumsViewControllerDelegate Methods

extension AutoUploadViewController {
    // Collect cosen Photo Library album (or whole Camera Roll)
    func didSelectPhotoAlbum(withId photoAlbumId: String) -> Void {
        // Check selection
        if photoAlbumId.isEmpty {
            // Did not select a Photo Library album
            UploadVars.autoUploadAlbumId = ""
            UploadVars.isAutoUploadActive = false
        } else if photoAlbumId != UploadVars.autoUploadAlbumId {
            // Did select another album
            UploadVars.autoUploadAlbumId = photoAlbumId
            UploadVars.isAutoUploadActive = false
        }
    }
}


// MARK: - SelectCategoryDelegate Methods

extension AutoUploadViewController {
    // Collect chosen Piwigo category
    func didSelectCategory(withId categoryId: Int32) -> Void {
        // Check selection
        if categoryId == Int32.min {
            // Did not select a Piwigo album
            UploadVars.autoUploadCategoryId = Int32.min
            UploadVars.isAutoUploadActive = false
        } else if categoryId != UploadVars.autoUploadCategoryId {
            // Did select another category
            UploadVars.autoUploadCategoryId = categoryId
            UploadVars.isAutoUploadActive = false
        }
    }
}


// MARK: - TagsViewControllerDelegate Methods

extension AutoUploadViewController {
    // Collect selected tags
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Store selected tags
        UploadVars.autoUploadTagIds = String(selectedTags.map({"\($0.tagId),"})
                                                        .reduce("", +).dropLast(1))

        // Update cell
        autoUploadTableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .automatic)
    }
}


// MARK: - UITextViewDelegate Methods

extension AutoUploadViewController {
    // Update comments and store them
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        UploadVars.autoUploadComments = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        autoUploadTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        UploadVars.autoUploadComments = textView.text
    }
}
