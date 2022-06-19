//
//  AlbumViewController+TransitioningDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

//import Foundation
//
//extension AlbumViewController: UIViewControllerTransitioningDelegate {
//
//    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
//        // B2 - 16
//        guard let firstViewController = presenting as? AlbumViewController,
//            let secondViewController = presented as? ImageDetailViewController,
//            let selectedCellImageViewSnapshot = selectedCellImageViewSnapshot
//            else { return nil }
//
//        animator = Animator(type: .present,
//                            firstViewController: firstViewController,
//                            secondViewController: secondViewController,
//                            selectedCellImageViewSnapshot: selectedCellImageViewSnapshot)
//        return animator
//    }
//
//    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
//        return nil
//    }
//}
