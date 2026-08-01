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
import PwgKit
import PwgAPIKit

final class AppMetrics: NSObject, MXMetricManagerSubscriber {
    
    static let shared = AppMetrics()
    
    // Logs app metrics
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    private let logger = PwgLogger(subsystem: "org.piwigo", category: String(describing: AppMetrics.self))
    
    func start() {
        MXMetricManager.shared.add(self)
    }
    
    deinit {
        MXMetricManager.shared.remove(self)
    }
    
    // Receive daily metrics
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.notice("Metrics received: \(payload.debugDescription)")
            saveMetrics(withName: "Metrics", jsonData: payload.jsonRepresentation())
        }
    }
    
    // Receive diagnostics immediately when available
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            logger.notice("Metrics received: \(payload.debugDescription)")
            saveMetrics(withName: "Diagnostics", jsonData: payload.jsonRepresentation())
        }
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
