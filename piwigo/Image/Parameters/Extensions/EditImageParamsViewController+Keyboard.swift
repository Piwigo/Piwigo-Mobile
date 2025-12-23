//
//  EditImageParamsViewController+Keyboard.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension EditImageParamsViewController
{
    @objc func onKeyboardWillShow(_ notification: NSNotification) {
        guard view.traitCollection.userInterfaceIdiom == .phone,
              let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = editImageParamsTableView.window,
              let parentVC = navigationController?.presentingViewController
        else { return }
        
        // Calc intersection between the keyboard's frame and the view's bounds
        let toCoordinateSpace: any UICoordinateSpace = parentVC.view
        let convertedViewFrame = view.convert(view.bounds, to: toCoordinateSpace)
        let fromCoordinateSpace = window.screen.coordinateSpace
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = convertedViewFrame.intersection(convertedKeyboardFrameEnd)
        if viewIntersection.height > 0 {
            // Extend the content view to allow full scrolling
            editImageParamsTableView.contentInset = UIEdgeInsets(top: CGFloat.zero, left: CGFloat.zero,
                                                                 bottom: viewIntersection.height, right: CGFloat.zero)
        }
    }
    
    @objc func onKeyboardDidShow(_ notification: NSNotification) {
        guard let editedRow = editedRow,
              let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        
        // If necessary, scroll the table so that the cell remains visible
        if view.traitCollection.userInterfaceIdiom == .phone,
           let cell = editImageParamsTableView.cellForRow(at: editedRow) {
            let toCoordinateSpace: any UICoordinateSpace = view
            let convertedCellFrame = cell.convert(cell.bounds, to: toCoordinateSpace)
            let barHeight = convertedCellFrame.origin.y - cell.frame.origin.y   // status & navigation bars
            let availableHeight = editImageParamsTableView.bounds.height - barHeight - kbInfo.height
            let frameOfInterest = CGRect(origin: convertedCellFrame.origin,
                                         size: CGSize(width: convertedCellFrame.width, height: availableHeight))
            editImageParamsTableView.scrollRectToVisible(frameOfInterest, animated: true)
        } else {
            editImageParamsTableView.scrollToRow(at: editedRow, at: .top, animated: true)
        }
    }
    
    @objc func onKeyboardWillHide(_ notification: NSNotification) {
        // Reset content inset
        if view.traitCollection.userInterfaceIdiom == .pad {
            let navBarHeight = navigationController?.navigationBar.bounds.size.height ?? 0.0
            editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0,
                                                                 bottom: navBarHeight, right: 0.0)
        } else {
            editImageParamsTableView.contentInset = .zero
        }
    }
}
