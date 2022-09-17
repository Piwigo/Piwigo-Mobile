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
    func update(username: String, onServer server: Server,
                status: String = NetworkVars.userStatus,
                withName name: String = "", lastUsed: Date = Date()) throws {
        // Check user's status
        guard let userStatus = pwgUserStatus(rawValue: status),
              pwgUserStatus.allValues.contains(userStatus) else {
            throw UserError.unknownUserStatus
        }
        
        // Username and server path
        self.username = username
        self.server = server

        // When the name is not provided, build name from the path
        let login = username.isEmpty ? pwgUserStatus.guest.rawValue : username
        self.name = name.isEmpty ? login + " @ " + server.path : name
        
        // Last time the user used this account
        self.lastUsed = lastUsed
    }
}
