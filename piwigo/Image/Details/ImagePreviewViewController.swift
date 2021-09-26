//
//  ImagePreviewViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 04/09/2021.
//

import AVKit
import UIKit
import piwigoKit

@objc protocol ImagePreviewDelegate: NSObjectProtocol {
    func downloadProgress(_ progress: CGFloat)
}

class ImagePreviewViewController: UIViewController
{
    @objc weak var imagePreviewDelegate: ImagePreviewDelegate?

    var imageIndex = 0
    var imageLoaded = false
    var imageData: PiwigoImageData!
    var downloadTask: URLSessionDataTask?

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var videoView: UIView!
    
    private var previousScale: CGFloat = 0.0


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Scroll view
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        
        // Display "play" button if video
        playImage.isHidden = !imageData.isVideo

        // Thumbnail image should be available in cache
        let thumbnailSize = kPiwigoImageSize(rawValue: AlbumVars.defaultThumbnailSize)
        let thumbnailStr = imageData.getURLFromImageSizeType(thumbnailSize)
        let thumbnailURL = URL(string: thumbnailStr ?? "")
        let thumb = UIImageView()
        if let thumbnailURL = thumbnailURL {
            thumb.image = NetworkVarsObjc.thumbnailCache?.imageforRequest(URLRequest(url: thumbnailURL), withAdditionalIdentifier: nil)
        }
        imageView.image = thumb.image ?? UIImage(named: "placeholderImage")

        // Previewed image
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        let imagePreviewSize = kPiwigoImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize)
        var previewStr = imageData.getURLFromImageSizeType(imagePreviewSize)
        if previewStr == nil {
            // Image URL unknown => default to medium image size
            previewStr = imageData.getURLFromImageSizeType(kPiwigoImageSizeMedium)
            // After an upload, the server only returns the Square and Thumbnail sizes
            if previewStr == nil {
                previewStr = imageData.getURLFromImageSizeType(kPiwigoImageSizeThumb)
            }
        }
        guard let previewURL = URL(string: previewStr ?? "") else {return }
        weak var weakSelf = self

//        debugPrint("==> Start loading \(previewURL.path)")
        downloadTask = NetworkVarsObjc.imagesSessionManager?.get(
            previewURL.absoluteString,
            parameters: nil,
            headers: nil,
            progress: { progress in
                DispatchQueue.main.async(
                    execute: {
                        // Update progress bar
                        if weakSelf?.imagePreviewDelegate?.responds(to: #selector(ImagePreviewDelegate.downloadProgress(_:))) ?? false {
                            weakSelf?.imagePreviewDelegate?.downloadProgress(CGFloat(progress.fractionCompleted))
                        }
                    })
            },
            success: { task, image in
                if let image = image as? UIImage {
                    weakSelf?.imageView.image = image
                    // Hide progress bar
                    weakSelf?.imageLoaded = true
                    if weakSelf?.imagePreviewDelegate?.responds(to: #selector(ImagePreviewDelegate.downloadProgress(_:))) ?? false {
                        weakSelf?.imagePreviewDelegate?.downloadProgress(1.0)
                    }
                    // Store image in cache
                    var cachedResponse: CachedURLResponse? = nil
                    if let response = task.response,
                        let image1 = image.jpegData(compressionQuality: 0.9) {
                        cachedResponse = CachedURLResponse(response: response, data: image1)
                    }
                    if let cachedResponse = cachedResponse, let downloadTask1 = weakSelf?.downloadTask {
                        NetworkVarsObjc.imageCache?.storeCachedResponse(cachedResponse, for: downloadTask1)
                    }
                } else {
                    // Keep thumbnail or placeholder if image could not be loaded
                    print("setImageScrollViewWithImageData: loaded image is nil!")
                }
            },
            failure: { task, error in
                if let error = error as NSError? {
                    print("setImageScrollViewWithImageData/GET Error: \(error)")
                }
            })

        downloadTask?.resume()
    }
    
    @objc
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

        // Start playing automatically…
        playerController.player?.play()

        videoView?.addSubview(playerController.view)
        playerController.view.frame = videoView?.bounds ?? CGRect.zero

        // Present the video
        var currentViewController = UIApplication.shared.keyWindow?.rootViewController
        while currentViewController?.presentedViewController != nil {
            currentViewController = currentViewController?.presentedViewController
        }
        playerController.modalTransitionStyle = .crossDissolve
        playerController.modalPresentationStyle = .overFullScreen
        currentViewController?.present(playerController, animated: true)
    }

    func assetFailedToPrepare(forPlayback error: Error?) {
        // Determine the present view controller
        var topViewController = UIApplication.shared.keyWindow?.rootViewController
        while topViewController?.presentedViewController != nil {
            topViewController = topViewController?.presentedViewController
        }

        if let error = error as NSError? {
            topViewController?.dismissPiwigoError(withTitle: error.localizedDescription, message: "",
                                                  errorMessage: error.localizedFailureReason ?? "",
                                                  completion: { })
        }
    }
}


// MARK: - AVAssetResourceLoader Methods
extension ImagePreviewViewController: AVAssetResourceLoaderDelegate
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
            let password = KeychainUtilities.password(forService: "\(NetworkVarsObjc.serverProtocol)\(NetworkVarsObjc.serverPath)", account: user)
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


// MARK: - UIScrollViewDelegate Methods
extension ImagePreviewViewController: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if (scale == 1.0) && (previousScale == 1.0) {
            // The user scaled down twice the image => back to collection of images
            let name = NSNotification.Name(rawValue: kPiwigoNotificationPinchedImage)
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            previousScale = scale
        }
    }
}
