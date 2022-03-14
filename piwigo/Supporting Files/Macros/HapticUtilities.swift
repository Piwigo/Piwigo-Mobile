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

@available(iOS 13.0, *)
class HapticUtilities {
    
    // Singleton
    static let shared = HapticUtilities()

    // A haptic engine manages the connection to the haptic server.
    var engine: CHHapticEngine? = {
        // Create and configure a haptic engine.
        var engine: CHHapticEngine?
        do {
            // Associate the haptic engine with the default audio session
            // to ensure the correct behavior when playing audio-based haptics.
            let audioSession = AVAudioSession.sharedInstance()
            engine = try CHHapticEngine(audioSession: audioSession)
        } catch let error {
            print("Engine Creation Error: \(error)")
        }
        
        guard let engine = engine else {
            print("Failed to create engine!")
            return nil
        }

        // The stopped handler alerts you of engine stoppage due to external causes.
        engine.stoppedHandler = { reason in
            print("The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                print("Audio session interrupt")
            case .applicationSuspended:
                print("Application suspended")
            case .idleTimeout:
                print("Idle timeout")
            case .systemError:
                print("System error")
            case .notifyWhenFinished:
                print("Playback finished")
            case .gameControllerDisconnect:
                print("Controller disconnected.")
            case .engineDestroyed:
                print("Engine destroyed.")
            @unknown default:
                print("Unknown error")
            }
        }
 
        // The reset handler provides an opportunity for your app to restart the engine in case of failure.
        engine.resetHandler = {
            // Try restarting the engine.
            print("The engine reset --> Restarting now!")
            do {
                try HapticUtilities.shared.engine?.start()
            } catch {
                print("Failed to restart the engine: \(error)")
            }
        }
        return engine
    }()
    
    // Play AHAP
    func playHapticsFile(named filename: String) {
        
        // If the device doesn't support Core Haptics, abort.
        if !AppVars.shared.supportsHaptics { return }
        
        // Express the path to the AHAP file before attempting to load it.
        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap") else {
            return
        }
        
        do {
            // Start the engine in case it's idle.
            try engine?.start()
            
            // Tell the engine to play a pattern.
            try engine?.playPattern(from: URL(fileURLWithPath: path))
            
        } catch { // Engine startup errors
            print("An error occured playing \(filename): \(error).")
        }
    }
}
