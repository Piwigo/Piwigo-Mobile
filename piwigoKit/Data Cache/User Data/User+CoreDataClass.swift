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
                userStatus: pwgUserStatus = NetworkVars.userStatus,
                withName name: String = "", lastUsed: Date = Date()) throws {
        // Check user's status
        guard pwgUserStatus.allCases.contains(userStatus) else {
            throw UserError.unknownUserStatus
        }
        
        // Server andd username
        if self.server == nil { self.server = server }
        if self.username != username { self.username = username }
        
        // When the name is not provided, build name from the path
        let login = username.isEmpty ? pwgUserStatus.guest.rawValue : username
        let newName = name.isEmpty ? login + " @ " + server.path : name
        if self.name != newName { self.name = newName }
        
        // Last time the user used this account
        if self.lastUsed != lastUsed { self.lastUsed = lastUsed }
    }
    
    func addAlbumWithUploadRights(_ id: Int32) {
        let IDstr = String(id)
        var idList = self.uploadRights.components(separatedBy: ",")
        if idList.contains(IDstr) == false {
            idList.append(IDstr)
            self.uploadRights = String(idList.map({"\($0),"}).reduce("", +).dropLast(1))
        }
    }
}
