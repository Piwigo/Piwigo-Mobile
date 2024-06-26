//
//  SettingsViewController+Keyboard.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

extension SettingsViewController
{
    @objc func onKeyboardWillShow(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = settingsTableView.window
        else { return }

        // Calc intersection between the keyboard's frame and the view's bounds
        let fromCoordinateSpace = window.screen.coordinateSpace
        let toCoordinateSpace: UICoordinateSpace = settingsTableView
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = settingsTableView.bounds.intersection(convertedKeyboardFrameEnd)
        if viewIntersection.height > 0 {
            // Extend the content view to allow full scrolling
            settingsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: viewIntersection.height, right: 0.0)
        }
    }

    @objc func onKeyboardDidShow(_ notification: NSNotification) {
        guard let editedRow = editedRow else { return }
        
        // If necessary, scroll the table so that the cell remains visible
        if let cell = settingsTableView.cellForRow(at: editedRow) {
            let toCoordinateSpace: UICoordinateSpace = view
            let convertedCellFrame = cell.convert(cell.bounds, to: toCoordinateSpace)
            settingsTableView.scrollRectToVisible(convertedCellFrame, animated: true)
        } else {
            settingsTableView.scrollToRow(at: editedRow, at: .none, animated: true)
        }
    }

    @objc func onKeyboardWillHide(_ notification: NSNotification) {
        // Reset content inset
        settingsTableView.contentInset = .zero
    }
}
