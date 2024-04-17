//
//  AlbumImageTableViewController+Settings.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: "Settings" Button
extension AlbumImageTableViewController
{
    func getSettingsBarButton() -> UIBarButtonItem {
        var button: UIBarButtonItem!
        if #available(iOS 14.0, *) {
            button = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(didTapSettingsButton))
        } else {
            button = UIBarButtonItem(image: UIImage(named: "settings"), landscapeImagePhone: UIImage(named: "settingsCompact"), style: .plain, target: self, action: #selector(didTapSettingsButton))
        }
        button.accessibilityIdentifier = "settings"
        return button
    }
    
    @objc func didTapSettingsButton() {
        let settingsSB = UIStoryboard(name: "SettingsViewController", bundle: nil)
        guard let settingsVC = settingsSB.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else { fatalError("No SettingsViewController") }
        settingsVC.settingsDelegate = self
        settingsVC.user = user
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalTransitionStyle = .coverVertical
        navController.modalPresentationStyle = .formSheet
        let mainScreenBounds = UIScreen.main.bounds
        navController.popoverPresentationController?.sourceRect = CGRect(
            x: mainScreenBounds.midX, y: mainScreenBounds.midY,
            width: 0, height: 0)
        navController.preferredContentSize = CGSize(
            width: pwgPadSettingsWidth,
            height: ceil(mainScreenBounds.size.height * 2 / 3))
        present(navController, animated: true)
    }
}


// MARK: - ChangedSettingsDelegate Methods
extension AlbumImageTableViewController: ChangedSettingsDelegate
{
    func didChangeDefaultAlbum() {
        // Change default album
        categoryId = AlbumVars.shared.defaultCategory
        albumData = currentAlbumData()
        changeAlbumID()
    }

    func didChangeRecentPeriod() {
        // Reload album
        albumImageTableView.reloadData()
    }
}
