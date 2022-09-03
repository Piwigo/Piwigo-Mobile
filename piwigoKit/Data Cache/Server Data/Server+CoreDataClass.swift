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
    func update(withPath path: String) throws {
        // Server path
        self.path = path
        
        // Server accepted file types
        if path == NetworkVars.serverPath {
            self.fileTypes = UploadVars.serverFileTypes
        } else {
            self.fileTypes = "jpg,jpeg,png,gif"
        }
    }
}
