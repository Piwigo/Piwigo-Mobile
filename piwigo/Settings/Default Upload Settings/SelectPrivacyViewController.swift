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

@objc
protocol SelectPrivacyDelegate: NSObjectProtocol {
    func selectedPrivacy(_ privacy: kPiwigoPrivacy)
}

@objc
class SelectPrivacyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @objc
    weak var delegate: SelectPrivacyDelegate?

    @objc
    func setPrivacy(_ privacy: kPiwigoPrivacy) {
        _privacy = privacy
    }

    @IBOutlet var privacyTableView: UITableView!
    
    private var _privacy: kPiwigoPrivacy?
    private var privacy: kPiwigoPrivacy {
        get {
            return _privacy ?? kPiwigoPrivacyEverybody
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
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        privacyTableView.separatorColor = UIColor.piwigoColorSeparator()
        privacyTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        privacyTableView.reloadData()
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
        let titleString = "\(NSLocalizedString("privacyLevel", comment: "Privacy Level"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("settings_defaultPrivacy>414px", comment: "Please select who will be able to see images")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes as [NSAttributedString.Key : Any], context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
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
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint(item: headerLabel, attribute: .bottom, relatedBy: .equal, toItem: headerLabel.superview, attribute: .bottom, multiplier: 1.0, constant: -4))
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
        return Int(kPiwigoPrivacyCount.rawValue)
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

        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
        cell.textLabel?.adjustsFontSizeToFitWidth = false
        cell.textLabel?.text = Model.sharedInstance().getNameForPrivacyLevel(Int(privacyLevel.rawValue))
        cell.tag = Int(privacyLevel.rawValue)

        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedPrivacy = getPrivacyLevel(forRow: indexPath.row)

        for visibleCell in tableView.visibleCells {
            visibleCell.accessoryType = .none
            if visibleCell.tag == Int(selectedPrivacy.rawValue) {
                visibleCell.accessoryType = .checkmark
            }
        }


        if delegate?.responds(to: #selector(SelectPrivacyDelegate.selectedPrivacy(_:))) ?? false {
            delegate?.selectedPrivacy(selectedPrivacy)
        }

        navigationController?.popViewController(animated: true)
    }
}


// MARK: - Utilities

    private func getPrivacyLevel(forRow row: Int) -> kPiwigoPrivacy {
        var privacyLevel: kPiwigoPrivacy
        switch row {
            case 0:
                privacyLevel = kPiwigoPrivacyEverybody
            case 1:
                privacyLevel = kPiwigoPrivacyAdminsFamilyFriendsContacts
            case 2:
                privacyLevel = kPiwigoPrivacyAdminsFamilyFriends
            case 3:
                privacyLevel = kPiwigoPrivacyAdminsFamily
            case 4:
                privacyLevel = kPiwigoPrivacyAdmins
            default:
                privacyLevel = kPiwigoPrivacyEverybody
                break
        }

        return privacyLevel
    }
