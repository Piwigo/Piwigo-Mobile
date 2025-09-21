//
//  DefaultAlbumThumbnailSizeViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/08/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit
import piwigoKit

protocol DefaultAlbumThumbnailSizeDelegate: NSObjectProtocol {
    func didSelectAlbumDefaultThumbnailSize(_ thumbnailSize: pwgImageSize)
}

class DefaultAlbumThumbnailSizeViewController: UIViewController {
    
    weak var delegate: DefaultAlbumThumbnailSizeDelegate?
    private lazy var currentThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
    private lazy var optimumSize = AlbumUtilities.optimumAlbumThumbnailSizeForDevice()
    private lazy var scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
    
    @IBOutlet var tableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")

        // Table view
        tableView?.accessibilityIdentifier = "Album Thumbnail Size"
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "Settings Bar"
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        tableView.separatorColor = PwgColor.separator
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Return selected album thumbnail size
        delegate?.didSelectAlbumDefaultThumbnailSize(currentThumbnailSize)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension DefaultAlbumThumbnailSizeViewController: UITableViewDataSource {
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSize.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
            ? "LabelTableViewCell"
            : "LabelTableViewCell2"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }

        // Add checkmark in front of selected item
        let imageSize = pwgImageSize(rawValue: Int16(indexPath.row)) ?? .medium
        let isSelected = imageSize == currentThumbnailSize

        // Disable unavailable and useless sizes
        switch imageSize {
        case .square, .thumb, .xxSmall, .xSmall, .small, .medium, .large, .xLarge, .xxLarge:
            configCell(cell, forSize: imageSize, selectable: true, selected: isSelected)
        case .fullRes:
            configCell(cell, forSize: imageSize, selectable: false)
        }
        return cell
    }
    
    private func configCell(_ cell: LabelTableViewCell, forSize size: pwgImageSize,
                            selectable: Bool, selected: Bool = false) {
        // Selected?
        cell.accessoryType = selected ? .checkmark : .none
        
        // Available?
        guard size.isAvailable
        else {
            cell.configure(with: size.name, detail: " ")
            cell.titleLabel.textColor = cell.detailLabel.textColor
            cell.isUserInteractionEnabled = false
            return
        }
        
        // Optimum?
        if size == optimumSize {
            let detail = NSLocalizedString("defaultImageSize_recommended", comment: "(recommended)")
            cell.configure(with: size.name, detail: detail)
        } else {
            cell.configure(with: size.name, detail: size.sizeAndScale(forScale: scale))
        }
        
        // Selectable?
        cell.isUserInteractionEnabled = selectable
        if selectable == false {
            // Colour must be changed after configuration
            cell.titleLabel.textColor = cell.detailLabel.textColor
        }
    }
}


// MARK: - UITableViewDelegate Methods
extension DefaultAlbumThumbnailSizeViewController: UITableViewDelegate {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("defaultAlbumThumbnailFile>414px", comment: "Albums Thumbnail File"))
        let text = NSLocalizedString("defaultAlbumThumbnailSizeHeader", comment: "Please select an album thumbnail size")
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change of default size
        guard let selectedSize = pwgImageSize(rawValue: Int16(indexPath.row)) else { return }
        if selectedSize == currentThumbnailSize { return }

        // Update deslected cell
        let selectable = currentThumbnailSize != .fullRes
        let deselectedIndexPath = IndexPath(row: Int(currentThumbnailSize.rawValue), section: 0)
        if let cell = tableView.cellForRow(at: deselectedIndexPath) as? LabelTableViewCell {
            configCell(cell, forSize: currentThumbnailSize, selectable: selectable, selected: false)
        }
        
        // Update selected cell
        currentThumbnailSize = selectedSize
        if let cell = tableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            configCell(cell, forSize: currentThumbnailSize, selectable: selectable, selected: true)
        }
    }

    
    // MARK: - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }
}
