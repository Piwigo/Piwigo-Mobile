//
//  PasteboardImagesViewController+Bar.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Navigation Bar & Buttons
extension PasteboardImagesViewController {
    
    // MARK: - Navigation Bar
    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
        case 0:
            // Buttons
            cancelBarButton.isEnabled = false
            uploadBarButton.isEnabled = false
            
            // Display "Back" button on the left side
            navigationItem.leftBarButtonItems = []
            
            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                // The action button proposes:
                /// - to allow/disallow  re-uploading photos,
                if let submenu = getMenuForReuploadingPhotos() {
                    let menu = UIMenu(title: "", children: [submenu].compactMap({$0}))
                    actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                }
                
                // Present the "Upload" button in the toolbar
                legendLabel.text = NSLocalizedString("selectImages", comment: "Select Photos")
                legendBarItem = UIBarButtonItem(customView: legendLabel)
                toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
            }
            
        default:
            // Buttons
            cancelBarButton.isEnabled = true
            uploadBarButton.isEnabled = true
            
            // Display "Cancel" button on the left side
            navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
            
            // Set buttons on the right side on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                // Update the number of selected photos in the toolbar
                legendLabel.text = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                legendBarItem = UIBarButtonItem(customView: legendLabel)
                toolbarItems = [legendBarItem, .flexibleSpace(), uploadBarButton]
            }
            
            // Set buttons on the right side on iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Update the number of selected photos in the navigation bar
                title = nberOfSelectedImages == 1 ? NSLocalizedString("selectImageSelected", comment: "1 Photo Selected") : String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
                
                // Update status of buttons
                navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
            }
        }
    }
    
    
    // MARK: - Action Button
    func updateActionButton() {
        // Update action button
        // The action button proposes:
        /// - to allow/disallow re-uploading photos,
        actionBarButton.menu = UIMenu(title: "", children: [getMenuForReuploadingPhotos()].compactMap({$0}))
    }
}
