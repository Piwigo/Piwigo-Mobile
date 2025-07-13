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

class CategorySortViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var sortDelegate: CategorySortDelegate?
    private lazy var currentDefaultSort = AlbumVars.shared.defaultSort

    @IBOutlet var sortSelectTableView: UITableView!


// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_albums", comment: "Albums")
        sortSelectTableView.accessibilityIdentifier = "sortSelect"
        navigationController?.navigationBar.accessibilityIdentifier = "CategorySortBar"

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // This view is called only if the Piwigo version < 14
        if AlbumVars.shared.defaultSort.rawValue > pwgImageSort.random.rawValue {
            AlbumVars.shared.defaultSort = .dateCreatedAscending
        }
    }

    @MainActor
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
        sortSelectTableView.separatorColor = .piwigoColorSeparator()
        sortSelectTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        sortSelectTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
    
    
    // MARK: - UITableView - Header
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

    
    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pwgImageSort.allCases.count - 3
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let sortChoice = pwgImageSort(rawValue: Int16(indexPath.row))!

        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
        cell.textLabel?.text = sortChoice.name
        cell.textLabel?.minimumScaleFactor = 0.5
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
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

    
    // MARK: - UITableViewDelegate Methods
    
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
