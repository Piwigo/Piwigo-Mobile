//
//  Constants.swift
//  PwgMetadataKit
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

// Swift Package Version
public enum PwgMetadataKit {
    public static let version = "1.0.0"
    public static let build = 1
}

// Bundle for PwgMetadataKit localized strings
public extension Bundle {
    static let pwgMetadataKit: Bundle = .module
}
