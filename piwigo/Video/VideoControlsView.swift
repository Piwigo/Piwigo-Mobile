//
//  VideoControlsView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/09/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

protocol VideoControlsDelegate: NSObjectProtocol {
    func didChangeTime(value: Double)
}

class VideoControlsView: UIVisualEffectView {
    
    weak var videoControlsDelegate: VideoControlsDelegate?
    
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var endLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configView()
    }
    
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        configView()
    }
    
    // Initialisation
    private var videoDuration: Double?
    private func configView() {
        let view = viewFromNibForClass()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(view)
    }
    
    // Loads XIB file into a view and returns this view
    private func viewFromNibForClass() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        return view
    }
    
    func applyColorPalette() {
        if #available(iOS 13.0, *) {
            startLabel.textColor = .piwigoColorText()
            endLabel.textColor = .piwigoColorText()
            timeSlider.thumbTintColor = .piwigoColorThumb()
            timeSlider.maximumTrackTintColor = .piwigoColorThumb()
        } else {
            backgroundColor = .piwigoColorBackground()
            startLabel.textColor = .piwigoColorText()
            endLabel.textColor = .piwigoColorText()
            timeSlider.thumbTintColor = .piwigoColorThumb()
            timeSlider.maximumTrackTintColor = .piwigoColorThumb()
        }
    }
    
    func config(currentTime: TimeInterval, duration: TimeInterval) {
        // Update video object
        videoDuration = duration
        
        // Set starting and ending times
        startLabel.text = getTimeLabel(currentTime, forDuration: duration)
        endLabel.text = getTimeLabel(duration, forDuration: duration)
        
        // Set slider value
        setCurrentTime(currentTime)
        
        // Hide loading indicator, show labels and time slider
        loadingIndicator.isHidden = true
        startLabel.isHidden = false
        endLabel.isHidden = false
        timeSlider.isHidden = false
        
        // Show/hide slider and labels
        if let rootVC = window?.topMostViewController() as? ImageViewController {
            isHidden = rootVC.navigationController?.isNavigationBarHidden ?? false
        }
    }
    
    func setCurrentTime(_ value: Double) {
        autoreleasepool {
            // Set slider value
            if let duration = videoDuration, duration != 0 {
                // Start label shows current time
                startLabel.text = getTimeLabel(value, forDuration: duration)
                // Set slider value
                timeSlider.value = Float(value / duration)
            } else {
                timeSlider.value = 0.5
            }
        }
    }
    
    @IBAction func didChangeTime(_ sender: Any) {
        if let slider = sender as? UISlider {
            videoControlsDelegate?.didChangeTime(value: Double(slider.value))
        }
    }

    private func getTimeLabel(_ value: TimeInterval, forDuration duration: TimeInterval) -> String {
        // Format depends on video duration
        if duration < 60 {          // i.e. one minute
            return String(format: "0:%02.0f", value.rounded(.toNearestOrEven))
        }
        
        if duration < 3_600 {       // i.e. one hour
            var timeLeft = value
            let minutes = (timeLeft / 60).rounded(.towardZero)
            timeLeft -= minutes * 60
            let seconds = timeLeft.rounded(.toNearestOrEven)
            return String(format: "%02.0f:%02.0f", minutes, seconds)
        }
        
        var timeLeft = value
        let hours = (timeLeft / 3_600).rounded(.towardZero)
        timeLeft -= hours * 3_600
        let minutes = (timeLeft / 60).rounded(.towardZero)
        timeLeft -= minutes * 60
        let seconds = timeLeft.rounded(.toNearestOrEven)
        return String(format: "%02.0f:%02.0f:%02.0f", hours, minutes, seconds)
    }
    
//    deinit {
//        debugPrint("••> VideoControlsView deinit")
//    }
}
