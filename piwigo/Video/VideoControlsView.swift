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
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configView()
    }
    
    override init(effect: UIVisualEffect?) {
        super.init(effect: effect)
        configView()
    }
    
    // Initialisation
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

    private var videoDuration: Double?
    private lazy var hoursFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    private lazy var minsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "mm:ss"
        return formatter
    }()
    private lazy var minFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "m:ss"
        return formatter
    }()
    
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
        
        // Show/hide slider and labels
        if let rootVC = window?.topMostViewController() as? ImageViewController {
            isHidden = rootVC.navigationController?.isNavigationBarHidden ?? false
        }
    }
    
    func setCurrentTime(_ value: Double) {
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
    
    @IBAction func didChangeTime(_ sender: Any) {
        if let slider = sender as? UISlider {
            videoControlsDelegate?.didChangeTime(value: Double(slider.value))
        }
    }

    private func getTimeLabel(_ value: TimeInterval, forDuration duration: TimeInterval) -> String {
        // Format depends on video duration
        if duration < 600 {           // i.e. one minute
            return minFormatter.string(from: Date(timeIntervalSince1970: value))
        } else if duration < 3600 {   // i.e. one hour
            return minsFormatter.string(from: Date(timeIntervalSince1970: value))
        } else {
            return hoursFormatter.string(from: Date(timeIntervalSince1970: value))
        }
    }
}
