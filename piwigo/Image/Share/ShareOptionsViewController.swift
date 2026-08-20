//
//  ShareOptionsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/08/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import UIKit
import PwgKit
import PwgCacheKit
import PwgUIKit

/// Lets the user choose what is handed over before the share sheet is presented.
/// The choice cannot be proposed afterwards: the type and the size of the item given to
/// UIActivityViewController decide which activities it proposes and what they receive.
class ShareOptionsViewController: UIViewController {
    
    /// Called with the chosen options, or with nil when the user gave up.
    /// A closure rather than a delegate because the presenters are extensions,
    /// which cannot store the state the callback needs.
    var completion: ((ShareOptions?) -> Void)?
    
    @IBOutlet var optionsTableView: UITableView!
    
    /// Images about to be shared, used to label the rows with the dimensions
    /// the user will actually get and to hide the sections which cannot change anything.
    var images = [Image]()
    
    private var options = ShareOptions.lastUsed
    private var hasFormatSection = false
    private var hasSizeSection = false
    private var originalResolution: CGSize?
    private var optimisedResolution: CGSize?
    private var didShare = false
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title and buttons
        title = String(localized: "shareOptions_title", comment: "Title of the view proposing what to share, presented before the share sheet")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self,
                                                           action: #selector(cancelShare))
        navigationItem.rightBarButtonItem = UIBarButtonItem.shareImageButton(self, action: #selector(share))
        
        // Which sections can change something for this selection?
        let sections = ShareUtilities.optionsToPropose(for: images)
        hasFormatSection = sections.format

        // Dimensions shown in the Size section
        let resolutions = ShareUtilities.resolutions(of: images)
        originalResolution = resolutions.original
        optimisedResolution = resolutions.optimised

        // The Size section is pointless when the optimised size is the original one
        hasSizeSection = sections.size
            && ShareUtilities.isOptimisedSizeWorthProposing(original: originalResolution,
                                                            optimised: optimisedResolution)
        
        // Table view
        optionsTableView?.accessibilityIdentifier = "Share Options"
        optionsTableView?.rowHeight = UITableView.automaticDimension
        optionsTableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "Share Options Bar"
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar appearence
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        if #available(iOS 26.0, *) {
            navigationItem.leftBarButtonItem?.tintColor = PwgColor.tintColor
            navigationItem.rightBarButtonItem?.tintColor = PwgColor.tintColor
        }
        
        // Table view
        optionsTableView?.separatorColor = PwgColor.separator
        optionsTableView?.indicatorStyle = UIVars.shared.isDarkPaletteActive ? .white : .black
        optionsTableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Tell the presenter that the user gave up, unless they asked to share.
        /// Covers the swipe-down dismissal, which does not go through the Cancel button.
        if didShare == false {
            completion?(nil)
        }
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Buttons
    @objc func cancelShare() {
        // Remember the choice for the next share
        ShareOptions.lastUsed = options
        dismiss(animated: true)
    }
    
    @objc func share() {
        // Remember the choice for the next share
        didShare = true
        ShareOptions.lastUsed = options
        
        // Present the share sheet once this view is dismissed
        let options = self.options
        dismiss(animated: true) { [self] in
            completion?(options)
        }
    }
    
    
    // MARK: - Sections
    private enum Section: Int {
        case format, metadata, size
    }
    
    /// The sections which cannot change anything for this selection are not proposed.
    private var sections: [Section] {
        var sections = [Section]()
        if hasFormatSection { sections.append(.format) }
        sections.append(.metadata)
        if hasSizeSection { sections.append(.size) }
        return sections
    }
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Animated update for smoother experience
            self.optionsTableView?.beginUpdates()
            self.optionsTableView?.endUpdates()

            // Update navigation bar
            self.navigationController?.navigationBar.configAppearance(withLargeTitles: true)
        }
    }
}


// MARK: - UITableViewDataSource Methods
extension ShareOptionsViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2    // Each section proposes two options
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        switch sections[indexPath.section] {
        case .format:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "LabelTableViewCell"
                : "LabelTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            
            let format: pwgShareFormat = indexPath.row == 0 ? .original : .mostCompatible
            let title = format == .original
                ? String(localized: "shareOptions_formatOriginal", comment: "Share the file in its original format — adjective agreeing with 'Format', the section header")
                : String(localized: "shareOptions_formatCompatible", comment: "Share the file in a format any app can read — adjective agreeing with 'Format', the section header")
            cell.configure(with: title, detail: "")
            cell.accessoryType = options.format == format ? .checkmark : .none
            cell.accessibilityIdentifier = "shareFormat"
            return cell
            
        case .metadata:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load SwitchTableViewCell") }
            
            if indexPath.row == 0 {
                cell.configure(with: String(localized: "shareOptions_location", comment: "Switch keeping or dropping the place where the photo was taken"))
                cell.cellSwitch.setOn(options.keepsLocation, animated: false)
                cell.cellSwitchBlock = { [weak self] isOn in
                    self?.options.keepsLocation = isOn
                }
                cell.accessibilityIdentifier = "shareLocation"
            } else {
                cell.configure(with: String(localized: "shareOptions_contactInfo", comment: "Switch keeping or dropping the name and contact info of the author of the photo"))
                cell.cellSwitch.setOn(options.keepsContactInfo, animated: false)
                cell.cellSwitchBlock = { [weak self] isOn in
                    self?.options.keepsContactInfo = isOn
                }
                cell.accessibilityIdentifier = "shareContactInfo"
            }
            return cell
            
        case .size:
            let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
                ? "LabelTableViewCell"
                : "LabelTableViewCell2"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            
            let size: pwgShareSize = indexPath.row == 0 ? .original : .optimised
            let title = size == .original
                      ? String(localized: "shareOptions_sizeOriginal", comment: "Share the file in its original resolution — adjective agreeing with 'Size', the section header")
                      : String(localized: "shareOptions_sizeOptimised", comment: "Share the file in a smaller resolution, downloaded faster — adjective agreeing with 'Size', the section header")
            let resolution = size == .original ? originalResolution : optimisedResolution
            cell.configure(with: title, detail: ShareUtilities.dimensions(of: resolution))
            cell.accessoryType = options.size == size ? .checkmark : .none
            cell.accessibilityIdentifier = "shareSize"
            return cell
        }
    }
}


// MARK: - UITableViewDelegate Methods
extension ShareOptionsViewController: UITableViewDelegate
{
    // MARK: - Header
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        switch sections[section] {
        case .format:
            return (String(format: "%@\n", String(localized: "shareOptions_format", comment: "Header of the section proposing to share files in their original or most compatible format — noun with which 'Original' and 'Most Compatible' agree")),
                    String(localized: "shareOptions_formatInfo", comment: "The most compatible format can be read by any app."))
        case .metadata:
            return (String(format: "%@\n", String(localized: "shareOptions_metadata", comment: "Header of the section proposing to share or drop the location and the author's contact info stored in the files")),
                    String(localized: "shareOptions_metadataInfo", comment: "Camera and lens serial numbers are always removed."))
        case .size:
            return (String(format: "%@\n", String(localized: "shareOptions_size", comment: "Header of the section proposing to share files in their original or optimised size — noun with which 'Original' and 'Optimised' agree")),
                    String(localized: "shareOptions_sizeInfo", comment: "The optimised size is downloaded faster."))
        }
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


    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Only the Format and Size sections propose a choice between two rows
        switch sections[indexPath.section] {
        case .format:
            options.format = indexPath.row == 0 ? .original : .mostCompatible
        case .metadata:
            return
        case .size:
            options.size = indexPath.row == 0 ? .original : .optimised
        }

        // Move the checkmark to the tapped row.
        /// The cells are updated in place: reloading the section would also rebuild
        /// its header, which is unchanged and would visibly flicker.
        for row in 0..<tableView.numberOfRows(inSection: indexPath.section) {
            let cell = tableView.cellForRow(at: IndexPath(row: row, section: indexPath.section))
            cell?.accessoryType = row == indexPath.row ? .checkmark : .none
        }
    }
}
