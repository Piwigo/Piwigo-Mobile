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
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "share"
        return button
    }
    
    static func moveImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .reply,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "move"
        return button
    }
    
    static func deleteImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .trash,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "delete"
        return button
    }
    
    static func playImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .play,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "play"
        return button
    }
    
    static func pauseImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .pause,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "pause"
        return button
    }
    
    
    // MARK: - Set Album Thumbnail Bar Button Item
    static func setThumbnailButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button: UIBarButtonItem!
        if #available(iOS 13.0, *) {
            button = UIBarButtonItem(image: UIImage(systemName: "rectangle.and.paperclip"),
                                     style: .plain, target: target, action: action)
        } else {
            // Fallback on earlier versions
            button = UIBarButtonItem(image: UIImage(named: "imagePaperclip"),
                                     landscapeImagePhone: UIImage(named: "imagePaperclipCompact"),
                                     style: .plain, target: target, action: action)
        }
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "albumThumbnail"
        return button
    }
    
    
    // MARK: - Favorite Bar Button Item
    static func favoriteImageButton(_ isFavorite: Bool, target: Any?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: nil)
        button.setFavoriteImage(for: isFavorite)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "favorite"
        return button
    }
    
    func setFavoriteImage(for state: Bool) {
        if state {
            if #available(iOS 13.0, *) {
                self.image = UIImage(systemName: "heart.fill")
            } else {
                self.image = UIImage(named: "imageFavorite")
                self.landscapeImagePhone = UIImage(named: "imageFavoriteCompact")
            }
        } else {
            if #available(iOS 13.0, *) {
                self.image = UIImage(systemName: "heart")
            } else {
                self.image = UIImage(named: "imageNotFavorite")
                self.landscapeImagePhone = UIImage(named: "imageNotFavoriteCompact")
            }
        }
    }
    
    
    // MARK: - Play/Pause Bar Button Item
    static func playPauseImageButton(_ isPlaying: Bool, target: Any?, action: Selector?) -> UIBarButtonItem {
        let button: UIBarButtonItem
        if isPlaying {
            button = pauseImageButton(target, action: action)
        } else {
            button = playImageButton(target, action: action)
        }
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "play/pause"
        return button
    }
    
    
    // MARK: - Back Bar Button Item
    static func backImageButton(target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: action)
        button.setBackImage()
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "back"
        return button
    }
    
    func setBackImage() {
        if #available(iOS 13, *) {
            let configuration = UIImage.SymbolConfiguration(pointSize: 23, weight: .medium, scale: .medium)
            if #available(iOS 14.0, *) {
                self.image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
            } else {
                if AppVars.shared.isAppLanguageL2R {
                    self.image = UIImage(systemName: "chevron.left")
                } else {
                    self.image = UIImage(systemName: "chevron.right")
                }
            }
        } else {
            if AppVars.shared.isAppLanguageL2R {
                self.image = UIImage(named: "chevronBackLeft")
                self.landscapeImagePhone = UIImage(named: "chevronBackLeftCompact")
            } else {
                self.image = UIImage(named: "chevronBackRight")
                self.landscapeImagePhone = UIImage(named: "chevronBackRightCompact")
            }
        }
    }
}
