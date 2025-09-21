//
//  DefaultImageThumbnailSizeViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/06/2017.
//  Copyright © 2017 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 05/04/2020.
//

import UIKit
import piwigoKit

protocol DefaultImageThumbnailSizeDelegate: NSObjectProtocol {
    func didSelectImageDefaultThumbnailSize(_ thumbnailSize: pwgImageSize)
}

class DefaultImageThumbnailSizeViewController: UIViewController {
    
    weak var delegate: DefaultImageThumbnailSizeDelegate?
    private lazy var currentThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
    private lazy var optimumSize = AlbumUtilities.optimumThumbnailSizeForDevice()
    private lazy var scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
    
    @IBOutlet var tableView: UITableView!
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("severalImages", comment: "Images")

        // Table view
        tableView?.accessibilityIdentifier = "Image Thumbnail Size"
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
        
        // Return selected image thumbnail size
        delegate?.didSelectImageDefaultThumbnailSize(currentThumbnailSize)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension DefaultImageThumbnailSizeViewController: UITableViewDataSource {
    
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
        let imageSize = pwgImageSize(rawValue: Int16(indexPath.row)) ?? .thumb
        let isSelected = imageSize == currentThumbnailSize

        // Disable unavailable and useless sizes
        switch imageSize {
        case .square, .thumb, .xxSmall, .xSmall, .small, .medium:
            configCell(cell, forSize: imageSize, selectable: true, selected: isSelected)
        case .large, .xLarge, .xxLarge, .fullRes:
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
extension DefaultImageThumbnailSizeViewController: UITableViewDelegate {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("defaultThumbnailFile>414px", comment: "Images Thumbnail File"))
        let text = NSLocalizedString("defaultThumbnailSizeHeader", comment: "Please select an image thumbnail size")
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
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TableViewUtilities.shared.rowHeight(forContentSizeCategory: traitCollection.preferredContentSizeCategory)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change of default size
        guard let selectedSize = pwgImageSize(rawValue: Int16(indexPath.row)) else { return }
        if selectedSize == currentThumbnailSize { return }

        // Update default size
        tableView.cellForRow(at: IndexPath(row: Int(currentThumbnailSize.rawValue), section: 0))?.accessoryType = .none
        currentThumbnailSize = selectedSize
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
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
