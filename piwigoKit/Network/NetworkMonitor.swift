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

        // Register network monitoring stopper
        NotificationCenter.default.addObserver(forName: Notification.Name.pwgStopNetworkMonitoring, object: nil, queue: nil) { [weak self] _ in
            Task { @NetworkMonitoring in
                self?.stopMonitoring()
                debugPrint("••> Network monitoring stopped.")
            }
        }
    }
    
    public func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            // Network connection change
            NetworkVars.shared.hasNetworkConnectionChanged = true
            
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
