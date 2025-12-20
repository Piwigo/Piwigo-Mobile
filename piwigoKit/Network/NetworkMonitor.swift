//
//  NetworkMonitor.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Network
import Foundation

@globalActor
public actor NetworkMonitoring {
    public static let shared = NetworkMonitoring()
    
    private init() { }  // Prevents duplicate instances
}

@NetworkMonitoring
public final class NetworkMonitor {
    
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
        
    public init() {
        startMonitoring()
    }
    
    public func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            // Network connection change
            PwgSession.shared.hasNetworkConnectionChanged = true
            
            // Interface type?
            NetworkVars.shared.isConnectedToWiFi = path.usesInterfaceType(.wifi)
        }
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        monitor.cancel()
    }
}
