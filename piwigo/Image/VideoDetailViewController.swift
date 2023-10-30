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
    var imageIndex = 0
    var imageData: Image!
    var video: Video?
    var videoSize: CGSize?
    let playbackController = PlaybackController.shared
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var placeHolderView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var videoContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var videoControls: VideoControlsView!
    
    private let placeHolder = UIImage(named: "unknownImage")!

    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Thumbnail image should be available in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        placeHolderView.image = imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder
        setPlaceHolderViewFrame()

        // Initialise videoContainerView size with placeHolder size
        configVideoViews()
        
        // Initialise video controls
        videoControls.isHidden = true
        videoControls.videoControlsDelegate = self

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.applyColorPalette()
        videoControls.applyColorPalette()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Initialise video player
        if let video = video {
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
        
        // Configure the description view before layouting subviews
        descContainer.config(with: imageData.comment, inViewController: self, forVideo: true)

        // Hide/show the description and controls views with the navigation bar
        updateDescriptionControlsVisibility()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Animate change of view size and reposition video
        coordinator.animate(alongsideTransition: { [self] context in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(with: imageData.comment, inViewController: self, forVideo: true)
                descContainer.applyColorPalette()
            }
            
            // Set place holder view frame for this orientation
            setPlaceHolderViewFrame()
            
            // Update scale, insets and offsets
            if videoSize != nil {
                configScrollView()
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
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
    
    
    // MARK: - Video Management
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
    
    func configVideoViews() {
        // Set video container view size
        videoContainerView.frame.size = videoSize ?? placeHolderView.frame.size
        videoContainerWidthConstraint.constant = videoSize?.width ?? placeHolderView.frame.width
        videoContainerHeightConstraint.constant = videoSize?.height ?? placeHolderView.frame.height

        // Set scroll view content size
        scrollView.contentSize = videoSize ?? placeHolderView.frame.size

        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false

        // Set scroll view scale and range
        if videoSize != nil {
            // Set zoom scale and scroll view
            configScrollView()
        }
    }

    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    private func configScrollView() {
        // Initialisation
        scrollView.isPagingEnabled = false    // Do not stop on multiples of the scroll view’s bounds
        scrollView.contentInsetAdjustmentBehavior = .never  // Do not add/remove safe area insets

        // Calc new zoom scale range
        scrollView.bounds = view.bounds
        let widthScale = view.bounds.size.width / videoContainerView.bounds.size.width
        let heightScale = view.bounds.size.height / videoContainerView.bounds.size.height
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
        debugPrint("••> Did reset scrollView scale: ")
        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale); soon: x\(zoomFactor)")
        debugPrint("    Offset: \(scrollView.contentOffset)")
        debugPrint("    Inset : \(scrollView.contentInset)")

        // Next line calls scrollViewDidZoom() if zoomScale has changed
        let newZoomScale = minScale * zoomFactor
        if scrollView.zoomScale != newZoomScale {
            scrollView.zoomScale = newZoomScale
        } else {
            updateScrollViewInset()
        }
    }
    
    /// Called when the PlayerViewController is ready
    private func updateScrollViewInset() {
        // Reset insets
        scrollView.contentInset = UIEdgeInsets.zero
        
        // Center video horizontally in scrollview
        let videoWidth = videoContainerView.bounds.size.width * scrollView.zoomScale
        let horizontalSpace = max(0, (view.bounds.width - videoWidth) / 2)
        scrollView.contentInset.left = horizontalSpace
        scrollView.contentInset.right = horizontalSpace
        if horizontalSpace > 0 {
            scrollView.contentOffset.x = -horizontalSpace
        }

        // Center image vertically  in scrollview
        let videoHeight = videoContainerView.bounds.size.height * scrollView.zoomScale
        let verticalSpace = max(0, (view.bounds.height - videoHeight) / 2 )
        scrollView.contentInset.top = verticalSpace
        scrollView.contentInset.bottom = verticalSpace
        if verticalSpace > 0 {
            scrollView.contentOffset.y = -verticalSpace
        }

        // Show video with controls
        videoContainerView.isHidden = false
        videoControls.isHidden = navigationController?.isNavigationBarHidden ?? false
        debugPrint("••> Did updateScrollViewInset: ")
        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
        debugPrint("    Offset: \(scrollView.contentOffset)")
        debugPrint("    Inset : \(scrollView.contentInset)")
    }

    func updateImageMetadata(with data: Image) {
        // Update image description
        descContainer.config(with: data.comment, inViewController: self, forVideo: true)
    }

    
    // MARK: - Gestures Management
    func updateDescriptionControlsVisibility() {
        // Hide/show the description and controls views with the navigation bar
        let state = navigationController?.isNavigationBarHidden ?? false
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = state
        }
        if videoContainerView.isHidden == false {
            videoControls.isHidden = state
        }
    }
    
    func didTapTwice(_ gestureRecognizer: UIGestureRecognizer) {
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
extension VideoDetailViewController: VideoControlsDelegate
{
    func didChangeTime(value: Double) {
        if let video = video {
            playbackController.seek(contentOfVideo: video, toTimeFraction: value)
        }
    }
}
