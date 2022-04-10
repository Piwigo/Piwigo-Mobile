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
    func didSelectImageDefaultThumbnailSize(_ thumbnailSize: kPiwigoImageSize)
}

class DefaultImageThumbnailSizeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: DefaultImageThumbnailSizeDelegate?
    private var currentThumbnailSize = kPiwigoImageSize(AlbumVars.shared.defaultThumbnailSize)
    
    @IBOutlet var tableView: UITableView!
    

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_images", comment: "Images")

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Return selected image thumbnail size
        delegate?.didSelectImageDefaultThumbnailSize(currentThumbnailSize)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
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
        return Int(kPiwigoImageSizeEnumCount.rawValue)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let imageSize = kPiwigoImageSize(UInt32(indexPath.row))

        // Appearance
        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .piwigoFontNormal()
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
        cell.textLabel?.adjustsFontSizeToFitWidth = false

        // Add checkmark in front of selected item
        if imageSize == currentThumbnailSize {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        // Disable unavailable and useless sizes
        switch imageSize {
        case kPiwigoImageSizeSquare:
            if AlbumVars.shared.hasSquareSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeThumb:
            if AlbumVars.shared.hasThumbSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.shared.hasXXSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.shared.hasXSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.shared.hasSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeMedium:
            if AlbumVars.shared.hasMediumSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = .piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = .piwigoColorRightLabel()
            if !AlbumVars.shared.hasLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeXLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = .piwigoColorRightLabel()
            if !AlbumVars.shared.hasXLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeXXLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = .piwigoColorRightLabel()
            if !AlbumVars.shared.hasXXLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeFullRes:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = .piwigoColorRightLabel()
            cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
        default:
            break
        }

        return cell
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
        if kPiwigoImageSize(UInt32(indexPath.row)) == currentThumbnailSize { return }

        // Update default size
        tableView.cellForRow(at: IndexPath(row: Int(currentThumbnailSize.rawValue), section: 0))?.accessoryType = .none
        currentThumbnailSize = kPiwigoImageSize(UInt32(indexPath.row))
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}
