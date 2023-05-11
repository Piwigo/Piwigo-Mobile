//
//  PieProgressView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/04/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class PieProgressView: UIView {

    fileprivate var progressLayer = CAShapeLayer()
    fileprivate var trackLayer = CAShapeLayer()

    private var timeToFill = 3.43
    var progress: Float = 0.0 {
        didSet {
            let pathMoved = max(0, progress - oldValue)
            setProgress(duration: timeToFill * Double(pathMoved), to: progress)
        }
    }

    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
        
        // Initialisation
        let radius = frame.size.width / 2
        self.backgroundColor = UIColor.piwigoColorWhiteCream().withAlphaComponent(0.3)
        self.layer.cornerRadius = radius

        // Progress layer
        let progressPath = UIBezierPath(arcCenter: CGPoint(x: radius, y: radius), radius: (radius - 2) / 2,
                                        startAngle: CGFloat(-0.5 * .pi), endAngle: CGFloat(1.5 * .pi),
                                        clockwise: true)
        progressLayer.frame = CGRect(x: 0, y: 0, width: 2 * radius, height: 2 * radius)
        progressLayer.path = progressPath.cgPath
        progressLayer.fillColor = .none
        progressLayer.strokeColor = UIColor.white.cgColor
        progressLayer.lineCap = .butt
        progressLayer.lineWidth = radius - 1
        progressLayer.strokeEnd = 0.34
        layer.addSublayer(progressLayer)
    }

    func setProgress(duration: TimeInterval = 3, to newProgress: Float) -> Void{
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = newProgress
        progressLayer.strokeEnd = CGFloat(newProgress)
        progressLayer.add(animation, forKey: "animationProgress")
    }
}
