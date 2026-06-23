//
//  AppMetrics.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 21/06/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import os
import Foundation
import MetricKit
import piwigoKit

final class AppMetrics: NSObject, MXMetricManagerSubscriber {
    
    static let shared = AppMetrics()
    
    // Logs migration activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    private let logger = Logger(subsystem: "org.piwigo", category: String(describing: AppMetrics.self))
    
    func start() {
        MXMetricManager.shared.add(self)
    }
    
    deinit {
        MXMetricManager.shared.remove(self)
    }
    
    // Receive daily metrics
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.notice("Metrics received: \(payload.debugDescription, privacy: .public)")
            saveMetrics(withName: "Metrics", jsonData: payload.jsonRepresentation())
        }
    }
    
    // Receive diagnostics immediately when available
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logger.notice("Metrics received: \(payload.debugDescription, privacy: .public)")
            saveMetrics(withName: "Diagnostics", jsonData: payload.jsonRepresentation())
        }
    }
    
    
    // MARK: - Settings
    func saveSettings() {
        do {
            // Should be sent separately to ensure anonymity
            let appJSONData = try JSONEncoder().encode(appSettings)
            saveMetrics(withName: "App-Settings", jsonData: appJSONData)
            let pwgJSONData = try JSONEncoder().encode(pwgSettings)
            saveMetrics(withName: "Piwigo-Settings", jsonData: pwgJSONData)
        } catch {
            logger.notice("Metrics error encountered while preparing anonymous settings: \(error.localizedDescription)")
        }
    }
    
    private let appSettings: [String: String] = [
        "appVersion"                    : Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
        "switchPaletteAutomatically"    : UserDefaults.standard.object(forKey: "switchPaletteAutomatically") as? Bool ?? false ? "Yes" : "No",
        "isAppLockActive"               : UserDefaults.standard.object(forKey: "isAppLockActive") as? Bool ?? false ? "Yes" : "No",
        "displayAlbumDescriptions"      : UserDefaults.standard.object(forKey: "displayAlbumDescriptions") as? Bool ?? false ? "Yes" : "No",
        "userStatusRaw"                 : UserDefaults.dataSuite.object(forKey: "userStatusRaw") as? String ?? "Unknown"
    ]

    private let pwgSettings: [String: String] = [
        "pwgVersion"                    : UserDefaults.dataSuite.object(forKey: "pwgVersion") as? String ?? "Unknown",
        "serverFileTypes"               : UserDefaults.dataSuite.object(forKey: "serverFileTypes") as? String ?? "Unknown",
        "usesCommunityPluginV29"        : UserDefaults.dataSuite.object(forKey: "usesCommunityPluginV29") as? Bool ?? false ? "Yes" : "No",
        "usesAPIkeys"                   : UserDefaults.dataSuite.object(forKey: "usesAPIkeys") as? Bool ?? false ? "Yes" : "No"
    ]
    
    struct SettingEvent: Encodable {
        let key: String
        let value: String
    }
    
    
    // MARK: - Utilities
    private func saveMetrics(withName type: String, jsonData: Data) {
        // Prepare file name from current date (local time)
        let fileName: String = JSONprefix + DateUtilities.logsDateFormatter.string(from: Date()) + " " + type + JSONextension
        
        // Logs are saved in the /tmp directory and will be deleted:
        // - by the app if the user kills it
        // - by the system after a certain amount of time
        let filePath = NSTemporaryDirectory().appending(fileName)
        if FileManager.default.fileExists(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        FileManager.default.createFile(atPath: filePath, contents: jsonData)
    }
}
