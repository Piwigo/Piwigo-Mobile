//
//  VideoDetailViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import AVKit
import UIKit
import piwigoKit

class VideoDetailViewController: UIViewController
{
    var user: User!
    var indexPath = IndexPath(item: 0, section: 0)
    var imageData: Image! {
        didSet {
            video = imageData.video
        }
    }
    var video: Video?
    let playbackController = PlaybackController.shared
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var placeHolderView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var videoContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var videoControls: VideoControlsView!
    @IBOutlet weak var videoAirplay: UIImageView!
    
    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Thumbnail image should be available in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        placeHolderView.image = imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder
        setPlaceHolderViewFrame()
        
        // Initialise videoContainerView size with placeHolder size
        configVideoViews()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.applyColorPalette(withImage: imageData)
        videoControls.applyColorPalette()
        videoAirplay.tintColor = PwgColor.text
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Initialise video controls delegate
        videoControls.videoControlsDelegate = self
        
        // Initialise video player if displayed on device
        if AppVars.shared.inSingleDisplayMode, let video = video {
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
        
        // Configure the description view before layouting subviews
        descContainer.config(withImage: imageData, inViewController: self, forVideo: true)
        
        // Hide/show the description and controls views with the navigation bar
        updateDescriptionControlsVisibility()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Should this video be also displayed on the external screen?
        self.configExternalVideoViews()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Animate change of view size and reposition video
        coordinator.animate(alongsideTransition: { [self] _ in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(withImage: imageData, inViewController: self, forVideo: true)
                descContainer.applyColorPalette(withImage: imageData)
            }
            
            // Set place holder view frame for this orientation
            setPlaceHolderViewFrame()
            
            // Update scale, insets and offsets
            if let size = video?.frameSize {
                configScrollView(withSize: size)
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Show image before beginning transition
        placeHolderView.isHidden = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Remove video player
        if let video = video {
            playbackController.remove(contentOfVideo: video)
        }
    }
    
    deinit {
        // Release memory
        if let video = video {
            playbackController.delete(video: video)
        }
        
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Video Management
    @MainActor
    private func setPlaceHolderViewFrame() {
        // Check input
        guard let imageSize = placeHolderView.image?.size
        else { return }
        
        // Calc scale for displaying it fullscreen
        let widthScale = view.bounds.size.width / imageSize.width
        let heightScale = view.bounds.size.height / imageSize.height
        let scale = min(widthScale, heightScale)
        
        // Center image on screen
        let imageWidth = CGFloat(imageSize.width * scale)
        let horizontalSpace = max(0, (CGFloat(view.bounds.width) - imageWidth) / 2)
        let imageHeight = CGFloat(imageSize.height * scale)
        let verticalSpace: CGFloat = max(0, (CGFloat(view.bounds.height) - imageHeight) / 2)
        placeHolderView.frame = CGRect(x: horizontalSpace, y: verticalSpace,
                                       width: imageWidth, height: imageHeight)
    }
    
    @MainActor
    func configVideoViews() {
        // Initialisation
        scrollView.bounds = view.bounds
        scrollView.isPagingEnabled = false    // Do not stop on multiples of the scroll view’s bounds
        scrollView.contentInsetAdjustmentBehavior = .never  // Do not add/remove safe area insets
        scrollView.contentSize = video?.frameSize ?? placeHolderView.frame.size
        
        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false
        
        // Don't display video if screen mirroring is enabled
        guard AppVars.shared.inSingleDisplayMode else {
            placeHolderView.layer.opacity = 0.3
            videoContainerView.isHidden = true
            videoAirplay.isHidden = false
            return
        }
                
        // Video size available?
        guard let size = video?.frameSize
        else { return }
        
        // Set video container view size
        videoContainerView.frame.size = size
        videoContainerWidthConstraint.constant = size.width
        videoContainerHeightConstraint.constant = size.height

        // Set zoom scale and scroll view
        configScrollView(withSize: size)
    }
    
    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    @MainActor
    private func configScrollView(withSize size: CGSize) {
        // Calc new zoom scale range
        debugPrint("••> configScrollView withSize:\(view.bounds.size), \(videoContainerView.bounds.size), \(size)")
        let widthScale = view.bounds.size.width / size.width
        let heightScale = view.bounds.size.height / size.height
        let minScale = min(widthScale, heightScale)
        let maxScale = max(widthScale, heightScale)
        
        // Calc zoom scale change
        var zoomFactor = 1.0
        if scrollView.minimumZoomScale != 0 {
            zoomFactor = scrollView.zoomScale / scrollView.minimumZoomScale
        }
        
        // Set zoom scale range
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = 2 * maxScale
        //        debugPrint("••> Did reset scrollView scale: ")
        //        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale); soon: x\(zoomFactor)")
        //        debugPrint("    Offset: \(scrollView.contentOffset)")
        //        debugPrint("    Inset : \(scrollView.contentInset)")
        
        // Next line calls scrollViewDidZoom() if zoomScale has changed
        let newZoomScale = minScale * zoomFactor
        if scrollView.zoomScale != newZoomScale {
            scrollView.zoomScale = newZoomScale
        } else {
            updateScrollViewInset()
        }
    }
    
    /// Called when the PlayerViewController is ready
    @MainActor
    private func updateScrollViewInset() {
        // Reset insets
        scrollView.contentInset = UIEdgeInsets.zero
        
        // Center video horizontally in scrollview
        let videoWidth = videoContainerView.bounds.size.width * scrollView.zoomScale
        let horizontalSpace = max(0, (view.bounds.width - videoWidth) / 2.0)
        scrollView.contentInset.left = horizontalSpace
        scrollView.contentInset.right = horizontalSpace
        if horizontalSpace > 0 {
            scrollView.contentOffset.x = -horizontalSpace
        }
        
        // Center image vertically  in scrollview
        let videoHeight = videoContainerView.bounds.size.height * scrollView.zoomScale
        let verticalSpace = max(0, (view.bounds.height - videoHeight) / 2.0)
        scrollView.contentInset.top = verticalSpace
        scrollView.contentInset.bottom = verticalSpace
        if verticalSpace > 0 {
            scrollView.contentOffset.y = -verticalSpace
        }
        
        //        debugPrint("••> Did updateScrollViewInset: ")
        //        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
        //        debugPrint("    Offset: \(scrollView.contentOffset)")
        //        debugPrint("    Inset : \(scrollView.contentInset)")
    }
    
    func presentVideoContainer() {
        debugPrint("presentVideoContainer !!!!!!!!!!!!!!!")
        // Show/hide video according to situation
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Always show player controls
            self.videoControls.isHidden = self.navigationController?.isNavigationBarHidden ?? false
            
            // Show video unless it is presented on an external display
            self.videoContainerView.alpha = 0.0
            self.videoContainerView.isHidden = !AppVars.shared.inSingleDisplayMode
            
            // Animate appearance of video
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveLinear) { [weak self] in
                guard let self else { return }
                // Hide place holder image unless the video is presented on an external display
                self.placeHolderView.layer.opacity = AppVars.shared.inSingleDisplayMode ? 0.0 : 0.3
                // Show video unless it is presented on an external display
                self.videoContainerView.alpha = AppVars.shared.inSingleDisplayMode ? 1.0 : 0.0
            }
            completion: { [weak self] _ in
                guard let self else { return }
                // Hide place holder image unless the video is presented on an external display
                self.placeHolderView.isHidden = AppVars.shared.inSingleDisplayMode
                // Reset alpha channel for future use
                self.placeHolderView.layer.opacity = 1.0
                // Play video if requested
                if VideoVars.shared.autoPlayOnDevice, let video = self.video {
                    self.playbackController.play(contentOfVideo: video)
                }
            }
        }
    }
    
    @MainActor
    func updateImageMetadata(with imageData: Image) {
        // Update image description
        descContainer.config(withImage: imageData, inViewController: self, forVideo: true)
    }
    
    
    // MARK: - Gestures Management
    @MainActor
    func updateDescriptionControlsVisibility() {
        // Hide/show the description and controls views with the navigation bar
        let state = navigationController?.isNavigationBarHidden ?? false
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = state
        }
        if AppVars.shared.inSingleDisplayMode,
           videoContainerView.isHidden == false {
            videoControls.isHidden = state
        }
    }
    
    @MainActor
    func didTapTwice(_ gestureRecognizer: UIGestureRecognizer) {
        // Don't zoom video if it is presented on an external display
        if AppVars.shared.inSingleDisplayMode == false {
            return
        }
        
        // Get current scale
        let scale = min(scrollView.zoomScale * 1.5, scrollView.maximumZoomScale)
        
        // Should we zoom in?
        if scale != scrollView.zoomScale {
            // Let's zoom in…
            let point = gestureRecognizer.location(in: videoContainerView)
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
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Apply changes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Configure the description view before layouting subviews
            self.descContainer.config(withImage: self.imageData, inViewController: self, forVideo: true)
        }
    }
    
    
    // MARK: - External Video Management
    @MainActor
    private func configExternalVideoViews() {
        // Get scene role of external display
        var wantedRole: UISceneSession.Role!
        if #available(iOS 16.0, *) {
            wantedRole = .windowExternalDisplayNonInteractive
        } else {
            // Fallback on earlier versions
            wantedRole = .windowExternalDisplay
        }
        
        // Get scene of external display
        let scenes = UIApplication.shared.connectedScenes.filter({$0.session.role == wantedRole})
        guard let sceneDelegate = scenes.first?.delegate as? ExternalDisplaySceneDelegate,
              let windowScene = scenes.first as? UIWindowScene
        else { return }
        
        // Add image view to external screen
        if let imageVC = windowScene.rootViewController() as? ExternalDisplayViewController {
            // Configure external display view controller
            imageVC.imageData = imageData
            imageVC.videoDetailDelegate = self
            imageVC.configImage()
        }
        else {
            // Create external display view controller
            let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
            guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController
            else { preconditionFailure("Could not load ExternalDisplayViewController") }
            imageVC.imageData = imageData
            imageVC.videoDetailDelegate = self
            
            // Create window and make it visible
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = imageVC
            sceneDelegate.initExternalDisplay(with: window)
        }
    }
}


// MARK: - UIScrollViewDelegate Methods
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension VideoDetailViewController: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return videoContainerView
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
            // Hide navigation bar, toolbar and description if needed
            if navigationController?.isNavigationBarHidden == false,
               scrollView.zoomScale > scrollView.minimumZoomScale {
                if let imageVC = parent?.parent as? ImageViewController {
                    imageVC.didTapOnce()
                }
            }
            // Keep video centred
            updateScrollViewInset()
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
            updateScrollViewInset()
        } else if scale > scrollView.maximumZoomScale {
            scrollView.zoomScale = scrollView.maximumZoomScale
            updateScrollViewInset()
        } else {
            updateScrollViewInset()
        }
    }
}


// MARK: - VideoControlsDelegate Methods
extension VideoDetailViewController: @MainActor VideoControlsDelegate
{
    func didChangeTime(value: Double) {
        if let video = video {
            playbackController.seek(contentOfVideo: video, toTimeFraction: value)
        }
    }
}


// MARK: - VideoDetailDelegate Methods
extension VideoDetailViewController: VideoDetailDelegate
{
    @MainActor
    func config(currentTime: TimeInterval, duration: TimeInterval, delegate: any VideoControlsDelegate) {
        videoControls?.config(currentTime: currentTime, duration: duration)
    }
    
    @MainActor
    func setCurrentTime(_ value: Double) {
        videoControls?.setCurrentTime(value)
    }
}
