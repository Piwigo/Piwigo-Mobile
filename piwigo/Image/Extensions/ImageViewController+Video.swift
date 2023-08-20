//
//  ImageViewController+Video.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Video Buttons
extension ImageViewController
{
    // MARK: - Play/pause video
    @objc func didChangePlaybackStatus(_ notification: Notification) {
        // NOP if pwgID or player status unknown
        guard let pwgID = notification.userInfo?["pwgID"] as? Int64,
              let videoPVC = pageViewController?.viewControllers?.first as? VideoDetailViewController,
              videoPVC.imageData.pwgID == pwgID
        else {
            return
        }

        // Set button according to status if needed
        var didChangeButton = false
        if let isReady = notification.userInfo?["ready"] as? Bool, isReady {
            // Hide image and show play/pause button
            videoPVC.placeHolderView.isHidden = true
        }
        if let isPlaying = notification.userInfo?["playing"] as? Bool {
            // Set play/pause button according to player status
            if isPlaying, playBarButton?.accessibilityIdentifier ?? "" != "pause" {
                playBarButton = UIBarButtonItem.pauseImageButton(self, action: #selector(pauseVideo))
                didChangeButton = true
            } else if !isPlaying, playBarButton?.accessibilityIdentifier ?? "" != "play" {
                playBarButton = UIBarButtonItem.playImageButton(self, action: #selector(playVideo))
                didChangeButton = true
            }
        }
        if let isMuted = notification.userInfo?["muted"] as? Bool {
            // Set mute/unmute button according to player status
            if setMuteButtonItem(isMuted) { didChangeButton = true }
        }
        if didChangeButton {
            updateNavBar()
        }
    }
    
    @objc func playVideo() {
        guard let videoPVC = pageViewController?.viewControllers?.first as? VideoDetailViewController,
              let video = videoPVC.video
        else {
            return
        }
        playbackController.play(contentOfVideo: video)
    }
    
    @objc func pauseVideo() {
        guard let videoPVC = pageViewController?.viewControllers?.first as? VideoDetailViewController,
              let video = videoPVC.video else {
            return
        }
        playbackController.pause(contentOfVideo: video)
    }


    // MARK: - Mute/unmute video
    @objc func didChangeMuteOption(_ notification: Notification) {
        // NOP if pwgID or player status unknown
        guard let pwgID = notification.userInfo?["pwgID"] as? Int64,
              let videoDVC = pageViewController?.viewControllers?.first as? VideoDetailViewController,
              videoDVC.imageData.pwgID == pwgID,
              let isMuted = notification.userInfo?["muted"] as? Bool
        else {
            return
        }

        // Set mute/unmute button according to player observer if needed
        if setMuteButtonItem(isMuted) {
            updateNavBar()
        }
    }
    
    private func setMuteButtonItem(_ isMuted: Bool) -> Bool {
        let wantedTag = isMuted ? UIBarButtonItem.pwgMuted : UIBarButtonItem.pwgNotMuted
        if wantedTag == muteBarButton?.tag ?? 0 { return false }
        muteBarButton = UIBarButtonItem.muteAudioButton(isMuted, target: self, action: #selector(muteUnmuteAudio))
        return true
    }
    
    @objc func muteUnmuteAudio() {
        guard let videoPVC = pageViewController?.viewControllers?.first as? VideoDetailViewController,
              let video = videoPVC.video else {
            return
        }
        playbackController.muteUnmute(contentOfVideo: video)
    }
}


// MARK: - Player and PlayerViewControllerCoordinator Delegates
extension ImageViewController: PlayerViewControllerCoordinatorDelegate
{
    func playerViewControllerCoordinator(_ coordinator: PlayerViewControllerCoordinator,
                                         restoreUIForPIPStop completion: @escaping (Bool) -> Void) {
        if coordinator.playerViewControllerIfLoaded?.parent == nil {
            playbackController.dismissActivePlayerViewController(animated: false) {
                if let navigationController = self.navigationController {
                    coordinator.restoreFullScreen(from: navigationController) {
                        completion(true)
                    }
                } else {
                    completion(false)
                }
            }
        } else {
            completion(true)
        }
    }
}
