//
//  AlbumViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

// MARK: - Search Images
extension AlbumViewController
{
    func initSearchBar() {
        searchController = UISearchController(searchResultsController: nil)
        searchController?.delegate = self

        searchController?.searchBar.searchBarStyle = .minimal
        searchController?.searchBar.isTranslucent = false
        searchController?.searchBar.showsSearchResultsButton = false
        searchController?.searchBar.delegate = self // Monitor when the search button is tapped.
        if #available(iOS 26.0, *) {
            // UISearchController automatically manages the Cancel button's visibility
            // when embedded in the navigation bar.
            // Explicitly setting showsCancelButton = true in iOS 26 is conflicting
            // with this automatic behavior.
            searchController?.hidesNavigationBarDuringPresentation = false
        } else {
            // Fallback on previous version
            searchController?.searchBar.showsCancelButton = false
            searchController?.hidesNavigationBarDuringPresentation = true
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
        
        // Enable Dynamic Type
        if let textField = searchController?.searchBar.searchTextField as? UITextField {
            textField.font = UIFont.preferredFont(forTextStyle: .body)
            textField.adjustsFontForContentSizeCategory = true
        }

        // Place the search bar in the navigation bar.
        navigationItem.searchController = searchController

        // Don't hide the search bar when scrolling
        navigationItem.hidesSearchBarWhenScrolling = false
    }
}


// MARK: - UISearchControllerDelegate
extension AlbumViewController: UISearchControllerDelegate
{
    func willPresentSearchController(_ searchController: UISearchController) {
        #if DEBUG
        debugPrint("willPresentSearchController…")
        #endif
        // Switch to Search album
        categoryId = pwgSmartAlbum.search.rawValue
        
        // Initialise albumData
        albumData = (try? AlbumProvider().getOrCreateProperties(ofAlbumWithID: categoryId, inContext: mainContext))!
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
        #if DEBUG
        debugPrint("didPresentSearchController")
        #endif
        searchController.becomeFirstResponder()
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        #if DEBUG
        debugPrint("willDismissSearchController…")
        #endif
        // Deselect photos if needed
        cancelSelect()

        // Re-allow fetching image data
        imageProvider.userDidCancelSearch = false

        // Back to default album
        categoryId = AlbumVars.shared.defaultCategory
        
        // Title forgotten when searching immediately after launch
        title = Localized.tabBar_albums
        
        // Reset navigation bar
        applyColorPalette()
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        #if DEBUG
        debugPrint("didDismissSearchController…")
        #endif
        // Update albumData
        albumData = AlbumProvider().getProperties(ofAlbumWithID: categoryId, inContext: mainContext)!
        
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
        guard let album = albumProvider.getAlbum(withID: categoryId, inContext: mainContext)
        else { preconditionFailure("••> Search album not found!!!") }

        // Reset search album
       album.query = query
       album.nbImages = query.isEmpty ? Int64.zero : Int64.min
       album.totalNbImages = query.isEmpty ? Int64.zero : Int64.min

        // Remove images
        if let images = album.images {
            album.removeFromImages(images)
        }
        
        // Update album properties
        albumData = album.getProperties()
        mainContext.saveIfNeeded()
        
        // Hides "no album/photo" label
        noAlbumLabel.isHidden = true
    }
}


// MARK: - UISearchBarDelegate Methods
extension AlbumViewController: UISearchBarDelegate
{
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        #if DEBUG
        debugPrint("searchBar textDidChange…")
        #endif
        // Pause image loader and stop importing images
        imageProvider.userDidCancelSearch = true
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        #if DEBUG
        debugPrint("searchBarShouldBeginEditing…")
        #endif
        
        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(true, animated: true)
        }
        return true
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        #if DEBUG
        debugPrint("searchBarShouldEndEditing…")
        #endif
        // Dismiss keyboard
        return true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        #if DEBUG
        debugPrint("searchBarTextDidEndEditing…")
        #endif
        // Will fetch images and accept imports
        imageProvider.userDidCancelSearch = false

        // Get query string
        guard let query = searchBar.text, query.isEmpty == false
        else { return }
        
        // Did the query string change?
        if albumData.query == query {
            // Restart loading pages of images
            Task {
                // Remember that the app is fetching all album data
                // until the fetch completes or the fetch or the import below throws an error
                AlbumVars.shared.isFetchingAlbumData.insert(categoryId)
                defer { AlbumVars.shared.isFetchingAlbumData.remove(categoryId) }

                await self.fetchImages(withInitialImageIds: self.oldImageIDs, query: query,
                                       fromPage: self.onPage, toPage: self.lastPage)
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
        #if DEBUG
        debugPrint("searchBarCancelButtonClicked…")
        #endif
        // Stop image loader and image import
        imageProvider.userDidCancelSearch = true

        // The paused fetch will not be resumed
        // ► Remove current album from list of albums being fetched
        AlbumVars.shared.isFetchingAlbumData.remove(categoryId)

        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        #if DEBUG
        debugPrint("searchBarSearchButtonClicked…")
        #endif
        
        // Animates Cancel button appearance
        if #unavailable(iOS 26.0) {
            // NOP — See initSearchBar() comment
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
}
