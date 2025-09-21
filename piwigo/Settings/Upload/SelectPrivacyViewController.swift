//
//  SelectPrivacyViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 31/03/2020
//

import UIKit
import piwigoKit

protocol SelectPrivacyDelegate: NSObjectProtocol {
    func didSelectPrivacyLevel(_ privacy: pwgPrivacy)
}

class SelectPrivacyViewController: UIViewController {
    
    weak var delegate: SelectPrivacyDelegate?

    @IBOutlet var privacyTableView: UITableView!
    
    private var _privacy: pwgPrivacy?
    var privacy: pwgPrivacy {
        get {
            return _privacy ?? .everybody
        }
        set(privacy) {
            _privacy = privacy
        }
    }


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")

        // Table view
        privacyTableView?.accessibilityIdentifier = "Privacy"
        privacyTableView?.rowHeight = UITableView.automaticDimension
        privacyTableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
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
        privacyTableView.separatorColor = PwgColor.separator
        privacyTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        privacyTableView.reloadData()
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
        super .viewDidDisappear(animated)

        // Update cell of parent view
        delegate?.didSelectPrivacyLevel(privacy)
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension SelectPrivacyViewController: UITableViewDataSource
{
    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgPrivacy.allCases.count - 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell3", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }

        // Add checkmark in front of selected item
        let privacyLevel = getPrivacyLevel(forRow: indexPath.row)
        cell.accessoryType = privacyLevel == privacy ? .checkmark : .none

        // Configure cell
        cell.configure(with: privacyLevel.name, detail: "")
        cell.tag = Int(privacyLevel.rawValue)
        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension SelectPrivacyViewController: UITableViewDelegate
{
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("privacyLevel", comment: "Privacy Level"))
        let text = NSLocalizedString("settings_defaultPrivacy>414px", comment: "Please select who will be able to see images")
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Did the user change the level?
        let newPrivacy = getPrivacyLevel(forRow: indexPath.row)
        if newPrivacy == privacy { return }
        
        // Update choice
        privacy = newPrivacy
        for visibleCell in tableView.visibleCells {
            visibleCell.accessoryType = .none
            if visibleCell.tag == Int(privacy.rawValue) {
                visibleCell.accessoryType = .checkmark
            }
        }
    }
}


// MARK: - Utilities
private func getPrivacyLevel(forRow row: Int) -> pwgPrivacy {
    var privacyLevel: pwgPrivacy
    switch row {
        case 0:
            privacyLevel = .admins
        case 1:
            privacyLevel = .adminsFamily
        case 2:
            privacyLevel = .adminsFamilyFriends
        case 3:
            privacyLevel = .adminsFamilyFriendsContacts
        case 4:
            privacyLevel = .everybody
        default:
            privacyLevel = .unknown
            break
    }

    return privacyLevel
}
