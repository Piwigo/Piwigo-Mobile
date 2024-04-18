//
//  ImageAnimatedTransitioning.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

enum PresentationType {
    case present
    case dismiss

    var isPresenting: Bool {
        return self == .present
    }
}

// See https://medium.com/@tungfam/custom-uiviewcontroller-transitions-in-swift-d1677e5aa0bf
final class ImageAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

    static let duration: TimeInterval = {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 0.5
        } else {
            return 0.25
        }
    }()

    private let type: PresentationType
    private let albumImageTableViewController: AlbumImageTableViewController
    private let imageNavViewController: UINavigationController
    private let albumViewSnapshot: UIView
    private var cellImageViewSnapshot: UIView
    private var cellImageViewRect: CGRect
    private let navBarSnapshot: UIView
    private let navBarRect: CGRect

    init?(type: PresentationType,
          albumImageTableViewController: AlbumImageTableViewController,
          imageNavViewController: UINavigationController,
          albumViewSnapshot: UIView,
          cellImageViewSnapshot: UIView,
          navBarSnapshot: UIView)
    {
        self.type = type
        self.albumImageTableViewController = albumImageTableViewController
        self.imageNavViewController = imageNavViewController
        self.albumViewSnapshot = albumViewSnapshot
        self.cellImageViewSnapshot = cellImageViewSnapshot
        self.navBarSnapshot = navBarSnapshot
        
        guard let window = albumImageTableViewController.view.window ?? imageNavViewController.view.window,
              let animatedCell = albumImageTableViewController.animatedCell,
              let navBar = albumImageTableViewController.navigationController?.navigationBar
            else { return nil } // i.e. use default present/dismiss animation

        // Get frame of cell relative to the window’s frame
        self.cellImageViewRect = animatedCell.convert(animatedCell.bounds, to: window)

        // Get frame of navigation bar relative to the window’s frame
        self.navBarRect = navBar.convert(navBar.bounds, to: window)
    }

    // Return animation duration
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return Self.duration
    }

    // Transition logic and animation
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        // Retrieve window and image or video detail view
        guard let window = albumImageTableViewController.view.window ?? imageNavViewController.view.window,
              let imageViewController = imageNavViewController.children.last as? ImageViewController,
              let detailVC = imageViewController.pageViewController?.viewControllers?.first
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        // Retrieve snapshot
        if let imageDVC = detailVC as? ImageDetailViewController,
           let imageViewSnapshot = imageDVC.imageView.snapshotView(afterScreenUpdates: true) {
            presentOrDismissView(using: transitionContext, imageViewController: imageViewController,
                                 detailViewController: imageDVC, imageViewSnapshot: imageViewSnapshot,
                                 window: window)
            return
        }
        else if let videoDVC = detailVC as? VideoDetailViewController,
                let imageViewSnapshot = videoDVC.placeHolderView.snapshotView(afterScreenUpdates: true) {
            presentOrDismissView(using: transitionContext, imageViewController: imageViewController,
                                 detailViewController: videoDVC, imageViewSnapshot: imageViewSnapshot,
                                 window: window)
            return
        }
        
        transitionContext.completeTransition(false)
    }
    
    private func presentOrDismissView(using transitionContext: UIViewControllerContextTransitioning,
                                      imageViewController: ImageViewController,
                                      detailViewController: UIViewController,
                                      imageViewSnapshot: UIView,
                                      window: UIWindow) {
        // Check boolean telling whether we are presenting or dismissing
        if type.isPresenting {
            presentImageView(using: transitionContext, imageViewController: imageViewController,
                             detailViewController: detailViewController,
                             imageViewSnapshot: imageViewSnapshot,
                             window: window)
        } else {
            dismissImageView(using: transitionContext, imageViewController: imageViewController,
                             detailViewController: detailViewController,
                             imageViewSnapshot: imageViewSnapshot,
                             window: window)
        }
    }
    
    private func presentImageView(using transitionContext: UIViewControllerContextTransitioning,
                                  imageViewController: ImageViewController,
                                  detailViewController: UIViewController,
                                  imageViewSnapshot: UIView,
                                  window: UIWindow) {
        // Retrieve the animated view supplied by iOS
        // and placed in between the album and image views
        let containerView = transitionContext.containerView
        
        // Add image subview to display it in the container
        guard let toView = imageNavViewController.view else {
            transitionContext.completeTransition(false)
            return
        }
        containerView.addSubview(toView)
        
        // Transparent so that it does not hide the transition view
        toView.alpha = 0

        // Set frame of images for starting the animation
        cellImageViewSnapshot.frame = cellImageViewRect
        imageViewSnapshot.frame = cellImageViewRect

        // Set opacity of images for starting the animation
        cellImageViewSnapshot.alpha = 1
        imageViewSnapshot.alpha = 0

        // Fade out album view content
        let fadeView = UIView(frame: containerView.bounds)
        fadeView.backgroundColor = .piwigoColorBackground()
        fadeView.alpha = 0

        // Fade in image preview navigation bar
        var navBarFadeView: UIView?
        if let navBar = imageViewController.navigationController?.navigationBar {
            navBarFadeView = navBar.snapshotView(afterScreenUpdates: true)
            navBarFadeView?.frame = self.navBarRect
            navBarFadeView?.alpha = 0
        }

        // Fade in image preview toolbar
        var toolbarFadeView: UIView?
        if imageViewController.isToolbarRequired,
           let toolbar = imageViewController.navigationController?.toolbar {
            toolbarFadeView = toolbar.snapshotView(afterScreenUpdates: true)
            toolbarFadeView?.frame = toolbar.convert(toolbar.bounds, to: window)
            toolbarFadeView?.alpha = 0
        }

        // Add transition views to container
        // Superpose fade in/out, cell and image views with backg above the others
        [fadeView, cellImageViewSnapshot, imageViewSnapshot, navBarFadeView, toolbarFadeView]
            .compactMap({$0}).forEach { containerView.addSubview($0) }

        // Calc frame of images at the end of the animation
        var imageViewRect = CGRect.zero
        if let imageDVC = detailViewController as? ImageDetailViewController {
            imageViewRect = imageDVC.imageView.convert(imageDVC.imageView.bounds, to: window)
        } else if let videoDVC = detailViewController as? VideoDetailViewController {
            imageViewRect = videoDVC.placeHolderView.convert(videoDVC.placeHolderView.bounds, to: window)
        }

        // Perform the animation
        UIView.animateKeyframes(withDuration: Self.duration, delay: 0, options: .calculationModeCubic, animations: {
            // Change frames and opacities
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                // Set frame of images at the end the animation
                self.cellImageViewSnapshot.frame = imageViewRect
                imageViewSnapshot.frame = imageViewRect

                // Set opacity used to end the animation
                self.cellImageViewSnapshot.alpha = 0
                imageViewSnapshot.alpha = 1
                fadeView.alpha = 1
                navBarFadeView?.alpha = 1
                toolbarFadeView?.alpha = 1
            }
        }, completion: { _ in
            // Remove views which performed the transition
            self.cellImageViewSnapshot.removeFromSuperview()
            imageViewSnapshot.removeFromSuperview()
            fadeView.removeFromSuperview()
            navBarFadeView?.removeFromSuperview()
            toolbarFadeView?.removeFromSuperview()

            // Final view was transparent during the transition
            toView.alpha = 1
            
            // Tell transitionContext that transition finished
            transitionContext.completeTransition(true)
        })
    }

    private func dismissImageView(using transitionContext: UIViewControllerContextTransitioning,
                                  imageViewController: ImageViewController,
                                  detailViewController: UIViewController,
                                  imageViewSnapshot: UIView,
                                  window: UIWindow) {
        // Retrieve the animated view supplied by iOS
        // and placed in between the album and image views
        let containerView = transitionContext.containerView
        
        // Add blank subview to display it in the container
        let toView = UIView(frame: containerView.bounds)
        toView.backgroundColor = .piwigoColorBackground()
        containerView.addSubview(toView)

        // Calc frame of images at the start of the animation
        var imageViewRect = CGRect.zero
        if let imageDVC = detailViewController as? ImageDetailViewController {
            imageViewRect = imageDVC.imageView.convert(imageDVC.imageView.bounds, to: window)
        } else if let videoDVC = detailViewController as? VideoDetailViewController {
            imageViewRect = videoDVC.placeHolderView.convert(videoDVC.placeHolderView.bounds, to: window)
        }

        // Set frame of images for starting the animation
        cellImageViewSnapshot.frame = imageViewRect
        imageViewSnapshot.frame = imageViewRect

        // Set opacity of images for starting the animation
        cellImageViewSnapshot.alpha = 0
        imageViewSnapshot.alpha = 1

        // Fade in album view content
        let fadeView = albumViewSnapshot
        fadeView.alpha = 0

        // Fade out image preview navigation bar
        let navBarFadeView = navBarSnapshot
        navBarFadeView.frame = navBarRect
        navBarFadeView.alpha = 0

        // Fade out image preview navigation bar
        var imgNavBarFadeView: UIView?
        if let navBar = imageViewController.navigationController?.navigationBar {
            imgNavBarFadeView = navBar.snapshotView(afterScreenUpdates: false)
            imgNavBarFadeView?.frame = navBar.convert(navBar.bounds, to: window)
            imgNavBarFadeView?.alpha = 1
        }

        // Fade out image preview toolbar
        var toolbarFadeView: UIView?
        if imageViewController.isToolbarRequired,
           let toolbar = imageViewController.navigationController?.toolbar {
            toolbarFadeView = toolbar.snapshotView(afterScreenUpdates: false)
            toolbarFadeView?.frame = toolbar.convert(toolbar.bounds, to: window)
            toolbarFadeView?.alpha = 1
        }

        // Add transition views to container
        // Superpose fade in/out, cell and image views with backg above the others
        [fadeView, cellImageViewSnapshot, imageViewSnapshot, navBarFadeView, imgNavBarFadeView, toolbarFadeView]
            .compactMap({$0}).forEach { containerView.addSubview($0) }

        // Perform the animation
        UIView.animateKeyframes(withDuration: Self.duration, delay: 0, options: .calculationModeCubic, animations: {
            // Change frames and opacities
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                // Set frame of images at the end the animation
                self.cellImageViewSnapshot.frame = self.cellImageViewRect
                imageViewSnapshot.frame = self.cellImageViewRect

                // Set opacity used to end the animation
                self.cellImageViewSnapshot.alpha = 1
                fadeView.alpha = 1
                navBarFadeView.alpha = 1
                imageViewSnapshot.alpha = 0
                imgNavBarFadeView?.alpha = 0
                toolbarFadeView?.alpha = 0
            }
        }, completion: { _ in
            // Remove views which performed the transition
            self.cellImageViewSnapshot.removeFromSuperview()
            fadeView.removeFromSuperview()
            navBarFadeView.removeFromSuperview()
            imageViewSnapshot.removeFromSuperview()
            imgNavBarFadeView?.removeFromSuperview()
            toolbarFadeView?.removeFromSuperview()
            
            // Tell transitionContext that transition finished
            transitionContext.completeTransition(true)
        })
    }
}
