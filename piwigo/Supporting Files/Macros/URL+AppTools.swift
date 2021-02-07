//
//  URL+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

extension URL {
    // Return the MD5 checksum of a file
    func MD5checksum() -> (String, NSError?) {
        var fileData: Data = Data()
        do {
            try fileData = NSData(contentsOf: self) as Data
            
            // Determine MD5 checksum of video file to upload
            let md5Checksum = fileData.MD5checksum()
            return (md5Checksum, nil)
        }
        catch let error as NSError {
            // Report failure
            return ("", error)
        }
    }
}
