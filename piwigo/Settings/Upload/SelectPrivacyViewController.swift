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
    func didSelectPrivacyLevel(_ privacy: kPiwigoPrivacy)
}

class SelectPrivacyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: SelectPrivacyDelegate?

    @IBOutlet var privacyTableView: UITableView!
    
    private var _privacy: kPiwigoPrivacy?
    var privacy: kPiwigoPrivacy {
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
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
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
        privacyTableView.separatorColor = .piwigoColorSeparator()
        privacyTableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
        privacyTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)

        // Update cell of parent view
        delegate?.didSelectPrivacyLevel(privacy)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    
    // MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = String(format: "%@\n", NSLocalizedString("privacyLevel", comment: "Privacy Level"))
        let text = NSLocalizedString("settings_defaultPrivacy>414px", comment: "Please select who will be able to see images")
        return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                 width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("privacyLevel", comment: "Privacy Level"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("settings_defaultPrivacy>414px", comment: "Please select who will be able to see images")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        headerAttributedString.append(textAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = .piwigoColorHeader()
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
        return Int(kPiwigoPrivacy.count.rawValue)
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
        cell.textLabel?.font = .piwigoFontNormal()
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

private func getPrivacyLevel(forRow row: Int) -> kPiwigoPrivacy {
    var privacyLevel: kPiwigoPrivacy
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
