//
//  Constants.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import Photos

// Swift Package Version
public enum PwgKit {
    public static let version = "4.0.0"
    public static let build = 677
}

// Bundle for PwgKit localised strings
public extension Bundle {
    static let pwgKit: Bundle = .module
}
