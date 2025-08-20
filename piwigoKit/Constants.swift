//
//  Constants.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 20/08/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// Bundle name
public var piwigoKit = Bundle.allFrameworks.first(where: { ($0.bundleIdentifier ?? "").contains("piwigoKit")})
