//
//  Constants.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// Bundle name
public let piwigoKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("piwigoKit")})

// Disconnects and asks to update the Piwigo server if version is lower than:
public let pwgMinVersion = "2.10.0"

// At login, invites to update the Piwigo server if version is lower than:
public let pwgRecentVersion = "14.0.0"
