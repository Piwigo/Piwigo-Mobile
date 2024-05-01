//
//  AlbumImageTableViewController+TransitioningDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension AlbumImageTableViewController: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController,
                                    presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let albumImageTableViewController = presenting.children.last as? AlbumImageTableViewController,
              let imageNavViewController = presented as? UINavigationController,
              let albumViewSnapshot = self.albumViewSnapshot,
              let cellImageViewSnapshot = self.cellImageViewSnapshot,
              let navBarSnapshot = self.navBarSnapshot
            else { return nil }

        imageAnimator = ImageAnimatedTransitioning(type: .present,
                                                   albumImageTableViewController: albumImageTableViewController,
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

        imageAnimator = ImageAnimatedTransitioning(type: .dismiss, albumImageTableViewController: self,
                                                   imageNavViewController: imageNavViewController,
                                                   albumViewSnapshot: albumViewSnapshot,
                                                   cellImageViewSnapshot: cellImageViewSnapshot,
                                                   navBarSnapshot: navBarSnapshot)
        return imageAnimator
    }
}
