//
//  UploadRenameAction+Separator.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Separators
public enum pwgSeparator: String, CaseIterable, Hashable {
    case none       = ""
    case dash       = "-"
    case underscore = "_"
    case space      = " "
    case plus       = "+"
    
    public var index: Int {
        return pwgSeparator.allCases.firstIndex(of: self)! - 1
    }
}
