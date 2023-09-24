//
//  VideoControlsView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/09/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit

class VideoControlsView : UIVisualEffectView {
    
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var endLabel: UILabel!
    
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
    
    override func awakeFromNib() {
        // Initialization code
        super.awakeFromNib()
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
