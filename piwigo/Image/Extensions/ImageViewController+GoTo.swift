//
//  ImageViewController+GoTo.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28 July 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

// MARK: Go To
extension ImageViewController
{    
    // MARK: - Menu
    /// Returns nil when the image belongs to no other album than the one being browsed:
    /// a submenu without children would be presented as a dead, greyed out row.
    @MainActor
    func goToAlbumMenu() -> UIMenu? {
        guard let actions = goToAlbumActions() else { return nil }
        return UIMenu(title: String(localized: "imageOptions_goToAlbum", comment: "Go To Album…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.goToAlbum"),
                      children: [actions])
    }
    
    
    // MARK: - Go To Album
    @MainActor
    func goToAlbumActions() -> UIMenu? {
        // Get parent albums
        let parentAlbums = imageData.albums ?? []
        // Exclude smart albums
        var albumIDs: Set<Int32> = Set(parentAlbums.map({ $0.pwgID }).filter({ $0 > Int32.zero }))
        // Keep current album only if presented in a smart album
        if categoryId > Int32.zero {
            albumIDs.remove(categoryId)
        }
        
        // Create goToAlbum actions
        var children: [UIMenuElement] = []
        for albumId in albumIDs {
            // Get album in cache
            guard let album = AlbumProvider().getAlbum(withID: albumId,inContext: mainContext)
            else { continue }
            
            // Create dynamic action
            let dynamicElement = UIDeferredMenuElement { [weak self] completion in
                /// The menu is retained by a bar button item, i.e. by this view controller
                guard let self
                else { return completion([]) }
                /// The capture is explicit so that the weak capture of the action below,
                /// which is retained by the menu, does not conflict with it.
                self.albumMenuIcon(album: album) { [self] icon in
                    let action = UIAction(title: album.name, image: icon,
                                          handler: { [weak self] _ in
                        guard let self else { return }
                        self.goToAlbumWithID(album.pwgID)
                    })
                    completion([action])
                }
            }
            children.append(dynamicElement)
        }
        if children.isEmpty { return nil }
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.goToAlbumList"),
                      options: UIMenu.Options.displayInline,
                      children: children)
    }
    
    func albumMenuIcon(album: Album, completion: @escaping (_ icon: UIImage?) -> Void) {
        // Look for an album thumbnail of 40x40 points
        let scale = max(self.view.traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(40.0 * scale, 40.0 * scale)
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        Task {
            await ImageDownloader.shared.getImage(withID: album.thumbnailId, ofSize: thumbSize, type: .album,
                                                  atURL: album.thumbnailUrl as? URL,
                                                  fromServer: album.user?.server?.uuid) { cachedImageURL in
                // Downsample image in cache
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, for: .album)
                // Return cached image
                DispatchQueue.main.async {
                    completion(cachedImage.crop(width: cellSize.width, height: cellSize.height))
                }
            } failure: { _ in
                // No cached image
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    @MainActor
    func goToAlbumWithID(_ albumId: Int32) {
        // Disable buttons during action
        setEnableStateOfButtons(false)
        
        // Get source and destination albums
        guard let sourceAlbum = AlbumProvider().getAlbum(withID: categoryId, inContext: mainContext),
              let destinationAlbum = AlbumProvider().getAlbum(withID: albumId, inContext: mainContext)
        else { return }
        
        // Get common path (don't use Set() which does not retain the order)
        let sourcePath = sourceAlbum.upperIds.components(separatedBy: ",").compactMap({ Int32($0) })
        let destinationPath = destinationAlbum.upperIds.components(separatedBy: ",").compactMap({ Int32($0) })
        let commonPath = sourcePath.filter({ destinationPath.contains($0) })
        if commonPath.isEmpty {
            AlbumVars.shared.defaultCategory = pwgSmartAlbum.root.rawValue
        }
        let lastCommonAlbumId = Array(commonPath).last ?? Int32.zero
        
        // Keep album view controllers from which to push the remaining albums
        /// Note: firstAlbumVCs should at least contain the root album vew controller.
        var firstAlbumVCs: [AlbumViewController] = []
        guard let navController = self.view.window?.rootViewController as? UINavigationController,
              let albumVCs = navController.viewControllers as? [AlbumViewController],
              let indexOfCommonAlbumVC = albumVCs.firstIndex(where: { $0.categoryId == lastCommonAlbumId })
        else {
            // Re-enable buttons
            setEnableStateOfButtons(true)
            return
        }
        firstAlbumVCs = Array(albumVCs[...indexOfCommonAlbumVC])
        
        // Create missing album view controllers
        let remainingPath = destinationPath.filter({ sourcePath.contains($0) == false })
        let newAlbumVCs = remainingPath.map({
            // Create album view controller
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = $0
            return subAlbumVC
        })
        
        // Update the stack of album view controllers
        navController.setViewControllers(firstAlbumVCs + newAlbumVCs, animated: true)
        
        // Dismiss the image view and reset the search if necessary
        dismiss(animated: false) {
            // Reset search if necessary
            guard self.categoryId == pwgSmartAlbum.search.rawValue,
                  let searchVC = firstAlbumVCs.first?.searchController
            else { return }
            searchVC.isActive = false
            searchVC.searchBar.text = ""
            searchVC.searchBar.resignFirstResponder()
        }
    }

    
    // MARK: - Go To PDF Page
//    @MainActor
//    func goToPageAction() -> UIAction? {
//        // Check that the current image is a PDF document
//        guard imageData.isPDF else { return nil }
//        
//        // Copy image to album
//        let action = UIAction(title: String(localized: "goToPage_title", comment: "Go to page…"),
//                              image: UIImage(systemName: "arrow.turn.down.right"),
//                              handler: { [weak self] _ in
//            guard let self else { return }
//            // Request page number
//            self.goToPage()
//        })
//        action.accessibilityIdentifier = "org.piwigo.image.goToPage"
//        return action
//    }

    @MainActor
    @objc func goToPage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)
        
        // Request page number
        let alert = UIAlertController(title: "",
                                      message: String(localized: "goToPage_message", comment: "Page number?"),
                                      preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "1"
            textField.clearButtonMode = .always
            textField.keyboardType = .numberPad
            textField.keyboardAppearance = UIVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.returnKeyType = .continue
            textField.delegate = nil
        })
        
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel, handler: { [self] action in
            // Re-enable buttons
            setEnableStateOfButtons(true)
        })
        
        let goToPageAction = UIAlertAction(title: Localized.ok,
            style: .default, handler: { [self] action in
                // Display requested page
                if let pdfDVC = pageViewController?.viewControllers?.first as? PdfDetailViewController {
                    pdfDVC.didSelectPageNumber(Int(alert.textFields?.last?.text ?? "") ?? 0)
                }
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })
        
        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(goToPageAction)
        
        // Present list of actions
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}
