//
//  UIButton+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

enum SelectButtonState : Int {
    case none
    case select
    case deselect
}

extension UIButton
{
    // MARK: Select Button
    func setTitle(forState state: SelectButtonState) {
        let title: String, bckgColor: UIColor
        switch state {
        case .select:
            title = String(format: "  %@  ", NSLocalizedString("selectAll", comment: "Select All"))
            bckgColor = PwgColor.cellBackground
        case .deselect:
            title = String(format: "  %@  ", NSLocalizedString("categoryImageList_deselectButton", comment: "Deselect"))
            bckgColor = PwgColor.cellBackground
        case .none:
            title = ""
            bckgColor = .clear
        }
        self.backgroundColor = bckgColor
        self.setTitle(title, for: .normal)
        self.setTitleColor(PwgColor.whiteCream, for: .normal)
        self.accessibilityIdentifier = "SelectAll"
    }
}
