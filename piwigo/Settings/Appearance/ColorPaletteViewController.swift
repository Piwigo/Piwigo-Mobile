//
//  ColorPaletteViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ColorPaletteViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView!
    

// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("settingsHeader_appearance", comment: "Appearance")
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
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
        tableView.separatorColor = .piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
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
    private func getContentOfHeader() -> String {
        let title = NSLocalizedString("settingsHeader_colorPalette", comment: "Color Palette")
        return title
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader()
        return TableViewUtilities.shared.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader()
        return TableViewUtilities.shared.viewOfHeader(withTitle: title)
    }

    
    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 214.0
        case 1:
            return 44.0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        switch indexPath.row {
        case 0:
            if UIDevice.current.userInterfaceIdiom == .phone {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneTableViewCell", for: indexPath) as? PhoneTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a PhoneTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure()
                tableViewCell = cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PadTableViewCell", for: indexPath) as? PadTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a PadTableViewCell!")
                    return LabelTableViewCell()
                }
                cell.configure()
                tableViewCell = cell
            }
            
        case 1:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            cell.configure(with: NSLocalizedString("settings_switchPalette", comment: "Automatic"))
            cell.cellSwitch.setOn(AppVars.shared.switchPaletteAutomatically, animated: true)
            cell.cellSwitchBlock = { switchState in

                // Number of rows will change accordingly
                AppVars.shared.switchPaletteAutomatically = switchState

                // What should we do?
                if switchState {
                    // Switch off light/dark modes
                    AppVars.shared.isLightPaletteModeActive = false
                    AppVars.shared.isDarkPaletteModeActive = false
                }

                // Notify palette change
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
            cell.accessibilityIdentifier = "switchColourAuto"
            tableViewCell = cell
            
        default:
            fatalError()
        }

        // Appearance
        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()

        return tableViewCell
    }
}
