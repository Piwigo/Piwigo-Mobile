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
    var hideMetadata = false

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var videoView: UIView!
    
    @IBOutlet weak var descContainer: UIVisualEffectView!
    @IBOutlet weak var descContainerOffset: NSLayoutConstraint!
    @IBOutlet weak var descTextView: UITextView!
    @IBOutlet weak var descTextViewWidth: NSLayoutConstraint!
    @IBOutlet weak var descTextViewHeight: NSLayoutConstraint!
    
    private var downloadTask: URLSessionDataTask?
    private var previousScale: CGFloat = 0          // To remember the previous image scale
    private var didTapView: Bool = false            // True if the user did tap the view


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        guard let imageThumbnail = thumb.image ?? UIImage(named: "placeholderImage") else {
            fatalError("!!! No placeholder image available !!!")
        }
        imageView.image = imageThumbnail
        imageViewWidthConstraint.constant = imageThumbnail.size.width
        imageViewHeightConstraint.constant = imageThumbnail.size.height

        // Description of the image
        configDescription()

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

        downloadTask = NetworkVarsObjc.imagesSessionManager?.get(
            previewURL.absoluteString,
            parameters: [],
            headers: [:],
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
                    // Set image view content
                    weakSelf?.imageView.image = image
                    weakSelf?.imageViewWidthConstraint.constant = image.size.width
                    weakSelf?.imageViewHeightConstraint.constant = image.size.height
                    weakSelf?.view.layoutIfNeeded()
                    
                    // Configure description view
                    weakSelf?.configDescription()

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
                    debugPrint("setImageScrollViewWithImageData: loaded image is nil!")
                }
            },
            failure: { task, error in
                if let error = error as NSError? {
                    debugPrint("setImageScrollViewWithImageData/GET Error: \(error)")
                }
            })

        downloadTask?.resume()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descTextView.textColor = .piwigoColorWhiteCream()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Update description view if necessary
            configDescription()
        })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if didTapView {
            didTapView = false
//            centerImageView()
        } else {
            updateMinZoomScaleForSize(view.bounds.size)
        }
    }

    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    func updateMinZoomScaleForSize(_ size: CGSize) {
        guard let image = imageView.image else { return }
        let widthScale = size.width / image.size.width
        let heightScale = size.height / image.size.height
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        if minScale > 1 {
            scrollView.maximumZoomScale = 1.5*minScale
        } else {
            scrollView.maximumZoomScale = 4*minScale
        }
        scrollView.zoomScale = minScale
        debugPrint("=> From (\(size.width),\(size.height)) and (\(image.size.width),\(image.size.height)), minScale: \(minScale)")
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    
    // MARK: - Image Metadata
    func didTapViewWillHideMetadata(_ hide:Bool) {
        didTapView = true
        hideMetadata = hide
        configDescription()
    }
    
    func updateImageMetadata(with data:PiwigoImageData) {
        // Update Piwigo data
        imageData = data

        // Should we update the image description?
        if descTextView.text != data.comment {
            configDescription()
        }
    }

    private func configDescription() {
        // Should we present a description?
        if imageData.comment.isEmpty || hideMetadata {
            // Hide the description view
            descContainer.isHidden = true
            // Center image in available space
            centerImageView()
            return
        }
        
        // Configure the description view
        descContainer.isHidden = false
        descTextView.text = imageData.comment

        // Calculate the available width
        guard let root = UIApplication.shared.keyWindow?.rootViewController else { return }
        var safeAreaWidth: CGFloat = view.frame.size.width
        if #available(iOS 11.0, *) {
            safeAreaWidth -= root.view.safeAreaInsets.left + root.view.safeAreaInsets.right
        }
        
        // Calculate the required number of lines, corners' width deducted
        let attributes = [
            NSAttributedString.Key.font: descTextView.font ?? UIFont.piwigoFontSmall()
        ] as [NSAttributedString.Key : Any]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let lineHeight = (descTextView.font ?? UIFont.piwigoFontSmall()).lineHeight
        let cornerRadius = descTextView.textContainerInset.top + lineHeight/2
        let rect = descTextView.text.boundingRect(with: CGSize(width: safeAreaWidth - cornerRadius, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes, context: context)
        let textHeight = rect.height
        let nberOfLines = textHeight / lineHeight
        
        // Can we display the description on one or two lines?
        if nberOfLines < 3 {
            // Calculate the height (the width should be < safeAreaWidth)
            let requiredHeight = ceil(descTextView.textContainerInset.top + textHeight + descTextView.textContainerInset.bottom)
            // Calculate the optimum size
            let size = descTextView.sizeThatFits(CGSize(width: safeAreaWidth,
                                                        height: requiredHeight))
            descContainerOffset.constant = -8                   // Shift description view up by 8 pixels
            descTextViewWidth.constant = size.width   // Add space taken by corners
            descTextViewHeight.constant = size.height
            descContainer.layer.cornerRadius = cornerRadius
            descContainer.layer.masksToBounds = true
        }
        else {
            // Several lines are required -> full width for minimising height
            descContainerOffset.constant = 0                // Glue the description to the toolbar
            descContainer.layer.cornerRadius = 0            // Disable rounded corner in case user added text
            descContainer.layer.masksToBounds = false
            descTextViewWidth.constant = safeAreaWidth
            let height = descTextView.sizeThatFits(CGSize(width: safeAreaWidth,
                                                          height: CGFloat.greatestFiniteMagnitude)).height

            // The maximum height is limited on iPhone
            if UIDevice.current.userInterfaceIdiom == .phone {
                let orientation: UIInterfaceOrientation
                if #available(iOS 14, *) {
                    orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                } else {
                    orientation = UIApplication.shared.statusBarOrientation
                }
                let maxHeight:CGFloat = orientation.isPortrait ? 88 : 52
                descTextViewHeight.constant = min(maxHeight, height)
            }
            else {
                descTextViewHeight.constant = height
            }
        }
        
        // Center image in available space
        centerImageView()
    }
        
    
    // MARK: - Video Player
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

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard let view = view else { return }
        guard let image = imageView.image else { return }
        debugPrint("=> zoomScale = \(scale), image: \(round(image.size.width)) x \(round(image.size.height)), imageView: \(round(imageView.frame.width)) x \(round(imageView.frame.height))")
        debugPrint("   view bounds: \(round(view.bounds.origin.x)), \(round(view.bounds.origin.y)), \(round(view.bounds.size.width)), \(round(view.bounds.size.height)), view frame: \(round(view.frame.origin.x)), \(round(view.frame.origin.y)), \(round(view.frame.size.width)), \(round(view.frame.size.height))")
        debugPrint("   offset: \(round(scrollView.contentOffset.x)), \(round(scrollView.contentOffset.y))")
        debugPrint("   scrollView bounds: \(round(scrollView.bounds.size.width)) x \(round(scrollView.bounds.size.height)), frame: \(round(scrollView.frame.size.width)) x \(round(scrollView.frame.size.height))")
        
        // Image should be displayed at a minimum scale
        if scale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
                
//        if (scale == 1.0) && (previousScale == 1.0) {
//            // The user scaled down twice the image => back to collection of images
//            let name = NSNotification.Name(rawValue: kPiwigoNotificationPinchedImage)
//            NotificationCenter.default.post(name: name, object: nil)
//        } else {
//            previousScale = scale
//        }
    }

    private func centerImageView() {
        // Determine the available spaces above and below the image
        var spaceAbove:CGFloat = 0
        var spaceBelow:CGFloat = imageData.comment.isEmpty ? 0 : descTextViewHeight.constant + 8
        if let nav = navigationController {
            // Remove the heights of the navigation bar and of the toolbar
            spaceAbove += nav.navigationBar.bounds.height
            spaceBelow += nav.toolbar.bounds.height
        }
        if #available(iOS 11.0, *) {
            // Takes into account the safe area insets
            if let root = UIApplication.shared.keyWindow?.rootViewController {
                spaceAbove += root.view.safeAreaInsets.top
                spaceBelow += root.view.safeAreaInsets.bottom
            }
        }
        let spaceAvailable = scrollView.bounds.height - spaceAbove - spaceBelow - imageView.frame.height
        debugPrint("   space above: \(spaceAbove), below: \(spaceBelow), available: \(spaceAvailable)")
        
        // Update constraints
        debugPrint("   constraint top: \(max(0, spaceAbove + spaceAvailable/2)), bottom: \(max(0, spaceBelow + spaceAvailable/2))")
        imageViewTopConstraint.constant = max(0, spaceAbove + spaceAvailable/2)
        imageViewBottomConstraint.constant = max(0, spaceBelow + spaceAvailable/2)
    }
}
