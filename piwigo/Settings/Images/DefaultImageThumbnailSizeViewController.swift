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

class DefaultImageThumbnailSizeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: DefaultImageThumbnailSizeDelegate?
    private lazy var currentThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
    private lazy var optimumSize = AlbumUtilities.optimumThumbnailSizeForDevice()
    
    @IBOutlet var tableView: UITableView!
    

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("severalImages", comment: "Images")

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
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
        tableView.separatorColor = .piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
    
    
    // MARK: - UITableView - Header
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

    
    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSize.allCases.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let imageSize = pwgImageSize(rawValue: Int16(indexPath.row)) ?? .thumb

        // Appearance
        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
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
            configCell(cell, forSize: .large, available: NetworkVars.shared.hasLargeSizeImages, allowed: false)
        case .xLarge:
            configCell(cell, forSize: .xLarge, available: NetworkVars.shared.hasXLargeSizeImages, allowed: false)
        case .xxLarge:
            configCell(cell, forSize: .xxLarge, available: NetworkVars.shared.hasXXLargeSizeImages, allowed: false)
        case .fullRes:
            configCell(cell, forSize: .fullRes, available: true, allowed: false)
        }

        return cell
    }

    private func configCell(_ cell: UITableViewCell, forSize size: pwgImageSize, available: Bool, allowed: Bool = true) {
        if available {
            // This image size is available
            cell.isUserInteractionEnabled = allowed
            cell.textLabel?.textColor = allowed ? .piwigoColorLeftLabel() : .piwigoColorRightLabel()
            var sizeName = size.name
            if size == optimumSize {
                sizeName.append(contentsOf: NSLocalizedString("defaultImageSize_recommended", comment: " (recommended)"))
            } else {
                sizeName.append(contentsOf: size.sizeAndScale)
            }
            cell.textLabel?.text = sizeName
        } else {
            // This image size is not available
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = .piwigoColorRightLabel()
            cell.textLabel?.text = size.name + NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)")
        }
    }
    
    
    // MARK: - UITableView - Footer
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }

    
    // MARK: - UITableViewDelegate Methods

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
}
