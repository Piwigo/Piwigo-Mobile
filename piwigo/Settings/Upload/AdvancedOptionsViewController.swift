//
//  AdvancedOptionsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/03/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class AdvancedOptionsViewController: UIViewController
{
    enum pwgAvancedOptions: Int, CaseIterable, Sendable {
        case maxPrepared = 0
        case maxTransfers
        case chunkSize
    }
    
    @IBOutlet var tableView: UITableView!

    lazy var sizeStyle = ByteCountFormatStyle(style: .file, allowedUnits: .kb, spellsOutZero: false)

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        title = NSLocalizedString("settings_advancedOptions", comment: "Advanced Options")
        
        // Table view
        tableView?.accessibilityIdentifier = "advancedOptions"
        tableView?.rowHeight = UITableView.automaticDimension
        tableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "Settings Bar"
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background

        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        tableView.separatorColor = PwgColor.separator
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
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
extension AdvancedOptionsViewController: UITableViewDataSource
{
    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        return pwgAvancedOptions.allCases.count
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create slider table view cell
        let cellIdentifier: String = traitCollection.preferredContentSizeCategory < .accessibilityMedium
            ? "SliderTableViewCell"
            : "SliderTableViewCell2"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? SliderTableViewCell
        else { preconditionFailure("Could not load SliderTableViewCell") }
        
        // Slider configuration
        switch pwgAvancedOptions(rawValue: indexPath.section) {
        case .maxPrepared:
            // Value
            let value = Float(UploadVars.shared.maxNberOfPreparedUploads)
            
            // Slider configuration
            cell.configure(with: NSLocalizedString("settings_advancedLimit", comment: "Limit"),
                           value: value, increment: 1, minValue: 1, maxValue: 10,
                           prefix: "", suffix: "")
            cell.cellSliderBlock = { newValue in
                // Update settings
                UploadVars.shared.maxNberOfPreparedUploads = Int16(newValue)
            }
            cell.accessibilityIdentifier = "maxPreparedUploads"
            
        case .maxTransfers:
            // Value
            let value = Float(UploadVars.shared.maxNberOfUploadTransfers)
            
            // Slider configuration
            cell.configure(with: NSLocalizedString("settings_advancedLimit", comment: "Limit"),
                           value: value, increment: 1, minValue: 1, maxValue: 8,
                           prefix: "", suffix: "")
            cell.cellSliderBlock = { newValue in
                // Update settings
                UploadVars.shared.maxNberOfUploadTransfers = Int16(newValue)
            }
            cell.accessibilityIdentifier = "maxUploadTransfers"
        
        case .chunkSize:
            // Value
            let value = Float(UploadVars.shared.customUploadChunkSize)
            
            // Slider configuration
            cell.configure(with: NSLocalizedString("settings_advancedChunkSize", comment: "Size"),
                           value: value, increment: 250*1000, minValue: 500*1000, maxValue: 5000*1000,
                           prefix: "", suffix: "", style: sizeStyle)
            cell.cellSliderBlock = { newValue in
                // Update settings
                UploadVars.shared.customUploadChunkSize = Int(newValue)
            }
            cell.accessibilityIdentifier = "chunkSize"
        
        default:
            preconditionFailure("!!! Invalid advanced upload option !!!")
        }
        
        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension AdvancedOptionsViewController: UITableViewDelegate
{
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        var title = "", text = ""
        switch pwgAvancedOptions(rawValue: section) {
        case .maxPrepared:
            title = NSLocalizedString("settings_advancedPreparedTitle", comment: "Upload Preparation") + "\n"
            text = NSLocalizedString("settings_advancedPreparedText", comment: "Please select the maximum number of uploads to prepare in advance.")
        case .maxTransfers:
            title = NSLocalizedString("settings_advancedTransfersTitle", comment: "File Transfers") + "\n"
            text = NSLocalizedString("settings_advancedTransfersText", comment: "Please select the maximum number of files to transfer simultaneously.")
        case .chunkSize:
            title = NSLocalizedString("settings_advancedChunksTitle", comment: "Chunk Size") + "\n"
            text = NSLocalizedString("settings_advancedChunksText", comment: "Please select the size of the chunks that files are split into during upload.")
        default:
            break
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - UITableView - Footer
    private func getContentOfFooter(inSection section: Int) -> String {
        var text = ""
        switch pwgAvancedOptions(rawValue: section) {
        case .maxPrepared:
            text = NSLocalizedString("settings_advancedPreparedDesc", comment: "A suitable value is one slightly above the maximum number of photos or videos you can upload at a time. Note that a higher limit will result in greater disk space usage.")
        case .maxTransfers:
            text = NSLocalizedString("settings_advancedTransfersDesc", comment: "A value of 4 is generally a good starting point. It is advisable to keep this number low, or to check with your hosting provider or network administrator. If you encounter timeout or 503 errors, try reducing this number.")
        case .chunkSize:
            let advice = (1000 * 1000).formatted(sizeStyle)
            let max = (5000 * 1000).formatted(sizeStyle)
            text = String(format: NSLocalizedString("settings_advancedChunkSizeDesc", comment: "A value of %@ is generally a good starting point. Fast connections will have better performances with high values, such as %@."), advice, max)
        default:
            break
        }
        return text
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.heightOfFooter(withText: footer, width: tableView.frame.width)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.viewOfFooter(withText: footer, alignment: .center)
    }
}
