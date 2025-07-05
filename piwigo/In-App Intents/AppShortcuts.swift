//
//  AppShortcuts.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/06/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import AppIntents

/**
 An `AppShortcut` wraps an intent to make it automatically discoverable throughout the system. An `AppShortcutsProvider` manages the shortcuts the app
 makes available. The app can update the available shortcuts by calling `updateAppShortcutParameters()` as needed.
 */
@available(iOS 16.0, *)
class AppShortcuts: AppShortcutsProvider {
    
    /// The color the system uses to display the App Shortcuts in the Shortcuts app.
    static let shortcutTileColor = ShortcutTileColor.orange
    
    /**
     Only the intents this array describes should make sense as App Shortcuts.
     Put the App Shortcut most people will use as the first item in the array. This first shortcut shouldn't bring the app to the foreground.
     
     Each phrase that people use to invoke an App Shortcut needs to contain the app name, using the `applicationName` placeholder in the provided
     phrase text, as well as any app name synonyms you declare in the `INAlternativeAppNames` key of the app's `Info.plist` file. You localize these
     phrases in a string catalog named `AppShortcuts.xcstrings`.
     */
    static var appShortcuts: [AppShortcut]
    {
        AppShortcut(intent: AutoUpload(), phrases: [
            "Upload photos with \(.applicationName)",
            "Upload my photos to \(.applicationName)",
            "Upload my photos with \(.applicationName)",
            "Upload my latest photos with \(.applicationName)",
            "Auto-upload photos with \(.applicationName)",
            "Auto-upload my photos with \(.applicationName)"
        ],
        shortTitle: LocalizedStringResource("Auto-Upload Photos", table: "In-AppIntents"),
        systemImageName: "photo.stack")
    }
}
