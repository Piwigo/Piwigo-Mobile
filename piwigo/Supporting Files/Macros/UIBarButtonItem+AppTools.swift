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
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    static func moveImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .reply,
                                     target: target, action: action)
        button.accessibilityIdentifier = "move"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    static func deleteImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .trash,
                                     target: target, action: action)
        button.accessibilityIdentifier = "delete"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    static func playImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .play,
                                     target: target, action: action)
        button.accessibilityIdentifier = "play"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    static func pauseImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .pause,
                                     target: target, action: action)
        button.accessibilityIdentifier = "pause"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }

    static func goToPageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.turn.down.right"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "goToPage"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }

    
    // MARK: - Set Album Thumbnail Bar Button Item
    static func setThumbnailButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "rectangle.and.paperclip"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "albumThumbnail"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    
    // MARK: - Favorite Bar Button Item
    static func favoriteImageButton(_ isFavorite: Bool, target: Any?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: nil)
        button.setFavoriteImage(for: isFavorite)
        button.accessibilityIdentifier = "favorite"
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
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
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
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
        if #available(iOS 26.0, *) {
            button.tintColor = PwgColor.gray
        } else {
            button.tintColor = PwgColor.orange
        }
        return button
    }
    
    func setMuteAudioImage(for isMuted: Bool) {
        // NB: We do not use the SF symbols because their width difference leads
        // to a movement of the icon when switching from one to the other.
        if isMuted {
            if #available(iOS 13, *) {
                self.image = UIImage(systemName: "speaker.slash.fill")
            } else {
                let isAppLanguageL2R = UIApplication.shared.userInterfaceLayoutDirection == .leftToRight
                if isAppLanguageL2R {
                    self.image = UIImage(named: "mutedRight")
                    self.landscapeImagePhone = UIImage(named: "mutedRightCompact")
                } else {
                    self.image = UIImage(named: "mutedLeft")
                    self.landscapeImagePhone = UIImage(named: "mutedLeftCompact")
                }
            }
        } else {
            if #available(iOS 13, *) {
                self.image = UIImage(systemName: "speaker.wave.2.fill")
            } else {
                let isAppLanguageL2R = UIApplication.shared.userInterfaceLayoutDirection == .leftToRight
                if isAppLanguageL2R {
                    self.image = UIImage(named: "unmutedRight")
                    self.landscapeImagePhone = UIImage(named: "unmutedRightCompact")
                } else {
                    self.image = UIImage(named: "unmutedLeft")
                    self.landscapeImagePhone = UIImage(named: "unmutedLeftCompact")
                }
            }
        }
    }
}
