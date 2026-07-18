//
//  UITools.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 20/05/2026.
//

import Foundation
import UIKit

@MainActor
public final class UITools {
    
    // Singleton
    public static let shared = UITools()
    
    // MARK: - Light and Dark Modes
    // Called:
    /// - when the app is launched
    /// - when the user changes settings (PhoneTableViewCell and PadTableViewCell classes)
    /// - by traitCollectionDidChange() in the app when the system switches between Light and Dark modes
    /// NB: Extensions never call traitCollectionDidChange() because trait changes are driven by UIWindowScene.
    public func applyColorPalette(for userInterfaceStyle: UIUserInterfaceStyle) {
        // Color palette depends on system settings
        UIVars.shared.isSystemDarkModeActive = (userInterfaceStyle == .dark)
        
        // Apply color palette change if needed
        if UIVars.shared.isLightPaletteModeActive
        {
            if !UIVars.shared.isDarkPaletteActive {
                // Already in light mode but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                return;
            } else {
                // "Always Light Mode" selected
                UIVars.shared.isDarkPaletteActive = false
            }
        }
        else if UIVars.shared.isDarkPaletteModeActive
        {
            if UIVars.shared.isDarkPaletteActive {
                // Already showing dark palette but make sure that images stays in appropriate mode
                NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                return;
            } else {
                // "Always Dark Mode" selected or iOS Dark Mode active => Dark palette
                UIVars.shared.isDarkPaletteActive = true
            }
        }
        else if UIVars.shared.switchPaletteAutomatically
        {
            // Dynamic palette mode chosen
            if UIVars.shared.isSystemDarkModeActive {
                // System-wide dark mode active
                if UIVars.shared.isDarkPaletteActive {
                    // Keep dark palette but make sure that images stays in appropriate mode
                    NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                    return;
                } else {
                    // Switch to dark mode
                    UIVars.shared.isDarkPaletteActive = true
                }
            } else {
                // System-wide light mode active
                if UIVars.shared.isDarkPaletteActive {
                    // Switch to light mode
                    UIVars.shared.isDarkPaletteActive = false
                } else {
                    // Keep light palette but make sure that images stays in appropriate mode
                    NotificationCenter.default.post(name: .pwgPaletteChanged, object: nil)
                    return;
                }
            }
        } else {
            // Return to either static Light or Dark mode
            UIVars.shared.isLightPaletteModeActive = !UIVars.shared.isSystemDarkModeActive;
            UIVars.shared.isDarkPaletteModeActive = UIVars.shared.isSystemDarkModeActive;
            UIVars.shared.isDarkPaletteActive = UIVars.shared.isSystemDarkModeActive;
        }
        
        // Tint colour
        UIView.appearance().tintColor = PwgColor.tintColor
        
        // Activity indicator
        UIActivityIndicatorView.appearance().color = PwgColor.orange
        
        // Tab bars
        UITabBar.appearance().barTintColor = PwgColor.background
        
        // Styles
        if UIVars.shared.isDarkPaletteActive
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
        debugPrint("••> App changed to \(UIVars.shared.isDarkPaletteActive ? "dark" : "light") mode");
    }
    
    
    // - App Lock 
}
