//
//  UploadVideoSizeViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import UIKit
import piwigoKit

protocol UploadVideoSizeDelegate: NSObjectProtocol {
    func didSelectUploadVideoSize(_ imageSize: Int16)
}

class UploadVideoSizeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: UploadVideoSizeDelegate?
    
    @IBOutlet var tableView: UITableView!
    
    private var _videoMaxSize: Int16?
    var videoMaxSize: Int16 {
        get {
            return _videoMaxSize ?? pwgVideoMaxSizes.fullResolution.rawValue
        }
        set(photoSize) {
            if photoSize < 0 || photoSize > pwgVideoMaxSizes.allCases.count {
                _videoMaxSize = pwgVideoMaxSizes.fullResolution.rawValue
            } else {
                _videoMaxSize = photoSize
            }
        }
    }

    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")

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
        delegate?.didSelectUploadVideoSize(videoMaxSize)

        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        // Title
        let titleString = "\(NSLocalizedString("UploadPhotoSize_title", comment: "Photo Size"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("UploadPhotoSize_header", comment: "Please select the maximum size of the photos which will be uploaded.")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("UploadPhotoSize_title", comment: "Max Photo Size"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("UploadPhotoSize_header", comment: "Please select the maximum size of the photos which will be uploaded.")
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
        return pwgVideoMaxSizes.allCases.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        // Name of the image size
        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
        cell.textLabel?.adjustsFontSizeToFitWidth = false
        cell.textLabel?.text = indexPath.row == 0 ? pwgVideoMaxSizes(rawValue: Int16(indexPath.row))!.name  : String(format: "%@ | <= %ld px", pwgVideoMaxSizes(rawValue: Int16(indexPath.row))!.name, pwgVideoMaxSizes(rawValue: Int16(indexPath.row))!.pixels)

        // Add checkmark in front of selected item
        if indexPath.row == videoMaxSize {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    
    // MARK: - UITableView - Footer
    private func cameraResolution() -> String {
        // Collect system and device data
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = Int(_SYS_NAMELEN) // is 32, but posix AND its init is 256....
        let resolution: String = DeviceUtilities.cameraResolution(forCode: withUnsafeMutablePointer(to: &systemInfo.machine) {p in
            p.withMemoryRebound(to: CChar.self, capacity: size, {p2 in
                return String(cString: p2)
            })
        })
        return resolution
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Footer height?
        let resolution = cameraResolution()
        if resolution.isEmpty { return 0.0 }
        let footer = String(format: "%@ %@.", NSLocalizedString("UploadPhotoSize_resolution", comment: "Maximum resolution of the built-in cameras:"), resolution)
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
        footerLabel.text = String(format: "%@ %@.", NSLocalizedString("UploadPhotoSize_resolution", comment: "Maximum resolution of the built-in cameras:"), cameraResolution())
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

        // Did the user change of max photo size?
        if indexPath.row == videoMaxSize { return }

        // Update default size
        tableView.cellForRow(at: IndexPath(row: Int(videoMaxSize), section: 0))?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        videoMaxSize = Int16(indexPath.row)
    }
}
