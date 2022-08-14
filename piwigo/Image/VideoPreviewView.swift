//
//  VideoPreviewView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import AVKit
import UIKit
import piwigoKit

extension ImageViewController
{
    // MARK: - Video Player
    func startVideoPlayerView(with imageData: PiwigoImageData?) {
        // Set URL
        let videoURL = URL(string: imageData?.fullResPath ?? "")

        // AVURLAsset + Loader
        var asset: AVURLAsset? = nil
        if let videoURL = videoURL {
            asset = AVURLAsset(url: videoURL, options: nil)
        }
        let loader = asset?.resourceLoader
        loader?.setDelegate(self, queue: DispatchQueue(label: "Piwigo loader"))

        // Load the asset's "playable" key
        asset?.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: { [self] in
            DispatchQueue.main.async(
                execute: { [self] in
                    // IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem.
                    var error: NSError? = nil
                    let keyStatus = asset?.statusOfValue(forKey: "playable", error: &error)
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

    func playVideoAsset(_ asset: AVAsset?) {
        // AVPlayer
        var playerItem: AVPlayerItem? = nil
        if let asset = asset {
            playerItem = AVPlayerItem(asset: asset)
        }
        let videoPlayer = AVPlayer(playerItem: playerItem) // Intialise video controller
        let playerController = AVPlayerViewController()
        playerController.player = videoPlayer
        playerController.videoGravity = .resizeAspect

        // Playback controls
        playerController.showsPlaybackControls = true
//    [self.videoPlayer addObserver:self.imageView forKeyPath:@"rate" options:0 context:nil];

        // Start playing automatically
        playerController.player?.play()

        // Present the video
        videoView?.addSubview(playerController.view)
        playerController.view.frame = videoView?.bounds ?? CGRect.zero
        present(playerController, animated: true)
    }

    func assetFailedToPrepare(forPlayback error: Error?) {
        // Determine the present view controller
        if let error = error as NSError? {
            dismissPiwigoError(withTitle: error.localizedDescription, message: "",
                               errorMessage: error.localizedFailureReason ?? "") {}
        }
    }
}


// MARK: - AVAssetResourceLoader Methods
extension ImageViewController: AVAssetResourceLoaderDelegate
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
            let password = KeychainUtilities.password(forService: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)", account: user)
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
