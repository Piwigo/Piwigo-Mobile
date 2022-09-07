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
                lastUsed: TimeInterval = Date().timeIntervalSinceReferenceDate) throws {
        // Server path
        guard path.isEmpty == false,
              let _ = URL(string: NetworkVars.serverPath) else {
            throw ServerError.wrongURL
        }
        self.path = path
        
        // Other attributes
        self.fileTypes = fileTypes.isEmpty ? "jpg,jpeg,png,gif" : fileTypes
        self.lastUsed = lastUsed        // Defaults to now
    }
}
