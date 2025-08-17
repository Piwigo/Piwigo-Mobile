//
//  ImageViewController+Menus.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: Menus
extension ImageViewController
{
    // MARK: - Albums
    /// - for copying images to another album
    /// - for moving images to another album
    /// - for setting an image as album thumbnail
    func albumMenu() -> UIMenu {
        let identifier = UIMenu.Identifier("org.piwigo.image.albumMenu")
        if user.hasAdminRights {
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
    /// - for going to a page of a PDF file
    @MainActor
    func goToMenu() -> UIMenu {
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.goToMenu"),
                      options: UIMenu.Options.displayInline,
                      children: [goToAlbumMenu(),goToPageAction()].compactMap({$0}))
    }


    // MARK: - Image Edition
    /// - for rotating image (not video)
    /// - for editing image parameters
    func editMenu() -> UIMenu {
        var children = [UIMenuElement]()
        if imageData.isImage {
            children.append(rotateMenu())
        }
        children.append(editParamsAction())
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.image.editMenu"),
                      options: .displayInline,
                      children: children)
    }
}
