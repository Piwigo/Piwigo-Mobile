//
//  UploadPhotoSizeViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/07/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import AVFoundation
import UIKit
import piwigoKit
import uploadKit

protocol UploadPhotoSizeDelegate: NSObjectProtocol {
    func didSelectUploadPhotoSize(_ imageSize: Int16)
}

class UploadPhotoSizeViewController: UIViewController {

    weak var delegate: UploadPhotoSizeDelegate?
    
    @IBOutlet var tableView: UITableView!
    
    private var _photoMaxSize: Int16?
    var photoMaxSize: Int16 {
        get {
            return _photoMaxSize ?? pwgPhotoMaxSizes.fullResolution.rawValue
        }
        set(photoSize) {
            if photoSize < 0 || photoSize > pwgPhotoMaxSizes.allCases.count {
                _photoMaxSize = pwgPhotoMaxSizes.fullResolution.rawValue
            } else {
                _photoMaxSize = photoSize
            }
        }
    }

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        if #available(iOS 26.0, *) {
            navigationItem.attributedTitle = TableViewUtilities.shared.attributedTitle(title)
        }
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
        delegate?.didSelectUploadPhotoSize(photoMaxSize)
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension UploadPhotoSizeViewController: UITableViewDataSource
{
    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgPhotoMaxSizes.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        // Name of the image size
        cell.backgroundColor = PwgColor.cellBackground
        cell.tintColor = PwgColor.orange
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = PwgColor.leftLabel
        cell.textLabel?.adjustsFontSizeToFitWidth = false
        cell.textLabel?.text = indexPath.row == 0 ? pwgPhotoMaxSizes(rawValue: Int16(indexPath.row))!.name  : String(format: "%@ | <= %ld px", pwgPhotoMaxSizes(rawValue: Int16(indexPath.row))!.name, pwgPhotoMaxSizes(rawValue: Int16(indexPath.row))!.pixels)

        // Add checkmark in front of selected item
        if indexPath.row == photoMaxSize {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension UploadPhotoSizeViewController: UITableViewDelegate
{
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("UploadPhotoSize_title", comment: "Max Photo Size"))
        let text = NSLocalizedString("UploadPhotoSize_header", comment: "Please select the maximum size of the photos which will be uploaded.")
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

        // Did the user change of max photo size?
        if indexPath.row == photoMaxSize { return }

        // Update default size
        tableView.cellForRow(at: IndexPath(row: Int(photoMaxSize), section: 0))?.accessoryType = .none
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        photoMaxSize = Int16(indexPath.row)
    }

    
    // MARK: - Footer
    private func getContentOfFooter() -> String {
        let resolution = UIDevice.current.modelPhotoResolution
        if resolution.isEmpty { return "" }
        return String(format: "%@ %@.", NSLocalizedString("UploadPhotoSize_resolution", comment: "Built-in cameras maximum resolution:"), resolution)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter()
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = getContentOfFooter()
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }
}
