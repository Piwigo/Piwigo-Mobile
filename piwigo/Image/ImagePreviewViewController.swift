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

class ImagePreviewViewController: UIViewController
{
    var imageIndex = 0
    var imageData: Image!
    
    var imageURL: URL?
    var video: Video?
    let playbackController = PlaybackController.shared
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var videoContainerLeft: NSLayoutConstraint!
    @IBOutlet weak var videoContainerRight: NSLayoutConstraint!
    @IBOutlet weak var videoContainerTop: NSLayoutConstraint!
    @IBOutlet weak var videoContainerBottom: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var progressView: PieProgressView!
    
    private var serverID = ""
    private let placeHolder = UIImage(named: "placeholderImage")!
    private var userDidTapOnce: Bool = false        // True if the user did tap the view
    private var userDidRotateDevice: Bool = false   // True if the user did rotate the device
    private var startingZoomScale = CGFloat(1)      // To remember the scale before starting zooming
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retrieve server ID
        serverID = imageData.server?.uuid ?? ""
        if serverID.isEmpty {
            // Configure the description view before layouting subviews
            descContainer.configDescription(with: imageData.comment) {
                self.configScrollView(with: self.placeHolder)
            }
            return
        }
        
        // Thumbnail image should be available in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        let cacheDir = DataDirectories.shared.cacheDirectory.appendingPathComponent(serverID)
        let fileURL = cacheDir.appendingPathComponent(thumbSize.path)
            .appendingPathComponent(String(imageData.pwgID))
        
        // Configure the description view before layouting subviews
        let thumbImage = UIImage(contentsOfFile: fileURL.path) ?? placeHolder
        descContainer.configDescription(with: imageData.comment) {
            self.configScrollView(with: thumbImage)
        }
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.setDescriptionColor()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Previewed image
        imageView.layoutIfNeeded()   // Ensure imageView in its final size
        let cellSize = self.scrollView.bounds.size
        let scale = self.scrollView.traitCollection.displayScale
        var previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        if imageData.isVideo, previewSize == .fullRes {
            previewSize = .xxLarge
        }
        imageURL = ImageUtilities.getURL(imageData, ofMinSize: previewSize)
        if let imageURL = imageURL {
            ImageSession.shared.getImage(withID: self.imageData.pwgID, ofSize: previewSize, atURL: imageURL,
                                         fromServer: self.serverID, fileSize: self.imageData.fileSize,
                                         placeHolder: self.placeHolder) { fractionCompleted in
                DispatchQueue.main.async {
                    self.progressView.progress = fractionCompleted
                }
            } completion: { cachedImageURL in
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, scale: scale)
                if cachedImage == self.placeHolder {
                    // Image in cache is not appropriate
                    try? FileManager.default.removeItem(at: imageURL)
                }
                DispatchQueue.main.async {
                    self.configImage(cachedImage)
                }
            } failure: { _ in }
        }
        
        // Show/hide the description
        guard let comment = imageData?.comment,
              comment.string.isEmpty == false else {
            descContainer.isHidden = true
            return
        }
        descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
    }
    
    func configImage(_ image: UIImage) {
        // Set image view content
        self.configScrollView(with: image)
        // Layout subviews
        self.view.setNeedsLayout()  // Required by iOS 12
        self.view.layoutIfNeeded()
        
        // Hide progress view
        self.progressView.isHidden = true
        
        // Initialise video player if needded
        if let video = video {
            // The video size is unknown at that point
            videoContainerLeft.constant = scrollView.contentInset.left
            videoContainerRight.constant = scrollView.contentInset.right
            videoContainerTop.constant = scrollView.contentInset.top
            videoContainerBottom.constant = scrollView.contentInset.bottom
            
            // Show video container and embed video player in it
            videoContainerView.isHidden = false
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if userDidTapOnce {
            userDidTapOnce = false
            return
        }
        
        // Configure scrollview after:
        /// - configuring the description view
        /// - loading the thumbnail image
        /// - loading the high-resolution image
        /// - rotating the device
        configScrollView()
        centerImageView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause video and remember selected mute option
        if let video = video {
            playbackController.pause(contentOfVideo: video, savingMuteOption: true)
        }
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
        // Remove video player coordinator
        if let video = video {
            playbackController.remove(contentOfVideo: video)
        }
    }
    
    
    // MARK: - Image Management
    private func configScrollView(with image: UIImage) {
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height
        //        debugPrint("••> imageView: \(image.size.width) x \(image.size.height)")
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
        
        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false
        
        // Don't adjust the insets when showing or hiding the navigation bar/toolbar
        scrollView.contentInset = .zero
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Define the zoom scale range
        let widthScale = view.bounds.size.width / image.size.width
        let heightScale = view.bounds.size.height / image.size.height
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(pwgImageSize.maxZoomScale, 4 * minScale)
        scrollView.zoomScale = minScale     // Will trigger the scrollViewDidZoom() method
        //        debugPrint("=> scrollView: \(scrollView.bounds.size.width) x \(scrollView.bounds.size.height), imageView: \(imageView.frame.size.width) x \(imageView.frame.size.height), minScale: \(minScale)")
    }
    
    private func centerImageView() {
        guard let image = imageView?.image else { return }
        
        // Determine the orientation of the device
        let orientation = getOrientation()
        
        // Determine if the toolbar is presented
        let isToolbarRequired = isToolbarRequired()
        
        // Determine the available spaces around the image
        var spaceLeading: CGFloat, spaceTrailing: CGFloat, spaceTop:CGFloat, spaceBottom:CGFloat
        (spaceLeading, spaceTrailing, spaceTop, spaceBottom) = initSpaces(for: orientation, isToolbarRequired: isToolbarRequired)
        
        // Horizontal constraints
        let imageWidth = image.size.width * scrollView.zoomScale
        let horizontalSpaceAvailable = view.bounds.width - (spaceLeading + imageWidth + spaceTrailing)
        spaceLeading += horizontalSpaceAvailable/2
        spaceTrailing += horizontalSpaceAvailable/2
        
        // Vertical constraints
        let imageHeight = image.size.height * scrollView.zoomScale
        let verticalSpaceAvailable = view.bounds.height - (spaceTop + imageHeight + spaceBottom)
        var descHeight: CGFloat = 0.0
        if let comment = imageData?.comment, comment.string.isEmpty == false {
            descHeight = descContainer.descHeight.constant + 8
        }
        (spaceTop, spaceBottom) = calcVertPosition(from: verticalSpaceAvailable, commentHeight: descHeight,
                                                   topSpace: spaceTop, bottomSpace: spaceBottom,
                                                   isToolbarRequired: isToolbarRequired)
        
        // Center image horizontally in scrollview
        scrollView.contentInset.left = max(0, spaceLeading)
        scrollView.contentInset.right = max(0, spaceTrailing)
        
        // Center image vertically  in scrollview
        scrollView.contentInset.top = max(0, spaceTop)
        scrollView.contentInset.bottom = max(0, spaceBottom)
    }
    
    func updateImageMetadata(with data: Image) {
        // Update image description
        descContainer.configDescription(with: data.comment) {
            self.view.layoutIfNeeded()
        }
    }

    
    // MARK: - Video Management
    func centerVideoView(ofSize size: CGSize) {
        // Determine the orientation of the device
        let orientation = getOrientation()
        
        // Determine if the toolbar is presented
        let isToolbarRequired = isToolbarRequired()

        // Determine the available spaces around the image
        var spaceLeading: CGFloat, spaceTrailing: CGFloat, spaceTop:CGFloat, spaceBottom:CGFloat
        (spaceLeading, spaceTrailing, spaceTop, spaceBottom) = initSpaces(for: orientation, isToolbarRequired: isToolbarRequired)
        
        // Determine scale factor
        let scale = min(view.bounds.width / size.width, view.bounds.height / size.height)
        let videoWidth = size.width * scale
        let videoHeight = size.height * scale

        // Horizontal constraints
        let horizontalSpaceAvailable = view.bounds.width - (spaceLeading + videoWidth + spaceTrailing)
        spaceLeading += horizontalSpaceAvailable/2
        spaceTrailing += horizontalSpaceAvailable/2
        
        // Vertical constraints
        let verticalSpaceAvailable = view.bounds.height - (spaceTop + videoHeight + spaceBottom)
        var descHeight: CGFloat = 0.0
        if let comment = imageData?.comment, comment.string.isEmpty == false {
            descHeight = descContainer.descHeight.constant + 8
        }
        (spaceTop, spaceBottom) = calcVertPosition(from: verticalSpaceAvailable, commentHeight: descHeight,
                                                   topSpace: spaceTop, bottomSpace: spaceBottom,
                                                   isToolbarRequired: isToolbarRequired)
        
        // Center video horizontally in scrollview
        videoContainerLeft.constant = max(0, spaceLeading)
        videoContainerRight.constant = max(0, spaceTrailing)
        
        // Center video vertically  in scrollview
        videoContainerTop.constant = max(0, spaceTop)
        videoContainerBottom.constant = max(0, spaceBottom)
//        debugPrint("••> video: left: \(max(0, spaceLeading)), right: \(max(0, spaceTrailing)), top \(max(0, spaceTop)), bottom: \(max(0, spaceBottom)) <")
    }
    
    // MARK: - Gestures Management
    func didTapOnce() {
        // Remember that user did tap the view
        userDidTapOnce = true
        
        // Show/hide the description
        guard let comment = imageData?.comment,
              comment.string.isEmpty == false else {
            descContainer.isHidden = true
            return
        }
        descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
    }
    
    func didTapTwice(_ gestureRecognizer: UIGestureRecognizer) {
        // Get current scale
        let scale = min(scrollView.zoomScale * 1.5, scrollView.maximumZoomScale)
        
        // Should we zoom in?
        if scale != scrollView.zoomScale {
            // Let's zoom in…
            let point = gestureRecognizer.location(in: imageView)
            let scrollSize = scrollView.frame.size
            let size = CGSize(width: scrollSize.width / scale,
                              height: scrollSize.height / scale)
            let origin = CGPoint(x: point.x - size.width / 2,
                                 y: point.y - size.height / 2)
            scrollView.zoom(to:CGRect(origin: origin, size: size), animated: true)
        }
        else {
            // Let's zoom out…
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }
    }
    
    func didRotateDevice() {
        // Remember that user did tap the view
        userDidRotateDevice = true
        
        // Should we update the description?
        if descContainer.descTextView.text.isEmpty {
            self.view.layoutIfNeeded()
        } else {
            descContainer.configDescription(with: imageData.comment) { [unowned self] in
                self.descContainer.setDescriptionColor()
                self.view.layoutIfNeeded()
            }
        }
        
        // Update video player bounds
        if let video = video,
           let playerViewController = playbackController.coordinator(for: video).playerViewControllerIfLoaded {
            centerVideoView(ofSize: playerViewController.videoBounds.size)
        }
    }
    
    
    // MARK: - Utilities
    private func getOrientation() -> UIInterfaceOrientation {
        let orientation: UIInterfaceOrientation
        if #available(iOS 14, *) {
            orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        return orientation
    }
    
    private func isToolbarRequired() -> Bool {
        var isToolbarRequired = false
        if let viewControllers = navigationController?.viewControllers.filter({ $0.isKind(of: ImageViewController.self)}),
           let vc = viewControllers.first as? ImageViewController {
            isToolbarRequired = vc.isToolbarRequired
        }
        return isToolbarRequired
    }
    
    private func initSpaces(for orientation: UIInterfaceOrientation, isToolbarRequired: Bool)
    -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var spaceLeading: CGFloat = 0, spaceTrailing: CGFloat = 0
        var spaceTop:CGFloat = 0, spaceBottom:CGFloat = 0
        
        // Takes into account the safe area insets
        if let root = topMostViewController()?.view?.window?.topMostViewController() {
            spaceTop += orientation.isLandscape ? 0 : root.view.safeAreaInsets.top
            spaceBottom += orientation.isLandscape ? 0 : isToolbarRequired ? root.view.safeAreaInsets.bottom : 0
            spaceLeading += root.view.safeAreaInsets.left
            spaceTrailing += root.view.safeAreaInsets.right
        }
        
        return (spaceLeading, spaceTrailing, spaceTop, spaceBottom)
    }
    
    private func calcVertPosition(from verticalSpace: CGFloat, commentHeight: CGFloat,
                                  topSpace: CGFloat, bottomSpace: CGFloat, isToolbarRequired: Bool)
    -> (spaceTop: CGFloat, spaceBottm: CGFloat) {
        // Initialisation
        var verticalSpaceAvailable = verticalSpace, descHeight = commentHeight
        var spaceTop = topSpace, spaceBottom = bottomSpace
        
        // With or without toolbar?
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
        return (spaceTop, spaceBottom)
    }
}


// MARK: - UIScrollViewDelegate Methods
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension ImagePreviewViewController: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // Zooming of the content in the scroll view is about to commence
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // Allows scrolling zoomed image
        scrollView.isScrollEnabled = true
        // Store zoom scale value before starting zooming
        startingZoomScale = scrollView.zoomScale
    }

    // The scroll view’s zoom factor changed
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale < 0.9 * scrollView.minimumZoomScale,
            startingZoomScale < 1.1 * scrollView.minimumZoomScale {
            dismiss(animated: true)
        } else {
            if imageData.isVideo {
                scrollView.zoomScale = min(scrollView.zoomScale, scrollView.minimumZoomScale)
            }
            centerImageView()
        }
    }

    // Zooming of the content in the scroll view completed
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // Limit the zoom scale
        if scrollView.zoomScale < 0.9 * scrollView.minimumZoomScale,
           startingZoomScale < 1.1 * scrollView.minimumZoomScale {
            dismiss(animated: true)
        } else if scale <= scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
            centerImageView()
        } else if scale > scrollView.maximumZoomScale {
            scrollView.zoomScale = scrollView.maximumZoomScale
            centerImageView()
        }
    }
}
