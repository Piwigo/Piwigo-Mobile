//
//  User+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData


public class User: NSManagedObject {

    /**
     Updates the attributes of a User Account instance.
     */
    func update(username: String, onServer server: Server, withName name: String = "") throws {
        guard username.isEmpty == false else {
            throw UserError.emptyUsername
        }
        self.username = username
        self.server = server

        // When the name is not provided, build name from the path
        self.name = name.isEmpty ? username + " @ " + server.path : name
    }
}
