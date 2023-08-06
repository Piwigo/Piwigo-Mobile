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
    private var readyForDisplayObservation: NSKeyValueObservation?
    private(set) var playerViewControllerIfLoaded: AVPlayerViewController? {
        didSet {
            guard playerViewControllerIfLoaded != oldValue else { return }
            
            // Invalidate the key value observer, delegate, player, and status for the original player view controller.
            readyForDisplayObservation?.invalidate()
            readyForDisplayObservation = nil
            if oldValue?.delegate === self {
                oldValue?.delegate = nil
            }
            if oldValue?.hasContent(fromVideo: video) == true {
                oldValue?.player = nil
            }
            
            status = []
            
            // Set up the new playerViewController.
            if let playerViewController = playerViewControllerIfLoaded {
                // Assign self as the player view controller delegate.
                playerViewController.delegate = self
                
                // Create a player for the video.
                if !playerViewController.hasContent(fromVideo: video) {
                    let assetURL: URL
                    if FileManager.default.fileExists(atPath: video.cacheURL.path) {
                        assetURL = video.cacheURL
                    } else {
                        assetURL = video.pwgURL
                    }
                    let asset = AVURLAsset(url: assetURL, options: nil)
                    let loader = asset.resourceLoader
                    loader.setDelegate(self, queue: DispatchQueue(label: "org.piwigo.resourceLoader"))
                    let playerItem = AVPlayerItem(asset: asset)
                    // Seek to the resume time *before* assigning the player to the view controller.
                    // This is more efficient, and provides a better user experience because the media only loads at the actual start time.
                    playerItem.seek(to: CMTime(seconds: video.resumeTime, preferredTimescale: 90_000),
                                    completionHandler: nil)
                    playerViewController.player = AVPlayer(playerItem: playerItem)
                    playerViewController.videoGravity = .resizeAspect
                    playerViewController.view.backgroundColor = .clear
                    playerViewController.view.tintColor = .white
                }
                
                // Update the player view contoller's ready-for-display status and start observing the property.
                if playerViewController.isReadyForDisplay {
                    status.insert(.readyForDisplay)
                    playerViewController.player?.playImmediately(atRate: 1.0)
                }
                
                readyForDisplayObservation = playerViewController.observe(\.isReadyForDisplay) { [weak self] observed, _ in
                    if observed.isReadyForDisplay {
                        self?.status.insert(.readyForDisplay)
                        playerViewController.player?.playImmediately(atRate: 1.0)
                    } else {
                        self?.status.remove(.readyForDisplay)
                    }
                }

                // Update the VideoHUD with the current status.
                videoHud.status = status
            }
        }
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
    
    
    // MARK: - Initialisation
    init(video: Video) {
        self.video = video
        super.init()

        // Observe system notifications for storing videos in cache
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishPlaying(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    @objc func didFinishPlaying(_ notification: Notification?) {
        if notification?.name == .AVPlayerItemDidPlayToEndTime,
           let playerItem = notification?.object as? AVPlayerItem,
           let urlAsset = playerItem.asset as? AVURLAsset, urlAsset.url == video.pwgURL,
           let videoAsset = playerItem.asset.copy() as? AVAsset, videoAsset.isExportable {
               // User did watch video until the end
               DispatchQueue.global(qos: .background).async {
                   // Get export session
//                   let presets = AVAssetExportSession.exportPresets(compatibleWith: videoAsset)
                   guard let exportSession = AVAssetExportSession(asset: videoAsset,
                                                presetName: AVAssetExportPresetHighestQuality) else { return }
                   // Set parameters
                   exportSession.outputFileType = .mov
                   exportSession.shouldOptimizeForNetworkUse = true
                   exportSession.timeRange = CMTimeRangeMake(start: .zero, duration: .positiveInfinity)
                   exportSession.metadata = videoAsset.metadata
                   exportSession.outputURL = self.video.cacheURL
                   
                   // Store video file in cache for reuse
                   exportSession.exportAsynchronously {
                       switch exportSession.status {
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
                       case .unknown, .waiting, .exporting, .failed, .cancelled:
                           debugPrint("••> Video not stored in cache: \(String(describing: exportSession.error))")
                       @unknown default:
                           debugPrint("••> Video not stored in cache: Unknown error")
                       }
                   }
               }
        }
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
        loadPlayerViewControllerIfNeeded()
        guard let playerViewController = playerViewControllerIfLoaded,
              playerViewController.parent != parent else { return }
        removeFromParentIfNeeded()
        status.insert(.embeddedInline)
        playerViewController.showsPlaybackControls = true
        playerViewController.allowsPictureInPicturePlayback = true
        playerViewController.player?.isMuted = VideoVars.shared.isPlayerMuted
        embed(playerViewController: playerViewController, in: parent, container: container)
    }

    // Use the standard UIKit view controller containment API to embed the player view controller inline.
    // Track the player view controller status for the embedded inline playback on th external display.
    func embedExternalDisplay(in parent: UIViewController, container: UIView) {
        loadPlayerViewControllerIfNeeded()
        guard let playerViewController = playerViewControllerIfLoaded,
              playerViewController.parent != parent else { return }
        removeFromParentIfNeeded()
        status.insert(.externalDisplayActive)
        playerViewController.showsPlaybackControls = true
        playerViewController.allowsPictureInPicturePlayback = false
        embed(playerViewController: playerViewController, in: parent, container: container)
    }
    
    private func embed(playerViewController: AVPlayerViewController, in parent: UIViewController, container: UIView) {
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
        playerViewController.beginAppearanceTransition(true, animated: false)
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
        if status.contains(.embeddedInline) {
            removeFromParent()
            status.remove(.embeddedInline)
        } else if status.contains(.externalDisplayActive) {
            removeFromParent()
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
        return url == video.pwgURL
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
        
        coordinator.animate(alongsideTransition: nil) { context in
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
        status.insert([.beingDismissed])
        
        coordinator.animate(alongsideTransition: nil) { context in
            self.status.remove(.beingDismissed)
            if !context.isCancelled {
                self.status.remove(.fullScreenActive)
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
            print("Other type: username password, client trust...")
        }
        return true
    }
}
