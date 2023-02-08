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
    class func space() -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                     target: nil, action: nil)
        return button
    }
    
    class func shareImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .action,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "share"
        return button
    }
    
    class func moveImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .reply,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "move"
        return button
    }
    
    class func deleteImageButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: .trash,
                                     target: target, action: action)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "delete"
        return button
    }
    
    
    // MARK: — Set Album Thumbnail Bar Button Item
    class func setThumbnailButton(_ target: Any?, action: Selector?) -> UIBarButtonItem {
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
    class func favoriteImageButton(_ isFavorite: Bool, target: Any?) -> UIBarButtonItem {
        let button = UIBarButtonItem(title: nil, style: .plain, target: target, action: nil)
        button.setFavoriteImage(for: isFavorite)
        button.tintColor = .piwigoColorOrange()
        button.accessibilityIdentifier = "favorite"
        return button
    }
    
    func setFavoriteImage(for state:Bool) {
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
}
