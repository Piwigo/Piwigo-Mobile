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

    private var _isToolbarRequired = false
    var isToolbarRequired: Bool {
        get {
            return _isToolbarRequired
        }
        set(isRequired) {
            if isRequired != _isToolbarRequired {
                // Update flag
                _isToolbarRequired = isRequired
                // Device rotated -> reset scroll view
                self.configScrollView()
            }
        }
    }

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var videoView: UIView!
    
    @IBOutlet weak var descContainer: UIVisualEffectView!
    @IBOutlet weak var descContainerOffset: NSLayoutConstraint!
    @IBOutlet weak var descContainerWidth: NSLayoutConstraint!
    @IBOutlet weak var descContainerHeight: NSLayoutConstraint!
    @IBOutlet weak var descTextView: UITextView!

    private var downloadTask: URLSessionDataTask?
    private var previousScale: CGFloat = 0          // To remember the previous image scale
    private var userDidTapView: Bool = false        // True if the user did tap the view
    private var statusBarHeight: CGFloat = 0        // To remmeber the height of the status bar


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
        
        // Configure the description view before the scrollview
        // which will then call the centerImage() method
        configDescription {
            self.configScrollView(with: imageThumbnail)
        }

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
                    weakSelf?.configScrollView(with: image)
                    weakSelf?.view.layoutIfNeeded()
                    
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
        
        // Store status bar height (is null when not displayed)
        if #available(iOS 11.0, *) {
            statusBarHeight = UIApplication.shared.keyWindow?.safeAreaInsets.top ?? UIApplication.shared.statusBarFrame.size.height
        } else {
            // Fallback on earlier versions
            statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        }
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descTextView.textColor = .piwigoColorWhiteCream()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()

        // Show/hide the description
        if imageData.comment.isEmpty {
            descContainer.isHidden = true
        } else {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if userDidTapView {
            userDidTapView = false
        }
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    
    // MARK: - Scroll View

    private func configScrollView(with image: UIImage) {
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height
        configScrollView()
    }
    
    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    private func configScrollView() {
        guard let image = imageView?.image else { return }
        scrollView.isPagingEnabled = false
        scrollView.bounds = view.bounds
        scrollView.contentSize = image.size
        scrollView.contentInset = UIEdgeInsets.zero
        let widthScale = view.bounds.size.width / image.size.width
        let heightScale = view.bounds.size.height / image.size.height
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        if minScale > 1 {
            scrollView.maximumZoomScale = 2*minScale
        } else {
            scrollView.maximumZoomScale = 4*minScale
        }
        scrollView.zoomScale = minScale     // Will trigger the scrollViewDidZoom() method
        debugPrint("=> scrollView: \(scrollView.bounds.size.width) x \(scrollView.bounds.size.height), imageView: \(imageView.frame.size.width) x \(imageView.frame.size.height), minScale: \(minScale)")
    }
    
    private func updateImageViewConstraints() {
        guard let image = imageView?.image else { return }

        // Determine the orientation of the device
        let orientation: UIInterfaceOrientation
        if #available(iOS 14, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        // Determine the available spaces around the image
        var spaceLeading: CGFloat = 0, spaceTrailing: CGFloat = 0
        var spaceTop:CGFloat = 0, spaceBottom:CGFloat = 0
        if let nav = navigationController {
            // Remove the heights of the navigation bar and toolbar
            spaceTop += nav.navigationBar.bounds.height
            spaceBottom += isToolbarRequired ? nav.toolbar.bounds.height : 0
        }
        if #available(iOS 11.0, *) {
            // Takes into account the safe area insets
            if let root = UIApplication.shared.keyWindow?.rootViewController {
                spaceTop += orientation.isLandscape ? 0 : root.view.safeAreaInsets.top
                spaceBottom += isToolbarRequired ? root.view.safeAreaInsets.bottom : 0
                spaceLeading += orientation.isLandscape ? 0 : root.view.safeAreaInsets.left
                spaceTrailing += orientation.isLandscape ? 0 : root.view.safeAreaInsets.right
            }
        }
        
        // Horizontal constraints
        let imageWidth = image.size.width * scrollView.zoomScale
        let horizontalSpaceAvailable = view.bounds.width - (spaceLeading + imageWidth + spaceTrailing)
        spaceLeading += horizontalSpaceAvailable/2
        spaceTrailing += horizontalSpaceAvailable/2
        
        // Vertical constraints
        let imageHeight = image.size.height * scrollView.zoomScale
        var verticalSpaceAvailable = view.bounds.height - (spaceTop + imageHeight + spaceBottom)
        let descHeight = imageData.comment.isEmpty ? 0 : descContainerHeight.constant + 8
        if isToolbarRequired {
            if verticalSpaceAvailable >= descHeight {
                // Centre image between navigation bar and description/toolbar
                verticalSpaceAvailable -= descHeight
                spaceTop += verticalSpaceAvailable/2
                spaceBottom += descHeight + verticalSpaceAvailable/2
            } else if verticalSpaceAvailable >= 0 {
                // Keep image glued to navigation bar
                spaceBottom += verticalSpaceAvailable
            } else {
                // Centre image between navigation bar and toolbar
                spaceTop += verticalSpaceAvailable/2
                spaceBottom += verticalSpaceAvailable/2
            }
        } else {
            if verticalSpaceAvailable >= descHeight {
                // Centre image between navigation bar and bottom
                verticalSpaceAvailable -= descHeight
                spaceTop += verticalSpaceAvailable/2
                spaceBottom += descHeight + verticalSpaceAvailable/2
            } else if verticalSpaceAvailable >= 0 {
                // Keep image glued to navigation bar
                spaceBottom += verticalSpaceAvailable
            } else if -verticalSpaceAvailable < spaceTop {
                // Keep image glued to bottom
                spaceTop += verticalSpaceAvailable
            } else {
                // Centre image between top and bottom
                verticalSpaceAvailable += spaceTop
                spaceTop = verticalSpaceAvailable/2
                spaceBottom = verticalSpaceAvailable/2
            }
        }
        
        // Update image view position
//        var frameToCenter = imageView.frame
//        frameToCenter.origin.x = max(0, spaceLeading)
//        frameToCenter.origin.y = max(0, spaceTop)
//        imageView.frame = frameToCenter
        
        // Update constraints
        imageViewLeadingConstraint.constant = max(0, spaceLeading)
        imageViewTrailingConstraint.constant = max(0, spaceTrailing)
        imageViewTopConstraint.constant = max(0, spaceTop)
        imageViewBottomConstraint.constant = max(0, spaceBottom)
        debugPrint("=> updateImageViewConstraints —> leading: \(round(imageViewLeadingConstraint.constant)), trailing: \(round(imageViewTrailingConstraint.constant)) (\(round(horizontalSpaceAvailable))), top: \(round(imageViewTopConstraint.constant)), bot: \(round(imageViewBottomConstraint.constant)) (\(round(verticalSpaceAvailable)))")

        // Center image if necessary
        self.centerImageView()
    }
    
    private func centerImageView() {
        // Should we center the image horizontally?
        var offset = scrollView.contentOffset
//        if imageViewLeadingConstraint.constant > 0,
//           imageViewTrailingConstraint.constant > 0,
//           offset.x != 0 {
//            // Image height smaller than screen height
//            offset.x = 0
//            debugPrint("=> centerImageView: offset.x -> 0")
//            scrollView.setContentOffset(offset, animated: false)
//        }

        // Should we center the image vertically?
        if imageViewTopConstraint.constant > 0,
           imageViewBottomConstraint.constant > 0,
           offset.y != 0 {
            // Image width smaller than screen width
            offset.y = 0
            debugPrint("=> centerImageView: offset.y -> 0")
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    
    // MARK: - Image Metadata
    func didTapView() {
        // Remember that user did tap the view
        userDidTapView = true
        
        // Show/hide the description
        if imageData.comment.isEmpty {
            descContainer.isHidden = true
        } else {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
        }
        
        // Keep image in place when its size is greater than the screen size
        guard let nav = navigationController else { return }
        var offset = scrollView.contentOffset
        if imageViewTopConstraint.constant == 0,
           imageViewBottomConstraint.constant == 0,
           scrollView.zoomScale > scrollView.minimumZoomScale {
            // Add/subtract navigation bar height
            offset.y -= nav.navigationBar.bounds.height * (nav.isNavigationBarHidden ? 1 : -1)
            if UIDevice.current.userInterfaceIdiom == .pad {
                offset.y -= statusBarHeight * (nav.isNavigationBarHidden ? 1 : -1)
            } else {
                if #available(iOS 14, *) {
//                    offset.y -= statusBarHeight * (nav.isNavigationBarHidden ? 1 : -1)
                }
                else if #available(iOS 13, *) {
                    let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
                    if orientation.isPortrait {
                        offset.y -= statusBarHeight * (nav.isNavigationBarHidden ? 1 : -1)
                    }
                } else {
                    offset.y -= statusBarHeight * (nav.isNavigationBarHidden ? 1 : -1)
                }
            }
            scrollView.setContentOffset(offset, animated: false)
        }
    }
    
    func updateImageMetadata(with data:PiwigoImageData) {
        // Update Piwigo data
        imageData = data

        // Should we update the image description?
        if descTextView.text != data.comment {
            configDescription {
                self.centerImageView()
            }
        }
    }

    private func configDescription(completion: @escaping () -> Void) {
        // Should we present a description?
        if imageData.comment.isEmpty {
            // Hide the description view
            descTextView.text = ""
            descContainer.isHidden = true
            completion()
        }
        
        // Configure the description view
        descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
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
            descContainerOffset.constant = -8         // Shift description view up by 8 pixels
            descContainerWidth.constant = size.width   // Add space taken by corners
            descContainerHeight.constant = size.height
            descContainer.layer.cornerRadius = cornerRadius
            descContainer.layer.masksToBounds = true
        }
        else {
            // Several lines are required -> full width for minimising height
            descContainerOffset.constant = 0                // Glue the description to the toolbar
            descContainer.layer.cornerRadius = 0            // Disable rounded corner in case user added text
            descContainer.layer.masksToBounds = false
            descContainerWidth.constant = safeAreaWidth
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
                descContainerHeight.constant = min(maxHeight, height)
            }
            else {
                descContainerHeight.constant = height
            }
        }
        completion()
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
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension ImagePreviewViewController: UIScrollViewDelegate
{
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        debugPrint("=> didScroll: \(round(scrollView.contentOffset.x)), \(round(scrollView.contentOffset.y))")
        centerImageView()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateImageViewConstraints()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // Limit the zoom scale
        if scale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        } else if scale > scrollView.maximumZoomScale {
            scrollView.zoomScale = scrollView.maximumZoomScale
        }
        
        // Should we quit the preview mode?
        if (scale == scrollView.minimumZoomScale) &&
            (previousScale == scrollView.minimumZoomScale) {
            // The user scaled down twice the image => back to collection of images
            let name = NSNotification.Name(rawValue: kPiwigoNotificationPinchedImage)
            NotificationCenter.default.post(name: name, object: nil)
        } else {
            previousScale = scale
        }
    }
}
