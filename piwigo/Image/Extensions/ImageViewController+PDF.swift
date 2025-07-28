//
//  ImageViewController+PDF.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28 July 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: Copy/Move Image Actions
@available(iOS 14, *)
extension ImageViewController
{
    func goToPage() -> UIAction {
        // Copy image to album
        let action = UIAction(title: NSLocalizedString("goToPage_title", comment: "Go to page…"),
                              image: UIImage(systemName: "arrow.turn.down.right"),
                              handler: { [self] _ in
            // Request page number
            self.goToPage()
        })
        action.accessibilityIdentifier = "GoToPageAction"
        return action
    }
}


// MARK: - Go To Page of PDF file
@available(iOS 14.0, *)
extension ImageViewController
{
    @MainActor
    func goToPage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)
        
        // Request page number
        let alert = UIAlertController(title: "",
                                      message: NSLocalizedString("goToPage_message", comment: "Page number?"),
                                      preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "1"
            textField.clearButtonMode = .always
            textField.keyboardType = .numberPad
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.returnKeyType = .continue
            textField.delegate = nil
        })
        
        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })
        
        let goToPageAction = UIAlertAction(
            title: NSLocalizedString("alertOkButton", comment: "OK"),
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
        alert.view.tintColor = .piwigoColorOrange()
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }
    
}
