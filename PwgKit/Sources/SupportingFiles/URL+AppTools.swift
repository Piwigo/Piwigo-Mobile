//
//  URL+AppTools.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

extension URL {
    // Returns the file attributes
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            return nil
        }
    }
    
    // Returns the file size
    public var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64.zero
    }
    
    // Returns the creation date of the file
    public var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}
