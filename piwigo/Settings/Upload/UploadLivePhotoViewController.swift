//
//  UploadLivePhotoViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/07/2021.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import AVFoundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit
import PwgUIKit

protocol UploadLivePhotoAsDelegate: NSObjectProtocol {
    func didSelectUploadLivePhotoAs(_ option: pwgUploadLivePhotoAs)
}

final class UploadLivePhotoViewController: UIViewController {

    weak var delegate: (any UploadLivePhotoAsDelegate)?
    
    /// Option presented and returned to the delegate. Set by the caller so that the upload
    /// of a selection can adopt an option without changing the default stored in settings.
    private var _uploadLivePhotoAs: pwgUploadLivePhotoAs?
    var uploadLivePhotoAs: pwgUploadLivePhotoAs {
        get { return _uploadLivePhotoAs ?? UploadVars.shared.uploadLivePhotoAs }
        set { _uploadLivePhotoAs = newValue }
    }
    
    @IBOutlet var tableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "tabBar_upload", comment: "Upload")

        // Table view
        tableView?.accessibilityIdentifier = "Upload Live Photo As"
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
        tableView.indicatorStyle = UIVars.shared.isDarkPaletteActive ? .white : .black
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

        // Return selected Live Photo upload mode
        delegate?.didSelectUploadLivePhotoAs(uploadLivePhotoAs)
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension UploadLivePhotoViewController: UITableViewDataSource
{
    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgUploadLivePhotoAs.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell3", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        // Configure cell
        let choice = pwgUploadLivePhotoAs(rawValue: Int16(indexPath.row)) ?? .photo
        cell.configure(with: choice.name, detail: "")
        /// The effective option, not the stored one, which may not be applicable anymore
        cell.accessoryType = choice == uploadLivePhotoAs ? .checkmark : .none

        // Options uploading the video are proposed only when the server accepts videos
        let isSelectable = (choice == .photo) || UploadVars.shared.serverAcceptsVideos
        cell.titleLabel.textColor = isSelectable ? PwgColor.leftLabel : PwgColor.rightLabel
        cell.isUserInteractionEnabled = isSelectable
        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension UploadLivePhotoViewController: UITableViewDelegate
{
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", String(localized: "settings_livePhotos", comment: "Live Photos"))
        let text = String(localized: "UploadLivePhotoAs_header", comment: "Please select what to upload from a Live Photo.")
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
    
    
    // MARK: - Footer
    private func getContentOfFooter() -> String {
        // Explain why the options uploading the video are not proposed
        if UploadVars.shared.serverAcceptsVideos { return "" }
        return String(localized: "UploadLivePhotoAs_footer", comment: "This Piwigo server does not accept videos, so only the photo of a Live Photo can be uploaded.")
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return TableViewUtilities.heightOfFooter(withText: getContentOfFooter(),
                                                 width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return TableViewUtilities.viewOfFooter(withText: getContentOfFooter(), alignment: .center)
    }


    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change the option?
        let newChoice = pwgUploadLivePhotoAs(rawValue: Int16(indexPath.row)) ?? .photo
        let oldChoice = uploadLivePhotoAs
        if newChoice == oldChoice { return }

        // Update choice
        tableView.cellForRow(at: IndexPath(row: Int(oldChoice.rawValue), section: 0))?.accessoryType = .none
        uploadLivePhotoAs = newChoice
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}


// MARK: - pwgUploadLivePhotoAs Names
extension pwgUploadLivePhotoAs {
    public var name: String {
        switch self {
        case .photo:   return String(localized: "UploadLivePhotoAs_photo", comment: "Photo Only")
        case .movie:   return String(localized: "UploadLivePhotoAs_movie", comment: "Video Only")
        case .both:    return String(localized: "UploadLivePhotoAs_both", comment: "Photo & Video")
        }
    }
}
