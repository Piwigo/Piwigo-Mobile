//
//  ColorPaletteViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ColorPaletteViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("settingsHeader_appearance", comment: "Appearance")

        // Table view
        tableView?.accessibilityIdentifier = "Color Palette Selector"
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Disable large titles
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar appearance
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        
        // Table view
        tableView?.separatorColor = PwgColor.separator
        tableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Back to large titles
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension ColorPaletteViewController: UITableViewDataSource {
    
    // MARK: - Sections
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        switch indexPath.row {
        case 0:
            if UIDevice.current.userInterfaceIdiom == .phone {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PhoneTableViewCell", for: indexPath) as? PhoneTableViewCell
                else { preconditionFailure("Could not load a PhoneTableViewCell!") }
                cell.configure()
                tableViewCell = cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PadTableViewCell", for: indexPath) as? PadTableViewCell
                else { preconditionFailure("Could not load a PadTableViewCell!")}
                cell.configure()
                tableViewCell = cell
            }
            
        case 1:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "SwitchTableViewCell"
                : "SwitchTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load SwitchTableViewCell") }
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
        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.tintColor

        return tableViewCell
    }
}


// MARK: - UITableViewDelegate Methods
extension ColorPaletteViewController: UITableViewDelegate {
    
    // MARK: - Header
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
}
