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

class ImagePreviewViewController: UINavigationController
{
    @objc weak var imagePreviewDelegate: ImagePreviewDelegate?

    var imageIndex = 0
    var imageLoaded = false
    var scrollView: ImageScrollView?
    var videoView: VideoView?
    var downloadTask: URLSessionDataTask?

    init() {
        super.init(nibName: nil, bundle: nil)
        
        // Image
        scrollView = ImageScrollView()
        view = scrollView

        // Video
        videoView = VideoView()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }


    // MARK: - View Lifecycle

    @objc func applyColorPalette() {
        // Background color depends on the navigation bar visibility
        if navigationController?.isNavigationBarHidden ?? false {
            view.backgroundColor = UIColor.black
        } else {
            view.backgroundColor = UIColor.piwigoColorBackground()
        }

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()
        isNavigationBarHidden = true

//        if #available(iOS 15.0, *) {
//            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
//            /// which by default produces a transparent background, to all navigation bars.
//            let barAppearance = UINavigationBarAppearance()
//            barAppearance.configureWithOpaqueBackground()
//            barAppearance.backgroundColor = UIColor.piwigoColorBackground()
//            navigationController?.navigationBar.standardAppearance = barAppearance
//            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
//
//            let toolbarAppearance = UIToolbarAppearance(barAppearance: barAppearance)
//            navigationController?.toolbar.standardAppearance = toolbarAppearance
//            navigationController?.toolbar.scrollEdgeAppearance = navigationController?.toolbar.standardAppearance
//        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }

    @objc
    func setImageScrollViewWith(_ imageData: PiwigoImageData) {
        // Display "play" button if video
        scrollView?.playImage.isHidden = !imageData.isVideo

        // Thumbnail image should be available in cache
        let thumbnailSize = kPiwigoImageSize(rawValue: AlbumVars.defaultThumbnailSize)
        let thumbnailStr = imageData.getURLFromImageSizeType(thumbnailSize)
        let thumbnailURL = URL(string: thumbnailStr ?? "")
        let thumb = UIImageView()
        if let thumbnailURL = thumbnailURL {
            thumb.image = NetworkVarsObjc.thumbnailCache?.imageforRequest(URLRequest(url: thumbnailURL), withAdditionalIdentifier: nil)
        }
        scrollView?.imageView.image = thumb.image ?? UIImage(named: "placeholderImage")

        // Previewed image
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

        //    NSLog(@"==> Start loading %@", previewURL.path);
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
                    weakSelf?.scrollView?.imageView.image = image
                    // Update progress bar
                    if weakSelf?.imagePreviewDelegate?.responds(to: #selector(ImagePreviewDelegate.downloadProgress(_:))) ?? false {
                        weakSelf?.imagePreviewDelegate?.downloadProgress(1.0)
                    }
                    // Hide progress bar
                    weakSelf?.imageLoaded = true
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
