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
