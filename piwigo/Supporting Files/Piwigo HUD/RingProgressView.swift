//
//  RingProgressView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit

final class RingProgressView: UIView {

    fileprivate var progressLayer = CAShapeLayer()
    fileprivate var backgroundLayer = CAShapeLayer()

    fileprivate var lastUpdateTime: CFTimeInterval = 0
    fileprivate var lastProgress: Float = 0.0
    fileprivate let minDuration: TimeInterval = 0.05
    fileprivate let maxDuration: TimeInterval = 0.5

    var progress: Float = 0.0 {
        didSet {
            progress = min(1.0, max(0.0, progress))
            let pathMoved = max(0, progress - lastProgress)
            guard pathMoved > 0 else { return }
            
            let duration = adaptiveDuration()
            if self.isHidden { self.isHidden = false }
            setProgress(duration: duration, to: progress)
            
            lastProgress = progress
            lastUpdateTime = CACurrentMediaTime()
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
        backgroundLayer.strokeColor = PwgColor.cellBackground.cgColor
        backgroundLayer.lineCap = .round
        backgroundLayer.lineWidth = 2
        backgroundLayer.strokeEnd = 1
        layer.addSublayer(backgroundLayer)

        progressLayer.frame = rect
        progressLayer.path = progressPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = PwgColor.rightLabel.cgColor
        progressLayer.lineCap = .round
        progressLayer.lineWidth = 2
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }
    
    private func adaptiveDuration() -> TimeInterval {
        let now = CACurrentMediaTime()
        let interval = lastUpdateTime > 0 ? now - lastUpdateTime : maxDuration

        // Animate slightly faster than the update rate to stay ahead,
        // clamped to sane bounds to handle bursts or stalls
        let duration = interval * 0.9
        return min(maxDuration, max(minDuration, duration))
    }
    
    private func setProgress(duration: TimeInterval = 3, to newProgress: Float) -> Void{
        debugPrint("setProgress(duration: \(duration), from: \(progressLayer.strokeEnd), to: \(newProgress)")
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration

        // Read from the presentation layer to get the current visual position,
        // falling back to the model layer if no animation is running
        let fromValue = (progressLayer.presentation() ?? progressLayer).strokeEnd
        animation.fromValue = fromValue
        animation.toValue = newProgress
        
        // Update the model value immediately so the next call reads correctly
        progressLayer.strokeEnd = CGFloat(newProgress)

        // Prevent CABasicAnimation from snapping back to model value on completion
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        progressLayer.add(animation, forKey: "animationProgress")
    }
}
