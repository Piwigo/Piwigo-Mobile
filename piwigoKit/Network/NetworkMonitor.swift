//
//  NetworkMonitor.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 13 August 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Network
import Foundation

@globalActor actor NetworkMonitoring {
    public static let shared = NetworkMonitoring()
    
    private init() { }
}

@NetworkMonitoring
final class NetworkMonitor {
    
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
        
    init() {
        monitor.pathUpdateHandler = { path in
            // Network connection change
            PwgSession.shared.hasNetworkConnectionChanged = true
            
            // Interface type?
            NetworkVars.shared.isConnectedToWiFi = path.usesInterfaceType(.wifi)
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
