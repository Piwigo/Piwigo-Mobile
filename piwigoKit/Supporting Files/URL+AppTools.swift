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
    /// https://developer.apple.com/forums/thread/115401
    func MD5checksum() -> (String, NSError?) {
        var fileData: Data = Data()
        do {
            try fileData = NSData(contentsOf: self, options: .alwaysMapped) as Data
            
            // Determine MD5 checksum of video file to upload
            let md5Checksum = fileData.MD5checksum()
            return (md5Checksum, nil)
        }
        catch let error as NSError {
            // Report failure
            return ("", error)
        }
    }
    
    // Returns the file attributes
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    // Returns the file size
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    // Returns the unit of the file size
    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    // Returns the creation date of the file
    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}
