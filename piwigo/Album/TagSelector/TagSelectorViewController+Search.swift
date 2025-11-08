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
    func initSearchBar(_ searchBar: UISearchBar) {
        // Initialisation
        searchBar.searchBarStyle = .minimal
        searchBar.isTranslucent = true
        searchBar.showsCancelButton = false
        searchBar.showsSearchResultsButton = false
        searchBar.placeholder = NSLocalizedString("tags", comment: "Tags")
        
        // Enable Dynamic Type
        searchBar.searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
        searchBar.searchTextField.adjustsFontForContentSizeCategory = true
    }
}


// MARK: - UISearchBarDelegate Methods
extension TagSelectorViewController: UISearchBarDelegate
{
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateSearchResults(for: searchController)
    }
}


// MARK: - UISearchResultsUpdating Methods
extension TagSelectorViewController: UISearchResultsUpdating
{
    func updateSearchResults(for searchController: UISearchController) {
        // Update query
        searchQuery = searchController.searchBar.text ?? ""

        // Update fetch request predicate
        fetchRequest.predicate = predicate.withSubstitutionVariables(getQueryVar())

        // Perform a new fetch
        try? tags.performFetch()

        // Shows filtered data
        tagsTableView.reloadData()
    }
}
