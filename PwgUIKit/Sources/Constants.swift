//
//  Constants.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 19/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

// Swift Package Version
public enum PwgUploadKit {
    public static let version = "1.0.0"
    public static let build = 1
}

// Bundle for PwgUploadKit localised strings
public extension Bundle {
    static let pwgUIKit: Bundle = .module
}
