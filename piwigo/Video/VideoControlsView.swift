//
//  VideoControlsView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 04/09/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import PwgUIKit

protocol VideoControlsDelegate: NSObjectProtocol {
    func didChangeTime(value: Double)
    func didTapPlayPause()
    func didTapMuteUnmute()
}

final class VideoControlsView: UIVisualEffectView {
    
    weak var videoControlsDelegate: (any VideoControlsDelegate)?
    
    /// Both buttons are ExpandedTouchButton in the XIB, for a large enough touch area.
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var muteButton: UIButton!
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
    
    /// True while the user drags the thumb of the time slider. The player reports its
    /// current time every 0.1 s, which would otherwise move the thumb back under the
    /// finger — and make the last seek target the position playback had reached.
    private var isUserSeeking = false
    
    @MainActor
    private func configView() {
        let view = viewFromNibForClass()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(view)
    }
    
    // Loads XIB file into a view and returns this view
    @MainActor
    private func viewFromNibForClass() -> UIView {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: String(describing: type(of: self)), bundle: bundle)
        let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
        return view
    }
    
    @MainActor
    func applyColorPalette() {
        playPauseButton.tintColor = PwgColor.tintColor
        muteButton.tintColor = PwgColor.tintColor
        timeSlider.thumbTintColor = PwgColor.thumb
        timeSlider.maximumTrackTintColor = PwgColor.thumb
        playPauseButton.tintColor = PwgColor.tintColor
        playPauseButton.tintColor = PwgColor.tintColor
    }
    
    @MainActor
    func config(currentTime: TimeInterval, duration: TimeInterval) {
        // Update video object
        videoDuration = duration
        
        // Set slider value
        setCurrentTime(currentTime)
        
        // The mute option is remembered across videos, whereas the play/pause state is
        // pushed by the .pwgVideoPlaybackStatus notification which follows this call.
        setMuted(VideoVars.shared.isMuted)
        
        // Hide loading indicator, show buttons and time slider
        loadingIndicator.isHidden = true
        playPauseButton.isHidden = false
        muteButton.isHidden = false
        timeSlider.isHidden = false
        
        // Show/hide slider and labels
        if let rootVC = window?.topMostViewController() as? ImageViewController {
            isHidden = rootVC.navigationController?.isNavigationBarHidden ?? false
        }
    }
    
    @MainActor
    func setCurrentTime(_ value: Double) {
        // The user is dragging the thumb: leave it where the finger is
        guard isUserSeeking == false else { return }
        
        autoreleasepool {
            // Set slider value
            if let duration = videoDuration, duration != 0 {
                // Set slider value
                timeSlider.value = Float(value / duration)
            } else {
                timeSlider.value = 0.5
            }
        }
    }
    
    @IBAction func didBeginSeeking(_ sender: Any) {
        isUserSeeking = true
    }
    
    @IBAction func didChangeTime(_ sender: Any) {
        if let slider = sender as? UISlider {
            videoControlsDelegate?.didChangeTime(value: Double(slider.value))
        }
    }
    
    @IBAction func didEndSeeking(_ sender: Any) {
        isUserSeeking = false
        
        // Seek a last time, to the position where the thumb was released
        if let slider = sender as? UISlider {
            videoControlsDelegate?.didChangeTime(value: Double(slider.value))
        }
    }

    @MainActor
    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            playPauseButton.accessibilityLabel = String(localized: "pauseVideo_title", comment: "Pause")
        } else {
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            playPauseButton.accessibilityLabel = String(localized: "playVideo_title", comment: "Play")
        }
    }
    
    /// Shows the loading indicator while the player buffers, so that a pause button which
    /// is not playing anything yet does not look stuck.
    @MainActor
    func setBuffering(_ isBuffering: Bool) {
        loadingIndicator.isHidden = !isBuffering
    }
    
    @MainActor
    func setMuted(_ isMuted: Bool) {
        if isMuted {
            muteButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
            muteButton.accessibilityLabel = String(localized: "unmuteAudio_title", comment: "Unmute")
        } else {
            muteButton.setImage(UIImage(systemName: "speaker.fill"), for: .normal)
            muteButton.accessibilityLabel = String(localized: "muteAudio_title", comment: "Mute")
        }
    }
    
    @IBAction func didTapPlayPause(_ sender: Any) {
        videoControlsDelegate?.didTapPlayPause()
    }
    
    @IBAction func didTapMuteUnmute(_ sender: Any) {
        videoControlsDelegate?.didTapMuteUnmute()
    }
    
    deinit {
        #if DEBUG
        debugPrint("••> VideoControlsView released memory")
        #endif
    }
}


// MARK: - Expanded Touch Area
/**
 A button whose touch area is expanded to the 44 points recommended by the Human
 Interface Guidelines, without changing the size of the button itself.

 The video controls bar is 40 points high, is drawn as a pill (its corner radius is half
 of that) and clips its subviews, so the icons of the play/pause and mute buttons cannot
 simply be enlarged: their intrinsic size is that of their SF Symbol, around 22 points.

 Only the width is expanded in practice. Hit testing does not reach a subview beyond the
 bounds of its superview, so the height of the touch area remains that of the bar. The
 expansion stays smaller than the 16 point gap which separates each button from the time
 slider, so the slider keeps receiving its own touches.
 */
final class ExpandedTouchButton: UIButton {

    private let minimumTouchSide = CGFloat(44)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // A negative inset expands the rectangle; a button already large enough is left as is.
        let dx = min(0, bounds.width - minimumTouchSide) / 2
        let dy = min(0, bounds.height - minimumTouchSide) / 2
        return bounds.insetBy(dx: dx, dy: dy).contains(point)
    }
}
