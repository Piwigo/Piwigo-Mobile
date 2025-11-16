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
    
    private var playbackItems = [Int64: PlayerViewControllerCoordinator]()
    
    init() {
        // Piwigo will play audio even if the Silent switch set to silent or when the screen locks.
        // Furthermore, it will interrupt any other current audio sessions (no mixing)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    deinit {
        playbackItems = [Int64: PlayerViewControllerCoordinator]()
    }
        
    func coordinator(for video: Video) -> PlayerViewControllerCoordinator {
        if let playbackItem = playbackItems[video.pwgID] {
            return playbackItem
        } else {
            let playbackItem = PlayerViewControllerCoordinator(video: video)
            playbackItem.delegate = videoItemDelegate
            playbackItems[video.pwgID] = playbackItem
            return playbackItem
        }
    }
    
    func embed(contentOfVideo video: Video, in parentViewController: UIViewController, containerView: UIView) {
        coordinator(for: video).embedInline(in: parentViewController, container: containerView)
    }

    func remove(contentOfVideo video: Video) {
        playbackItems[video.pwgID]?.removeFromParentIfNeeded()
    }
    
    func present(contentOfVideo video: Video, from presentingViewController: UIViewController) {
        coordinator(for: video).presentFullScreen(from: presentingViewController)
    }
    
    @MainActor
    func play(contentOfVideo video: Video) {
        coordinator(for: video).playOrReplay()
    }

    func seek(contentOfVideo video: Video, toTimeFraction fraction: Double) {
        coordinator(for: video).seekToTime(video.duration * fraction)
    }
    
    func isPlayingVideo(_ video: Video) -> Bool {
        return coordinator(for: video).isPlayingVideo()
    }

    func pause(contentOfVideo video: Video) {
        coordinator(for: video).pauseAndStoreTime()
    }
    
    func muteUnmute(contentOfVideo video: Video) {
        coordinator(for: video).muteUnmute()
    }

    func removeAllEmbeddedViewControllers() {
        playbackItems.forEach {
            $0.value.removeFromParentIfNeeded()
        }
    }
    
    @MainActor
    func dismissActivePlayerViewController(animated: Bool, completion: @escaping () -> Void) {
        let fullScreenItems = playbackItems.filter({ $0.value.status.contains(.fullScreenActive) }).map({ $0.value })
        assert(fullScreenItems.count <= 1, "Never should be more than one thing full screen!")
        if let fullScreenItem = fullScreenItems.first {
            fullScreenItem.dismiss(completion: completion)
        } else {
            completion()
        }
    }
    
    func delete(video: Video) {
        if playbackItems[video.pwgID] != nil {
            // Delete coordinator
            coordinator(for: video).delete()
            // Delete video item
            playbackItems[video.pwgID] = nil
        }
    }
}
