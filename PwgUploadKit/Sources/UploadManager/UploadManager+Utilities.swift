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
    public func checkSession(ofUser userData: inout UserProperties) async throws(PwgKitError) {
        
        // Check if the session is still active and re-login every 60 seconds or more
        let secondsSinceLastCheck = Date.timeIntervalSinceReferenceDate - userData.lastUsed
        if ServerVars.shared.hasNetworkConnectionChanged == false,
           secondsSinceLastCheck < 60 {
            return
        }
        
        // Determine if the session is still active
        ServerVars.shared.hasNetworkConnectionChanged = false
        #if DEBUG
        debugPrint("Session: starting checking… \(ServerVars.shared.isConnectedToWiFi ? "WiFi" : "Cellular")")
        #endif
        let oldToken = ServerVars.shared.pwgToken
        var sessionData = userData
        try await JSONManager.shared.sessionGetStatus(&sessionData)
#if DEBUG
        debugPrint("Session: \"\(ServerVars.shared.username)\" vs \"\(sessionData.username)\", \"\(oldToken)\" vs \"\(ServerVars.shared.pwgToken)\"")
#endif
        let bckgContext = DataController.shared.newTaskContext()
        if sessionData.username != ServerVars.shared.username || oldToken.isEmpty || ServerVars.shared.pwgToken != oldToken {
            // Collect list of methods supplied by Piwigo server
            // => Determine if Community extension 2.9a or later is installed and active
            try await JSONManager.shared.getMethods()
            
            // Perform login
            let username = ServerVars.shared.login
            let password = KeychainUtilities.password(forService: ServerVars.shared.serverPath, account: username)
            try await JSONManager.shared.sessionLogin(withUsername: username, password: password)
#if DEBUG
            debugPrint("Session: logged as \(ServerVars.shared.login)")
#endif
            // Check Piwigo version, get token, available sizes, etc.
            if ServerVars.shared.usesCommunityPluginV29 {
                try await JSONManager.shared.communityGetStatus(&userData)
            }
            else {
                userData.createAlbumRights = nil
            }
            try await getPiwigoStatusForUser(&userData)

            // Update date of accesss to the server by guest
            userData.lastUsed = Date.timeIntervalSinceReferenceDate
            try UserProvider().updateUser(withProperties: userData, inContext: bckgContext)
        }
    }
            
    fileprivate func getPiwigoStatusForUser(_ userData: inout UserProperties) async throws(PwgKitError)
    {
        // Retrieve the username
        try await JSONManager.shared.sessionGetStatus(&userData)
                
        // Are cached data associated to an API public key?
        // (pursue logging in without waiting for the fix to complete)
        if ServerVars.shared.fixUserIsAPIKeyV412 {
            let userURIstr = userData.URIstr
            DispatchQueue.global(qos: .background).async {
                // Retrieve background context
                let bckgContext = DataController.shared.newTaskContext()
                
                // Attribute upload requests to appropriate user if necessary
                #if DEBUG
                debugPrint("Session: attributing API Key upload requests to user…")
                #endif
                UploadProvider().attributeAPIKeyUploadRequests(toUserWithID: userURIstr,
                                                               inContext: bckgContext)
                
                // Delete API Key user (and albums in cascade)
                #if DEBUG
                debugPrint("Session: deleting API Key user…")
                #endif
                UserProvider().deleteUser(withUsername: ServerVars.shared.login,
                                          inContext: bckgContext)
                
                // Job completed
                #if DEBUG
                debugPrint("Session: API Key user deleted")
                #endif
                ServerVars.shared.fixUserIsAPIKeyV412 = false
                
                // Try to resume upload requests if the low power mode is not enabled
                let name = Notification.Name.NSProcessInfoPowerStateDidChange
                NotificationCenter.default.post(name: name, object: nil)
            }
        }
    }
}
