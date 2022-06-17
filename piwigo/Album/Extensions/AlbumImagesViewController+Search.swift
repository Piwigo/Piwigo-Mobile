//
//  AlbumImagesViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Search Images
extension AlbumImagesViewController
{
    @available(iOS 11.0, *)
    func initSearchBar() {
        let resultsCollectionController = SearchImagesViewController()
        let searchController = UISearchController(searchResultsController: resultsCollectionController)
        searchController.delegate = self
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchResultsUpdater = self

        searchController.searchBar.searchBarStyle = .minimal
        searchController.searchBar.isTranslucent = false
        searchController.searchBar.showsCancelButton = false
        searchController.searchBar.showsSearchResultsButton = false
        searchController.searchBar.tintColor = UIColor.piwigoColorOrange()
        searchController.searchBar.delegate = self // Monitor when the search button is tapped.
        definesPresentationContext = true

        // Place the search bar in the navigation bar.
        navigationItem.searchController = searchController

        // Hide the search bar when scrolling
        navigationItem.hidesSearchBarWhenScrolling = true
    }
}

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
            let searchAlbum = PiwigoAlbumData(id: kPiwigoSearchCategoryId, andQuery: searchString)!
            CategoriesData.sharedInstance().updateCategories([searchAlbum])

            // Resfresh image collection
            resultsController.searchQuery = searchString
            resultsController.searchAndLoadImages()
        }
    }
}
