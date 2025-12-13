//
//  URL+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

extension URL {
    // Returns the MD5 checksum of a file
    /// https://developer.apple.com/forums/thread/115401
    public var MD5checksum: (String, PwgKitError?) {
        var fileData: Data = Data()
        do {
            try fileData = NSData(contentsOf: self, options: .alwaysMapped) as Data
            let md5Checksum = fileData.MD5checksum
            return (md5Checksum, nil)
        }
        catch let error as CocoaError {
            // Update upload request state
            return ("", .fileOperationFailed(innerError: error))
        }
        catch {
            return ("", .otherError(innerError: error))
        }
    }
    
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
    
    // Returns the unit of the file size
    public var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    // Returns the creation date of the file
    public var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
    
    // Returns the folder size
    public var folderSize: UInt64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
            return size(of: contents)

        } catch let error {
            debugPrint(error.localizedDescription)
            return UInt64.zero
        }
    }
    
    public var photoFolderSize: UInt64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
            let onlyPhotos = contents.filter({$0.pathExtension != "mov"})
            return size(of: onlyPhotos)

        } catch let error {
            debugPrint(error.localizedDescription)
            return UInt64.zero
        }
    }
    
    // Returns the total size of videos in the folder
    public var videoFolderSize: UInt64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
            let onlyVideos = contents.filter({$0.pathExtension == "mov"})
            return size(of: onlyVideos)
            
        } catch let error {
            debugPrint(error.localizedDescription)
            return UInt64.zero
        }
    }
    
    private func size(of contents: [URL]) -> UInt64 {
        var folderSize: UInt64 = UInt64.zero
        for content in contents {
            folderSize += content.fileSize
        }
        return folderSize
    }
}
