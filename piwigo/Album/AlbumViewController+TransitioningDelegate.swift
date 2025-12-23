//
//  AlbumViewController+TransitioningDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension AlbumViewController: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let albumViewController = presenting.children.last as? AlbumViewController,
              let imageNavViewController = presented as? UINavigationController,
              let albumViewSnapshot = self.albumViewSnapshot,
              let cellImageViewSnapshot = self.cellImageViewSnapshot,
              let navBarSnapshot = self.navBarSnapshot
            else { return nil }

        imageAnimator = ImageAnimatedTransitioning(type: .present,
                                                   albumViewController: albumViewController,
                                                   imageNavViewController: imageNavViewController,
                                                   albumViewSnapshot: albumViewSnapshot,
                                                   cellImageViewSnapshot: cellImageViewSnapshot,
                                                   navBarSnapshot: navBarSnapshot)
        return imageAnimator
    }

    public func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        guard let imageNavViewController = dismissed as? UINavigationController,
              let albumViewSnapshot = self.albumViewSnapshot,
              let cellImageViewSnapshot = self.cellImageViewSnapshot,
              let navBarSnapshot = self.navBarSnapshot
            else { return nil }

        imageAnimator = ImageAnimatedTransitioning(type: .dismiss, albumViewController: self,
                                                   imageNavViewController: imageNavViewController,
                                                   albumViewSnapshot: albumViewSnapshot,
                                                   cellImageViewSnapshot: cellImageViewSnapshot,
                                                   navBarSnapshot: navBarSnapshot)
        return imageAnimator
    }
}
