//
//  PlaybackController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import AVKit
import piwigoKit

// See WWDC 2019 session 503: Delivering Intuitive Media Playback with AVKit
class PlaybackController {
    
    // Singleton
    static let shared = PlaybackController()
    
    weak var videoItemDelegate: PlayerViewControllerCoordinatorDelegate?
    
    private var playbackItems = [Video: PlayerViewControllerCoordinator]()
    
    init() {
        // Piwigo will play audio even if the Silent switch set to silent or when the screen locks.
        // Furthermore, it will interrupt any other current audio sessions (no mixing)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            print(error)
        }
    }
    
    func coordinator(for video: Video) -> PlayerViewControllerCoordinator {
        if let playbackItem = playbackItems[video] {
            return playbackItem
        } else {
            let playbackItem = PlayerViewControllerCoordinator(video: video)
            playbackItem.delegate = videoItemDelegate
            playbackItems[video] = playbackItem
            return playbackItem
        }
    }
    
    func embed(contentOfVideo video: Video, in parentViewController: UIViewController, containerView: UIView) {
        if parentViewController is ImagePreviewViewController {
            coordinator(for: video).embedInline(in: parentViewController, container: containerView)
        } else if parentViewController is ExternalDisplayViewController {
            coordinator(for: video).embedExternalDisplay(in: parentViewController, container: containerView)
        }
    }

    func remove(contentOfVideo video: Video) {
        playbackItems[video]?.removeFromParentIfNeeded()
    }
    
    func present(contentOfVideo video: Video, from presentingViewController: UIViewController) {
        coordinator(for: video).presentFullScreen(from: presentingViewController)
    }
    
    func play(contentOfVideo video: Video, usingMuteOption: Bool = false) {
        coordinator(for: video).playerViewControllerIfLoaded?.player?.isMuted = VideoVars.shared.isPlayerMuted
        coordinator(for: video).playerViewControllerIfLoaded?.player?.play()
    }

    func pause(contentOfVideo video: Video, savingMuteOption: Bool = false) {
        coordinator(for: video).playerViewControllerIfLoaded?.player?.pause()
        if savingMuteOption {
            VideoVars.shared.isPlayerMuted = coordinator(for: video).playerViewControllerIfLoaded?.player?.isMuted ?? false
        }
    }

    func removeAllEmbeddedViewControllers() {
        playbackItems.forEach {
            $0.value.removeFromParentIfNeeded()
        }
    }
    
    func dismissActivePlayerViewController(animated: Bool, completion: @escaping () -> Void) {
        let fullScreenItems = playbackItems.filter({ $0.value.status.contains(.fullScreenActive) }).map({ $0.value })
        assert(fullScreenItems.count <= 1, "Never should be more than one thing full screen!")
        if let fullScreenItem = fullScreenItems.first {
            fullScreenItem.dismiss(completion: completion)
        } else {
            completion()
        }
    }
}
