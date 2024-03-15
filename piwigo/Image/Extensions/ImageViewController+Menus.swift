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

@available(iOS 14.0, *)
extension ImageViewController
{
    // MARK: - Albums related Actions & Menus
    /// - for copying images to another album
    /// - for moving images to another album
    /// - for setting an image as album thumbnail
    func albumMenu() -> UIMenu {
        if user.hasAdminRights {
            return UIMenu(title: "", image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.piwigoImage.album"),
                          options: .displayInline,
                          children: [copyAction(), moveAction(), setAsThumbnailAction()])
        } else {
            return UIMenu(title: "", image: nil,
                          identifier: UIMenu.Identifier("org.piwigo.piwigoImage.album"),
                          options: .displayInline,
                          children: [copyAction(), moveAction()])
        }
    }

    private func copyAction() -> UIAction {
        // Copy image to album
        let action = UIAction(title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
                              image: UIImage(systemName: "rectangle.stack.badge.plus"),
                              handler: { [unowned self] _ in
            // Disable buttons during action
            setEnableStateOfButtons(false)
            // Present album selector for copying image
            selectCategory(withAction: .copyImage)
        })
        action.accessibilityIdentifier = "Copy"
        return action
    }

    private func moveAction() -> UIAction {
        let action = UIAction(title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
                              image: UIImage(systemName: "arrowshape.turn.up.right"),
                              handler: { [unowned self] _ in
            // Disable buttons during action
            setEnableStateOfButtons(false)

            // Present album selector for moving image
            selectCategory(withAction: .moveImage)
        })
        action.accessibilityIdentifier = "Move"
        return action
    }

    private func setAsThumbnailAction() -> UIAction {
        let action = UIAction(title: NSLocalizedString("imageOptions_setAlbumImage",
                                                       comment:"Set as Album Thumbnail"),
                              image: UIImage(systemName: "rectangle.and.paperclip"),
                              handler: { [unowned self] _ in
            // Present album selector for setting album thumbnail
            self.setAsAlbumImage()
        })
        action.accessibilityIdentifier = "SetThumbnail"
        return action
    }


    // MARK: - Images related Actions & Menus
    /// - for rotating image (not video)
    /// - for editing image parameters
    func editMenu() -> UIMenu {
        var children = [UIMenuElement]()
        if imageData.isVideo == false {
            children.append(rotateMenu())
        }
        children.append(editParamsAction())
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.piwigoImage.edit"),
                      options: .displayInline,
                      children: children)
    }

    private func rotateMenu() -> UIMenu {
        return UIMenu(title: NSLocalizedString("rotateImage_rotate",
                                               comment: "Rotate Photo…"),
                      image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.piwigoImage.rotate"),
                      children: [rotateRightAction(), rotateLeftAction()])
    }
    
    private func editParamsAction() -> UIAction {
        // Edit image parameters
        let action = UIAction(title: NSLocalizedString("imageOptions_properties",
                                                       comment: "Modify Information"),
                              image: UIImage(systemName: "pencil"),
                              handler: { _ in
            // Edit image informations
            self.editImage()
        })
        action.accessibilityIdentifier = "Edit Parameters"
        return action
    }
    
    private func rotateRightAction() -> UIAction {
        // Rotate image right
        let action = UIAction(title: NSLocalizedString("rotateImage_right", 
                                                       comment: "Clockwise"),
                              image: UIImage(systemName: "rotate.right"),
                              handler: { _ in
            // Edit image informations
            self.rotateImage(by: -90.0)
        })
        action.accessibilityIdentifier = "Rotate Right"
        return action
    }

    private func rotateLeftAction() -> UIAction {
        // Rotate image left
        let action = UIAction(title: NSLocalizedString("rotateImage_left", 
                                                       comment: "Counterclockwise"),
                              image: UIImage(systemName: "rotate.left"),
                              handler: { _ in
            // Edit image informations
            self.rotateImage(by: 90.0)
        })
        action.accessibilityIdentifier = "Rotate Left"
        return action
    }
}
