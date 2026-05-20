//
//  InterfaceManager.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 20/05/2026.
//

import Foundation
import UIKit

@MainActor
public final class InterfaceManager {
    
    // Singleton
    public static let shared = InterfaceManager()
        
    // MARK: - Light and Dark Modes
    public func initColorPalette() {
        // Color palette depends on system settings
        InterfaceVars.shared.isSystemDarkModeActive = (UIScreen.main.traitCollection.userInterfaceStyle == .dark)
        debugPrint("••> iOS mode: \(InterfaceVars.shared.isSystemDarkModeActive ? "Dark" : "Light"), App mode: \(InterfaceVars.shared.isDarkPaletteModeActive ? "Dark" : "Light"), app: \(InterfaceVars.shared.isDarkPaletteActive ? "Dark" : "Light")")

        // Apply color palette
        screenBrightnessChanged()
    }
    
    // Called when the user changes settings and by
    // traitCollectionDidChange() when the system switches between Light and Dark modes
    @objc public func screenBrightnessChanged() {
        if InterfaceVars.shared.isLightPaletteModeActive
        {
            if !InterfaceVars.shared.isDarkPaletteActive {
                // Already in light mode but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                return;
            } else {
                // "Always Light Mode" selected
                InterfaceVars.shared.isDarkPaletteActive = false
            }
        }
        else if InterfaceVars.shared.isDarkPaletteModeActive
        {
            if InterfaceVars.shared.isDarkPaletteActive {
                // Already showing dark palette but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                return;
            } else {
                // "Always Dark Mode" selected or iOS Dark Mode active => Dark palette
                InterfaceVars.shared.isDarkPaletteActive = true
            }
        }
        else if InterfaceVars.shared.switchPaletteAutomatically
        {
            // Dynamic palette mode chosen
            if InterfaceVars.shared.isSystemDarkModeActive {
                // System-wide dark mode active
                if InterfaceVars.shared.isDarkPaletteActive {
                    // Keep dark palette but make sure that images stays in appropriate mode
                    NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                    return;
                } else {
                    // Switch to dark mode
                    InterfaceVars.shared.isDarkPaletteActive = true
                }
            } else {
                // System-wide light mode active
                if InterfaceVars.shared.isDarkPaletteActive {
                    // Switch to light mode
                    InterfaceVars.shared.isDarkPaletteActive = false
                } else {
                    // Keep light palette but make sure that images stays in appropriate mode
                    NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                    return;
                }
            }
        } else {
            // Return to either static Light or Dark mode
            InterfaceVars.shared.isLightPaletteModeActive = !InterfaceVars.shared.isSystemDarkModeActive;
            InterfaceVars.shared.isDarkPaletteModeActive = InterfaceVars.shared.isSystemDarkModeActive;
            InterfaceVars.shared.isDarkPaletteActive = InterfaceVars.shared.isSystemDarkModeActive;
        }
        
        // Tint colour
        UIView.appearance().tintColor = PwgColor.tintColor
        
        // Activity indicator
        UIActivityIndicatorView.appearance().color = PwgColor.orange
        
        // Tab bars
        UITabBar.appearance().barTintColor = PwgColor.background

        // Styles
        if InterfaceVars.shared.isDarkPaletteActive
        {
            UITabBar.appearance().barStyle = .black
            UIToolbar.appearance().barStyle = .black
            UINavigationBar.appearance().barStyle = .black
        }
        else {
            UITabBar.appearance().barStyle = .default
            UIToolbar.appearance().barStyle = .default
            UINavigationBar.appearance().barStyle = .default
        }

        // Notify palette change to views
        NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
//        debugPrint("••> App changed to \(InterfaceVars.shared.isDarkPaletteActive ? "dark" : "light") mode");
    }
}
