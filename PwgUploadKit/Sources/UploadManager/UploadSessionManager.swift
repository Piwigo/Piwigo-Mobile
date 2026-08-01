//
//  UploadSessionManager.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 19/06/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import os
import Foundation
import piwigoKit

@UploadManagerActor
public final class UploadSessionManager {
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadSessionManager.self))
    
    // Singleton
    static public let shared = UploadSessionManager()

    /// The active session new tasks are submitted to
    private(set) var bckgSession: URLSession
    
    /// Sessions that called finishTasksAndInvalidate() and are still draining
    private var drainingSessions: [URLSession] = []
    
    private init() {
        bckgSession = makeBckgSession(maxConnections: UploadVars.shared.maxConnectionsPerHost)
    }
    
    private var currentConnectionsPerHost = 4
    
    // Functions called within the framework
    func updateMaxConnectionsPerHost(to count: Int) {
        UploadSessionManager.logger.debug("Update max connections per host to \(count, privacy: .public)")
        let old = bckgSession
        drainingSessions.append(old)
        old.finishTasksAndInvalidate()
        bckgSession = makeBckgSession(maxConnections: count)
    }
    
    func sessionDidBecomeInvalid(_ identifier: String) {
        UploadSessionManager.logger.debug("Session \(identifier, privacy: .public) became invalid")
        drainingSessions.removeAll { $0.configuration.identifier ?? "" == identifier }
    }
    
    
    // Public functions
    public func reattach(identifier: String, maxConnections: Int) {
        // Active session? Nothing to do
        if bckgSession.configuration.identifier == identifier {
            return
        }
        
        // Already among the draining sessions?
        if drainingSessions.contains(where: { $0.configuration.identifier == identifier }) {
            return
        }
        
        // Recreate the session
        UploadSessionManager.logger.debug("Re-attach session \(identifier, privacy: .public)")
        let session = makeBckgSession(maxConnections: maxConnections)
        drainingSessions.append(session)
    }

    public func allTasks() async -> [URLSessionTask] {
        var allTasks: [URLSessionTask] = []
        for session in [bckgSession] + drainingSessions {
            allTasks.append(contentsOf: await session.allTasks)
        }
        return allTasks
    }
}
