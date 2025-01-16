//
//  PlayerViewControllerCoordinator.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/07/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import AVKit
import piwigoKit

protocol PlayerViewControllerCoordinatorDelegate: AnyObject {
    func playerViewControllerCoordinator(_ coordinator: PlayerViewControllerCoordinator,
                                         restoreUIForPIPStop completion: @escaping (Bool) -> Void)
}

// See WWDC 2019 session 503: Delivering Intuitive Media Playback with AVKit
class PlayerViewControllerCoordinator: NSObject {
    
    // MARK: - Properties
    weak var delegate: PlayerViewControllerCoordinatorDelegate?
    
    var video: Video
    private lazy var scale = CMTimeScale(USEC_PER_SEC)
    private lazy var videoHud = VideoHUD()
    private(set) var status: Status = [] {
        didSet {
            videoHud.status = status
            if oldValue.isBeingShown && !status.isBeingShown {
                playerViewControllerIfLoaded = nil
            }
            addVideoHUDToPlayerViewControllerIfNeeded()
        }
    }
//    private var imagePage: UIViewController?
//    private var imagePageContainer: UIView?
    
    // OptionSet describing the various states the app tracks in the VideoHUD.
    struct Status: OptionSet, CustomDebugStringConvertible {
        let rawValue: Int
        static let embeddedInline =         Status(rawValue: 1 << 0)    // i.e. in ImagePreviewController
        static let fullScreenActive =       Status(rawValue: 1 << 1)    // i.e. in full screen
        static let beingPresented =         Status(rawValue: 1 << 2)
        static let beingDismissed =         Status(rawValue: 1 << 3)
        static let pictureInPictureActive = Status(rawValue: 1 << 4)    // i.e. in PiP mode
        static let readyForDisplay =        Status(rawValue: 1 << 5)
        static let externalDisplayActive =  Status(rawValue: 1 << 6)    // i.e. in ExternalDisplayViewController
        
        static let descriptions: [(Status, String)] = [
            (.embeddedInline,           "Embedded Inline"),
            (.fullScreenActive,         "Full Screen Active"),
            (.beingPresented,           "Being Presented"),
            (.beingDismissed,           "Being Dismissed"),
            (.pictureInPictureActive,   "Picture In Picture Active"),
            (.readyForDisplay,          "Ready For Display"),
            (.externalDisplayActive,    "External Display active")
        ]
        
        var isBeingShown: Bool {
            return !intersection([.embeddedInline, .pictureInPictureActive,
                                  .externalDisplayActive, .fullScreenActive]).isEmpty
        }
        
        var debugDescription: String {
            var debugDescriptions = Status.descriptions.filter({ contains($0.0) }).map({ $0.1 })
            if isEmpty {
                debugDescriptions.append("Idle (Tap to full screen)")
            } else if !contains(.readyForDisplay) {
                debugDescriptions.append("NOT Ready For Display")
            }
            return debugDescriptions.joined(separator: "\n")
        }
    }
    
    private weak var fullScreenViewController: UIViewController?
    private var playerStatusObservation: NSKeyValueObservation?
    private var playerRateObservation: NSKeyValueObservation?
    private var playerMuteObservation: NSKeyValueObservation?
    private var playbackReadyObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private(set) var playerViewControllerIfLoaded: AVPlayerViewController? {
        didSet {
            guard playerViewControllerIfLoaded != oldValue else { return }
            
            // Invalidate the key value observers, delegate, player,
            // and status for the original player view controller.
            playerStatusObservation?.invalidate()
            playerStatusObservation = nil
            playerRateObservation?.invalidate()
            playerRateObservation = nil
            playerMuteObservation?.invalidate()
            playerMuteObservation = nil
            playbackReadyObservation?.invalidate()
            playbackReadyObservation = nil
            if oldValue?.delegate === self {
                oldValue?.delegate = nil
            }
            if oldValue?.hasContent(fromVideo: video) == true {
                oldValue?.player = nil
            }
            
            status = []
            
            autoreleasepool {
                // Set up the new playerViewController.
                if let playerViewController = playerViewControllerIfLoaded {
                    // Initialisation
                    playerViewController.delegate = self
                    playerViewController.updatesNowPlayingInfoCenter = true
                    
                    // Create a player for the video.
                    if !playerViewController.hasContent(fromVideo: video) {
                        // Prefer asset in cache if available
                        let asset: AVURLAsset
                        if FileManager.default.fileExists(atPath: video.cacheURL.path) {
                            asset = AVURLAsset(url: video.cacheURL, options: nil)
                        } else {
                            asset = AVURLAsset(url: video.pwgURL, options: nil)
                            let loader = asset.resourceLoader
                            loader.setDelegate(self, queue: DispatchQueue(label: "org.piwigo.resourceLoader"))
                        }
                        
                        // Initialise player item
                        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["duration"])
                        playerItem.preferredForwardBufferDuration = TimeInterval(5)
                        // Seek to the resume time *before* assigning the player to the view controller.
                        // This is more efficient, and provides a better user experience because the media only loads at the actual start time.
                        playerItem.seek(to: CMTime(seconds: video.resumeTime, preferredTimescale: scale),
                                        completionHandler: nil)
                        
                        // Add title and artwork
                        if #available(iOS 12.2, *) {
                            // Any title?
                            let titleItems = AVMetadataItem.metadataItems(from: playerItem.externalMetadata,
                                                                          filteredByIdentifier: .commonIdentifierTitle)
                            if titleItems.isEmpty {
                                playerItem.externalMetadata.append(metadataItemForMediaTitle())
                            }
                            let artworkItems = AVMetadataItem.metadataItems(from: playerItem.externalMetadata,
                                                                            filteredByIdentifier: .commonIdentifierArtwork)
                            if artworkItems.isEmpty {
                                let item = metadataItemForMediaArtwork()
                                playerItem.externalMetadata.append(item)
                            }
                        } else {
                            // Fallback on earlier versions
                        }
                        
                        // Create player minimizing stalling
                        let player = AVPlayer(playerItem: playerItem)
                        player.automaticallyWaitsToMinimizeStalling = true
                        
                        // In case the cached video file is not playable, delete it and replace item
                        playerStatusObservation = playerItem.observe(\.status,
                                                                      changeHandler: { [weak self] item, _ in
                            if item.status == .failed,
                               asset.url == self?.video.cacheURL,
                               let pwgURL = self?.video.pwgURL {
                                // Delete cached file
                                try? FileManager.default.removeItem(at: asset.url)
                                //
                                let pwgAsset = AVURLAsset(url: pwgURL, options: nil)
                                let loader = pwgAsset.resourceLoader
                                loader.setDelegate(self, queue: DispatchQueue(label: "org.piwigo.resourceLoader"))
                                let playerItem = AVPlayerItem(asset: pwgAsset)
                                playerViewController.player?.replaceCurrentItem(with: playerItem)
                            }
                        })
                        
                        // Observe playback rate
                        playerRateObservation = player.observe(\.rate,
                                                                changeHandler: { [weak self] player, _ in
                            // Update play/pause button
                            let userInfo = ["pwgID"   : self?.video.pwgID as Any,
                                            "playing" : player.rate != 0] as [String : Any]
                            NotificationCenter.default.post(name: .pwgVideoPlaybackStatus,
                                                            object: nil, userInfo: userInfo)
                        })
                        
                        // Observe playback mute option
                        playerMuteObservation = player.observe(\.isMuted,
                                                                changeHandler: { [weak self] player, _ in
                            // Store user preference for next use
                            if playerViewController.parent is VideoDetailViewController {
                                VideoVars.shared.isMuted = playerViewController.player?.isMuted ?? false
                            }
                            // Update mute button
                            let userInfo = ["pwgID" : self?.video.pwgID as Any,
                                            "muted" : player.isMuted]  as [String : Any]
                            NotificationCenter.default.post(name: .pwgVideoMutedOrNot,
                                                            object: nil, userInfo: userInfo)
                        })
                        
                        // Complete player controller settings
                        let start = CMTime(seconds: video.resumeTime, preferredTimescale: scale)
                        player.seek(to: start) { _ in
                            playerViewController.player = player
                            playerViewController.videoGravity = .resizeAspect
                            playerViewController.view.backgroundColor = .clear
                            playerViewController.view.tintColor = .white
                        }
                        
                        // Invoke callback every 0.1 s
                        let interval = CMTime(seconds: 0.1,
                                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                        // Add time observer. Invoke closure on the main queue.
                        timeObserverToken =
                        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                            // Update player transport UI
                            if let parent = playerViewController.parent as? VideoDetailViewController {
                                parent.videoControls.setCurrentTime(time.seconds)
                            } else if let parent = playerViewController.parent as? ExternalDisplayViewController {
                                parent.setCurrentTime(time.seconds)
                            }
                        }
                    }
                    
                    // Update the player view contoller's ready-for-display status and start observing the property.
                    if playerViewController.isReadyForDisplay {
                        // Remember status and hides HUD if needed
                        status.insert(.readyForDisplay)
                        // Store video parameters
                        video.duration = playerViewController.player?.currentItem?.duration.seconds ?? 0
                        // Center container view now that the video size is known and configure slider
                        let currentTime = playerViewController.player?.currentTime().seconds ?? 0
                        if let parent = playerViewController.parent as? VideoDetailViewController {
                            parent.video?.duration = video.duration
                            parent.videoSize = playerViewController.videoBounds.size
                            parent.configVideoViews()
                            parent.videoControls.config(currentTime: currentTime, duration: video.duration)
                            playerViewController.player?.rate = 1
                        } else if let parent = playerViewController.parent as? ExternalDisplayViewController {
                            parent.config(currentTime: currentTime, duration: video.duration)
                            playerViewController.player?.rate = 1
                        }
                        // Hide image and show play button when ready
                        let userInfo = ["pwgID"   : video.pwgID as Any,
                                        "ready"   : playerViewController.player?.status == .readyToPlay,
                                        "playing" : playerViewController.player?.rate != 0,
                                        "muted"   : playerViewController.player?.isMuted as Any] as [String : Any]
                        NotificationCenter.default.post(name: .pwgVideoPlaybackStatus,
                                                        object: nil, userInfo: userInfo)
                    }
                    
                    playbackReadyObservation = playerViewController.observe(\.isReadyForDisplay,
                                                                             changeHandler: { [weak self] observed, _ in
                        if observed.isReadyForDisplay {
                            // Remember status and hides HUD if needed
                            self?.status.insert(.readyForDisplay)
                            // Store video parameters
                            self?.video.duration = playerViewController.player?.currentItem?.duration.seconds ?? 0
                            // Center container view now that the video size is known and configure slider
                            let currentTime = playerViewController.player?.currentTime().seconds ?? 0
                            if let parent = playerViewController.parent as? VideoDetailViewController {
                                parent.video?.duration = self?.video.duration ?? TimeInterval(0)
                                parent.videoSize = playerViewController.videoBounds.size
                                parent.configVideoViews()
                                parent.videoControls.config(currentTime: currentTime, duration: self?.video.duration ?? 0)
                                playerViewController.player?.rate = 1
                            } else if let parent = playerViewController.parent as? ExternalDisplayViewController {
                                parent.config(currentTime: currentTime, duration: self?.video.duration ?? 0)
                                playerViewController.player?.rate = 1
                            }
                        } else {
                            // Remember status and shows HUD if needed
                            self?.status.remove(.readyForDisplay)
                        }
                        
                        // Hide image and show play button
                        let userInfo = ["pwgID"   : self?.video.pwgID as Any,
                                        "ready"   : playerViewController.player?.status == .readyToPlay,
                                        "playing" : playerViewController.player?.rate != 0,
                                        "muted"   : playerViewController.player?.isMuted as Any] as [String : Any]
                        NotificationCenter.default.post(name: .pwgVideoPlaybackStatus,
                                                        object: nil, userInfo: userInfo)
                    })
                    
                    // Update the VideoHUD with the current status.
                    videoHud.status = status
                }
            }
        }
    }

    
    // MARK: - Initialisation
    init(video: Video) {
        self.video = video
        super.init()

        // Observe system notifications for storing videos in cache
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishPlaying(_:)),
                                               name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
    }
    
    // Create AVPlayerController only if necessary
    private func loadPlayerViewControllerIfNeeded() {
        if playerViewControllerIfLoaded == nil {
            playerViewControllerIfLoaded = AVPlayerViewController()
        }
    }
    
    private func addVideoHUDToPlayerViewControllerIfNeeded() {
        if status.contains(.embeddedInline) || status.contains(.fullScreenActive) || status.contains(.externalDisplayActive),
           let playerViewController = playerViewControllerIfLoaded,
           let contentOverlayView = playerViewController.contentOverlayView,
           !videoHud.isDescendant(of: contentOverlayView) {
            playerViewController.contentOverlayView?.addSubview(videoHud)
            videoHud.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                videoHud.centerXAnchor.constraint(equalTo: contentOverlayView.centerXAnchor),
                videoHud.centerYAnchor.constraint(equalTo: contentOverlayView.centerYAnchor),
                videoHud.widthAnchor.constraint(equalTo: contentOverlayView.widthAnchor),
                videoHud.heightAnchor.constraint(equalTo: contentOverlayView.heightAnchor)
            ])
        }
    }
    
    func metadataItemForMediaTitle() -> AVMetadataItem {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.value = video.title as NSString
        metadataItem.identifier = .commonIdentifierTitle
        return metadataItem
    }
    
    func metadataItemForMediaArtwork() -> AVMetadataItem {
        autoreleasepool {
            let metadataItem = AVMutableMetadataItem()
            if let data = video.artwork.pngData() {
                metadataItem.value = NSData(data: data)
            } else {
                metadataItem.value = NSData(data: UIImage(named: "AppIconShare")!.pngData()!)
            }
            metadataItem.identifier = .commonIdentifierArtwork
            return metadataItem
        }
    }
    
    @objc func didFinishPlaying(_ notification: Notification?) {
        guard notification?.name == AVPlayerItem.didPlayToEndTimeNotification,
              let playerItem = notification?.object as? AVPlayerItem
        else  { return }

        // User did watch video until the end -> replay it
        DispatchQueue.main.async { [self] in
            self.playOrReplay()
        }

        // Store the video in cache if possible
        if let urlAsset = playerItem.asset as? AVURLAsset, urlAsset.url == video.pwgURL,
           let videoAsset = playerItem.asset.copy() as? AVAsset, videoAsset.isExportable {
            DispatchQueue.global(qos: .background).async {
                // Get export session
//               let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
                guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                             presetName: AVAssetExportPresetHighestQuality) else { return }
                // Set parameters
                exportSession.outputFileType = .mov
                exportSession.shouldOptimizeForNetworkUse = true
                exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
                exportSession.metadata = videoAsset.metadata
                exportSession.outputURL = self.video.cacheURL
 
                // Create intermediate directories if needed
                let fm = FileManager.default
                let dirURL = self.video.cacheURL.deletingLastPathComponent()
                if fm.fileExists(atPath: dirURL.path) == false {
                    debugPrint("••> Create directory \(dirURL.path)")
                    try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true,
                                                attributes: nil)
                }
                
                // Delete existing file if it exists (incomplete previous attempt?)
                try? fm.removeItem(at: self.video.cacheURL)
 
                // Store video file in cache for reuse
                exportSession.exportAsynchronously { [self] in
                    switch exportSession.status {
                    case .waiting:
                        debugPrint("••> Video waiting to export more data… ;-)")
                    case .exporting:
                        debugPrint("••> Video export is in progress… ;-)")
                    case .completed:
                        debugPrint("••> Video stored in cache ;-)")
                        // Replace player item
                        DispatchQueue.main.async {
                            if let playerViewController = self.playerViewControllerIfLoaded {
                                let asset = AVURLAsset(url: self.video.cacheURL, options: nil)
                                let playerItem = AVPlayerItem(asset: asset)
                                if let resumeTime = playerViewController.player?.currentTime() {
                                    playerItem.seek(to: resumeTime) {_ in
                                        playerViewController.player?.replaceCurrentItem(with: playerItem)
                                    }
                                } else {
                                    playerViewController.player?.replaceCurrentItem(with: playerItem)
                                }
                            }
                        }
                    case .unknown, .failed, .cancelled:
                        debugPrint("••> Video not stored in cache: \(String(describing: exportSession.error)) — \(exportSession.outputURL?.absoluteString ?? "—?—")")
                    @unknown default:
                        debugPrint("••> Video not stored in cache: Unknown error")
                    }
                }
           }
        }
    }
    
    func delete() {
        playerViewControllerIfLoaded?.player?.replaceCurrentItem(with: nil)
        playerViewControllerIfLoaded?.player = nil
        playerViewControllerIfLoaded = nil
    }
    
    deinit {
        videoHud.removeFromSuperview()
    }
    

    // MARK: - Utility Functions for some UIKit tasks that the coordinator manages
    // Present full screen, and then start playback. There's no need to change the modal presentation style
    // or set the transitioning delegate. AVPlayerViewController handles that automatically.
    func presentFullScreen(from presentingViewController: UIViewController) {
        guard !status.contains(.fullScreenActive) else { return }
        removeFromParentIfNeeded()
        loadPlayerViewControllerIfNeeded()
        guard let playerViewController = playerViewControllerIfLoaded else { return }
        presentingViewController.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
    // Use the standard UIKit view controller containment API to embed the player view controller inline.
    // Track the player view controller status for the embedded inline playback.
    func embedInline(in parent: UIViewController, container: UIView) {
        // Initialisation
        loadPlayerViewControllerIfNeeded()
        guard let playerViewController = playerViewControllerIfLoaded,
              playerViewController.parent != parent else { return }
        removeFromParentIfNeeded()
        
        // Settings depend on parent view controller
        playerViewController.showsPlaybackControls = false
        if parent is VideoDetailViewController {
            status.insert(.embeddedInline)
            playerViewController.allowsPictureInPicturePlayback = true
            playerViewController.player?.isMuted = VideoVars.shared.isMuted
        } else if parent is ExternalDisplayViewController {
            status.insert(.externalDisplayActive)
            playerViewController.allowsPictureInPicturePlayback = false
        }
        
        // Finalise the job
        parent.addChild(playerViewController)
        container.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            playerViewController.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            playerViewController.view.widthAnchor.constraint(equalTo: container.widthAnchor),
            playerViewController.view.heightAnchor.constraint(equalTo: container.heightAnchor)
        ])
        playerViewController.didMove(toParent: parent)
        
        // Required since iOS 16
        playerViewController.beginAppearanceTransition(true, animated: true)
        
        // Store parent and container for restoring image page when exiting fullscreen mode
//        imagePage = parent
//        imagePageContainer = container
    }
    
    // Play or replay the video if the end is reached
    func playOrReplay() {
        guard let player = playerViewControllerIfLoaded?.player,
              let duration = player.currentItem?.duration.seconds,
              let currentTime = player.currentItem?.currentTime().seconds else {
            return
        }
        
        // Did we reach the end of the video?
        if duration - currentTime < 0.1 {
            // Reached the end of the video
            let start = CMTime(seconds: 0, preferredTimescale: scale)
            player.seek(to: start) { success in
                if success {
                    player.play()
                }
            }
        } else {
            player.play()
        }
    }
    
    func isPlayingVideo() -> Bool {
        guard let player = playerViewControllerIfLoaded?.player else { return false }
        return player.rate != 0
    }
    
    func seekToTime(_ time: Double) {
        // Complete player controller settings
        guard let player = playerViewControllerIfLoaded?.player else {
            return
        }
        
        let value = CMTime(seconds: time, preferredTimescale: scale)
        let before = CMTime(seconds: max(0, time - 0.1), preferredTimescale: scale)
        let after = CMTime(seconds: min(video.duration, time + 0.1), preferredTimescale: scale)
        player.seek(to: value, toleranceBefore: before, toleranceAfter: after) { [weak self] successs in
            if successs == false {
                return
            }
            self?.playerViewControllerIfLoaded?.player = player
        }
    }
    
    // Pause playback and remember current time
    func pauseAndStoreTime() {
        guard let player = playerViewControllerIfLoaded?.player,
              let duration = player.currentItem?.duration.seconds,
              let currentTime = player.currentItem?.currentTime().seconds else {
            return
        }

        player.pause()
        video.duration = duration
        video.resumeTime = currentTime
    }
    
    func muteUnmute() {
        guard let player = playerViewControllerIfLoaded?.player else { return }
        let isMuted = player.isMuted
        player.isMuted = !isMuted
    }

    // Demonstrates how to restore the video playback interface when Picture in Picture stops.
    func restoreFullScreen(from presentingViewController: UIViewController, completion: @escaping () -> Void) {
        guard let playerViewController = playerViewControllerIfLoaded,
            status.contains(.pictureInPictureActive),
            !status.contains(.fullScreenActive)
            else {
                completion()
                return
        }
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = true
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleWidth]
        presentingViewController.present(playerViewController, animated: true, completion: completion)
    }
    
    // Dismiss any active player view controllers before restoring the interface from Picture in Picture mode.
    // The AVPlayerViewController delegate methods show how to obtain the fullScreenViewController.
    func dismiss(completion: @escaping () -> Void) {
        fullScreenViewController?.dismiss(animated: true) {
            completion()
            self.status.remove(.fullScreenActive)
        }
    }
    
    // Removes the playerViewController from its container, and updates the status accordingly.
    func removeFromParentIfNeeded() {
        pauseAndStoreTime()
        removeFromParent()
        if status.contains(.embeddedInline) {
            status.remove(.embeddedInline)
        } else if status.contains(.externalDisplayActive) {
            status.remove(.externalDisplayActive)
        }
    }
    
    private func removeFromParent() {
        playerViewControllerIfLoaded?.willMove(toParent: nil)
        playerViewControllerIfLoaded?.view.removeFromSuperview()
        playerViewControllerIfLoaded?.removeFromParent()
    }
}


// MARK: - AVPlayerViewController Extension
private extension AVPlayerViewController {
    
    func hasContent(fromVideo video: Video) -> Bool {
        let url = (player?.currentItem?.asset as? AVURLAsset)?.url
        return (url == video.pwgURL) || (url == video.cacheURL)
    }
}


// MARK: - AVPlayerViewController Delegate
extension PlayerViewControllerCoordinator: AVPlayerViewControllerDelegate {
    
    // Update the status when Picture in Picture playback is about to start.
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        status.insert(.pictureInPictureActive)
    }
    
    // Update the status when Picture in Picture playback fails to start.
    func playerViewController(_ playerViewController: AVPlayerViewController,
                              failedToStartPictureInPictureWithError error: Error) {
        status.remove(.pictureInPictureActive)
    }
    
    // Update the status when Picture in Picture playback stops.
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        status.remove(.pictureInPictureActive)
    }
    
    // Track the presentation of the player view controller's content.
    // Note that this may happen while the player view controller is embedded inline.
    func playerViewController(_ playerViewController: AVPlayerViewController, willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        status.insert([.fullScreenActive, .beingPresented])
        
        coordinator.animate(alongsideTransition: nil) { [self] context in
            self.status.remove(.beingPresented)
            // You need to check context.isCancelled to determine whether the transition succeeds.
            if context.isCancelled {
                self.status.remove(.fullScreenActive)
            } else {
                // Keep track of the view controller playing full screen.
                self.fullScreenViewController = context.viewController(forKey: .to)
            }
        }
    }
    
    // Track the player view controller's dismissal from full-screen playback. This is the mirror
    // image of the playerViewController(_:willBeginFullScreenPresentationWithAnimationCoordinator:) function.
    func playerViewController(_ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator)
    {
        // Store current time for embeded player
        if let player = playerViewController.player,
           let duration = player.currentItem?.duration.seconds,
           let currentTime = player.currentItem?.currentTime().seconds {
            video.duration = duration
            video.resumeTime = currentTime
        }

        status.insert([.beingDismissed])
        
        coordinator.animate(alongsideTransition: nil) { [self] context in
            self.status.remove(.beingDismissed)
            if !context.isCancelled {
                self.status.remove(.fullScreenActive)
                // Restore video embeddded in image page
//                guard let imagePage = self.imagePage,
//                      let imagePageContainer = self.imagePageContainer else { return }
//                self.embedInline(in: imagePage, container: imagePageContainer)
            }
        }
    }
    
    // The most important delegate method for Picture in Picture--restoring the user interface.
    // This implementation sends the callback to its own delegate view controller because the coordinator
    // doesn't have enough global context to perform the restore operation.
    func playerViewController(_ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void)
    {
        if let delegate = delegate {
            delegate.playerViewControllerCoordinator(self, restoreUIForPIPStop: completionHandler)
        } else {
            completionHandler(false)
        }
    }
}


// MARK: - AVAssetResourceLoader Methods
extension PlayerViewControllerCoordinator: AVAssetResourceLoaderDelegate
{
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge
    ) -> Bool {
        let protectionSpace = authenticationChallenge.protectionSpace
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
        {
            // Self-signed certificate…
            if let certificate = protectionSpace.serverTrust {
                let credential = URLCredential(trust: certificate)
                authenticationChallenge.sender?.use(credential, for: authenticationChallenge)
            }
            authenticationChallenge.sender?.continueWithoutCredential(for: authenticationChallenge)
        }
        else if protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            // HTTP basic authentification credentials
            let user = NetworkVars.httpUsername
            let password = KeychainUtilities.password(forService: NetworkVars.service, account: user)
            authenticationChallenge.sender?.use(
                URLCredential(user: user, password: password, persistence: .synchronizable),
                              for: authenticationChallenge)
            authenticationChallenge.sender?.continueWithoutCredential(for: authenticationChallenge)
        }
        else {
            // Other type: username password, client trust...
            debugPrint("Other type: username password, client trust...")
        }
        return true
    }
}
