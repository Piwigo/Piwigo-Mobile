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


extension DefaultAlbumThumbnailSizeViewController: UITableViewDataSource {
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSize.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let imageSize = pwgImageSize(rawValue: Int16(indexPath.row)) ?? .medium

        // Name of the thumbnail size
        cell.backgroundColor = PwgColor.cellBackground
        cell.tintColor = PwgColor.orange
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.adjustsFontSizeToFitWidth = false

        // Add checkmark in front of selected item
        if imageSize == currentThumbnailSize {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        // Disable unavailable and useless sizes
        switch imageSize {
        case .square:
            configCell(cell, forSize: .square, available: NetworkVars.shared.hasSquareSizeImages)
        case .thumb:
            configCell(cell, forSize: .thumb, available: NetworkVars.shared.hasThumbSizeImages)
        case .xxSmall:
            configCell(cell, forSize: .xxSmall, available: NetworkVars.shared.hasXXSmallSizeImages)
        case .xSmall:
            configCell(cell, forSize: .xSmall, available: NetworkVars.shared.hasXSmallSizeImages)
        case .small:
            configCell(cell, forSize: .small, available: NetworkVars.shared.hasSmallSizeImages)
        case .medium:
            configCell(cell, forSize: .medium, available: NetworkVars.shared.hasMediumSizeImages)
        case .large:
            configCell(cell, forSize: .large, available: NetworkVars.shared.hasLargeSizeImages)
        case .xLarge:
            configCell(cell, forSize: .xLarge, available: NetworkVars.shared.hasXLargeSizeImages)
        case .xxLarge:
            configCell(cell, forSize: .xxLarge, available: NetworkVars.shared.hasXXLargeSizeImages)
        case .fullRes:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = PwgColor.rightLabel
            cell.textLabel?.text = imageSize.name
        }

        return cell
    }
    
    private func configCell(_ cell: UITableViewCell, forSize size: pwgImageSize, available: Bool) {
        if available {
            cell.isUserInteractionEnabled = true
            cell.textLabel?.textColor = PwgColor.leftLabel
            var sizeName = size.name
            if size == optimumSize {
                sizeName.append(contentsOf: NSLocalizedString("defaultImageSize_recommended", comment: " (recommended)"))
            } else {
                sizeName.append(contentsOf: size.sizeAndScale(forScale: scale))
            }
            cell.textLabel?.text = sizeName
        } else {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = PwgColor.rightLabel
            cell.textLabel?.text = size.name + NSLocalizedString("defaultSize_disabled",comment: " (disabled on server)")
       }
    }
}


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
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TableViewUtilities.rowHeight
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
