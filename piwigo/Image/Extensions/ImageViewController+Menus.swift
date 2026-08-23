//
//  ImageViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit

// MARK: Menus
extension ImageViewController
{
    // MARK: - Albums
    /// - for copying images to another album
    /// - for moving images to another album
    /// - for setting an image as album thumbnail
    func albumMenu() -> UIMenu {
        let identifier = UIMenu.Identifier("org.piwigo.image.albumMenu")
        if userData.hasAdminRights {
            return UIMenu(title: "", image: nil, identifier: identifier,
                          options: .displayInline,
                          children: [copyAction(), moveAction(), setAsThumbnailAction()])
        } else {
            return UIMenu(title: "", image: nil, identifier: identifier,
                          options: .displayInline,
                          children: [copyAction(), moveAction()])
        }
    }


    // MARK: - Image Preview
    /// - for going to another album containing that image
    /// Returns nil when there is no other album to go to.
    @MainActor
    func goToMenu() -> UIMenu? {
        guard let goToAlbumMenu = goToAlbumMenu() else { return nil }
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.goToMenu"),
                      options: UIMenu.Options.displayInline,
                      children: [goToAlbumMenu])
    }


    // MARK: - Image Edition
    /// - for rotating image (not video, nor EPS, PDF, and GIF whose animation would be lost)
    /// - for editing image parameters
    func editMenu() -> UIMenu {
        var children = [UIMenuElement?]()
        if imageData.hasFullResThumbnail {
            children.append(rotateMenu())
        }
        children.append(editParamsAction())
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.editMenu"),
                      options: .displayInline,
                      children: children.compactMap {$0} )
    }


    // MARK: - Image Sharing
    /// - for sharing the URL of the page presenting the image on the Piwigo server
    @MainActor
    func shareMenu() -> UIMenu {
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.shareMenu"),
                      options: .displayInline,
                      children: [shareLinkAction()])
    }
}
