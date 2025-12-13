//
//  HapticUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
/// - https://ahap.fancypixel.it/0b758273087c
/// - https://github.com/FancyPixel/moby

import AVFoundation
import CoreHaptics
import Foundation

final class HapticUtilities {
    
    // A haptic engine manages the connection to the haptic server.
    @MainActor
    static var engine: CHHapticEngine? = {
        // Create and configure a haptic engine.
        var engine: CHHapticEngine?
        do {
            // Associate the haptic engine with the default audio session
            // to ensure the correct behavior when playing audio-based haptics.
            let audioSession = AVAudioSession.sharedInstance()
            engine = try CHHapticEngine(audioSession: audioSession)
        } catch let error {
            debugPrint("Engine Creation Error: \(error.localizedDescription)")
        }
        
        // The stopped handler alerts you of engine stoppage due to external causes.
        engine?.stoppedHandler = { reason in
            debugPrint("The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                debugPrint("Audio session interrupt")
            case .applicationSuspended:
                debugPrint("Application suspended")
            case .idleTimeout:
                debugPrint("Idle timeout")
            case .systemError:
                debugPrint("System error")
            case .notifyWhenFinished:
                debugPrint("Playback finished")
            case .gameControllerDisconnect:
                debugPrint("Controller disconnected.")
            case .engineDestroyed:
                debugPrint("Engine destroyed.")
            @unknown default:
                debugPrint("Unknown error")
            }
        }
 
        // The reset handler provides an opportunity for your app to restart the engine in case of failure.
        engine?.resetHandler = {
            // Try restarting the engine.
            debugPrint("The engine reset --> Restarting now!")
            do {
                try HapticUtilities.engine?.start()
            } catch {
                debugPrint("Failed to restart the engine: \(error.localizedDescription)")
            }
        }
        return engine
    }()
    
    // Play AHAP
    @MainActor
    static func playHapticsFile(named filename: String) {
        
        // If the device doesn't support Core Haptics, abort.
        if !AppVars.shared.supportsHaptics { return }
        
        // Express the path to the AHAP file before attempting to load it.
        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap")
        else { return }
        
        do {
            // Start the engine in case it's idle.
            try engine?.start()
            
            // Tell the engine to play a pattern.
            try engine?.playPattern(from: URL(fileURLWithPath: path))
            
        } catch { // Engine startup errors
            debugPrint("An error occured playing \(filename): \(error.localizedDescription).")
        }
    }
}
