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
        if uuid.isEmpty { uuid = UUID().uuidString }
        if self.path != path { self.path = path }
        
        // File types accepted by the server
        let newFileTypes = fileTypes.isEmpty ? "jpg,jpeg,png,gif" : fileTypes
        if self.fileTypes != newFileTypes { self.fileTypes = newFileTypes }
        
        // Last time the user used this server
        if self.lastUsed != lastUsed { self.lastUsed = lastUsed }
    }
    
    
    // MARK: - Cache Management
    public lazy var thumbnailSize: String = {
        let serverUrl = DataController.cacheDirectory.appendingPathComponent(self.uuid)
        var folderSize = UInt64.zero
        for size in pwgImageSize.allCases {
            if size == .fullRes { continue }
            let sizeUrl = serverUrl.appendingPathComponent(size.path)
            folderSize += sizeUrl.folderSize
        }
        return ByteCountFormatter.string(fromByteCount: Int64(folderSize), countStyle: .file)
    }()
    
    public func deleteThumbnails() {
        let serverUrl = DataController.cacheDirectory.appendingPathComponent(self.uuid)
        for size in pwgImageSize.allCases {
            if size == .fullRes { continue }
            let sizeUrl = serverUrl.appendingPathComponent(size.path)
            try? FileManager.default.removeItem(at: sizeUrl)
        }
    }
    
    public lazy var fullResSize: String = {
        let fullResUrl = DataController.cacheDirectory.appendingPathComponent(self.uuid)
                                                      .appendingPathComponent(pwgImageSize.fullRes.path)
        let folderSize = fullResUrl.folderSize
        return ByteCountFormatter.string(fromByteCount: Int64(folderSize), countStyle: .file)
    }()
    
    public func deleteFullResImages() {
        let fullResUrl = DataController.cacheDirectory.appendingPathComponent(self.uuid)
                                                      .appendingPathComponent(pwgImageSize.fullRes.path)
        try? FileManager.default.removeItem(at: fullResUrl)
    }
}
