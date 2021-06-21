//
//  ColorPaletteViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

class ColorPaletteViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

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
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        tableView.separatorColor = UIColor.piwigoColorSeparator()
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
        return 2
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return 207.0
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
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceTableViewCell", for: indexPath) as? DeviceTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a DeviceTableViewCell!")
                return LabelTableViewCell()
            }
            cell.configure()
            tableViewCell = cell
            
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
                (UIApplication.shared.delegate as! AppDelegate).screenBrightnessChanged()
            }
            cell.accessibilityIdentifier = "switchColourAuto"
            tableViewCell = cell
            
        default:
            fatalError()
        }

        // Appearance
        tableViewCell.backgroundColor = UIColor.piwigoColorCellBackground()
        tableViewCell.tintColor = UIColor.piwigoColorOrange()

        return tableViewCell
    }
}
