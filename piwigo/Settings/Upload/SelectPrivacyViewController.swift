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

class SelectPrivacyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
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
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
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
        privacyTableView.separatorColor = .piwigoColorSeparator()
        privacyTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        privacyTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)

        // Update cell of parent view
        delegate?.didSelectPrivacyLevel(privacy)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
    
    
    // MARK: - UITableView - Header
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

    
    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(pwgPrivacy.count.rawValue)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "privacyCell", for: indexPath)
        let privacyLevel = getPrivacyLevel(forRow: indexPath.row)
        if privacyLevel == privacy {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
        cell.textLabel?.adjustsFontSizeToFitWidth = false
        cell.textLabel?.text = privacyLevel.name
        cell.tag = Int(privacyLevel.rawValue)

        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Did the user change the level?
        if privacy == getPrivacyLevel(forRow: indexPath.row) { return }
        
        // Update choice
        privacy = getPrivacyLevel(forRow: indexPath.row)
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
            privacyLevel = .everybody
        case 1:
            privacyLevel = .adminsFamilyFriendsContacts
        case 2:
            privacyLevel = .adminsFamilyFriends
        case 3:
            privacyLevel = .adminsFamily
        case 4:
            privacyLevel = .admins
        default:
            privacyLevel = .unknown
            break
    }

    return privacyLevel
}
