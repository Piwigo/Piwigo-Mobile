//
//  SettingsUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

class SettingsUtilities: NSObject {
    
    // Return the author names for different devices and orientations
    static func getAuthors(forView view: UIView) -> String {
        // Piwigo authors
        let authors1 = NSLocalizedString("authors1", tableName: "About", bundle: Bundle.main, value: "", comment: "By Spencer Baker, Olaf Greck,")
        let authors2 = NSLocalizedString("authors2", tableName: "About", bundle: Bundle.main, value: "", comment: "and Eddy Lelièvre-Berna")
        
        // Change label according to orientation
        var orientation: UIInterfaceOrientation
        if #available(iOS 13.0, *) {
            orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        if (UIDevice.current.userInterfaceIdiom == .phone) && orientation.isPortrait {
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
        return "— \(NSLocalizedString("version", tableName: "About", bundle: Bundle.main, value: "", comment: "Version:")) \(appVersionString ?? "") (\(appBuildString ?? "")) —"
    }
}
