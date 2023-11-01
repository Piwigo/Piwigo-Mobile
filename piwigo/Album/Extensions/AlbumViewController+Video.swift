//
//  AlbumViewController+Video.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/11/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - AlbumVideoControlsDelegate Methods
extension AlbumViewController: AlbumVideoControlsDelegate
{
    func config(currentTime: TimeInterval, duration: TimeInterval, delegate: VideoControlsDelegate) {
        if videoControlsView == nil {
            // Create video playback controls
            let blurEffect = UIBlurEffect(style: .regular)
            videoControlsView = VideoControlsView(effect: blurEffect)
            videoControlsView.videoControlsDelegate = delegate
            videoControlsView.layer.cornerRadius = 20
            videoControlsView.layer.masksToBounds = true
            videoControlsView.applyColorPalette()
            videoControlsView.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(videoControlsView, aboveSubview: imagesCollection!)

            var constraints = [NSLayoutConstraint]()
            constraints.append(NSLayoutConstraint.constraintCenterVerticalView(videoControlsView)!)
            constraints.append(NSLayoutConstraint.constraintView(videoControlsView, toHeight: 40)!)
            constraints.append(NSLayoutConstraint.constraintView(fromBottom: videoControlsView, amount: 40)!)
            
            let isCompactRegular = view.traitCollection.horizontalSizeClass == .compact &&
                                    view.traitCollection.verticalSizeClass == .regular
            if isCompactRegular {
                constraints.append(contentsOf: constraintsForCompactRegular())
            } else {
                constraints.append(contentsOf: constraintsForNonCompactRegular())
            }
            view.addConstraints(constraints)
        }

        // Configure controls
        videoControlsView?.config(currentTime: currentTime, duration: duration)
    }
    
    func configVideoControlsConstraints() {
        // Get current interface size class
        let isCompactRegular = view.traitCollection.horizontalSizeClass == .compact &&
                                view.traitCollection.verticalSizeClass == .regular
        if isCompactRegular {
            // Deactivate non-wanted constraints
            NSLayoutConstraint.deactivate(view.constraints.filter({$0.identifier == "nonForCompactRugular"}))
            // Do we have constraints for wC,hR ?
            if view.constraints.contains(where: {$0.identifier == "forCompactRegular"}) {
                NSLayoutConstraint.activate(view.constraints.filter({$0.identifier == "forCompactRegular"}))
            } else {
                view.addConstraints(constraintsForCompactRegular())
            }
        } else {
            // Deactivate non-wanted constraints
            NSLayoutConstraint.deactivate(view.constraints.filter({$0.identifier == "forCompactRegular"}))
            if view.constraints.contains(where: {$0.identifier == "nonForCompactRugular"}) {
                NSLayoutConstraint.activate(view.constraints.filter({$0.identifier == "nonForCompactRugular"}))
            } else {
                view.addConstraints(constraintsForNonCompactRegular())
            }
        }
    }
    
    private func constraintsForCompactRegular() -> [NSLayoutConstraint] {
        var constraints = [NSLayoutConstraint]()
        constraints.append(NSLayoutConstraint.constraintView(fromLeft: videoControlsView, amount: 20)!)
        constraints.append(NSLayoutConstraint.constraintView(fromRight: videoControlsView, amount: 20)!)
        constraints.forEach({ $0.identifier = "forCompactRegular" })
        return constraints
    }
    
    private func constraintsForNonCompactRegular() -> [NSLayoutConstraint] {
        var constraints = [NSLayoutConstraint]()
        constraints.append(NSLayoutConstraint.constraintView(videoControlsView, toWidth: 420)!)
        constraints.forEach({ $0.identifier = "nonForCompactRugular" })
        return constraints
    }
    
    func setCurrentTime(_ value: Double) {
        videoControlsView?.setCurrentTime(value)
    }

    func hideVideoControls() {
        videoControlsView?.removeFromSuperview()
        videoControlsView = nil
    }
}
