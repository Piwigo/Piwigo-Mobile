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

@available(iOS 14, *)
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


    // MARK: - PDF file related Actions & Menus
    /// - for going to a page
    func pdfMenu() -> UIMenu? {
        guard imageData.isPDF
        else { return nil }
        
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.piwigoPDF.goToPage"),
                      options: .displayInline,
                      children: [goToPage()])
    }


    // MARK: - Images related Actions & Menus
    /// - for rotating image (not video)
    /// - for editing image parameters
    func editMenu() -> UIMenu {
        var children = [UIMenuElement]()
        if imageData.isImage {
            children.append(rotateMenu())
        }
        children.append(editParamsAction())
        return UIMenu(title: "", image: nil,
                      identifier: UIMenu.Identifier("org.piwigo.piwigoImage.edit"),
                      options: .displayInline,
                      children: children)
    }
}
