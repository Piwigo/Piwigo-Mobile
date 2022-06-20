//
//  TagSelectorViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Search Images
@available(iOS 11.0, *)
extension TagSelectorViewController
{
    func initSearchBar() {
        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.isTranslucent = false
        searchController.searchBar.showsCancelButton = false
        searchController.searchBar.showsSearchResultsButton = false
        searchController.searchBar.tintColor = UIColor.piwigoColorOrange()
        searchController.searchBar.placeholder = NSLocalizedString("tags", comment: "Tags")
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false

        // Place the search bar in the header of the tableview
        tagsTableView.tableHeaderView = searchController.searchBar
    }
}


// MARK: - UISearchResultsUpdating Methods
@available(iOS 11.0, *)
extension TagSelectorViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController) {
        if let query = searchController.searchBar.text {
            // Update query
            searchQuery = query

            // Do not update content before pushing view in tableView(_:didSelectRowAt:)
            if searchController.isActive {
                // Shows filtered data
                tableView.reloadData()
            }
        }
    }
}


// MARK: - UISearchBarDelegate Methods
@available(iOS 11.0, *)
extension TagSelectorViewController: UISearchBarDelegate
{
    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Animates Cancel button appearance
        searchBar.setShowsCancelButton(true, animated: true)
        return true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Animates Cancel button disappearance
        searchBar.setShowsCancelButton(false, animated: true)
    }
}
