//
//  ColorPaletteViewControllerOld.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 13/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ColorPaletteViewControllerOld: UIViewController, UITableViewDataSource, UITableViewDelegate {

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
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

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
                                               name: .pwgPaletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
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
        return 2 + (AppVars.shared.switchPaletteAutomatically ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 214.0
        case 1...2:
            return 44.0
        default:
            return 0.0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        switch indexPath.row {
        case 0 /* Ligh and Dark options */:
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

        case 1 /* Automatic mode? */:
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

                    // Add row presenting the brightness threshold
                    tableView.insertRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
                }
                else {
                    // Remove row presenting the brightness threshold
                    tableView.deleteRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
                }

                // Notify palette change
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
            cell.accessibilityIdentifier = "switchColourAuto"
            tableViewCell = cell
            
        case 2 /* Switch at ambient brightness? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                return SliderTableViewCell()
            }
            let value = Float(AppVars.shared.switchPaletteThreshold)
            let currentBrightness = UIScreen.main.brightness * 100
            let prefix = String(format: "%ld/", lroundf(Float(currentBrightness)))
            cell.configure(with: NSLocalizedString("settings_brightness", comment: "Brightness"), value: value, increment: 1, minValue: 0, maxValue: 100, prefix: prefix, suffix: "%")
            cell.cellSliderBlock = { newThreshold in
                
                // Update settings
                AppVars.shared.switchPaletteThreshold = Int(newThreshold)
                
                // Update palette if needed
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
            cell.accessibilityIdentifier = "brightnessLevel"
            tableViewCell = cell

        default:
            fatalError()
        }

        // Appearance
        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()

        return tableViewCell
    }
    
    
    // MARK: - UITableView - Footer
        
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Display the footer when the Automatic mode is active
        if !AppVars.shared.switchPaletteAutomatically {
            return 0.0
        }
        
        // Footer height?
        let footer = NSLocalizedString("settings_brightnessHelp", comment: "In low ambient brightness, the Ambient Brightness option uses a darker color palette to make photos stand out against darker backgrounds.")
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Display the footer when the Automatic mode is active
        if !AppVars.shared.switchPaletteAutomatically {
            return nil
        }
        
        // Footer
        let footer = NSLocalizedString("settings_brightnessHelp", comment: "In low ambient brightness, the Ambient Brightness option uses a darker color palette to make photos stand out against darker backgrounds.")
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }
}
