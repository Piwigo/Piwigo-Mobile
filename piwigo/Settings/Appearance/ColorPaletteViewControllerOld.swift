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
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        tableView.separatorColor = UIColor.piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }


    // MARK: - UITableView - Header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString = NSLocalizedString("settingsHeader_colorPalette", comment: "Color Palette")
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

        // Title
        let titleString = NSLocalizedString("settingsHeader_colorPalette", comment: "Color Palette")
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = titleAttributedString

        // Header view
        let header = UIView()
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
        return 2 + (AppVars.switchPaletteAutomatically ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 207.0
        case 1...2:
            return 44.0
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        switch indexPath.row {
        case 0 /* Ligh and Dark options */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceTableViewCell", for: indexPath) as? DeviceTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a DeviceTableViewCell!")
                return LabelTableViewCell()
            }
            cell.configure()
            tableViewCell = cell
            
        case 1 /* Automatic mode? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SwitchTableViewCell!")
                return SwitchTableViewCell()
            }
            cell.configure(with: NSLocalizedString("settings_switchPalette", comment: "Automatic"))
            cell.cellSwitch.setOn(AppVars.switchPaletteAutomatically, animated: true)
            cell.cellSwitchBlock = { switchState in

                // Number of rows will change accordingly
                AppVars.switchPaletteAutomatically = switchState

                // What should we do?
                if switchState {
                    // Switch off light/dark modes
                    AppVars.isLightPaletteModeActive = false
                    AppVars.isDarkPaletteModeActive = false

                    // Add row presenting the brightness threshold
                    tableView.insertRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
                }
                else {
                    // Remove row presenting the brightness threshold
                    tableView.deleteRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
                }

                // Notify palette change
                (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
            }
            cell.accessibilityIdentifier = "switchColourAuto"
            tableViewCell = cell
            
        case 2 /* Switch at ambient brightness? */:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SliderTableViewCell", for: indexPath) as? SliderTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a SliderTableViewCell!")
                return SliderTableViewCell()
            }
            let value = Float(AppVars.switchPaletteThreshold)
            let currentBrightness = UIScreen.main.brightness * 100
            let prefix = String(format: "%ld/", lroundf(Float(currentBrightness)))
            cell.configure(with: NSLocalizedString("settings_brightness", comment: "Brightness"), value: value, increment: 1, minValue: 0, maxValue: 100, prefix: prefix, suffix: "%")
            cell.cellSliderBlock = { newThreshold in
                
                // Update settings
                AppVars.switchPaletteThreshold = Int(newThreshold)
                
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
        tableViewCell.backgroundColor = UIColor.piwigoColorCellBackground()
        tableViewCell.tintColor = UIColor.piwigoColorOrange()

        return tableViewCell
    }
    
    
    // MARK: - UITableView - Footer
        
        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            // Display the footer when the Automatic mode is active
            if !AppVars.switchPaletteAutomatically {
                return 0.0
            }
            
            // Footer height?
            let footer = NSLocalizedString("settings_brightnessHelp", comment: "In low ambient brightness, the Ambient Brightness option uses a darker color palette to make photos stand out against darker backgrounds.")
            let attributes = [
                NSAttributedString.Key.font: UIFont.piwigoFontSmall()
            ]
            let context = NSStringDrawingContext()
            context.minimumScaleFactor = 1.0
            let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: context)

            return CGFloat(fmax(44.0, ceil(footerRect.size.height)))
        }

        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
            // Display the footer when the Automatic mode is active
            if !AppVars.switchPaletteAutomatically {
                return nil
            }
            
            // Footer label
            let footerLabel = UILabel()
            footerLabel.translatesAutoresizingMaskIntoConstraints = false
            footerLabel.font = UIFont.piwigoFontSmall()
            footerLabel.textColor = UIColor.piwigoColorHeader()
            footerLabel.textAlignment = .center
            footerLabel.numberOfLines = 0
            footerLabel.text = NSLocalizedString("settings_brightnessHelp", comment: "In low ambient brightness, the Ambient Brightness option uses a darker color palette to make photos stand out against darker backgrounds.")
            footerLabel.adjustsFontSizeToFitWidth = false
            footerLabel.lineBreakMode = .byWordWrapping

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
}
