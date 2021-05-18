//
//  AutoUploadViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@objc
class AutoUploadViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsSelectorDelegate, SelectCategoryDelegate, TagsViewControllerDelegate, UITextViewDelegate {

    @IBOutlet var autoUploadTableView: UITableView!
    
    // MARK: - Core Data
    /**
     The TagsProvider that fetches tag data, saves it to Core Data,
     and serves it to this table view.
     */
    private lazy var tagsProvider: TagsProvider = {
        let provider : TagsProvider = TagsProvider()
        return provider
    }()
    
    let hasTagCreationRights:Bool = {
        // Admin?
        if Model.sharedInstance()?.hasAdminRights == true { return true }
        // Community user with upload rights?
        if let albumId = Model.sharedInstance()?.autoUploadCategoryId,
           let albumData = CategoriesData.sharedInstance().getCategoryById(albumId),
           (Model.sharedInstance().hasNormalRights && albumData.hasUploadRights) { return true }
        return false
    }()


    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        autoUploadTableView.separatorColor = UIColor.piwigoColorSeparator()
        autoUploadTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        autoUploadTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)

        // Pause UploadManager while changing settings
        UploadManager.shared.isPaused = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Check if the user is going to select a local album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC.isKind(of: LocalAlbumsViewController.self) { return }
            
        // Check if the user is going to select a Piwigo album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC.isKind(of: SelectCategoryViewController.self) { return }

        // Check if the user is going to select/deselect tags
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC.isKind(of: TagsViewController.self) { return }

        // Restart UploadManager activities
        if UploadManager.shared.isPaused {
            UploadManager.shared.isPaused = false
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.findNextImageToUpload()
            }
        }
    }


    // MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString: String
        switch section {
        case 0:
            titleString = NSLocalizedString("settings_autoUpload>414px", comment: "Auto Upload Photos")
        case 1:
            titleString = NSLocalizedString("tabBar_albums", comment: "Albums")
        case 2:
            titleString = NSLocalizedString("imageDetailsView_title", comment: "Properties")
        default:
            titleString = ""
        }
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(fmax(44.0, titleRect.size.height))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Title
        let titleString: String
        switch section {
        case 0:
            titleString = NSLocalizedString("settings_autoUpload>414px", comment: "Auto Upload Photos")
        case 1:
            titleString = NSLocalizedString("tabBar_albums", comment: "Albums")
        case 2:
            titleString = NSLocalizedString("imageDetailsView_title", comment: "Properties")
        default:
            titleString = ""
        }
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
        header.backgroundColor = UIColor.clear
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
            cell.cellSwitch.setOn(Model.sharedInstance().isAutoUploadActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Enable/disable auto-upload option
                UploadManager.shared.backgroundQueue.async {
                    if switchState {
                        // Enable auto-uploading
                        Model.sharedInstance().isAutoUploadActive = true
                        Model.sharedInstance().saveToDisk()
                        UploadManager.shared.appendAutoUploadRequests()
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
                if let collectionID = Model.sharedInstance()?.autoUploadAlbumId, !collectionID.isEmpty,
                   let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject {
                    detail = collection.localizedTitle ?? ""
                } else {
                    // Did not find the Photo Library album
                    Model.sharedInstance()?.autoUploadAlbumId = ""
                    Model.sharedInstance()?.isAutoUploadActive = false
                    Model.sharedInstance()?.saveToDisk()
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell

            case 1 /* Select Piwigo album*/ :
                title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
                if let categoryId = Model.sharedInstance()?.autoUploadCategoryId,
                   let albumData = CategoriesData.sharedInstance().getCategoryById(categoryId) {
                    detail = albumData.name ?? ""
                } else {
                    // Did not find the Piwigo album
                    Model.sharedInstance()?.autoUploadCategoryId = NSNotFound
                    Model.sharedInstance()?.isAutoUploadActive = false
                    Model.sharedInstance()?.saveToDisk()
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
                let tags = tagsProvider.fetchedResultsController.fetchedObjects
                let tagIds = Model.sharedInstance()?.autoUploadTagIds.components(separatedBy: ",").map({ Int32($0) }) ?? []
                var tagList = [PiwigoTagData]()
                tagIds.forEach({ tagId in
                    if let id = tagId,
                       let tag = tags?.first(where: { $0.tagId == id }) {
                        let newTag = PiwigoTagData.init()
                        newTag.tagId = Int(tag.tagId)
                        newTag.tagName = tag.tagName
                        newTag.lastModified = tag.lastModified
                        newTag.numberOfImagesUnderTag = tag.numberOfImagesUnderTag
                        tagList.append(newTag)
                    }
                })
                cell.setTagList(tagList, in: UIColor.piwigoColorRightLabel())
                tableViewCell = cell

            case 1 /* Comments */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
                    return EditImageTextViewTableViewCell()
                }
                cell.setComment(Model.sharedInstance()?.autoUploadComments ?? "", in:UIColor.piwigoColorRightLabel())
                cell.textView.delegate = self
                tableViewCell = cell

            default:
                break
            }

        default:
            break
        }

        tableViewCell.backgroundColor = UIColor.piwigoColorCellBackground()
        tableViewCell.tintColor = UIColor.piwigoColorOrange()
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
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // No footer by default (nil => 0 point)
        var footer = ""

        // Any footer text?
        switch section {
        case 0:
            if Model.sharedInstance().isAutoUploadActive {
                if Model.sharedInstance().serverFileTypes.contains("mp4") {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfoAll", comment: "Photos and videos will be automatically uploaded to your Piwigo.")
                } else {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfo", comment: "Photos will be automatically uploaded to your Piwigo.")
                }
            } else {
                footer = NSLocalizedString("settings_autoUploadDisabledInfo", comment: "Photos will not be automatically uploaded to your Piwigo.")
            }
        default:
            return 16.0
        }

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
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.piwigoFontSmall()
        footerLabel.textColor = UIColor.piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping

        // Any footer text?
        switch section {
        case 0:
            if Model.sharedInstance().isAutoUploadActive {
                if Model.sharedInstance().serverFileTypes.contains("mp4") {
                    footerLabel.text = NSLocalizedString("settings_autoUploadEnabledInfoAll", comment: "Photos and videos will be automatically uploaded to your Piwigo.")
                } else {
                    footerLabel.text = NSLocalizedString("settings_autoUploadEnabledInfo", comment: "Photos will be automatically uploaded to your Piwigo.")
                }
            } else {
                footerLabel.text = NSLocalizedString("settings_autoUploadDisabledInfo", comment: "Photos will not be automatically uploaded to your Piwigo.")
            }
        default:
            break
        }

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
        
        switch indexPath.section {
        case 1:
            switch indexPath.row {
            case 0 /* Select Photos Library album */ :
                // Check autorisation to access Photo Library before uploading
                if #available(iOS 14, *) {
                    PhotosFetch.sharedInstance().checkPhotoLibraryAuthorizationStatus(for: .readWrite, for: self) {
                        // Open local albums view controller
                        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewControllerGrouped", bundle: nil)
                        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewControllerGrouped") as? LocalAlbumsViewController else { return }
                        localAlbumsVC.setCategoryId(NSNotFound)
                        localAlbumsVC.delegate = self
                        self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                    } onDeniedAccess: {
                        PhotosFetch.sharedInstance().requestPhotoLibraryAccess(in: self)
                    }
                } else {
                    // Fallback on earlier versions
                    PhotosFetch.sharedInstance().checkPhotoLibraryAccessForViewController(self) {
                        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewControllerGrouped", bundle: nil)
                        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewControllerGrouped") as? LocalAlbumsViewController else { return }
                        localAlbumsVC.setCategoryId(NSNotFound)
                        localAlbumsVC.delegate = self
                        self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                    } onDeniedAccess: {
                        PhotosFetch.sharedInstance().requestPhotoLibraryAccess(in: self)
                    }
                }

            case 1 /* Select Piwigo album*/ :
                let categorySB = UIStoryboard(name: "SelectCategoryViewControllerGrouped", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewControllerGrouped") as? SelectCategoryViewController else { return }
                categoryVC.setInput(parameter: Model.sharedInstance()?.autoUploadCategoryId ?? NSNotFound,
                                    for: kPiwigoCategorySelectActionSetAutoUploadAlbum)
                categoryVC.delegate = self
                navigationController?.pushViewController(categoryVC, animated: true)

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
                    tagsVC.setPreselectedTagIds((Model.sharedInstance()?.autoUploadTagIds ?? "")
                                                    .components(separatedBy: ",")
                                                    .map { Int32($0) ?? nil }.compactMap {$0})
                    let tagCreationRights = (Model.sharedInstance()?.hasAdminRights ?? false) ||
                        ((Model.sharedInstance()?.hasNormalRights ?? false) && (Model.sharedInstance()?.usesCommunityPluginV29 ?? false))
                    tagsVC.setTagCreationRights(tagCreationRights)
                    navigationController?.pushViewController(tagsVC, animated: true)
                }

            default:
                break
            }
            
        default:
            break
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
            Model.sharedInstance()?.autoUploadAlbumId = ""
            Model.sharedInstance()?.isAutoUploadActive = false
        } else if photoAlbumId != Model.sharedInstance()?.autoUploadAlbumId {
            // Did select another album
            Model.sharedInstance()?.autoUploadAlbumId = photoAlbumId
            Model.sharedInstance()?.isAutoUploadActive = false
        }
        
        // Save choice
        Model.sharedInstance()?.saveToDisk()
    }
}


// MARK: - SelectCategoryDelegate Methods

extension AutoUploadViewController {
    // Collect chosen Piwigo category
    func didSelectCategory(withId categoryId: Int) -> Void {
        // Check selection
        if categoryId == NSNotFound {
            // Did not select a Piwigo album
            Model.sharedInstance()?.autoUploadCategoryId = NSNotFound
            Model.sharedInstance()?.isAutoUploadActive = false
        } else if categoryId != Model.sharedInstance()?.autoUploadCategoryId {
            // Did select another category
            Model.sharedInstance()?.autoUploadCategoryId = categoryId
            Model.sharedInstance()?.isAutoUploadActive = false
        }
        
        // Save choice
        Model.sharedInstance()?.saveToDisk()
    }
}


// MARK: - TagsViewControllerDelegate Methods

extension AutoUploadViewController {
    // Collect selected tags
    func didSelectTags(_ selectedTags: [Tag]) {
        // Store selected tags
        Model.sharedInstance()?.autoUploadTagIds = String(selectedTags.map({"\($0.tagId),"})
                                                            .reduce("", +).dropLast(1))
        Model.sharedInstance()?.saveToDisk()

        // Update cell
        autoUploadTableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .automatic)
    }
}


// MARK: - UITextViewDelegate Methods

extension AutoUploadViewController {
    // Update comments and store them
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        Model.sharedInstance()?.autoUploadComments = finalString
        Model.sharedInstance()?.saveToDisk()
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        autoUploadTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        Model.sharedInstance()?.autoUploadComments = textView.text
        Model.sharedInstance()?.saveToDisk()
    }
}
