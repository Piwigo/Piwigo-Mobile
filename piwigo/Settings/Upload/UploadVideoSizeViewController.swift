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
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
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
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("UploadVideoSize_title", comment: "Max Video Size"))
        let text = NSLocalizedString("UploadVideoSize_header", comment: "Please select the maximum size of the videos which will be uploaded.")
        return (title, text)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                 width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.viewOfHeader(withTitle: title, text: text)
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
        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .piwigoFontNormal()
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
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
    private func deviceVideoResolution() -> String {
        // Collect system and device data
        var systemInfo = utsname()
        uname(&systemInfo)
        let size = Int(_SYS_NAMELEN) // is 32, but posix AND its init is 256....
        let resolution: String = DeviceUtilities.deviceVideoCapabilities(forCode: withUnsafeMutablePointer(to: &systemInfo.machine) {p in
            p.withMemoryRebound(to: CChar.self, capacity: size, {p2 in
                return String(cString: p2)
            })
        })
        return resolution
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Footer height?
        let resolution = deviceVideoResolution()
        if resolution.isEmpty { return 0.0 }
        let footer = String(format: "%@ %@.", NSLocalizedString("UploadVideoSize_resolution", comment: "Built-in cameras maximum specifications:"), resolution)
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
        footerLabel.font = .piwigoFontSmall()
        footerLabel.textColor = .piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.text = String(format: "%@ %@.", NSLocalizedString("UploadVideoSize_resolution", comment: "Built-in cameras maximum specifications:"), deviceVideoResolution())
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
