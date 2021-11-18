//
//  UIImageView+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/11/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

import UIKit

// Constants
let playRatio: CGFloat = 58/75

@objc
extension UIImageView {
    
    // MARK: - Movie Icon
    func setMovieImage(inBackground: Bool) {
        var play = UIImage()
        if #available(iOS 13.0, *) {
            play = UIImage(systemName: "play.rectangle.fill")!
        } else {
            play = UIImage(named: "video")!
        }
        self.image = play.withRenderingMode(.alwaysTemplate)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.contentMode = .scaleAspectFit
        self.isHidden = true
        if inBackground {
            self.tintColor = .init(white: 0, alpha: 0.15)
        } else {
            self.tintColor = .white
        }
    }


    // MARK: - Favorite Icon
    func setFavoriteImage(inBackground: Bool) {
        var play = UIImage()
        if #available(iOS 13.0, *) {
            play = UIImage(systemName: "heart.fill")!
        } else {
            play = UIImage(named: "imageFavorite")!
        }
        self.image = play.withRenderingMode(.alwaysTemplate)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.contentMode = .scaleAspectFit
        self.isHidden = true
        if inBackground {
            self.tintColor = .init(white: 0, alpha: 0.15)
        } else {
            self.tintColor = .white
        }
    }
}
