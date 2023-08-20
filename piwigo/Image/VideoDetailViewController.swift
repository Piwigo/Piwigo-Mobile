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
    let playbackController = PlaybackController.shared
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var placeHolderView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var videoContainerWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    
    private var serverID = ""
    private let placeHolder = UIImage(named: "placeholderImage")!
    
    // Variable used to know when the scale should be calculated
    private var shouldSetZoomScale: Bool = true

    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Thumbnail image should be available in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        setPlaceHolderView(with: imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)

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
        
        // Initialise video player
        if let video = video {
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
        
        // Configure the description view before layouting subviews
        descContainer.configDescription(with: imageData.comment, inViewController: self)
        
        // Hide/show the description view with the navigation bar
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
        }
        
        // Set colors, fonts, etc.
        applyColorPalette()
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [self] context in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.configDescription(with: imageData.comment, inViewController: self)
                descContainer.setDescriptionColor()
            }

            // Update scale, insets and offsets
    //        let xOffset = (scrollView.contentInset.left + scrollView.contentOffset.x) / scrollView.bounds.width
    //        let yOffset = (scrollView.contentInset.top + scrollView.contentOffset.y) / scrollView.bounds.width

    //        debugPrint("••> Did start device rotation: ")
    //        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
    //        debugPrint("    Offset: \(scrollView.contentOffset) i.e. (\(xOffset), \(yOffset))")
    //        debugPrint("    Inset : \(scrollView.contentInset)")
            
            shouldSetZoomScale = true
            configScrollView()

    //        let xNewOffset = xOffset * scrollView.bounds.width
    //        let yNewOffset = yOffset * scrollView.bounds.height
    //        scrollView.contentOffset.x += xNewOffset
    //        scrollView.contentOffset.y += yNewOffset

    //        debugPrint("••> Did finish device rotation: ")
    //        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
    //        debugPrint("    Offset: \(scrollView.contentOffset) i.e. (\(xNewOffset), \(yNewOffset))")
    //        debugPrint("    Inset : \(scrollView.contentInset)")
        })
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
    
    
    // MARK: - Video Management
    private func setPlaceHolderView(with image: UIImage) {
        // Set image
        placeHolderView.image = image

        // Calc scale for displaying it fullscreen
        let widthScale = view.bounds.size.width / image.size.width
        let heightScale = view.bounds.size.height / image.size.height
        let scale = min(widthScale, heightScale)

        // Center image on screen
        let imageWidth = image.size.width * scale
        let horizontalSpace = max(0, (view.bounds.width - imageWidth) / 2)
        let imageHeight = image.size.height * scale
        let verticalSpace = max(0, (view.bounds.height - imageHeight) / 2)
        placeHolderView.frame = CGRect(x: horizontalSpace, y: verticalSpace,
                                       width: imageWidth, height: imageHeight)
        
        // Initialise videoContainerView dimensions
        videoContainerView.frame = placeHolderView.frame
        videoContainerWidthConstraint.constant = imageWidth
        videoContainerHeightConstraint.constant = imageHeight
    }

    func setVideoContainerViewSize(_ size: CGSize) {
        // Set video container view size
        videoContainerView.frame.size = size
        videoContainerWidthConstraint.constant = size.width
        videoContainerHeightConstraint.constant = size.height

        // Set scroll view content size
        scrollView.contentSize = size

        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false

        // Set scroll view scale and range
        shouldSetZoomScale = true
        configScrollView()
    }

    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    private func configScrollView() {
        // Initialisation
        scrollView.isPagingEnabled = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // Define the zoom scale range
        scrollView.bounds = view.bounds
        let widthScale = view.bounds.size.width / videoContainerView.bounds.size.width
        let heightScale = view.bounds.size.height / videoContainerView.bounds.size.height
        let minScale = min(widthScale, heightScale)
        let oldZoomScale = scrollView.zoomScale
        let oldZoomMinimumScale = scrollView.minimumZoomScale == 0 ? oldZoomScale : scrollView.minimumZoomScale

        // Did we load a new image?
        if shouldSetZoomScale {
            // Image just loaded, set zoom scale range
            scrollView.minimumZoomScale = minScale
            scrollView.maximumZoomScale = max(pwgImageSize.maxZoomScale, 4 * minScale)
            debugPrint("••> Did reset scrollView scale: ")
            debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
            debugPrint("    Offset: \(scrollView.contentOffset)")
            debugPrint("    Inset : \(scrollView.contentInset)")
            // Next line calls scrollViewDidZoom() if zoomScale scale has changed
            scrollView.zoomScale *= minScale / oldZoomMinimumScale
            shouldSetZoomScale = false
        } else {
            debugPrint("••> Will change scrollView scale: ")
            debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
            debugPrint("    Offset: \(scrollView.contentOffset)")
            debugPrint("    Inset : \(scrollView.contentInset)")
            // Next line calls scrollViewDidZoom() if zoomScale scale has changed
            scrollView.zoomScale = oldZoomScale / oldZoomMinimumScale * minScale
        }
        if scrollView.zoomScale == oldZoomScale {
            updateScrollViewInset()
        }
    }
    
    /// Called when the PlayerViewController is ready
    func updateScrollViewInset() {
        // Reset insets
        scrollView.contentInset = UIEdgeInsets.zero
        
        // Center video horizontally in scrollview
        let videoWidth = videoContainerView.bounds.size.width * scrollView.zoomScale
        let horizontalSpace = max(0, (view.bounds.width - videoWidth) / 2)
        if scrollView.contentInset.left != horizontalSpace {
            scrollView.contentInset.left = horizontalSpace
            scrollView.contentInset.right = horizontalSpace
        }
        
        // Center image vertically  in scrollview
        let videoHeight = videoContainerView.bounds.size.height * scrollView.zoomScale
        let verticalSpace = max(0, (view.bounds.height - videoHeight) / 2 )
        if scrollView.contentInset.top != verticalSpace {
            scrollView.contentInset.top = verticalSpace
            scrollView.contentInset.bottom = verticalSpace
        }

        debugPrint("••> Did updateScrollViewInset: ")
        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale)")
        debugPrint("    Offset: \(scrollView.contentOffset)")
        debugPrint("    Inset : \(scrollView.contentInset)")
    }

    func updateImageMetadata(with data: Image) {
        // Update image description
        descContainer.configDescription(with: data.comment, inViewController: self)
    }
    
    
    // MARK: - Gestures Management
    func didTapOnce() {
        // Hide/show the description view with the navigation bar
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
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
        }
    }
}
