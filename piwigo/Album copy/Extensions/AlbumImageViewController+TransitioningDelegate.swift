//
//  AlbumImageViewController+TransitioningDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

extension AlbumImageViewController: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let albumViewController = presenting.children.last as? AlbumViewController,
              let imageNavViewController = presented as? UINavigationController,
              let albumViewSnapshot = self.albumViewSnapshot,
              let cellImageViewSnapshot = self.cellImageViewSnapshot,
              let navBarSnapshot = self.navBarSnapshot
            else { return nil }

        imageAnimator = ImageAnimatedTransitioning(type: .present, albumViewController: albumViewController,
                                                   imageNavViewController: imageNavViewController,
                                                   albumViewSnapshot: albumViewSnapshot,
                                                   cellImageViewSnapshot: cellImageViewSnapshot,
                                                   navBarSnapshot: navBarSnapshot)
        return imageAnimator
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
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
