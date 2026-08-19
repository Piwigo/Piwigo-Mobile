//
//  ImageViewController+Video.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Video
extension ImageViewController
{
    // MARK: - Video Duration
    /// The duration of a video is not stored in cache and is often known only after the
    /// video is presented, so the subtitle of the title view is refreshed on arrival.
    @objc func didKnowVideoDuration(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // NOP unless the duration is the one of the presented video
            guard let pwgID = notification.userInfo?["pwgID"] as? Int64,
                  imageData?.pwgID == pwgID
            else { return }

            // The title view reads the duration from the playback controller
            setTitleViewFromImageData()
        }
    }
}


// MARK: - Player and PlayerViewControllerCoordinator Delegates
extension ImageViewController: PlayerViewControllerCoordinatorDelegate
{
    func playerViewControllerCoordinator(_ coordinator: PlayerViewControllerCoordinator,
                                         restoreUIForPIPStop completion: @escaping (Bool) -> Void) {
        if coordinator.playerViewControllerIfLoaded?.parent == nil {
            playbackController.dismissActivePlayerViewController(animated: false) { [self] in
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
