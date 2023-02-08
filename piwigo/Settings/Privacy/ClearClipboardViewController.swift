//
//  ClearClipboardViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

enum pwgClearClipboard: Int {
    case after10s
    case after30s
    case after1min
    case after2min
    case after5min
    case never
    case count
}

extension pwgClearClipboard {
    var seconds:TimeInterval {
        switch self {
        case .after10s:
            return 10
        case .after30s:
            return 30
        case .after1min:
            return 60
        case .after2min:
            return 120
        case .after5min:
            return 300
        case .never:
            return 0
        case .count:
            return .infinity
        }
    }
    
    var delayText: String {
        switch self {
        case .after10s:
            return NSLocalizedString("settings_clearClipboard10sText", comment: "10 seconds")
        case .after30s:
            return NSLocalizedString("settings_clearClipboard30sText", comment: "30 seconds")
        case .after1min:
            return NSLocalizedString("settings_clearClipboard1minText", comment: "1 minute")
        case .after2min:
            return NSLocalizedString("settings_clearClipboard2minText", comment: "2 minute")
        case .after5min:
            return NSLocalizedString("settings_clearClipboard5minText", comment: "5 minute")
        case .never:
            return NSLocalizedString("settings_clearClipboardNever", comment: "never")
        case .count:
            return ""
        }
    }

    var delayUnit: String {
        switch self {
        case .after10s:
            return NSLocalizedString("settings_clearClipboard10sUnit", comment: "10 s")
        case .after30s:
            return NSLocalizedString("settings_clearClipboard30sUnit", comment: "30 s")
        case .after1min:
            return NSLocalizedString("settings_clearClipboard1minUnit", comment: "1 min")
        case .after2min:
            return NSLocalizedString("settings_clearClipboard2minUnit", comment: "2 min")
        case .after5min:
            return NSLocalizedString("settings_clearClipboard5minUnit", comment: "5 min")
        case .never:
            return NSLocalizedString("settings_clearClipboardNever", comment: "never")
        case .count:
            return ""
        }
    }
}

protocol ClearClipboardDelegate: NSObjectProtocol {
    func didSelectClearClipboardDelay(_ delay: pwgClearClipboard)
}

class ClearClipboardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var delegate: ClearClipboardDelegate?
    
    @IBOutlet var delayTableView: UITableView!
    
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
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
        delayTableView.separatorColor = .piwigoColorSeparator()
        delayTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        delayTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Return selected album
        let delay = pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay) ?? pwgClearClipboard.never
        delegate?.didSelectClearClipboardDelay(delay)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("settings_clearClipboard", comment: "Clear Clipboard"))
        let text = NSLocalizedString("settings_clearClipboardInfo", comment: "Please select the delay after which the clipboard will be cleared.")
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
        return pwgClearClipboard.count.rawValue
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let delayChoice = pwgClearClipboard(rawValue: indexPath.row)

        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
        cell.textLabel?.text = delayChoice?.delayText
        cell.textLabel?.minimumScaleFactor = 0.5
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
        if indexPath.row == AppVars.shared.clearClipboardDelay {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }


    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change the delay?
        if indexPath.row == AppVars.shared.clearClipboardDelay { return }

        // Update choice
        tableView.cellForRow(at: IndexPath(row: AppVars.shared.clearClipboardDelay, section: 0))?.accessoryType = .none
        AppVars.shared.clearClipboardDelay = indexPath.row
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}
