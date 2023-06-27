//
//  ExternalDisplayVideoView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import AVKit
import UIKit
import piwigoKit

extension ExternalDisplayViewController
{
    // MARK: - Video Player
    func startVideoPlayerView(with imageData: Image?) {
        // Set URL
        guard let videoURL = imageData?.fullRes?.url as? URL else { return }

        // AVURLAsset + Loader
        let asset = AVURLAsset(url: videoURL, options: nil)
        let loader = asset.resourceLoader
        loader.setDelegate(self, queue: DispatchQueue(label: "Piwigo loader"))

        // Load the asset's "playable" key
        asset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: { [self] in
            DispatchQueue.main.async(
                execute: { [self] in
                    // IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem.
                    var error: NSError? = nil
                    let keyStatus = asset.statusOfValue(forKey: "playable", error: &error)
                    switch keyStatus {
                        case .loaded:
                            // Sucessfully loaded, continue processing
                            playVideoAsset(asset)
                        case .failed:
                            // Display the error.
                            assetFailedToPrepare(forPlayback: error)
                        case .cancelled:
                            // Loading cancelled
                            break
                        default:
                            // Handle all other cases
                            break
                    }
                })
        })
    }

    private func playVideoAsset(_ asset: AVAsset?) {
        // AVPlayer
        var playerItem: AVPlayerItem? = nil
        if let asset = asset {
            playerItem = AVPlayerItem(asset: asset)
        }
        let videoPlayer = AVPlayer(playerItem: playerItem) // Intialise video controller
        
        // AVPlayerController
        let playerController = AVPlayerViewController()
        playerController.player = videoPlayer
        playerController.videoGravity = .resizeAspect
        playerController.showsPlaybackControls = true
        playerController.allowsPictureInPicturePlayback = false
        
        // Start playing automatically
        playerController.player?.play()

        // Present the video
        playerController.modalTransitionStyle = .crossDissolve
        playerController.modalPresentationStyle = .overFullScreen
        view?.addSubview(playerController.view)
        view?.addConstraints(NSLayoutConstraint.constraintFillSize(playerController.view)!)
        present(playerController, animated: false)
    }

    func dismissVideoPlayerIfNeeded() {
        // Dismiss the video player if it exists
        if let playerVC = presentedViewController as? AVPlayerViewController {
            playerVC.dismiss(animated: true)
        }
    }
    
    private func assetFailedToPrepare(forPlayback error: Error?) {
        // Could not present the video
        imageView.image = nil
        helpLabel.isHidden = false
    }
}


// MARK: - AVAssetResourceLoader Methods
extension ExternalDisplayViewController: AVAssetResourceLoaderDelegate
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
