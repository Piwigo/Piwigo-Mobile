//
//  NetworkObjcUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/12/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
import piwigoKit

@objc
class NetworkObjcUtilities: NSObject {
    
    @objc
    class func utf8mb4ObjcString(from string: String?) -> String? {
        return NetworkUtilities.utf8mb4String(from: string)
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    @objc
    class func utf8mb3ObjcString(from string: String?) -> String? {
        return NetworkUtilities.utf8mb3String(from: string)
    }
}
