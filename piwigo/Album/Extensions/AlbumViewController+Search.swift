//
//  AlbumViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - Search Images
extension AlbumViewController
{
    func initSearchBar() {
        searchController = UISearchController(searchResultsController: nil)
        searchController?.delegate = self
        searchController?.hidesNavigationBarDuringPresentation = true

        searchController?.searchBar.searchBarStyle = .minimal
        searchController?.searchBar.isTranslucent = false
        if #unavailable(iOS 26.0) {
            // UISearchController automatically manages the Cancel button's visibility
            // when embedded in the navigation bar.
            // Explicitly setting showsCancelButton = true in iOS 26 is conflicting
            // with this automatic behavior.
            searchController?.searchBar.showsCancelButton = false
        }
        searchController?.searchBar.showsSearchResultsButton = false
        searchController?.searchBar.delegate = self // Monitor when the search button is tapped.
        definesPresentationContext = true

        // Place the search bar in the navigation bar.
        navigationItem.searchController = searchController

        // Don't hide the search bar when scrolling
        navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 26.0, *) {
            navigationItem.searchBarPlacementAllowsToolbarIntegration =  true
            navigationItem.preferredSearchBarPlacement = .integratedButton
        } else {
            // Fallback on earlier versions
            if #available(iOS 16.0, *) {
                navigationItem.preferredSearchBarPlacement = .stacked
            }
        }
    }
}


// MARK: - UISearchControllerDelegate
extension AlbumViewController: UISearchControllerDelegate
{
    func willPresentSearchController(_ searchController: UISearchController) {
        debugPrint("willPresentSearchController…")
        // Switch to Search album
        categoryId = pwgSmartAlbum.search.rawValue
        
        // Initialise albumData
        albumData = albumProvider.getAlbum(ofUser: user, withId: categoryId)!
        resetSearchAlbum(withQuery: "")
        
        // Update albums and images
        resetPredicatesAndPerformFetch()
        
        // Reload collection
        collectionView?.reloadData()
        
        // Adjust the interface
        if #available(iOS 26.0, *) {
            // Integrate the search bar into the toolbar
            initBarsInPreviewMode()
        }
        else {
            // Hide buttons and toolbar
            hideButtons()
            initBarsInPreviewMode()
            setTitleViewFromAlbumData()
        }
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        debugPrint("didPresentSearchController")
        searchController.becomeFirstResponder()
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        debugPrint("willDismissSearchController…")
        // Deselect photos if needed
        cancelSelect()

        // Back to default album
        categoryId = AlbumVars.shared.defaultCategory
        
        // Title forgotten when searching immediately after launch
        title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
        
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
        collectionView?.reloadData()
        
        // Show buttons and navigation bar
        if #unavailable(iOS 26.0) {
            updateButtons()
        }
        initBarsInPreviewMode()
        setTitleViewFromAlbumData()
    }
    
    private func resetSearchAlbum(withQuery query: String) {
        // Reset search album
        albumData.query = query
        albumData.nbImages = query.isEmpty ? Int64.zero : Int64.min
        albumData.totalNbImages = query.isEmpty ? Int64.zero : Int64.min
        
        // Remove images
        if let images = albumData.images {
            albumData.removeFromImages(images)
        }
        mainContext.saveIfNeeded()
        
        // Hides "no album/photo" label
        noAlbumLabel.isHidden = true
    }
}


// MARK: - UISearchBarDelegate Methods
extension AlbumViewController: UISearchBarDelegate
{
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchBar textDidChange…")
        // Pause image loader and stop importing images
        imageProvider.userDidCancelSearch = true
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        debugPrint("searchBarShouldBeginEditing…")
        
        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(true, animated: true)
        }
        return true
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        debugPrint("searchBarShouldEndEditing…")
        // Dismiss keyboard
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        debugPrint("searchBarTextDidEndEditing…")
        // Will fetch images and accept imports
        imageProvider.userDidCancelSearch = false

        // Get query string
        guard let query = searchBar.text else { return }
        
        // Did the query string change?
        if albumData.query == query {
            // Restart loading pages of images
            self.fetchImages(withInitialImageIds: self.oldImageIDs, query: query,
                             fromPage: self.onPage, toPage: self.lastPage) { [self] in
                self.fetchCompleted()
            }
            return
        }
        
        // Reset search
        resetSearchAlbum(withQuery: query)
        
        // The query string has changed
        updateNberOfImagesInFooter()
        
        // Fetch album/image data after checking session
        self.startFetchingAlbumAndImages(withHUD: true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        debugPrint("searchBarCancelButtonClicked…")
        // Stop image loader and image import
        imageProvider.userDidCancelSearch = true

        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        debugPrint("searchBarSearchButtonClicked…")
        
        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
}
