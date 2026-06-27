//
//  LoginUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/02/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

enum pwgLoginContext {
    case nonTrustedCertificate
    case nonSecuredAccess
    case incorrectURL
}

struct LoginUtilities
{
    // MARK: - Login Business
    @MainActor
    static func checkAvailableSizes(forScale scale: CGFloat) {
        // Check that default sizes were initialised
        if AlbumVars.shared.defaultAlbumThumbnailSize == -1 {
            AlbumVars.shared.defaultAlbumThumbnailSize = AlbumUtilities.optimumAlbumThumbnailSizeForDevice().rawValue
        }
        if AlbumVars.shared.defaultThumbnailSize == -1 {
            AlbumVars.shared.defaultThumbnailSize = AlbumUtilities.optimumThumbnailSizeForDevice().rawValue
        }
        if ImageVars.shared.defaultImagePreviewSize == -1 {
            ImageVars.shared.defaultImagePreviewSize = ImageUtilities.optimumImageSizeForDevice().rawValue
        }
        
        // Check that the actual default album thumbnail size is available
        // and select the next available size in case of unavailability
        let albumThumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .thumb
        AlbumVars.shared.defaultAlbumThumbnailSize = getAvailableSize(near: albumThumbSize).rawValue
        debugPrint("Album thumbnail size: \(getAvailableSize(near: albumThumbSize))")
        
        // Check that the actual default image thumbnail size is available
        // and select the next available size in case of unavailability
        let imageThumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        AlbumVars.shared.defaultThumbnailSize = getAvailableSize(near: imageThumbSize).rawValue
        debugPrint("Image thumbnail size: \(getAvailableSize(near: imageThumbSize))")
        
        // Calculate number of thumbnails per row for that selection
        let albumThumbnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        let albumThumbnailMaxWidth = albumThumbnailSize.minPoints(forScale: scale) * scale  // i.e. 1 screen point = 1 image pixel
        let minNberOfImages: Int = AlbumUtilities.imagesPerRowInPortrait(forMaxWidth: albumThumbnailMaxWidth)
        
        // Make sure that default number fits inside selected range
        AlbumVars.shared.thumbnailsPerRowInPortrait = max(AlbumVars.shared.thumbnailsPerRowInPortrait, minNberOfImages);
        AlbumVars.shared.thumbnailsPerRowInPortrait = min(AlbumVars.shared.thumbnailsPerRowInPortrait, 2*minNberOfImages);
        
        // Check that the actual default image preview size is still available
        // and select the next available size in case of unavailability
        let imagePreviewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .fullRes
        ImageVars.shared.defaultImagePreviewSize = getAvailableSize(near: imagePreviewSize).rawValue
        debugPrint("Image preview size: \(getAvailableSize(near: imagePreviewSize))")
    }
    
    @MainActor
    private static func getAvailableSize(near wantedSize: pwgImageSize) -> pwgImageSize
    {
        // Select the next greater available size in case of unavailability
        // knowing that the fullRes file might not be available (treated case per case)
        var greaterSizes = pwgImageSize.allCases
        greaterSizes.removeAll(where: { $0 < wantedSize })
        for greaterSize in greaterSizes {
            if greaterSize.isAvailable {
                return greaterSize
            }
        }
        return .fullRes
    }
    
    @MainActor
    static func getHttpCredentialsAlert(textFieldDelegate: (any UITextFieldDelegate)?,
                                        username: String, password: String,
                                        cancelAction: @escaping ((UIAlertAction) -> Void),
                                        loginAction: @escaping ((UIAlertAction) -> Void)) -> UIAlertController {
        let alert = UIAlertController(
            title: String(localized: "loginHTTP_title", comment: "HTTP Credentials"),
            message: String(localized: "loginHTTP_message", comment: "Piwigo server requires HTTP basic access authentication…"),
            preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = String(localized: "loginHTTPuser_placeholder", comment: "username")
            textField.text = (username.count > 0) ? username : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = InterfaceVars.shared.isDarkPaletteActive ? .dark : .default
            textField.returnKeyType = .continue
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.delegate = textFieldDelegate
        })
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = String(localized: "loginHTTPpwd_placeholder", comment: "password")
            textField.text = (password.count > 0) ? password : ""
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.isSecureTextEntry = true
            textField.keyboardAppearance = InterfaceVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.returnKeyType = .continue
            textField.delegate = textFieldDelegate
        })
        
        let cancelAction = UIAlertAction(title: Localized.cancel,
                                         style: .cancel, handler: cancelAction)
        alert.addAction(cancelAction)
        
        let loginAction = UIAlertAction(
            title: String(localized: "alertOkButton", comment: "OK"),
            style: .default, handler: loginAction)
        alert.addAction(loginAction)
        
        alert.view.tintColor = PwgColor.tintColor
        alert.overrideUserInterfaceStyle = InterfaceVars.shared.isDarkPaletteActive ? .dark : .light
        return alert
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
            // Don't use userStatus as it may not be known after Core Data migration
            if ServerVars.shared.username.isEmpty || ServerVars.shared.username.lowercased() == "guest" {
                
                // Session opened for guest
                debugPrint("Session: logged as Guest")
                try await getPiwigoConfigForUser(withID: objectID)
                
                // Update date of accesss to the server by guest
                updateUser(withID: objectID, includingStatus: true)
                ServerVars.shared.applicationShouldRelogin = false
            }
            else {
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
