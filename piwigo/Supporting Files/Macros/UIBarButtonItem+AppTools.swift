//
//  UIBarButtonItem+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/10/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import UIKit
import PwgUIKit

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
    
    static func goToPageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.turn.down.right"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "goToPage"
        button.accessibilityLabel = String(localized: "goToPage_title", comment: "Go to page…")
        button.tintColor = PwgColor.tintColor
        return button
    }

    
    // MARK: - Set Album Thumbnail Bar Button Item
    static func setThumbnailButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: "rectangle.and.paperclip"),
                                     style: .plain, target: target, action: action)
        button.accessibilityIdentifier = "albumThumbnail"
        button.accessibilityLabel = String(localized: "imageOptions_setAlbumImage", comment: "Set as Album Thumbnail")
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
            self.accessibilityLabel = String(localized: "categoryImageList_unfavorite", comment: "Unfavorite")
        } else {
            self.image = UIImage(systemName: "heart")
            self.accessibilityLabel = String(localized: "categoryImageList_favorite", comment: "Favorite")
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
        self.accessibilityLabel = String(localized: "backButton_title", comment: "Back")
    }
    
    
    // MARK: - Help Bar Button Item
    static func helpButton(target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: action)
        button.setHelpImage()
        button.accessibilityIdentifier = "Help"
        button.accessibilityLabel = String(localized: "settings_help", comment: "Help")
        button.tintColor = PwgColor.tintColor
        return button
    }
    
    private func setHelpImage() {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .medium)
        self.image = UIImage(systemName: "chevron.backward", withConfiguration: configuration)
        if #available(iOS 26.0, *) {
            self.image = UIImage(systemName: "questionmark")
        } else {
            self.image = UIImage(systemName: "questionmark.circle")
        }
    }
}
