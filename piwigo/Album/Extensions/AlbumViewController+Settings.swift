//
//  AlbumViewController+Settings.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import MessageUI
import UIKit
import piwigoKit

// MARK: Settings Button
extension AlbumViewController
{
    func settingsMenu() -> UIMenu? {
        // Used in Discover menu since iOS 26
        if #unavailable(iOS 26.0) { return  nil }
        
        // Create menu
        var children: [UIMenuElement?] = [helpMenu()]
        if categoryId == AlbumVars.shared.defaultCategory {
            children.append(settingsAction())
        }
        let menuId = UIMenu.Identifier("org.piwigo.settings.menu")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: children.compactMap({ $0 }))
        return menu
    }
    
    private func helpMenu() -> UIMenu? {
        if #unavailable(iOS 26.0) { return  nil }
        
        // Create menu
        let menuId = UIMenu.Identifier("org.piwigo.help.menu")
        let config = UIImage.SymbolConfiguration(weight: .regular)
        let helpIcon = UIImage(systemName: "questionmark", withConfiguration: config)
        let menu = UIMenu(title: NSLocalizedString("settings_help", comment: "Help"),
                          image: helpIcon, identifier: menuId,
                          children: [showHelpAction(), showReleaseNotesAction(), contactMenu()].compactMap({ $0 }))
        return menu
    }
    
    private func showHelpAction() -> UIAction {
        // Create action
        let actionId = UIAction.Identifier("org.piwigo.help.action")
        let config = UIImage.SymbolConfiguration(weight: .regular)
        let helpIcon: UIImage!
        if #available(iOS 17.0, *){
            helpIcon = UIImage(systemName: "book.pages", withConfiguration: config)
        } else {
            helpIcon = UIImage(systemName: "book", withConfiguration: config)
        }
        let action = UIAction(title: NSLocalizedString("settings_helpViews", comment: "Help Pages"),
                              image: helpIcon, identifier: actionId, handler: { [self] action in
            // Present help views
            let helpVC = HelpUtilities.getHelpViewController()
            pushView(helpVC)
        })
        action.accessibilityIdentifier = "help"
        return action
    }
    
    private func showReleaseNotesAction() -> UIAction? {
        let actionId = UIAction.Identifier("org.piwigo.help.releasenotes.action")
        let config = UIImage.SymbolConfiguration(weight: .regular)
        let releaseNotesIcon: UIImage!
        if #available(iOS 16.0, *){
            releaseNotesIcon = UIImage(systemName: "list.clipboard", withConfiguration: config)
        } else {
            releaseNotesIcon = UIImage(systemName: "doc.plaintext", withConfiguration: config)
        }
        let action = UIAction(title: NSLocalizedString("settings_releaseNotes", comment: "Release Notes"),
                              image: releaseNotesIcon, identifier: actionId, handler: { [self] _ in
            // Present release notes in settings navigation controller
            let releaseNotesSB = UIStoryboard(name: "ReleaseNotesViewController", bundle: nil)
            guard let releaseNotesVC = releaseNotesSB.instantiateViewController(withIdentifier: "ReleaseNotesViewController") as? ReleaseNotesViewController
            else { preconditionFailure("Could not load ReleaseNotesViewController") }
            pushView(releaseNotesVC)
        })
        return action
    }
    
    private func contactMenu() -> UIMenu {
        // Create menu
        let menuId = UIMenu.Identifier("org.piwigo.help.contact.menu")
        let menu = UIMenu(title: "", image: nil, identifier: menuId,
                          options: UIMenu.Options.displayInline,
                          children: [supportForumAction(), contactAction()].compactMap({ $0 }))
        return menu
    }
    
    private func supportForumAction() -> UIAction? {
        // Create action
        let actionId = UIAction.Identifier("org.piwigo.help.forum.action")
        let config = UIImage.SymbolConfiguration(weight: .regular)
        let forumIcon: UIImage!
        if #available(iOS 17.0, *) {
            forumIcon = UIImage(systemName: "bubble.left.and.text.bubble.right", withConfiguration: config)
        } else {
            forumIcon = UIImage(systemName: "bubble.left.and.bubble.right", withConfiguration: config)
        }
        let action = UIAction(title: NSLocalizedString("settings_supportForum", comment: "Support Forum"),
                              image: forumIcon, identifier: actionId, handler: { action in
            // Open Piwigo support forum webpage with default browser
            if let url = URL(string: NSLocalizedString("settings_pwgForumURL", comment: "http://piwigo.org/forum")) {
                UIApplication.shared.open(url)
            }
        })
        action.accessibilityIdentifier = "supportForum"
        return action
    }
    
    private func contactAction() -> UIAction? {
        // Can we send mails?
        if !MFMailComposeViewController.canSendMail() { return nil }
        
        // Create action
        let actionId = UIAction.Identifier("org.piwigo.help.contact.action")
        let config = UIImage.SymbolConfiguration(weight: .regular)
        let action = UIAction(title: NSLocalizedString("settings_contact", comment: "Contact Support"),
                              image: UIImage(systemName: "envelope", withConfiguration: config),
                              identifier: actionId, handler: { [self] action in
            // Get mail composer if possible
            guard let composeVC = SettingsUtilities.getMailComposer() else { return }
            composeVC.mailComposeDelegate = self

            // Present the view controller modally.
            present(composeVC, animated: true)
        })
        action.accessibilityIdentifier = "contact"
        return action
    }
    
    private func settingsAction() -> UIAction {
        // Create action
        let actionId = UIAction.Identifier("org.piwigo.settings.action")
        let boldConfig = UIImage.SymbolConfiguration(weight: .bold)
        let boldSettingsIcon = UIImage(systemName: "gear", withConfiguration: boldConfig)
        let action = UIAction(title: NSLocalizedString("tabBar_preferences", comment: "Settings"),
                              image: boldSettingsIcon,
                              identifier: actionId, handler: { [self] action in
            // Present settings
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
