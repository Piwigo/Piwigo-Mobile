//
//  URL+AppTools.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

extension URL {
    // Returns the MD5 checksum of a file
    /// https://developer.apple.com/forums/thread/115401
    public func MD5checksum() throws(PwgKitError) -> String {
        var fileData: Data = Data()
        do {
            try fileData = NSData(contentsOf: self, options: .alwaysMapped) as Data
            let md5Checksum = fileData.MD5checksum
            return md5Checksum
        }
        catch let error as CocoaError {
            // Update upload request state
            throw .fileOperationFailed(innerError: error)
        }
        catch {
            throw .otherError(innerError: error)
        }
    }
    
    // Returns the unit of the file size
    public var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    // Returns the folder size
    public var folderSize: UInt64 {
        return size(of: folderContents())
    }
    
    public var photoFolderSize: UInt64 {
        let onlyPhotos = folderContents().filter({
            let fileExt = $0.pathExtension.lowercased()
            return !["mov", "mp4"].contains(fileExt) })
        return size(of: onlyPhotos)
    }
    
    // Returns the total size of videos in the folder
    public var videoFolderSize: UInt64 {
        let onlyVideos = folderContents().filter({
            let fileExt = $0.pathExtension.lowercased()
            return ["mov", "mp4"].contains(fileExt) })
        return size(of: onlyVideos)
    }
    
    // Returns the contents of that folder, or nothing if it does not exist
    /// A cache folder is only created when a first file is stored in it, so asking
    /// the contents of a folder which does not exist yet is a normal situation:
    /// it should not produce a "No such file or directory" error.
    private func folderContents() -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return [] }

        do {
            return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
        }
        catch let error {
            #if DEBUG
            debugPrint(error.localizedDescription)
            #endif
            return []
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
