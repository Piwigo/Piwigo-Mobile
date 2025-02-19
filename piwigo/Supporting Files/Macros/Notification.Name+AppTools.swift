//
//  Notification.Name+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public extension Notification.Name {
    
    /// - Change palette colour
    static let pwgPaletteChanged = Notification.Name("pwgNotificationPaletteChanged")
    
    // MARK: - Fetch Images
    /// - Did fetch images —> used to update title view
    static let pwgFetchedImages = Notification.Name("pwgNotificationFetchedImages")

    
    // MARK: - Play videos
    /// - Video ready to play, rate changed —> used to update buttons
    static let pwgVideoPlaybackStatus = Notification.Name("pwgNotificationVideoPlaybackStatus")
    /// - Video muted or unmuted —> used to update buttons
    static let pwgVideoMutedOrNot = Notification.Name("pwgNotificationVideoMutedOrNot")


    // MARK: - Share images & videos
    /// - Share completed
    static let pwgDidShare = Notification.Name("pwgNotificationDidShare")
    /// - Cancel download of object to share
    static let pwgCancelDownload = Notification.Name("pwgNotificationCancelDownload")
}
