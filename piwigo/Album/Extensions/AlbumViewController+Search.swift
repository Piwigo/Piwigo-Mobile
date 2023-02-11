//
//  AlbumViewController+Search.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/05/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

// MARK: - Search Images
extension AlbumViewController
{
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
    func presentSearchController(_ searchController: UISearchController) {
        debugPrint("presentSearchController…")
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        debugPrint("willPresentSearchController…")
        // Switch to Search album
        categoryId = pwgSmartAlbum.search.rawValue
        
        // Initialise albumData
        albumData = albumProvider.getAlbum(inContext: mainContext, withId: categoryId)
        albumData?.query = ""
        albumData?.nbImages = Int64.min
        albumData?.totalNbImages = Int64.min
        albumData?.images = Set<Image>()

        // Update albums
        var andPredicates = predicates
        andPredicates.append(NSPredicate(format: "parentId == %i", categoryId))
        fetchAlbumsRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        try? albums.performFetch()

        // Update images
        andPredicates = predicates
        andPredicates.append(NSPredicate(format: "ANY albums.pwgID == %i", categoryId))
        fetchImagesRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        try? images.performFetch()
        
        // Hide buttons and toolbar
        updateButtonsInPreviewMode()
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {
        debugPrint("didPresentSearchController…")
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        debugPrint("willDismissSearchController…")
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
        albumData = albumProvider.getAlbum(inContext: mainContext, withId: categoryId)

        // Update albums and images
        resetPredicatesAndPerformFetch()

        // Reload collection
        imagesCollection?.reloadData()

        // Show buttons
        updateButtonsInPreviewMode()
    }
}


// MARK: - UISearchBarDelegate Methods
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
        
        // Query string empty?
        if searchString.isEmpty {
            // Cancel active image data session if any
            PwgSession.shared.dataSession.getAllTasks { tasks in
                tasks.forEach { task in
                    task.cancel()
                }
            }
            // Cancel active image downloads if any
            ImageSession.shared.dataSession.getAllTasks { tasks in
                tasks.forEach { task in
                    task.cancel()
                }
            }
            
            // Reset search album
            albumData?.query = ""
            albumData?.nbImages = Int64.min
            albumData?.totalNbImages = Int64.min
            albumData?.images = Set<Image>()
            do {
                try mainContext.save()
            } catch let error as NSError {
                print("Could not fetch \(error), \(error.userInfo)")
            }

            imagesCollection?.reloadData()
            return
        }
        
        // Resfresh image collection for new query only
        if albumData?.query != searchString {
            // Cancel active image data session if any
            PwgSession.shared.dataSession.getAllTasks { tasks in
                tasks.forEach { task in
                    task.cancel()
                }
            }
            // Cancel active image downloads if any
            ImageSession.shared.dataSession.getAllTasks { tasks in
                tasks.forEach { task in
                    task.cancel()
                }
            }
            
            // Initialise search cache
            self.query = searchString
            
            // Display "Loading..."
            if let footers = imagesCollection?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter),
               let footer = footers.first as? NberImagesFooterCollectionReusableView {
                footer.noImagesLabel?.text = AlbumUtilities.footerLegend(false, Int64.min)
            }
            
            // Determine if the session is active and for how long before fetching
            let pwgToken = NetworkVars.pwgToken
            let timeSinceLastLogin = NetworkVars.dateOfLastLogin.timeIntervalSinceNow
            LoginUtilities.sessionGetStatus { [self] in
                print("••> token: \(pwgToken) vs \(NetworkVars.pwgToken)")
                if pwgToken.isEmpty || NetworkVars.pwgToken != pwgToken ||
                    (timeSinceLastLogin < TimeInterval(-1800)) {
                    // Re-login before fetching album and image data
                    performRelogin { [self] in
                        fetchAlbumsAndImages { [self] in
                            fetchCompleted()
                        }
                    }
                } else {
                    // Fetch album and image data
                    fetchAlbumsAndImages { [self] in
                        fetchCompleted()
                    }
                }
            } failure: { _ in
                print("••> Failed to check session status…")
                // Will re-check later…
            }
        }
        
//        if albumData?.searchQuery != searchString || searchString.isEmpty  {
//            // Cancel active image downloads if any
//            NetworkVarsObjc.imagesSessionManager?.tasks.forEach({ task in
//                task.cancel()
//            })
//
//            // Initialise search cache
//            let searchAlbum = PiwigoAlbumData(id: kPiwigoSearchCategoryId, andQuery: searchString)!
//            CategoriesData.sharedInstance().updateCategories([searchAlbum])
//
//            // Display "Loading..."
//            if let footers = imagesCollection?.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionFooter),
//               let footer = footers.first as? NberImagesFooterCollectionReusableView {
//                footer.noImagesLabel?.text = AlbumUtilities.footerLegend(for: Int64.min)
//            }
//
//            // Load, sort images and reload collection
//            albumData?.searchQuery = searchString
//            albumData?.updateImageSort(kPiwigoSortObjc(rawValue: UInt32(AlbumVars.shared.defaultSort)), onCompletion: { [self] in
//                imagesCollection?.reloadData()
//            },
//            onFailure: { [self] _, error in
//                // Did user cancelled the search
//                if let error = error as? NSError, error.domain == NSURLErrorDomain,
//                   error.code == NSURLErrorCancelled { return }
//                // Display the error
//                dismissPiwigoError(withTitle: NSLocalizedString("albumPhotoError_title", comment: "Get Album Photos Error"), errorMessage: NSLocalizedString("albumPhotoError_message", comment: "Failed to get album photos (corrupt image in your album?)")) { }
//            })
//        }
    }
}
