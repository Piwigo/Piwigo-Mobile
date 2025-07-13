//
//  UploadParametersViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

enum EditImageDetailsOrder : Int {
    case imageName
    case author
    case privacy
    case tags
    case comment
    case count
}

class UploadParametersViewController: UITableViewController {

    @IBOutlet var paramsTableView: UITableView!

    var commonTitle = ""
    var shouldUpdateTitle = false
    var commonAuthor = UploadVars.shared.defaultAuthor
    var shouldUpdateAuthor = false
    var commonPrivacyLevel = pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel) ?? .everybody
    var shouldUpdatePrivacyLevel = false
    var commonTags = Set<Tag>()
    var shouldUpdateTags = false
    var commonComment = ""
    var shouldUpdateComment = false
    var user: User? {
        return (parent as? UploadSwitchViewController)?.user
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Collection view identifier
        paramsTableView.accessibilityIdentifier = "Parameters"
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()

        // Table view
        paramsTableView.separatorColor = .piwigoColorSeparator()
        paramsTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        paramsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SelectPrivacyDelegate Methods
extension UploadParametersViewController: SelectPrivacyDelegate {
    func didSelectPrivacyLevel(_ privacyLevel: pwgPrivacy) {
        // Update image parameter
        commonPrivacyLevel = privacyLevel

        // Remember to update image info
        shouldUpdatePrivacyLevel = true

        // Update cell
        let indexPath = IndexPath(row: EditImageDetailsOrder.privacy.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - TagsViewControllerDelegate Methods
extension UploadParametersViewController: TagsViewControllerDelegate {
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Update image parameter
        commonTags = selectedTags

        // Remember to update image info
        shouldUpdateTags = true

        // Update cell
        let indexPath = IndexPath(row: EditImageDetailsOrder.tags.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
