//
//  TagsViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Search Images
extension TagsViewController
{
    func initSearchBar() {
        searchController.obscuresBackgroundDuringPresentation = false

        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.isTranslucent = false
        searchController.searchBar.showsSearchResultsButton = false
        searchController.searchBar.placeholder = NSLocalizedString("tags", comment: "Tags")
        searchController.searchBar.delegate = self
        searchController.hidesNavigationBarDuringPresentation = false
        if #unavailable(iOS 26.0) {
            // Fallback on previous version
            searchController.searchBar.showsCancelButton = false
            if #available(iOS 16.0, *) {
                switch view.traitCollection.userInterfaceIdiom {
                case .phone:
                    navigationItem.preferredSearchBarPlacement = .stacked
                case .pad:
                    navigationItem.preferredSearchBarPlacement = .inline
                default:
                    break
                }
            }
        }
        definesPresentationContext = true
        searchController.searchResultsUpdater = self
        
        // Place the search bar in the header of the tableview
        tagsTableView.tableHeaderView = searchController.searchBar
    }
}


// MARK: - UISearchResultsUpdating Methods
extension TagsViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController) {
        if let query = searchController.searchBar.text {
            // Update persistent query string
            searchQuery = query

            // Do not update content before pushing view in tableView(_:didSelectRowAt:)
            if searchController.isActive {
                // Update fetch requests and perform fetches
                fetchSelectedTagsRequest.predicate = selectedTagsPredicate.withSubstitutionVariables(getSelectedVars())
                try? selectedTags.performFetch()
                fetchNonSelectedTagsRequest.predicate = nonSelectedTagsPredicate.withSubstitutionVariables(getNonSelectedVars())
                try? nonSelectedTags.performFetch()

                // Shows filtered data
                tableView.reloadData()
            }
        }
    }
}


// MARK: - UISearchBarDelegate Methods
extension TagsViewController: UISearchBarDelegate
{
    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Animates Cancel button appearance
        searchBar.setShowsCancelButton(true, animated: true)
        return true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Animates Cancel button disappearance
        searchBar.setShowsCancelButton(false, animated: true)

        // Update persistent query string
        searchQuery = ""

        // Update fetch requests and perform fetches
        fetchSelectedTagsRequest.predicate = selectedTagsPredicate.withSubstitutionVariables(getSelectedVars())
        try? selectedTags.performFetch()
        fetchNonSelectedTagsRequest.predicate = nonSelectedTagsPredicate.withSubstitutionVariables(getNonSelectedVars())
        try? nonSelectedTags.performFetch()

        // Reload tableview
        tableView.reloadData()
    }
}
