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
    private var currentThumbnailSize = kPiwigoImageSize(AlbumVars.defaultThumbnailSize)
    
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
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        tableView.separatorColor = UIColor.piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
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
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        // Title
        let titleString = "\(NSLocalizedString("defaultThumbnailFile>414px", comment: "Images Thumbnail File"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("defaultThumbnailSizeHeader", comment: "Please select an image thumbnail size")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("defaultThumbnailFile>414px", comment: "Images Thumbnail File"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("defaultThumbnailSizeHeader", comment: "Please select an image thumbnail size")
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
        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
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
            if AlbumVars.hasSquareSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeThumb:
            if AlbumVars.hasThumbSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.hasXXSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.hasXSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.hasSmallSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeMedium:
            if AlbumVars.hasMediumSizeImages {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            } else {
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            }
        case kPiwigoImageSizeLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
            if !AlbumVars.hasLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeXLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
            if !AlbumVars.hasXLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeXXLarge:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
            if !AlbumVars.hasXXLargeSizeImages {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: false)
                cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
            } else {
                cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
            }
        case kPiwigoImageSizeFullRes:
            cell.isUserInteractionEnabled = false
            cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
            cell.textLabel?.text = PiwigoImageData.name(forImageThumbnailSizeType: imageSize, withInfo: true)
        default:
            break
        }

        return cell
    }

    
    // MARK: - UITableView - Footer
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Footer height?
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: context)

        return CGFloat(fmax(44.0, ceil(footerRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.piwigoFontSmall()
        footerLabel.textColor = UIColor.piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.text = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping

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

        // Did the user change of default size
        if kPiwigoImageSize(UInt32(indexPath.row)) == currentThumbnailSize { return }

        // Update default size
        tableView.cellForRow(at: IndexPath(row: Int(currentThumbnailSize.rawValue), section: 0))?.accessoryType = .none
        currentThumbnailSize = kPiwigoImageSize(UInt32(indexPath.row))
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}
