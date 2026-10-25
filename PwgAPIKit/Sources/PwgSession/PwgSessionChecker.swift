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
 60 seconds short-circuit of the check, because none of them has stored the date of a more
 recent one yet, so each of them logs in again and every new session token invalidates the
 previous one. The requests already in flight are then answered by the server as if the
 user were a guest, i.e. with an authentication error.

 The work to perform is supplied by the caller, so that the app and the upload manager keep
 their own implementation, but only one of them runs at a time and the others adopt its
 outcome — including its failure, so that a caller never mistakes a shared failure for a
 successful session.
 */
public actor PwgSessionChecker {
    
    public static let shared = PwgSessionChecker()
    
    // Prevents duplicate instances
    private init() { }
    
    /// The check or the login being performed, if any.
    private var inFlight: Task<Result<Void, PwgKitError>, Never>?

    /// Whether the work in flight opens a session instead of checking one.
    private var inFlightOpensSession = false

    public func check(_ performCheck: @escaping @Sendable () async -> Result<Void, PwgKitError>) async throws(PwgKitError) {
        try await perform(performCheck, opensSession: false)
    }

    /**
     Opens a session, i.e. performs the sequence of the login view, while no check runs.

     A login is neither joined nor joining: the outcome of a login performed with the credentials
     which the user has just typed says nothing about the session a check is verifying — one of
     them may even belong to the server which is being left — and a check which logs in again
     during the login would invalidate the session it opens.
     */
    public func logIn(_ performLogin: @escaping @Sendable () async -> Result<Void, PwgKitError>) async throws(PwgKitError) {
        try await perform(performLogin, opensSession: true)
    }

    private func perform(_ work: @escaping @Sendable () async -> Result<Void, PwgKitError>,
                         opensSession: Bool) async throws(PwgKitError) {
        // Join the check which is already running, or queue this work behind it
        let task: Task<Result<Void, PwgKitError>, Never>
        if let inFlight, opensSession == false, inFlightOpensSession == false {
            task = inFlight
        } else {
            let previous = inFlight
            task = Task {
                /// The waiting is performed by the task itself, so that this actor is never
                /// suspended while the work it holds has not been awaited by its own caller.
                if let previous { _ = await previous.value }
                return await work()
            }
            inFlight = task
            inFlightOpensSession = opensSession
        }

        // Await its outcome
        /// The actor is released while suspended here, so the callers which arrive
        /// in the meantime join this very task instead of starting another one.
        let result = await task.value
        
        // Forget it so that the next caller checks the session again
        /// Another task may already have replaced it.
        if inFlight == task {
            inFlight = nil
            inFlightOpensSession = false
        }
        
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}
