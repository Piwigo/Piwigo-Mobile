//
//  EditImageParamsViewController+Keyboard.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

extension EditImageParamsViewController
{
    @objc func onKeyboardWillShow(_ notification: NSNotification) {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              let info = notification.userInfo,
              let kbInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = editImageParamsTableView.window,
              let parentVC = self.navigationController?.presentingViewController
        else { return }
        
        // Calc intersection between the keyboard's frame and the view's bounds
        let toCoordinateSpace: UICoordinateSpace = parentVC.view
        let convertedViewFrame = view.convert(view.bounds, to: toCoordinateSpace)
        let fromCoordinateSpace = window.screen.coordinateSpace
        let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(kbInfo, to: toCoordinateSpace)
        let viewIntersection = convertedViewFrame.intersection(convertedKeyboardFrameEnd)
        if viewIntersection.height > 0 {
            // Extend the content view to allow full scrolling
            editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: viewIntersection.height, right: 0.0)
        }
    }
    
    @objc func onKeyboardDidShow(_ notification: NSNotification) {
        guard let editedRow = editedRow else { return }
        
        // If necessary, scroll the table so that the cell remains visible
        if let cell = editImageParamsTableView.cellForRow(at: editedRow) {
            let toCoordinateSpace: UICoordinateSpace = view
            let convertedCellFrame = cell.convert(cell.bounds, to: toCoordinateSpace)
            let heightOfInterest = min(convertedCellFrame.height, view.bounds.height/2.0)
            let frameOfInterest = CGRect(origin: convertedCellFrame.origin,
                                         size: CGSize(width: convertedCellFrame.width, height: heightOfInterest))
            editImageParamsTableView.scrollRectToVisible(frameOfInterest, animated: true)
        } else {
            editImageParamsTableView.scrollToRow(at: editedRow, at: .none, animated: true)
        }
    }
    
    @objc func onKeyboardWillHide(_ notification: NSNotification) {
        // Reset content inset
        if UIDevice.current.userInterfaceIdiom == .pad {
            let navBarHeight = navigationController?.navigationBar.bounds.size.height ?? 0.0
            editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0,
                                                                 bottom: navBarHeight, right: 0.0)
        } else {
            editImageParamsTableView.contentInset = .zero
        }
    }
}
