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
class AutoUploadViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsSelectorDelegate, SelectCategoryDelegate {

    @IBOutlet var autoUploadTableView: UITableView!
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        return provider
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
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        default:
            fatalError("Unknown section")
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        
        switch indexPath.section {
        case 0:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            let title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
            cell.configure(with: title)
            cell.cellSwitch.setOn(Model.sharedInstance().isAutoUploadActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Enable/disable auto-upload option
                if switchState {
                    self.enableAutoUpload()
                } else {
                    self.disableAutoUpload()
                }
            }
            tableViewCell = cell
            
        case 1:
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

        default:
            break
        }
        return tableViewCell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0:
            return false
        default:
            return true
        }
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
                    } onDeniedAccess: { }
                } else {
                    // Fallback on earlier versions
                    PhotosFetch.sharedInstance().checkPhotoLibraryAccessForViewController(self) {
                        let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewControllerGrouped", bundle: nil)
                        guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewControllerGrouped") as? LocalAlbumsViewController else { return }
                        localAlbumsVC.setCategoryId(NSNotFound)
                        localAlbumsVC.delegate = self
                        self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                    } onDeniedAccess: { }
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
            
        default:
            break
        }
    }


    // MARK: - LocalAlbumsViewControllerDelegate Methods
    func didSelectPhotoAlbum(withId photoAlbumId: String) -> Void {
        Model.sharedInstance()?.autoUploadAlbumId = photoAlbumId
        Model.sharedInstance()?.saveToDisk()
    }


    // MARK: - SelectCategoryDelegate Methods
    func didSelectCategory(withId categoryId: Int) -> Void {
        if categoryId == NSNotFound { return }
        // Save new choice
        Model.sharedInstance()?.autoUploadCategoryId = categoryId
        Model.sharedInstance()?.saveToDisk()
    }


    // MARK: - Auto-Upload Request Management
    
    private func enableAutoUpload() {
        // Check access Photo Library album
        guard let collectionID = Model.sharedInstance()?.autoUploadAlbumId, !collectionID.isEmpty,
           let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject else {
            // Cannot access local album
            let title = NSLocalizedString("settings_autoUploadSourceInvalid", comment:"Invalid source album")
            let message = NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album from which photos and videos of your device will be auto-uploaded.")
            self.showError(withTitle: title, message: message) {
                self.disableAutoUpload()
            }
            return
        }

        // Check existence of Piwigo album
        guard let categoryId = Model.sharedInstance()?.autoUploadCategoryId, categoryId != NSNotFound else {
            // Cannot access local album
            let title = NSLocalizedString("settings_autoUploadDestinationInvalid", comment:"Invalid destination album")
            let message = NSLocalizedString("settings_autoUploadSourceInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded.")
            self.showError(withTitle: title, message: message) {
                self.disableAutoUpload()
            }
            return
        }
        
        // Collect IDs of images to upload
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchedImages = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        if fetchedImages.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }
        
        // Collect IDs of images already considered for upload
        guard let uploadIds = uploadsProvider.fetchedResultsController
                .fetchedObjects?.map({ $0.localIdentifier }) else {
            // Could not retrieve uploads
            return
        }
        
        // Determine which local images are still not considered for upload
        var imagesToUpload = [UploadProperties]()
        fetchedImages.enumerateObjects { image, idx, stop in
            if !uploadIds.contains(image.localIdentifier) {
                var uploadRequest = UploadProperties(localIdentifier: image.localIdentifier,
                                                     category: categoryId)
                // Image parameters
                if let author = Model.sharedInstance()?.defaultAuthor {
                    uploadRequest.author = author
                }
                if let privacy = Model.sharedInstance()?.defaultPrivacyLevel {
                    uploadRequest.privacyLevel = privacy
                }

                // Upload settings
                if let stripGPSdataOnUpload = Model.sharedInstance()?.stripGPSdataOnUpload {
                    uploadRequest.stripGPSdataOnUpload = stripGPSdataOnUpload
                }
                if let resizeImageOnUpload = Model.sharedInstance()?.resizeImageOnUpload {
                    uploadRequest.resizeImageOnUpload = resizeImageOnUpload
                    if resizeImageOnUpload {
                        if let photoResize = Model.sharedInstance()?.photoResize {
                            uploadRequest.photoResize = Int16(photoResize)
                        }
                    } else {
                        uploadRequest.photoResize = 100
                    }
                }
                if let compressImageOnUpload = Model.sharedInstance()?.compressImageOnUpload {
                    uploadRequest.compressImageOnUpload = compressImageOnUpload
                }
                if let photoQuality = Model.sharedInstance()?.photoQuality {
                    uploadRequest.photoQuality = Int16(photoQuality)
                }
                if let prefixFileNameBeforeUpload = Model.sharedInstance()?.prefixFileNameBeforeUpload {
                    uploadRequest.prefixFileNameBeforeUpload = prefixFileNameBeforeUpload
                }
                if let defaultPrefix = Model.sharedInstance()?.defaultPrefix {
                    uploadRequest.defaultPrefix = defaultPrefix
                }
                if let deleteImageAfterUpload = Model.sharedInstance()?.deleteImageAfterUpload {
                    uploadRequest.deleteImageAfterUpload = deleteImageAfterUpload
                }
                uploadRequest.markedForAutoUpload = true
                imagesToUpload.append(uploadRequest)
            }
        }
        if imagesToUpload.count == 0 {
            // Nothing to add to the upload queue - Job done
            return
        }

        // Append local images to upload queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.uploadsProvider.importUploads(from: imagesToUpload.compactMap{ $0 }) { error in
                // Show an alert if there was an error.
                guard let error = error else {
                    // Auto-upload mode enabled
                    Model.sharedInstance().isAutoUploadActive = true
                    Model.sharedInstance().saveToDisk()
                    
                    // Refresh cell
                    DispatchQueue.main.async {
                        self.autoUploadTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                    }

                    // Restart UploadManager activities
                    if UploadManager.shared.isPaused {
                        UploadManager.shared.isPaused = false
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.findNextImageToUpload()
                        }
                    }
                    return
                }
                
                // Inform user
                DispatchQueue.main.async {
                    let title = NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object.")
                    self.showError(withTitle: title, message: error.localizedDescription) {
                        DispatchQueue.global(qos: .userInteractive).async {
                            // Disable auto-uploading
                            self.disableAutoUpload()
                        }
                    }
                }
            }
        }
    }
    
    private func disableAutoUpload() {
        // Disable auto-uploading
        Model.sharedInstance().isAutoUploadActive = false
        Model.sharedInstance().saveToDisk()
        autoUploadTableView.reloadSections(IndexSet(integer: 0), with: .automatic)

        // Collect upload requests of images considered for auto-upload
        guard let uploads = uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects?
                .filter({ $0.markedForAutoUpload == true})
                .map({ $0.objectID }) else {
            // Could not retrieve uploads
            
            return
        }
        if uploads.count == 0 {
            // Nothing to remove from the upload queue - Job done
            return
        }
        
        // Remove upload requests marked for auto-upload from the upload queue
        uploadsProvider.delete(uploadRequests: uploads)
    }
    
    private func showError(withTitle title: String, message: String,
                           completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"),
                                          style: .default, handler: { _ in completion() } ))
            alert.view.tintColor = UIColor.piwigoColorOrange()
            if #available(iOS 13.0, *) {
                alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
            } else {
                // Fallback on earlier versions
            }
            self.present(alert, animated: true, completion: {
                // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                alert.view.tintColor = UIColor.piwigoColorOrange()
            })
        }
    }
}
