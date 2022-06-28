//
//  AlbumViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Search Images
extension AlbumViewController
{
    @available(iOS 11.0, *)
    func initSearchBar() {
        let searchController = UISearchController(searchResultsController: nil)
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

extension AlbumViewController: UISearchControllerDelegate
{
//    func presentSearchController(_ searchController: UISearchController) {
//        debugPrint("presentSearchController…")
//    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        debugPrint("willPresentSearchController…")
        // Reset album data -> Search album
        categoryId = kPiwigoSearchCategoryId
        albumData = AlbumData(categoryId: categoryId, andQuery: "")
        
        // Hide buttons and toolbar
        updateButtonsInPreviewMode()
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
//    func didPresentSearchController(_ searchController: UISearchController) {
//        debugPrint("didPresentSearchController…")
//    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        debugPrint("willDismissSearchController…")
        // Back to default album
        categoryId = AlbumVars.shared.defaultCategory
        albumData = AlbumData(categoryId: categoryId, andQuery: "")

        // Title forgotten when searching immediately after launch
        if categoryId == 0 {
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        } else {
            title = CategoriesData.sharedInstance().getCategoryById(categoryId).name
        }
        
        // Reset navigation bar
        applyColorPalette()
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        debugPrint("didDismissSearchController…")
        // Reload collection
        imagesCollection?.reloadData()

        // Show buttons
        updateButtonsInPreviewMode()
    }
}


// MARK: UISearchBarDelegate Methods
extension AlbumViewController: UISearchBarDelegate
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


// MARK: - UISearchResultsUpdating Methods
extension AlbumViewController: UISearchResultsUpdating
{
    public func updateSearchResults(for searchController: UISearchController) {
        // Query string
        guard let searchString =  searchController.searchBar.text else { return }
        
        // Resfresh image collection for new query only
        if albumData?.searchQuery != searchString || searchString.isEmpty  {
            // Cancel active image downloads if any
            NetworkVarsObjc.imagesSessionManager?.tasks.forEach({ task in
                task.cancel()
            })

            // Initialise search cache
            let searchAlbum = PiwigoAlbumData(id: kPiwigoSearchCategoryId, andQuery: searchString)!
            CategoriesData.sharedInstance().updateCategories([searchAlbum])

            // Display "Loading..."
            if let footers = imagesCollection?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter),
               let footer = footers.first as? NberImagesFooterCollectionReusableView {
                footer.noImagesLabel?.text = AlbumUtilities.footerLegend(for: NSNotFound)
            }
            
            // Load, sort images and reload collection
            albumData?.searchQuery = searchString
            albumData?.updateImageSort(kPiwigoSortObjc(rawValue: UInt32(AlbumVars.shared.defaultSort)), onCompletion: { [self] in
                imagesCollection?.reloadData()
            },
            onFailure: { [self] _, error in
                // Did user cancelled the search
                if let error = error as? NSError, error.domain == NSURLErrorDomain,
                   error.code == NSURLErrorCancelled { return }
                // Display the error
                dismissPiwigoError(withTitle: NSLocalizedString("albumPhotoError_title", comment: "Get Album Photos Error"), errorMessage: NSLocalizedString("albumPhotoError_message", comment: "Failed to get album photos (corrupt image in your album?)")) { }
            })
        }
    }
}
