//
//  UIBarButtonItem+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/10/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit

extension UIBarButtonItem {
    
    // MARK: - System Based Bar Button Items
    static func space() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                     target: nil, action: nil)
        return button
    }
    
    static func shareImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .action,
                                     target: target, action: action)
        button.accessibilityIdentifier = "share"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    static func moveImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .reply,
                                     target: target, action: action)
        button.accessibilityIdentifier = "move"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    static func deleteImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .trash,
                                     target: target, action: action)
        button.accessibilityIdentifier = "delete"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    static func playImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .play,
                                     target: target, action: action)
        button.accessibilityIdentifier = "play"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    static func pauseImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .pause,
                                     target: target, action: action)
        button.accessibilityIdentifier = "pause"
        button.tintColor = PwgColor.tintColor
        return button
    }

    static func goToPageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.turn.down.right"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "goToPage"
        button.tintColor = PwgColor.tintColor
        return button
    }

    
    // MARK: - Set Album Thumbnail Bar Button Item
    static func setThumbnailButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "rectangle.and.paperclip"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "albumThumbnail"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    
    // MARK: - Favorite Bar Button Item
    static func favoriteImageButton(_ isFavorite: Bool, target: Any?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: nil)
        button.setFavoriteImage(for: isFavorite)
        button.accessibilityIdentifier = "favorite"
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    func setFavoriteImage(for state: Bool) {
        if state {
            self.image = UIImage(systemName: "heart.fill")
        } else {
            self.image = UIImage(systemName: "heart")
        }
    }
    
    
    // MARK: - Back Bar Button Item
    static func backImageButton(target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: action)
        button.setBackImage()
        button.tintColor = PwgColor.tintColor
        button.accessibilityIdentifier = "back"
        return button
    }
    
    func setBackImage() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .medium)
        self.image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
    }
    
    
    // MARK: - Mute Audio Playback
    static let pwgMuted = 1
    static let pwgNotMuted = 2
    static func muteAudioButton(_ isMuted: Bool, target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: action)
        button.setMuteAudioImage(for: isMuted)
        button.accessibilityIdentifier = "mute"
        button.tag = isMuted ? pwgMuted : pwgNotMuted
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    func setMuteAudioImage(for isMuted: Bool) {
        // NB: We do not use the SF symbols because their width difference leads
        // to a movement of the icon when switching from one to the other.
        if isMuted {
            self.image = UIImage(systemName: "speaker.slash.fill")
        } else {
            self.image = UIImage(systemName: "speaker.fill")
        }
    }
}
