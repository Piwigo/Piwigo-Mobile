//
//  RingProgressView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

class RingProgressView: UIView {

    fileprivate var progressLayer = CAShapeLayer()
    fileprivate var backgroundLayer = CAShapeLayer()

    private var timeToFill = 0.1
    var progress: Float = 0.0 {
        didSet {
            let pathMoved = max(0, progress - oldValue)
            if self.isHidden { self.isHidden = false }
            setProgress(duration: timeToFill * Double(pathMoved), to: progress)
        }
    }

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Initialisation
        let radius = frame.size.width / 2
        let rect = CGRect(x: 0, y: 0, width: 2 * radius, height: 2 * radius)
        let progressPath = UIBezierPath(arcCenter: CGPoint(x: radius, y: radius), radius: radius - 2,
                                        startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(1.5 * .pi),
                                        clockwise: true)
        self.backgroundColor = .clear
        self.layer.cornerRadius = radius

        // Layers
        backgroundLayer.frame = rect
        backgroundLayer.path = progressPath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.piwigoColorCellBackground().cgColor
        backgroundLayer.lineCap = .round
        backgroundLayer.lineWidth = 2
        backgroundLayer.strokeEnd = 1
        layer.addSublayer(backgroundLayer)

        progressLayer.frame = rect
        progressLayer.path = progressPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.piwigoColorRightLabel().cgColor
        progressLayer.lineCap = .round
        progressLayer.lineWidth = 2
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }

    private func setProgress(duration: TimeInterval = 3, to newProgress: Float) -> Void{
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = newProgress
        progressLayer.strokeEnd = CGFloat(newProgress)
        progressLayer.add(animation, forKey: "animationProgress")
    }
}
