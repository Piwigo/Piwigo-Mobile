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
import piwigoKit

class SettingsUtilities: NSObject {
    
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
        
        // Collect version and build numbers
        let appVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appBuildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        // Compile ticket number from current date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmm"
        dateFormatter.locale = NSLocale(localeIdentifier: NetworkVars.shared.language) as Locale
        let date = Date()
        let ticketDate = dateFormatter.string(from: date)
        
        // Set subject
        composeVC.setSubject("[Ticket#\(ticketDate)]: \(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(NSLocalizedString("settings_feedback", comment: "Feedback"))")
        
        // Collect system and device data
        let deviceModel = UIDevice.current.modelName
        let deviceOS = UIDevice.current.systemName
        let deviceOSversion = UIDevice.current.systemVersion
        
        // Set message body
        composeVC.setMessageBody("\(NSLocalizedString("settings_appName", comment: "Piwigo Mobile")) \(appVersionString ?? "") (\(appBuildString ?? ""))\n\(deviceModel ) — \(deviceOS) \(deviceOSversion)\n==============>>\n\n", isHTML: false)
        
        return composeVC
    }
}
