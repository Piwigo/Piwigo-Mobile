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
        
        // Set the icons at once, so that they do not change size when the player reports
        // its first status: the XIB carries them at their default size.
        setPlaying(false)
        setMuted(VideoVars.shared.isMuted)
        
        // Adopt Liquid Glass, replacing the blur effect set in the storyboard.
        /// The bar is drawn as a pill: its shape is handed to the glass instead of being
        /// imposed by a corner radius, so that it follows the height of the bar and the
        /// glass is rendered with the right silhouette.
        if #available(iOS 26.0, *) {
            effect = UIGlassEffect(style: .regular)
            cornerConfiguration = .capsule()
            layer.cornerRadius = 0
            view.layer.cornerRadius = 0
        }
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
        if #available(iOS 26.0, *) {
            // Leave the thumb and the remaining track to the system, whose translucent
            // track is made to sit on glass.
            timeSlider.thumbTintColor = nil
            timeSlider.maximumTrackTintColor = nil
        } else {
            timeSlider.thumbTintColor = PwgColor.thumb
            timeSlider.maximumTrackTintColor = PwgColor.thumb
        }
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

    /// Icons are given the configuration used by the bar buttons of the app, so that the
    /// controls of the video match them in size and weight. See UIBarButtonItem.setBackImage().
    private static let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium,
                                                                        scale: .medium)
    
    @MainActor
    func setPlaying(_ isPlaying: Bool) {
        let configuration = VideoControlsView.symbolConfiguration
        if isPlaying {
            playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: configuration), for: .normal)
            playPauseButton.accessibilityLabel = String(localized: "pauseVideo_title", comment: "Pause")
        } else {
            playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: configuration), for: .normal)
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
        let configuration = VideoControlsView.symbolConfiguration
        if isMuted {
            muteButton.setImage(UIImage(systemName: "speaker.slash.fill", withConfiguration: configuration), for: .normal)
            muteButton.accessibilityLabel = String(localized: "unmuteAudio_title", comment: "Unmute")
        } else {
            muteButton.setImage(UIImage(systemName: "speaker.fill", withConfiguration: configuration), for: .normal)
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
