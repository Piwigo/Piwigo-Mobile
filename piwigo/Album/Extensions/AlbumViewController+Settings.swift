//
//  AlbumViewController+Settings.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Settings Button
extension AlbumViewController
{
    func settingsMenu() -> UIMenu? {
        // Used in Discover menu since iOS 26
        if #unavailable(iOS 26.0) { return  nil }
        
        // Create menu
        let menuId = UIMenu.Identifier("org.piwigo.settingsMenu")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [settingsAction()])
        return menu
    }
    
    private func settingsAction() -> UIAction {
        // Create action
        let actionId = UIAction.Identifier("SettingsAction")
        let boldConfig = UIImage.SymbolConfiguration(weight: .bold)
        let boldSettingsIcon = UIImage(systemName: "gear", withConfiguration: boldConfig)
        let action = UIAction(title: NSLocalizedString("tabBar_preferences", comment: "Settings"),
                              image: boldSettingsIcon,
                              identifier: actionId, handler: { [self] action in
            // Present tag selector
            didTapSettingsButton()
        })
        action.accessibilityIdentifier = "settings"
        return action
    }

    // Before iOS 26
    func getSettingsBarButton() -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(didTapSettingsButton))
        button.accessibilityIdentifier = "settings"
        return button
    }
    
    @objc func didTapSettingsButton() {
        let settingsSB = UIStoryboard(name: "SettingsViewController", bundle: nil)
        guard let settingsVC = settingsSB.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController
        else { preconditionFailure("Could not load SettingsViewController") }
        settingsVC.settingsDelegate = self
        settingsVC.user = user
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .formSheet
        
        // For iPads, adopt a size that fits all orientations
        let windowBounds = view.window?.bounds ?? .zero
        navController.popoverPresentationController?.sourceRect = CGRect(
            x: windowBounds.midX, y: windowBounds.midY,
            width: 0, height: 0)
        let minHeight = min(windowBounds.width, windowBounds.height)
        navController.preferredContentSize = CGSize(
            width: pwgPadSettingsWidth,
            height: ceil(minHeight * 2 / 3))
        
        present(navController, animated: true)
    }
}


// MARK: - ChangedSettingsDelegate Methods
extension AlbumViewController: ChangedSettingsDelegate
{
    func didChangeDefaultAlbum() {
        // Change default album
        categoryId = AlbumVars.shared.defaultCategory
        albumData = currentAlbumData()
        changeAlbumID()
    }
    
    func didChangeRecentPeriod() {
        // Reload album to update "recent" icons
        collectionView?.reloadData()
    }
}
