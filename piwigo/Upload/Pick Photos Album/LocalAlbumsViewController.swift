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
class LocalAlbumsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalAlbumsProviderDelegate {

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

    private var cancelBarButton: UIBarButtonItem?

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        title = NSLocalizedString("localAlbums", comment: "Photos library")
        
        // Button for returning to albums/images
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitUpload))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Use the LocalAlbumsProvider to fetch albums data.
        LocalAlbumsProvider.sharedInstance().fetchLocalAlbums {
            self.localAlbumsTableView.reloadData()
        }
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
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = self.localAlbumsTableView.visibleCells.first as? LocalAlbumsTableViewCell {
            if let indexPath = self.localAlbumsTableView.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { context in
                    self.localAlbumsTableView.reloadData()

                    // Scroll to previous position
                    self.localAlbumsTableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                })
            }
        }
    }

    @objc func quitUpload() {
        // Leave Upload action and return to Albums and Images
        dismiss(animated: true)
    }

    deinit {
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
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
        view.layer.zPosition = 0
    }

    
    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsTableViewCell", for: indexPath) as? LocalAlbumsTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a LocalAlbumsTableViewCell!")
            return LocalAlbumsTableViewCell()
        }

        let assetCollection = LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[indexPath.section][indexPath.row]
        let title = assetCollection.localizedTitle ?? "—> ? <——"
        let nberPhotos = assetCollection.estimatedAssetCount
        let startDate = assetCollection.startDate
        let endDate = assetCollection.endDate

        cell.configure(with: title, nberPhotos: nberPhotos, startDate: startDate, endDate: endDate)
        if assetCollection.assetCollectionType == .smartAlbum && assetCollection.assetCollectionSubtype == .smartAlbumGeneric {
            cell.accessibilityIdentifier = "LocalAlbum"
        }
        cell.isAccessibilityElement = true
        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let localImagesSB = UIStoryboard(name: "LocalImagesViewController", bundle: nil)
        let localImagesVC = localImagesSB.instantiateViewController(withIdentifier: "LocalImagesViewController") as? LocalImagesViewController
        localImagesVC?.setCategoryId(categoryId)
        localImagesVC?.setImageCollectionId(LocalAlbumsProvider.sharedInstance().fetchedLocalAlbums[indexPath.section][indexPath.row].localIdentifier)
        if let localImagesVC = localImagesVC {
            navigationController?.pushViewController(localImagesVC, animated: true)
        }
    }

    
    // MARK: - LocalAlbumsProviderDelegate Methods
    
    func didChangePhotoLibrary(section: Int) {
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before updating the UI.
        DispatchQueue.main.sync {
            localAlbumsTableView.reloadSections(IndexSet(integer: section), with: .automatic)
        }
    }
}
