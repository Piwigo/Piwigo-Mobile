//
//  Server+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//  An NSManagedObject subclass for the Server entity.
//

import Foundation
import CoreData

/* Server instances represent Piwigo servers.
   They are identified with a unique couple:
    - an UUID which is later used to store images in cache,
    - the server path e.g. "mywebsite.com/piwigo".
 */
public class Server: NSManagedObject {

    /**
     Updates the attributes of a Server instance.
     */
    func update(withPath path: String,
                fileTypes: String = UploadVars.serverFileTypes,
                lastUsed: Date = Date()) throws {
        // Server path
        guard path.isEmpty == false,
              let _ = URL(string: NetworkVars.serverPath) else {
            throw ServerError.wrongURL
        }
        if self.path != path {
            self.path = path
        }
        
        // UUID
        if uuid.isEmpty {
            uuid = UUID().uuidString
        }

        // File types accepted by the server
        let newFileTypes = fileTypes.isEmpty ? "jpg,jpeg,png,gif" : fileTypes
        if self.fileTypes != newFileTypes {
            self.fileTypes = newFileTypes
        }
        
        // Last time the user used this server
        if self.lastUsed != lastUsed {
            self.lastUsed = lastUsed
        }
    }
    
    
    // MARK: - Cache Management
    public func getCoreDataStoreSize() -> String {
        // WAL checkpointing is not controllable ► not an appropriate solution
//        let dataURL = DataDirectories.shared.appGroupDirectory
//        let folderSize = dataURL.folderSize
//        return ByteCountFormatter.string(fromByteCount: Int64(folderSize), countStyle: .file)
        
        // Calculate number of objects in background thread
        var totalCount = LocationProvider.shared.getObjectCount()
        totalCount += AlbumProvider().getObjectCount()
        totalCount += ImageProvider().getObjectCount()
        totalCount += TagProvider().getObjectCount()
        totalCount += UploadProvider().getObjectCount()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: totalCount as NSNumber) ?? "NaN"
    }

    public func getCacheSize(forImageSizes sizes: Set<pwgImageSize>) -> String {
        var folderSize = UInt64.zero
        let serverUrl = DataDirectories.shared.cacheDirectory.appendingPathComponent(self.uuid)
        sizes.forEach({ size in
            let cacheUrl = serverUrl.appendingPathComponent(size.path)
            folderSize += cacheUrl.folderSize
        })
        return ByteCountFormatter.string(fromByteCount: Int64(folderSize), countStyle: .file)
    }

    public func clearCachedImages(ofSizes sizes: Set<pwgImageSize>) {
        let serverUrl = DataDirectories.shared.cacheDirectory.appendingPathComponent(self.uuid)
        sizes.forEach { size in
            let cacheUrl = serverUrl.appendingPathComponent(size.path)
            try? FileManager.default.removeItem(at: cacheUrl)
        }
    }
}
