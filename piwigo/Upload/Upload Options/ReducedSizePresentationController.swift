//
//  ReducedSizePresentationController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation

class ReducedSizePresentationController : UIPresentationController {

    var dimmingView = UIView()

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        
        // Create the dimming view and set its initial appearance.
        dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        dimmingView.alpha = 0.0
    }

    override func presentationTransitionWillBegin() {
        // Get critical information about the presentation.
        guard let containerView = self.containerView else { return }
        let presentedViewController = self.presentedViewController

        // Set the dimming view to the size of the container's
        // bounds, and make it transparent initially.
        dimmingView.frame = containerView.bounds
        dimmingView.alpha = 0.0

        // Insert the dimming view below everything else.
        containerView.insertSubview(dimmingView, at: 0)

        // Set up the animations for fading in the dimming view.
        if presentedViewController.transitionCoordinator != nil {
            presentedViewController.transitionCoordinator?.animate(alongsideTransition: { context in
                // Fade in the dimming view.
                self.dimmingView.alpha = 1.0
            })
        } else {
            dimmingView.alpha = 1.0
        }
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        // If the presentation was canceled, remove the dimming view.
        if !completed {
            dimmingView.removeFromSuperview()
        }
    }

    override func dismissalTransitionWillBegin() {
        // Fade the dimming view back out.
        if presentedViewController.transitionCoordinator != nil {
            presentedViewController.transitionCoordinator?.animate(alongsideTransition: { context in
                self.dimmingView.alpha = 0.0
            })
        } else {
            dimmingView.alpha = 0.0
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        // If the dismissal was successful, remove the dimming view.
        if completed {
            dimmingView.removeFromSuperview()
        }
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        get {
            guard let theView = containerView else {
                return CGRect.zero
            }

            var frame: CGRect = .zero
            frame.size = size(forChildContentContainer: presentedViewController,
                              withParentContainerSize: containerView!.bounds.size)
            frame.size = size(forChildContentContainer: presentingViewController,
                              withParentContainerSize: containerView!.bounds.size)

            return CGRect(x: 0, y: theView.bounds.height*1/2,
                          width: theView.bounds.width, height: theView.bounds.height*1/2)
        }

//        var frame: CGRect = .zero
//        frame.size = size(forChildContentContainer: presentedViewController,
//                          withParentContainerSize: containerView!.bounds.size)
//
//        switch direction {
//        case .right:
//          frame.origin.x = containerView!.frame.width*(1.0/3.0)
//        case .bottom:
//          frame.origin.y = containerView!.frame.height*(1.0/3.0)
//        default:
//          frame.origin = .zero
//        }
//        return frame
    }
}
