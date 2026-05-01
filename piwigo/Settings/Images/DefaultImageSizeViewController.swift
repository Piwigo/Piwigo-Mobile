//
//  DefaultImageSizeViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 5/12/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 05/04/2020.
//

import UIKit
import piwigoKit

protocol DefaultImageSizeDelegate: NSObjectProtocol {
    func didSelectImageDefaultSize(_ imageSize: pwgImageSize)
}

class DefaultImageSizeViewController: UIViewController {
    
    weak var delegate: (any DefaultImageSizeDelegate)?
    private lazy var currentImageSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .fullRes
    private lazy var optimumSize = ImageUtilities.optimumImageSizeForDevice()
    private lazy var scale = CGFloat(fmax(1.0, self.view.traitCollection.displayScale))
    
    @IBOutlet var tableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("severalImages", comment: "Images")

        // Table view
        tableView?.accessibilityIdentifier = "Image Preview Size"
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
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Return selected image thumbnail size
        delegate?.didSelectImageDefaultSize(currentImageSize)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension DefaultImageSizeViewController: UITableViewDataSource {
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSize.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let contentSizeCategory = traitCollection.preferredContentSizeCategory
        let cellIdentifier: String = contentSizeCategory < .accessibilityMedium
            ? "LabelTableViewCell"
            : "LabelTableViewCell2"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }

        // Add checkmark in front of selected item
        let imageSize = pwgImageSize(rawValue: Int16(indexPath.row)) ?? .fullRes
        let isSelected = imageSize == currentImageSize

        // Disable unavailable sizes
        configCell(cell, forSize: imageSize, selected: isSelected)

        return cell
    }
    
    private func configCell(_ cell: LabelTableViewCell, forSize size: pwgImageSize,
                            selected: Bool = false) {
        switch size {
        case .square, .thumb, .xxSmall, .xSmall, .small:
            configCell(cell, forSize: size, selectable: false)
        case .medium, .large, .xLarge, .xxLarge, .xxxLarge, .xxxxLarge, .fullRes:
            configCell(cell, forSize: size, selectable: true, selected: selected)
        }
    }
    
    private func configCell(_ cell: LabelTableViewCell, forSize size: pwgImageSize,
                            selectable: Bool, selected: Bool = false) {
        // Selected?
        cell.accessoryType = selected ? .checkmark : .none
        
        // Available?
        guard size.isAvailable
        else {
            cell.configure(with: size.name, detail: " ")
            cell.titleLabel.textColor = cell.detailLabel.textColor
            cell.isUserInteractionEnabled = false
            return
        }
        
        // Optimum?
        if size == optimumSize {
            let detail = NSLocalizedString("defaultImageSize_recommended", comment: "(recommended)")
            cell.configure(with: size.name, detail: detail)
        } else {
            cell.configure(with: size.name, detail: size.sizeAndScale(forScale: scale))
        }
        
        // Selectable?
        cell.isUserInteractionEnabled = selectable
        if selectable == false {
            // Colour must be changed after configuration
            cell.titleLabel.textColor = cell.detailLabel.textColor
        }
    }
}


// MARK: - UITableViewDelegate Methods
extension DefaultImageSizeViewController: UITableViewDelegate {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("defaultPreviewFile>414px", comment: "Preview Image File"))
        let text = NSLocalizedString("defaultImageSizeHeader", comment: "Please select an image size")
        return (title, text)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.viewOfHeader(withTitle: title, text: text)
    }

    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change of default size
        guard let selectedSize = pwgImageSize(rawValue: Int16(indexPath.row)) else { return }
        if selectedSize == currentImageSize { return }

        // Update deselected cell
        let deselectedIndexPath = IndexPath(row: Int(currentImageSize.rawValue), section: 0)
        if let cell = tableView.cellForRow(at: deselectedIndexPath) as? LabelTableViewCell {
            configCell(cell, forSize: currentImageSize, selected: false)
        }
        
        // Update selected cell
        currentImageSize = selectedSize
        if let cell = tableView.cellForRow(at: indexPath) as? LabelTableViewCell {
            configCell(cell, forSize: selectedSize, selected: true)
        }
    }


    // MARK: - Footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.heightOfFooter(withText: footer, width: tableView.frame.width)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = NSLocalizedString("defaultSizeFooter", comment: "Greyed sizes are not advised or not available on Piwigo server.")
        return TableViewUtilities.viewOfFooter(withText: footer, alignment: .center)
    }
}
