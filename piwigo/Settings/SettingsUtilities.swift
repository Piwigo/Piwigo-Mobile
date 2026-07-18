//
//  SettingsUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import MessageUI
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

struct SettingsUtilities
{
    // Return the author names for different devices and orientations
    static func getAuthors(forView view: UIView) -> String {
        // Piwigo authors
        let authors1 = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        let authors2 = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")
        
        // Change label according to orientation
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        if (view.traitCollection.userInterfaceIdiom == .phone) && orientation.isPortrait {
            // iPhone in portrait mode
            return "\(authors1)\r\(authors2)"
        }
        else {
            // iPhone in landscape mode, iPad in any orientation
            return "\(authors1) \(authors2)"
        }
    }
    
    // Return the version and build number
    static func getAppVersion() -> String {
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionTitle = NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version")
        return "— \(versionTitle) \(appVersionString ?? "") (\(appBuildString ?? "")) —"
    }
    
    // Return mail composer
    static func getMailComposer() -> MFMailComposeViewController? {
        // Check that one can send mails
        if !MFMailComposeViewController.canSendMail() {
            return nil
        }
        
        let composeVC = MFMailComposeViewController()
        composeVC.view.tintColor = PwgColor.tintColor
        
        // Configure the fields of the interface.
        composeVC.setToRecipients([
            NSLocalizedString("contact_email", tableName: "PrivacyPolicy", bundle: Bundle.main, value: "", comment: "Contact email")
        ])
        
        // Compile ticket number from current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmm"
        dateFormatter.locale = NSLocale(localeIdentifier: ServerVars.shared.language) as Locale
        let date = Date()
        let ticketDate = dateFormatter.string(from: date)
        
        // Set subject
        composeVC.setSubject("[Ticket#\(ticketDate)]: \(String(localized: "settings_appName", comment: "Piwigo Mobile")) \(String(localized: "settings_feedback", comment: "Feedback"))")
        
        // Initialise message body
        var msg = "\n\n\n__________________\n"

        // Version and build numbers
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        msg += "\(String(localized: "settings_appName", comment: "Piwigo Mobile")) \(appVersion) (\(appBuild))\n"
        
        // Device and system info
        msg += "\(UIDevice.current.modelName) — \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)\n"
        
        // App settings
        msg += "\n— Piwigo App —\n"
        msg += "• switchPaletteAutomatically: \(InterfaceVars.shared.switchPaletteAutomatically ? "Yes" : "No")\n"
        msg += "• isAppLockActive: \(AppVars.shared.isAppLockActive ? "Yes" : "No")\n"
        msg += "• isBiometricsEnabled: \(AppVars.shared.isBiometricsEnabled ? "Yes" : "No")\n"
        msg += "• userStatusRaw: \(ServerVars.shared.userStatus)\n"
        msg += "• displayAlbumDescriptions: \(AlbumVars.shared.displayAlbumDescriptions ? "Yes" : "No")\n"
        msg += "• displayImageTitles: \(AlbumVars.shared.displayImageTitles ? "Yes" : "No")\n"
        msg += "• clearClipboardDelay: \((pwgClearClipboard(rawValue: AppVars.shared.clearClipboardDelay) ?? .never).delayText)\n"
        msg += "• isAutoUploadActive: \(UploadVars.shared.isAutoUploadActive ? "Yes" : "No")\n"
        msg += "• maxNberOfPreparedUploads: \(UploadVars.shared.maxNberOfPreparedUploads)\n"
        msg += "• maxConnectionsPerHost: \(UploadVars.shared.maxConnectionsPerHost)\n"
        msg += "• customUploadChunkSize: \(ServerVars.shared.customUploadChunkSize) KB\n"

        // Piwigo server settings
        msg += "\n— Piwigo Server —\n"
        msg += "• pwgVersion: \(ServerVars.shared.pwgVersion)\n"
        msg += "• stringEncoding: \(ServerVars.shared.stringEncoding)\n"
        if #available(iOS 16.0, *) {
            msg += "• serverFileTypes: \(ServerVars.shared.serverFileTypes.replacing(",", with: ", "))\n"
        } else {
            // Fallback on earlier versions
            msg += "• serverFileTypes: \(ServerVars.shared.serverFileTypes.replacingOccurrences(of: ",", with: ", "))\n"
        }
        msg += "• usesCommunityPluginV29: \(ServerVars.shared.usesCommunityPluginV29 ? "Yes" : "No")\n"
        msg += "• usesAPIkeys: \(NetworkVars.shared.usesAPIkeys ? "Yes" : "No")\n"
        msg += "• usesSetCategory: \(ServerVars.shared.usesSetCategory ? "Yes" : "No")\n"
        
        composeVC.setMessageBody(msg, isHTML: false)
        return composeVC
    }
}
