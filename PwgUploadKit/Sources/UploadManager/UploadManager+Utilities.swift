//
//  UploadUtilities.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 19/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import MobileCoreServices
import Photos
import PwgKit
import PwgAPIKit
import PwgCacheKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Upload File Utilities
    // Returns the URL of final upload file to be stored into Piwigo/Uploads directory
    // and delete existing file if demanded (case of a failed previous attempt)
    // ******************************************************************************************************
    // * declared "nonisolated" because the compiler returns:
    // * Pattern that the region based isolation checker does not understand how to check. Please file a bug
    // ******************************************************************************************************
    nonisolated func getUploadFileURL(from localIdentifier: String, withSuffix suffix: String = "",
                                      creationDate: TimeInterval, deleted deleteIt: Bool = false) -> URL {
        // File name of image data to be stored into Piwigo/Uploads directory
        var fileName = ""
        if #available(iOS 16.0, *) {
            fileName = localIdentifier.replacing("/", with: "-")
        } else {
            // Fallback on earlier versions
            fileName = localIdentifier.replacingOccurrences(of: "/", with: "-")
        }
        if fileName.isEmpty {
            fileName = "file-".appending(String(Int64(creationDate)))
        }
        fileName.append(suffix)
        let fileURL = DataDirectories.appUploadsDirectory.appendingPathComponent(fileName)
        
        // Should we delete it?
        if deleteIt {
            // Deletes temporary image file if it exists (incomplete previous attempt?)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        return fileURL
    }
    
    /// - Delete Upload files w/ or w/o prefix
    public func deleteFilesInUploadsDirectory(withPrefix prefix: String = "") {
        let fileManager = FileManager.default
        do {
            // Get list of files
            let uploadsDirectory = DataDirectories.appUploadsDirectory
            var filesToDelete = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            if prefix.isEmpty == false {
                // Will delete files with given prefix only
                filesToDelete.removeAll(where: { !$0.lastPathComponent.hasPrefix(prefix) })
            }
            
            // Delete files
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }
            
            // Release memory
            filesToDelete.removeAll()
            
            // For debugging
            //            let leftFiles = try fileManager.contentsOfDirectory(at: uploadsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            //            debugPrint("\(dbg()) Remaining files in cache: \(leftFiles)")
        } catch {
            UploadManager.logger.notice("Could not clear the Uploads folder: \(error)")
        }
    }
    
    
    // MARK: - Piwigo Session Management
    // Re-login if session was closed
    public func checkSession(ofUserWithID objectID: NSManagedObjectID,
                             lastConnected lastUsed: TimeInterval) async throws(PwgKitError) {
                
        // Check if the session is still active and update the server status
        // every 60 seconds or more
        let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - lastUsed
        if ServerVars.shared.hasNetworkConnectionChanged == false,
           ServerVars.shared.applicationShouldRelogin == false,
           secondsSinceLastCheck < 60 {
            return
        }
        
        // Determine if the session is still active
        ServerVars.shared.hasNetworkConnectionChanged = false
        debugPrint("Session: starting checking… \(ServerVars.shared.isConnectedToWiFi ? "WiFi" : "Cellular")")
        let oldToken = ServerVars.shared.pwgToken
        let pwgUser = try await JSONManager.shared.sessionGetStatus()
#if DEBUG
        debugPrint("Session: \"\(ServerVars.shared.user)\" vs \"\(pwgUser)\", \"\(oldToken)\" vs \"\(ServerVars.shared.pwgToken)\"")
#endif
        if pwgUser != ServerVars.shared.user || oldToken.isEmpty || ServerVars.shared.pwgToken != oldToken {
            // Collect list of methods supplied by Piwigo server
            // => Determine if Community extension 2.9a or later is installed and active
            try await JSONManager.shared.getMethods()
            
            // Known methods, perform re-login
            // Perform login
            let username = ServerVars.shared.username
            let password = KeychainUtilities.password(forService: ServerVars.shared.serverPath, account: username)
            try await JSONManager.shared.sessionLogin(withUsername: username, password: password)
#if DEBUG
            debugPrint("Session: logged as \(ServerVars.shared.username)")
#endif
            // Session now opened
            try await getPiwigoConfigForUser(withID: objectID)
            
            // Update date of accesss to the server by guest
            updateUser(withID: objectID, includingStatus: true)
            ServerVars.shared.applicationShouldRelogin = false
        }
        else {
            updateUser(withID: objectID, includingStatus: false)
        }
    }
    
    fileprivate func updateUser(withID objectID: NSManagedObjectID, includingStatus status: Bool) {
        let bckgContext = DataController.shared.newTaskContext()
        UserProvider().updateUser(withID: objectID,status: status, inContext: bckgContext)
    }
    
    fileprivate func getPiwigoConfigForUser(withID objectID: NSManagedObjectID) async throws(PwgKitError) {
        // Check Piwigo version, get token, available sizes, etc.
        if ServerVars.shared.usesCommunityPluginV29 {
            try await JSONManager.shared.communityGetStatus()
        }
        try await getPiwigoStatusForUser(withID: objectID)
    }
    
    fileprivate func getPiwigoStatusForUser(withID objectID: NSManagedObjectID) async throws(PwgKitError)
    {
        // Retrieve the username
        let userName = try await JSONManager.shared.sessionGetStatus()
        
        // Set Piwigo user
        ServerVars.shared.user = userName
        
        // Are cached data associated to an API public key?
        // (pursue logging in without waiting for the fix to complete)
        if ServerVars.shared.fixUserIsAPIKeyV412 {
            DispatchQueue.global(qos: .background).async {
                // Retrieve background context
                let bckgContext = DataController.shared.newTaskContext()
                
                // Attribute upload requests to appropriate user if necessary
                debugPrint("Session: attributing API Key upload requests to user…")
                UploadProvider().attributeAPIKeyUploadRequests(toUserWithID: objectID,
                                                               inContext: bckgContext)
                
                // Delete API Key user (and albums in cascade)
                debugPrint("Session: deleting API Key user…")
                UserProvider().deleteUser(withUsername: ServerVars.shared.username,
                                          inContext: bckgContext)
                
                // Job completed
                debugPrint("Session: API Key user deleted")
                ServerVars.shared.fixUserIsAPIKeyV412 = false
                
                // Try to resume upload requests if the low power mode is not enabled
                let name = Notification.Name.NSProcessInfoPowerStateDidChange
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }
}
