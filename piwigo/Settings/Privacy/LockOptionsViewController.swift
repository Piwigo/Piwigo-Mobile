//
//  LockOptionsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

protocol LockOptionsDelegate: NSObjectProtocol {
    func didSetAppLock(toState isLocked: Bool)
}

class LockOptionsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: LockOptionsDelegate?

    @IBOutlet var lockOptionsTableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
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
        lockOptionsTableView.separatorColor = .piwigoColorSeparator()
        lockOptionsTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        lockOptionsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> String {
        var title = ""
        switch section {
        default:
            title = " "
        }
        return title
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.heightOfHeader(withTitle: title, width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.viewOfHeader(withTitle: title)
    }


    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        switch indexPath.section {
        case 0:     // Auto-Upload On/Off
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            let title = NSLocalizedString("settings_appLock", comment: "App Lock")

            cell.configure(with: title)
            cell.cellSwitch.setOn(AppVars.shared.isAppLockActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Check if a password exists
                if switchState, AppVars.shared.appLockKey.isEmpty {
                    let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
                    guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
                    appLockVC.config(forAction: .enterPasscode)
                } else {
                    // Enable/disable app-lock option
                    AppVars.shared.isAppLockActive = switchState
                    self.delegate?.didSetAppLock(toState: true)
                }
            }
            tableViewCell = cell

        case 1:     // Change Password
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a ButtonTableViewCell!")
                return ButtonTableViewCell()
            }
            if AppVars.shared.appLockKey.isEmpty {
                cell.configure(with: NSLocalizedString("settings_appLockEnter", comment: "Enter Passcode"))
            } else {
                cell.configure(with: NSLocalizedString("settings_appLockModify", comment: "Modify Passcode"))
            }
            cell.accessibilityIdentifier = "passcode"
            tableViewCell = cell

        default:
            break
        }

        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()
        return tableViewCell
    }


    // MARK: - UITableView - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // No footer by default (nil => 0 point)
        var footer = ""

        // Any footer text?
        switch section {
        case 0:     // App-Lock On/Off
            footer = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")
        case 1:     // Change Passcode
            footer = NSLocalizedString("settings_passcodeInfo", comment: "The passcode is separate…")
        default:
            return CGFloat.zero
        }

        // Footer height?
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - CGFloat(30),
                                                          height: CGFloat.greatestFiniteMagnitude),
                                             options: .usesLineFragmentOrigin,
                                             attributes: attributes, context: context)

        return ceil(footerRect.size.height + 10.0)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = .piwigoFontSmall()
        footerLabel.textColor = .piwigoColorHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        footerLabel.adjustsFontSizeToFitWidth = false
        footerLabel.lineBreakMode = .byWordWrapping

        // Any footer text?
        switch section {
        case 0:     // App-Lock On/Off
            footerLabel.text = NSLocalizedString("settings_appLockInfo", comment: "With App Lock, ...")
        case 1:     // Change Passcode
            footerLabel.text = NSLocalizedString("settings_passcodeInfo", comment: "The passcode is separate…")
        default:
            break
        }

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
        
        // Change password?
        if indexPath.section ==  1 {
            // Display numpad for setting up a passcode
            let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
            guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
            if AppVars.shared.appLockKey.isEmpty {
                appLockVC.config(forAction: .enterPasscode)
            } else {
                appLockVC.config(forAction: .modifyPasscode)
            }
            navigationController?.pushViewController(appLockVC, animated: true)
        }
    }
}
