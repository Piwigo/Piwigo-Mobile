//
//  PwgSessionChecker.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 15/09/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

/**
 Joins concurrent session checks instead of performing them in parallel.

 The session is checked from about thirty places in the app and from the upload manager,
 and several of them run at the same time — e.g. the album which appears when a scene is
 restored and the upload requests which resume at the very same moment. They all pass the
 60 seconds short-circuit of the check, because the date of the last check is only stored
 once a re-login succeeded, so each of them logs in again and every new session token
 invalidates the previous one. The requests already in flight are then answered by the
 server as if the user were a guest, i.e. with an authentication error.

 The work to perform is supplied by the caller, so that the app and the upload manager keep
 their own implementation, but only one of them runs at a time and the others adopt its
 outcome — including its failure, so that a caller never mistakes a shared failure for a
 successful session.
 */
public actor PwgSessionChecker {
    
    public static let shared = PwgSessionChecker()
    
    // Prevents duplicate instances
    private init() { }
    
    /// The check being performed, if any.
    private var inFlight: Task<Result<Void, PwgKitError>, Never>?
    
    public func check(_ performCheck: @escaping @Sendable () async -> Result<Void, PwgKitError>) async throws(PwgKitError) {
        // Join the check which is already running, or start one
        let task: Task<Result<Void, PwgKitError>, Never>
        if let inFlight {
            task = inFlight
        } else {
            task = Task { await performCheck() }
            inFlight = task
        }
        
        // Await its outcome
        /// The actor is released while suspended here, so the callers which arrive
        /// in the meantime join this very task instead of starting another one.
        let result = await task.value
        
        // Forget it so that the next caller checks the session again
        /// Another task may already have replaced it.
        if inFlight == task {
            inFlight = nil
        }
        
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
