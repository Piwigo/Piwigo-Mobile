//
//  CategorySortViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit
import piwigoKit

protocol CategorySortDelegate: NSObjectProtocol {
    func didSelectCategorySortType(_ sortType: pwgImageSort)
}

class CategorySortViewController: UIViewController {
    
    weak var sortDelegate: (any CategorySortDelegate)?
    private lazy var currentDefaultSort = AlbumVars.shared.defaultSort
    
    @IBOutlet var sortSelectTableView: UITableView!
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Apply attributes to title
        title = NSLocalizedString("severalImages", comment: "Images")
        
        // Table view
        sortSelectTableView?.accessibilityIdentifier = "sortSelect"
        sortSelectTableView?.rowHeight = UITableView.automaticDimension
        sortSelectTableView?.estimatedRowHeight = TableViewUtilities.rowHeight
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "Settings Bar"
        
        // This view is called only if the Piwigo version < 14
        if AlbumVars.shared.defaultSort.rawValue > pwgImageSort.random.rawValue {
            AlbumVars.shared.defaultSort = .dateCreatedAscending
        }
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        sortSelectTableView.separatorColor = PwgColor.separator
        sortSelectTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        sortSelectTableView.reloadData()
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
        
        // Return selected album
        sortDelegate?.didSelectCategorySortType(currentDefaultSort)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - UITableViewDataSource Methods
extension CategorySortViewController: UITableViewDataSource {
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSort.allCases.count - 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell3", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        let sortChoice = pwgImageSort(rawValue: Int16(indexPath.row))!
        cell.configure(with: sortChoice.name, detail: "")
        if indexPath.row == 0 {
            cell.accessibilityIdentifier = "sortAZ"
        }
        if indexPath.row == currentDefaultSort.rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension CategorySortViewController: UITableViewDelegate {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images"))
        let text = NSLocalizedString("imageSortMessage", comment: "Please select how you wish to sort images")
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
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change the sort option
        let currentSort = Int(currentDefaultSort.rawValue)
        if indexPath.row == currentSort { return }

        // Update choice
        tableView.cellForRow(at: IndexPath(row: currentSort, section: 0))?.accessoryType = .none
        currentDefaultSort = pwgImageSort(rawValue: Int16(indexPath.row))!
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}
