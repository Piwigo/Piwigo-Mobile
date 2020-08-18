//
//  DefaultImageSizeViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 5/12/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 05/04/2020.
//

import UIKit

class DefaultImageSizeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView!
    
    
// MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_images", comment: "Images")
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
        tableView.separatorColor = UIColor.piwigoColorSeparator()
        tableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
// MARK: - UITableView - Header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        // Title
        let titleString = "\(NSLocalizedString("defaultPreviewFile>414px", comment: "Preview Image File"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("defaultImageSizeHeader", comment: "Please select an image size")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("defaultPreviewFile>414px", comment: "Preview Image File"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("defaultImageSizeHeader", comment: "Please select an image size")
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
        let imageSize = PiwigoImageData.getImageSize(forRow: indexPath.row)

        // Name of the image size
        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
        cell.textLabel?.adjustsFontSizeToFitWidth = false

        // Add checkmark in front of selected item
        if Model.sharedInstance().defaultImagePreviewSize == indexPath.row {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        // Disable unavailable sizes
        switch imageSize {
            case kPiwigoImageSizeSquare:
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                if !Model.sharedInstance().hasSquareSizeImages {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                } else {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                }
            case kPiwigoImageSizeThumb:
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                if !Model.sharedInstance().hasThumbSizeImages {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                } else {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                }
            case kPiwigoImageSizeXXSmall:
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                if !Model.sharedInstance().hasXXSmallSizeImages {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                } else {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                }
            case kPiwigoImageSizeXSmall:
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                if !Model.sharedInstance().hasXSmallSizeImages {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                } else {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                }
            case kPiwigoImageSizeSmall:
                cell.isUserInteractionEnabled = false
                cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                if !Model.sharedInstance().hasSmallSizeImages {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                } else {
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                }
            case kPiwigoImageSizeMedium:
                if Model.sharedInstance().hasMediumSizeImages {
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                } else {
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                }
            case kPiwigoImageSizeLarge:
                if Model.sharedInstance().hasLargeSizeImages {
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                } else {
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                }
            case kPiwigoImageSizeXLarge:
                if Model.sharedInstance().hasXLargeSizeImages {
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                } else {
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                }
            case kPiwigoImageSizeXXLarge:
                if Model.sharedInstance().hasXXLargeSizeImages {
                    cell.isUserInteractionEnabled = true
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
                } else {
                    cell.isUserInteractionEnabled = false
                    cell.textLabel?.textColor = UIColor.piwigoColorRightLabel()
                    cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: false)
                    cell.textLabel?.text = cell.textLabel?.text ?? "" + (NSLocalizedString("defaultSize_disabled", comment: " (disabled on server)"))
                }
            case kPiwigoImageSizeFullRes:
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = PiwigoImageData.name(forImageSizeType: imageSize, withInfo: true)
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

        Model.sharedInstance().defaultImagePreviewSize = indexPath.row
        Model.sharedInstance().saveToDisk()
        self.tableView.reloadData()

        navigationController?.popViewController(animated: true)
    }
}
