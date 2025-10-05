//
//  TagSelectorViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Search Images
extension TagSelectorViewController
{
    func initSearchBar() {
        searchController.obscuresBackgroundDuringPresentation = false

        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.isTranslucent = false
        searchController.searchBar.showsSearchResultsButton = false
        searchController.searchBar.placeholder = NSLocalizedString("tags", comment: "Tags")
        searchController.searchBar.delegate = self
        searchController.searchBar.searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
        searchController.searchBar.searchTextField.adjustsFontSizeToFitWidth = true
        searchController.searchResultsUpdater = self
        if #available(iOS 26.0, *) {
            searchController.searchBar.showsCancelButton = false
            searchController.hidesNavigationBarDuringPresentation = false
        } else {
            searchController.searchBar.showsCancelButton = false
            searchController.hidesNavigationBarDuringPresentation = true
        }
        
        // Enable Dynamic Type
        searchController.searchBar.searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
        searchController.searchBar.searchTextField.adjustsFontForContentSizeCategory = true
        
        // Place the search bar in the header of the tableview
        tagsTableView.tableHeaderView = searchController.searchBar
    }
}


// MARK: - UISearchResultsUpdating Methods
extension TagSelectorViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController) {
        if let query = searchController.searchBar.text {
            // Update query
            searchQuery = query

            // Do not update content before pushing view in tableView(_:didSelectRowAt:)
            if searchController.isActive {
                // Update fetch request predicate
                fetchRequest.predicate = predicate.withSubstitutionVariables(getQueryVar())

                // Perform a new fetch
                try? tags.performFetch()

                // Shows filtered data
                tableView.reloadData()
            }
        }
    }
}


// MARK: - UISearchBarDelegate Methods
extension TagSelectorViewController: UISearchBarDelegate
{
    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            searchBar.setShowsCancelButton(true, animated: true)
        }
        return true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Animates Cancel button disappearance
        if #unavailable(iOS 26.0) {
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
}
