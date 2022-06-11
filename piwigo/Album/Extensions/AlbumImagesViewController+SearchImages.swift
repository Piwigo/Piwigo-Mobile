//
//  AlbumImagesViewController+SearchImages.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: UISearchBarDelegate Methods
extension AlbumImagesViewController: UISearchBarDelegate
{
    public func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Animates Cancel button appearance
        searchBar.setShowsCancelButton(true, animated: true)
        return true
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Title forgotten when searching immediately after launch
        if categoryId == 0 {
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        } else {
            title = CategoriesData.sharedInstance().getCategoryById(categoryId).name
        }
                
        // Animates Cancel button disappearance
        searchBar.setShowsCancelButton(false, animated: true)
    }
}


// MARK: - UISearchResultsUpdating Methods
extension AlbumImagesViewController: UISearchResultsUpdating
{
    public func updateSearchResults(for searchController: UISearchController) {
        // Query string
        guard let searchString =  searchController.searchBar.text else { return }
        
        // Resfresh image collection for new query only
        if let resultsController = searchController.searchResultsController as? SearchImagesViewController,
           resultsController.searchQuery != searchString || searchString.isEmpty  {
            // Cancel active image downloads if any
            NetworkVarsObjc.imagesSessionManager?.tasks.forEach({ task in
                task.cancel()
            })

            // Initialise search cache
            let searchAlbum = PiwigoAlbumData.init(searchAlbumForQuery: searchString)!
            CategoriesData.sharedInstance().updateCategories([searchAlbum])

            // Resfresh image collection
            resultsController.searchQuery = searchString
            resultsController.searchAndLoadImages()
        }
    }
}
