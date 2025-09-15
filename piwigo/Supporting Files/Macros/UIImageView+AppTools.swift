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
let playRatio: CGFloat = 1.0 // was 506:503

extension UIImageView {
    
    // MARK: - Movie Icon
    func setMovieIconImage() {
        let play = UIImage(systemName: "play.square.fill")!
        self.image = play.withRenderingMode(.alwaysTemplate)
        self.tintColor = UIColor.white
        self.translatesAutoresizingMaskIntoConstraints = false
        self.contentMode = .scaleAspectFit
        self.isHidden = true
    }


    // MARK: - Favorite Icon
    func setFavoriteIconImage() {
        let play = UIImage(systemName: "heart.fill")!
        self.image = play.withRenderingMode(.alwaysTemplate)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.contentMode = .scaleAspectFit
        self.isHidden = true
    }
}
