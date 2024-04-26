//
//  AlbumImageTableViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - Search Images
extension AlbumImageTableViewController
{
    func initSearchBar() {
        searchController = UISearchController(searchResultsController: nil)
        searchController?.delegate = self
        searchController?.hidesNavigationBarDuringPresentation = true

        searchController?.searchBar.searchBarStyle = .minimal
        searchController?.searchBar.isTranslucent = false
        searchController?.searchBar.showsCancelButton = false
        searchController?.searchBar.showsSearchResultsButton = false
        searchController?.searchBar.tintColor = UIColor.piwigoColorOrange()
        searchController?.searchBar.delegate = self // Monitor when the search button is tapped.
        definesPresentationContext = true

        // Place the search bar in the navigation bar.
        navigationItem.searchController = searchController

        // Hide the search bar when scrolling
        navigationItem.hidesSearchBarWhenScrolling = false
    }
}


// MARK: - UISearchControllerDelegate
extension AlbumImageTableViewController: UISearchControllerDelegate
{
//    func presentSearchController(_ searchController: UISearchController) {
//        debugPrint("presentSearchController…")
//    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
//        debugPrint("willPresentSearchController…")
        // Switch to Search album
        categoryId = pwgSmartAlbum.search.rawValue
        
        // Initialise albumData
        albumData = albumProvider.getAlbum(ofUser: user, withId: categoryId)!
        resetSearchAlbum(withQuery: "")
        
        // Update albums and images
        resetPredicatesAndPerformFetch()
        
        // Reload collection
        albumImageTableView.reloadData()
        
        // Hide buttons and toolbar
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
        navigationController?.setToolbarHidden(true, animated: true)
    }
        
    func willDismissSearchController(_ searchController: UISearchController) {
//        debugPrint("willDismissSearchController…")
        // Back to default album
        categoryId = AlbumVars.shared.defaultCategory
        
        // Title forgotten when searching immediately after launch
        title = NSLocalizedString("tabBar_albums", comment: "Albums")
        
        // Reset navigation bar
        applyColorPalette()
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        debugPrint("didDismissSearchController…")
        // Update albumData
        albumData = albumProvider.getAlbum(ofUser: user, withId: categoryId)!
        
        // Update albums and images
        resetPredicatesAndPerformFetch()
        
        // Reload collection
        albumImageTableView.reloadData()
        
        // Show buttons
        initBarsInPreviewMode()
        updateBarsInPreviewMode()
    }
    
    func resetSearchAlbum(withQuery query: String) {
        // Reset search album
        albumData.query = query
        albumData.nbImages = query.isEmpty ? Int64.zero : Int64.min
        albumData.totalNbImages = query.isEmpty ? Int64.zero : Int64.min
        
        // Remove images
        if let images = albumData.images {
            albumData.removeFromImages(images)
        }
        try? mainContext.save()
    }
}


// MARK: - UISearchBarDelegate Methods
extension AlbumImageTableViewController: UISearchBarDelegate
{
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Animates Cancel button appearance
        searchBar.setShowsCancelButton(true, animated: true)
        // Pause image loader and store parameters
        pauseSearch = true
        return true
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        // Dismiss keyboard
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        // Get query string
        guard let query = searchBar.text else { return }
        
        // Did the query string change?
        if albumData.query == query {
            // Continue downloading images
            // Load next page of images
            self.fetchImages(withInitialImageIds: self.oldImageIds, query: query,
                             fromPage: self.onPage + 1, toPage: self.lastPage) {
                self.fetchCompleted()
            }
            return
        }
        
        // Cancel active image data session if any
        ClearCache.cancelTasks {
            DispatchQueue.main.async {
                // Reset search
                self.pauseSearch = false
                self.resetSearchAlbum(withQuery: query)
                
                // The query string has changed
                self.albumCollectionVC.updateNberOfImagesInFooter()
                
                // Determine if the session is active before fetching
                NetworkUtilities.checkSession(ofUser: self.user) {
                    self.startFetchingAlbumAndImages(withHUD: true)
                } failure: { error in
                    // Session logout required?
                    if let pwgError = error as? PwgSessionError,
                       [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                        .contains(pwgError) {
                        ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                        return
                    }
                    
                    // Report error
                    let title = "Error \(error.code)"
                    self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) {}
                }
            }
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Animates Cancel button disappearance
        searchBar.setShowsCancelButton(false, animated: true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if #available(iOS 13, *) {
            // NOP
        } else {
            // Dismiss seach bar on iOS 12 only
            navigationController?.navigationBar.prefersLargeTitles = false
            searchController?.dismiss(animated: true, completion: nil)
        }
    }
}
