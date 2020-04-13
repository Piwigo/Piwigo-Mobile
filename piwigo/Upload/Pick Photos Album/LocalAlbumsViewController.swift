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
import UIKit

@objc
class LocalAlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PHPhotoLibraryChangeObserver {

    @objc
    func setCategoryId(_ categoryId: Int) {
        _categoryId = categoryId
    }

    @IBOutlet var localAlbumsTableView: UITableView!
    
    private var _categoryId: Int?
    private var categoryId: Int {
        get {
            return _categoryId ?? 0
        }
        set(categoryId) {
            _categoryId = categoryId
        }
    }

    private var localGroups = [PHAssetCollection]()
    private var iCloudGroups = [PHAssetCollection]()
    private var cancelBarButton: UIBarButtonItem?

    func getLocalAlbums() {
        PhotosFetch.sharedInstance().getLocalGroups(onCompletion: { responseObject1, responseObject2 in
            if (responseObject1 is NSNumber) {
                // make view disappear
                self.navigationController?.popToRootViewController(animated: true)
            } else if responseObject1 == nil {
                let alert = UIAlertController(title: NSLocalizedString("localAlbums_photosNiltitle", comment: "Problem Reading Photos"), message: NSLocalizedString("localAlbums_photosNnil_msg", comment: "There is a problem reading your local photo library."), preferredStyle: .alert)

                let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .cancel, handler: { action in
                        // make view disappear
                        self.navigationController?.popViewController(animated: true)
                    })

                alert.addAction(dismissAction)
                alert.view.tintColor = UIColor.piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                self.present(alert, animated: true) {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = UIColor.piwigoColorOrange()
                }
            } else {
                self.localGroups = responseObject1 as! [PHAssetCollection]
                self.iCloudGroups = responseObject2 as! [PHAssetCollection]
                self.localAlbumsTableView?.reloadData()
            }
        })
    }

    
// MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        title = NSLocalizedString("localAlbums", comment: "Photos library")
        
        // Register CategoryTableViewCell
        localAlbumsTableView?.register(CategoryTableViewCell.self, forCellReuseIdentifier: "CategoryTableViewCell")

        // Button for returning to albums/images
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"

        // Get groups of Photos library albums
        getLocalAlbums()
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
        localAlbumsTableView?.separatorColor = UIColor.piwigoColorSeparator()
        localAlbumsTableView?.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        localAlbumsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation bar button and identifier
        navigationItem.setLeftBarButtonItems([cancelBarButton].compactMap { $0 }, animated: true)
        navigationController?.navigationBar.accessibilityIdentifier = "LocalAlbumsNav"
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Do not show title in backButtonItem of child view to provide enough space for title
        // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
        if view.bounds.size.width <= 414 {
            // i.e. smaller than iPhones 6,7 Plus screen width
            title = ""
        }
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    @objc func quitUpload() {
        // Leave Upload action and return to Albums and Images
        dismiss(animated: true)
    }

    
// MARK: - UITableView - Header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Header strings
        var titleString = ""
        var textString = ""
        switch section {
            case 0:
                titleString = "\(NSLocalizedString("categoryUpload_LocalAlbums", comment: "Local Albums"))\n"
                textString = NSLocalizedString("categoryUpload_chooseLocalAlbum", comment: "Select an album to get images from")
            case 1:
                titleString = "\(NSLocalizedString("categoryUpload_iCloudAlbums", comment: "iCloud Albums"))\n"
                textString = NSLocalizedString("categoryUpload_chooseiCloudAlbum", comment: "Select an iCloud album to get images from")
            default:
                break
        }

        // Header height
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)

        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Header strings
        var titleString = ""
        var textString = ""
        switch section {
            case 0:
                titleString = "\(NSLocalizedString("categoryUpload_LocalAlbums", comment: "Local Albums"))\n"
                textString = NSLocalizedString("categoryUpload_chooseLocalAlbum", comment: "Select an album to get images from")
            case 1:
                titleString = "\(NSLocalizedString("categoryUpload_iCloudAlbums", comment: "iCloud Albums"))\n"
                textString = NSLocalizedString("categoryUpload_chooseiCloudAlbum", comment: "Select an iCloud album to get images from")
            default:
                break
        }

        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        headerAttributedString.append(textAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint(item: headerLabel, attribute: .bottom, relatedBy: .equal, toItem: headerLabel.superview, attribute: .bottom, multiplier: 1.0, constant: -4))
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
        view.layer.zPosition = 0
    }

    
// MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1 + (iCloudGroups.count != 0 ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberRows = 0
        switch section {
            case 0:
                nberRows = localGroups.count
            case 1:
                nberRows = iCloudGroups.count
            default:
                break
        }
        return nberRows
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryTableViewCell", for: indexPath) as? CategoryTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a CategoryTableViewCell!")
            return ShareMetadataCell()
        }

        var groupAsset: PHAssetCollection?
        switch indexPath.section {
            case 0:
                groupAsset = localGroups[indexPath.row]
            case 1:
                groupAsset = iCloudGroups[indexPath.row]
            default:
                break
        }
        let name = groupAsset?.localizedTitle
        var nberAssets: Int? = nil
        if let groupAsset = groupAsset {
            nberAssets = PHAsset.fetchAssets(in: groupAsset, options: nil).count
        }
        cell.textLabel?.text = "\(name ?? "") (\(NSNumber(value: nberAssets ?? 0)) \(((nberAssets ?? 0) > 1) ? NSLocalizedString("severalImages", comment: "Photos") : NSLocalizedString("singleImage", comment: "Photo")))"
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.accessoryType = .disclosureIndicator
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.minimumScaleFactor = 0.5
        cell.textLabel?.lineBreakMode = .byTruncatingHead
        if (groupAsset?.assetCollectionType == .smartAlbum) && (groupAsset?.assetCollectionSubtype == .smartAlbumUserLibrary) {
            cell.accessibilityIdentifier = "CameraRoll"
        }

        cell.isAccessibilityElement = true
        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
            case 0:
                let groupAsset = localGroups[indexPath.row]
                if (groupAsset.assetCollectionType == .smartAlbum) && (groupAsset.assetCollectionSubtype == .smartAlbumUserLibrary) {
                    if let uploadVC = CameraRollUploadViewController(categoryId: categoryId) {
                        navigationController?.pushViewController(uploadVC, animated: true)
                    }
                } else {
                    if let uploadVC = AlbumUploadViewController(categoryId: categoryId, andCollection: localGroups[indexPath.row]) {
                        navigationController?.pushViewController(uploadVC, animated: true)
                    }
                }
            case 1:
                if let uploadVC = AlbumUploadViewController(categoryId: categoryId, andCollection: iCloudGroups[indexPath.row]) {
                    navigationController?.pushViewController(uploadVC, animated: true)
            }
            default:
                break
        }
    }

    
// MARK: - Changes occured in the Photo library
    func photoLibraryDidChange(_ changeInfo: PHChange) {
        // Photos may call this method on a background queue;
        // switch to the main queue to update the UI.
        DispatchQueue.main.async(execute: {
            // Collect new list of albums
            self.getLocalAlbums()

            // Refresh list
            self.localAlbumsTableView?.reloadData()
        })
    }
}
