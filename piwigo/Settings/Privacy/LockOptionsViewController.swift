//
//  LockOptionsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import LocalAuthentication
import UIKit
import PwgKit
import PwgUIKit

protocol LockOptionsDelegate: NSObjectProtocol {
    func didSetAppLock(toState isLocked: Bool)
}

class LockOptionsViewController: UIViewController {
    
    weak var delegate: (any LockOptionsDelegate)?
    
    var context = LAContext()
    var contextErrorMsg = ""
    
    @IBOutlet var lockOptionsTableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = Localized.privacy
        
        // Table view
        lockOptionsTableView?.accessibilityIdentifier = "Lock Settings"
        lockOptionsTableView?.rowHeight = UITableView.automaticDimension
        lockOptionsTableView?.estimatedRowHeight = TableViewUtilities.rowHeight

        // Evaluate biometrics policy
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        contextErrorMsg = error?.localizedDescription ?? ""
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        lockOptionsTableView?.separatorColor = PwgColor.separator
        lockOptionsTableView?.indicatorStyle = UIVars.shared.isDarkPaletteActive ? .white : .black
        lockOptionsTableView?.reloadData()
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


// MARK: - UITableViewDataSource Methods
extension LockOptionsViewController: UITableViewDataSource {
    
    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        var nberOfSection = 2
        nberOfSection += context.biometryType == .none ? 0 : 1
        return nberOfSection
    }
    

    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0...2:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        switch indexPath.section {
        case 0:     // Auto-Upload On/Off
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load SwitchTableViewCell") }

            let title = String(localized: "settings_appLock", comment: "App Lock")
            cell.configure(with: title)
            cell.cellSwitch.setOn(UIVars.shared.isAppLockActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Check if a password exists
                if switchState, UIVars.shared.appLockKey.isEmpty {
                    let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
                    guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
                    appLockVC.config(forAction: .enterPasscode)
                    self.navigationController?.pushViewController(appLockVC, animated: true)
                } else {
                    // Enable/disable app-lock option
                    UIVars.shared.isAppLockActive = switchState
                    self.delegate?.didSetAppLock(toState: switchState)
                }
            }
            tableViewCell = cell

        case 1:     // Change Password
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonTableViewCell", for: indexPath) as? ButtonTableViewCell
            else { preconditionFailure("Could not load a ButtonTableViewCell!") }
            if UIVars.shared.appLockKey.isEmpty {
                cell.configure(with: Localized.enterPasscode)
            } else {
                cell.configure(with: Localized.modifyPasscode)
            }
            cell.accessibilityIdentifier = "passcode"
            tableViewCell = cell

        case 2:     // TouchID / FaceID / OpticID On/Off
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load SwitchTableViewCell") }
            var title = ""
            switch context.biometryType {
            case .touchID:
                title = String(localized: "settings_biometricsTouchID", comment: "Touch ID")
            case .faceID:
                title = String(localized: "settings_biometricsFaceID", comment: "Face ID")
            case .opticID:
                title = String(localized: "settings_biometricsOpticID", comment: "Optic ID")
            default:
                title = "—?—"
            }
            cell.configure(with: title)
            if contextErrorMsg.isEmpty == false {
                cell.switchName.textColor = PwgColor.rightLabel
                cell.cellSwitch.onTintColor = PwgColor.rightLabel
                cell.isUserInteractionEnabled = false
            }
            cell.cellSwitch.setOn(UIVars.shared.isBiometricsEnabled, animated: true)
            cell.cellSwitchBlock = { switchState in
                UIVars.shared.isBiometricsEnabled = switchState
            }
            tableViewCell = cell

        default:
            break
        }

        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.orange
        return tableViewCell
    }
}


// MARK: - UITableViewDelegate Methods
extension LockOptionsViewController: UITableViewDelegate {
    
    // MARK: - Header
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
        return TableViewUtilities.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.viewOfHeader(withTitle: title)
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Change password?
        if indexPath.section ==  1 {
            // Display numpad for setting up a passcode
            let appLockSB = UIStoryboard(name: "AppLockViewController", bundle: nil)
            guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "AppLockViewController") as? AppLockViewController else { return }
            if UIVars.shared.appLockKey.isEmpty {
                appLockVC.config(forAction: .enterPasscode)
            } else {
                appLockVC.config(forAction: .modifyPasscode)
            }
            navigationController?.pushViewController(appLockVC, animated: true)
        }
    }

    
    // MARK: - Footer
    private func getContentOfFooter(inSection section: Int) -> String {
        var footer = ""
        switch section {
        case 0:     // App-Lock On/Off
            footer = Localized.appLockInfo
        case 1:     // Change Passcode
            footer = String(localized: "settings_passcodeInfo", comment: "The passcode is separate…")
        case 2:     // Touch ID / Face ID On/Off
            if contextErrorMsg.isEmpty {
                switch context.biometryType {
                case .none:
                    footer = ""
                case .touchID:
                    footer = String(localized: "settings_biometricsTouchIDinfo", comment: "Use Touch ID…")
                case .faceID:
                    footer = String(localized: "settings_biometricsFaceIDinfo", comment:"Use Face ID…")
                case .opticID:
                    footer = String(localized: "settings_biometricsOpticIDinfo", comment:"Use Optic ID…")
                @unknown default:
                    footer = ""
                }
            } else {
                footer = contextErrorMsg
            }
        default:
            footer = " "
        }
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.heightOfFooter(withText: text,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.viewOfFooter(withText: text)
    }
}
