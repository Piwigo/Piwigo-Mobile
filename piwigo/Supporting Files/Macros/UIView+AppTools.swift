//
//  UIView+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/03/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    
    // MARK: - Adaptive Layout
    /**
     Trait collection to base layout decisions on, instead of the device idiom or the
     interface orientation which do not describe the space available to the app
     (Split View, Stage Manager, iPhone Duo inner display, etc.).

     Not simply `traitCollection`: a view that has not entered the hierarchy yet — e.g. the view
     of a controller presented with a custom transition, only added to the container after
     `viewWillAppear` — reports unspecified size classes. Falls back to the scene the app is showing.

     The share extension cannot reach another scene, since `UIApplication.shared` —
     which `UIWindowScene.current` relies on — is unavailable there.
     */
    @MainActor
    var layoutTraitCollection: UITraitCollection {
        if traitCollection.horizontalSizeClass != .unspecified,
           traitCollection.verticalSizeClass != .unspecified {
            return traitCollection
        }
        if let sceneTraits = window?.windowScene?.traitCollection {
            return sceneTraits
        }
        #if EXTENSION
        return traitCollection
        #else
        return UIWindowScene.current?.traitCollection ?? traitCollection
        #endif
    }

    /// Bounds of the window presenting this view, or of the scene the app is showing
    /// when the view is not in the hierarchy yet — never the bounds of the screen.
    @MainActor
    var windowBounds: CGRect {
        if let window = window {
            return window.bounds
        }
        #if EXTENSION
        return bounds
        #else
        return UIWindowScene.current?.coordinateSpace.bounds ?? bounds
        #endif
    }
    
    
    // MARK: - Shake UIView
    func shakeHorizontally(completion: @escaping () -> Void) {
        // Move digits to the left and right several times
        UIView.animate(withDuration: 0.1, delay: 0, options:[.curveLinear], animations: {
            self.transform = CGAffineTransform(translationX: 50, y: 0)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                self.transform = CGAffineTransform(translationX: -50, y: 0)
            }, completion: { _ in
                UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                    self.transform = CGAffineTransform(translationX: 40, y: 0)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                        self.transform = CGAffineTransform(translationX: -40, y: 0)
                    }, completion: { _ in
                        UIView.animate(withDuration: 0.15, delay: 0, options:[.curveLinear], animations: {
                            self.transform = CGAffineTransform(translationX: 30, y: 0)
                        }, completion: { _ in
                            UIView.animate(withDuration: 0.1, delay: 0, options:[.curveEaseOut], animations: {
                                self.transform = CGAffineTransform(translationX: 0, y: 0)
                            }, completion: {_ in
                                completion()
                            })
                        })
                    })
                })
            })
        })
    }
    
    // Apply individual corner radius
    func roundCorners(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        let path = UIBezierPath()
        
        // Start at top-left, after the curve
        path.move(to: CGPoint(x: topLeft, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: bounds.width - topRight, y: 0))
        
        // Top-right corner
        path.addArc(withCenter: CGPoint(x: bounds.width - topRight, y: topRight),
                    radius: topRight,
                    startAngle: -.pi / 2,
                    endAngle: 0,
                    clockwise: true)
        
        // Right edge
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomRight))
        
        // Bottom-right corner
        path.addArc(withCenter: CGPoint(x: bounds.width - bottomRight, y: bounds.height - bottomRight),
                    radius: bottomRight,
                    startAngle: 0,
                    endAngle: .pi / 2,
                    clockwise: true)
        
        // Bottom edge
        path.addLine(to: CGPoint(x: bottomLeft, y: bounds.height))
        
        // Bottom-left corner
        path.addArc(withCenter: CGPoint(x: bottomLeft, y: bounds.height - bottomLeft),
                    radius: bottomLeft,
                    startAngle: .pi / 2,
                    endAngle: .pi,
                    clockwise: true)
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        
        // Top-left corner
        path.addArc(withCenter: CGPoint(x: topLeft, y: topLeft),
                    radius: topLeft,
                    startAngle: .pi,
                    endAngle: -.pi / 2,
                    clockwise: true)
        
        path.close()
        
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}


// MARK: - Size Classes
extension UITraitCollection {
    /// Regular width and regular height: iPad in full screen or in a large window,
    /// iPhone Duo inner display. Bar buttons are gathered in the navigation bar.
    var hasRegularWidthAndHeight: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    
    /// Compact width and regular height: iPhone in portrait, narrow iPad window,
    /// iPhone Duo outer display in portrait. Bar buttons are shared with the toolbar.
    var hasCompactWidthRegularHeight: Bool {
        return horizontalSizeClass == .compact && verticalSizeClass == .regular
    }
    
    /// Compact height: iPhone in landscape, iPhone Duo outer display in landscape.
    /// Vertical space is scarce: no subtitle, no status bar.
    var hasCompactHeight: Bool {
        return verticalSizeClass == .compact
    }
}
