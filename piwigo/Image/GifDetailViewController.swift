//
//  GifDetailViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import ImageIO
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit

class GifDetailViewController: UIViewController
{
    var indexPath = IndexPath(item: 0, section: 0)
    var imageData: Image!
    var imageURL: URL?

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var progressView: PieProgressView!

    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)

    // Variables used to start/stop the GIF animation
    // The animation is performed by ImageIO which decodes frames on the fly,
    // i.e. without loading all frames in memory.
    private var isAnimating = false
    private var shouldStopAnimation = false

    // Variable introduced to cope with iOS not updating view bounds
    // upon device rotation of preloaded page views
    private lazy var viewSize: CGSize =  {
        let size = UIApplication.shared.connectedScenes
            .filter({$0.session.role == .windowApplication})
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow})
            .first?.bounds.size
        return size ?? view.bounds.size
    }()


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Load and animate GIF image (resume download if needed)
        loadAndAnimateGifImage()

        // Configure the description view before layouting subviews
        descContainer.config(withImage: imageData, inViewController: self, forVideo: false)

        // Hide/show the description view with the navigation bar
        updateDescriptionVisibility()

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Should this image be also displayed on the external screen?
        self.setExternalImageView()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Animate change of view size and reposition image
        coordinator.animate(alongsideTransition: { [self] _ in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(withImage: imageData, inViewController: self, forVideo: false)
                descContainer.applyColorPalette(withImage: imageData)
            }

            // Update scale, insets and offsets
            self.viewSize = size
            configScrollView()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop the animation performed by ImageIO
        shouldStopAnimation = true
    }

    override func didReceiveMemoryWarning() {
        // Stop the animation and replace the animated image by the static thumbnail
        // (there is no animated version of lower resolution)
        shouldStopAnimation = true
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        self.setImageView(with: self.imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
    }

    deinit {
        // Stop the animation performed by ImageIO
        shouldStopAnimation = true

        // Unregister all observers
        imageData = nil
        imageView.image = nil
        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - GIF Image Management
    /// Piwigo servers only produce static derivatives of GIF images.
    /// So the animation can only be obtained from the full resolution image file,
    /// and this file must be decoded as a GIF file i.e. w/o downsampling.
    @MainActor
    private func loadAndAnimateGifImage() {
        // Check if we already have the full-resolution image file in cache
        if let cacheURL = imageData.cacheURL(ofSize: .fullRes),
           FileManager.default.fileExists(atPath: cacheURL.path) {
            // Animate full-resolution image file in cache
            startAnimation(withFileAt: cacheURL)
        } else {
            // Display thumbnail image which should be in cache
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            self.setImageView(with: self.imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)

            // Download full-resolution image
            imageURL = ImageUtilities.getPiwigoURL(self.imageData, ofMinSize: .fullRes)
            if let imageURL = self.imageURL {
                Task {
                    await ImageDownloader.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .image, atURL: imageURL,
                                                          fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            self.updateProgressView(with: fractionCompleted)
                        }
                    }
                    completion: { [weak self] cachedImageURL in
                        DispatchQueue.main.async { [weak self] in
                            guard let self else { return }
                            // Hide progress view
                            self.progressView.isHidden = true
                            // Replace thumbnail with animated full-resolution image
                            self.startAnimation(withFileAt: cachedImageURL)
                        }
                    }
                    failure: { _ in }
                }
            }
        }
    }

    private func updateProgressView(with fractionCompleted: Float) {
        DispatchQueue.main.async { [self] in
            // Show download progress
            self.progressView.progress = fractionCompleted
        }
    }

    /// ImageIO delivers the decoded frames on the main queue and honours the frame delays
    /// and loop count stored in the GIF file. Setting 'stop' ends the animation.
    @MainActor
    private func startAnimation(withFileAt fileURL: URL) {
        // NOP if the animation is already running
        if isAnimating { return }

        // Animate the GIF image, frame by frame
        shouldStopAnimation = false
        let status = CGAnimateImageAtURLWithBlock(fileURL as CFURL, nil) { [weak self] _, cgImage, stop in
            guard let self else {
                stop.pointee = true
                return
            }
            if self.shouldStopAnimation {
                stop.pointee = true
                self.isAnimating = false
                return
            }
            self.display(frame: UIImage(cgImage: cgImage))
        }
        isAnimating = (status == noErr)

        // Display the static image if the file could not be animated
        // (e.g. single-frame GIF or corrupted file)
        if isAnimating == false,
           let staticImage = UIImage(contentsOfFile: fileURL.path) {
            setImageView(with: staticImage)
        }
    }

    @MainActor
    private func display(frame image: UIImage) {
        // All frames have the size of the GIF canvas,
        // so the scroll view is only configured with the first frame
        if imageView.image?.size == image.size {
            imageView.image = image
        } else {
            setImageView(with: image)
        }
    }

    @MainActor
    private func setImageView(with image: UIImage) {
        // Set image view
        imageView.image = image
        imageView.frame.size = image.size
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height

        // Set scroll view content size
        scrollView.contentSize = image.size

        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false

        // Set scroll view scale and range
        configScrollView()
    }

    /*
     This method calculates the zoom scale for the scroll view.
     A zoom scale of 1 indicates that the content displays at its normal size.
     A zoom scale of less than 1 shows a zoomed-out version of the content,
     and a zoom scale greater than 1 shows the content zoomed in.
     */
    func configScrollView() {
        // Initialisation
        guard let imageSize = imageView?.image?.size else { return }
        scrollView.isPagingEnabled = false    // Do not stop on multiples of the scroll view’s bounds
        scrollView.contentInsetAdjustmentBehavior = .never  // Do not add/remove safe area insets

        // Calc new zoom scale range
        scrollView.bounds = view.bounds
        let widthScale = viewSize.width / imageSize.width
        let heightScale = viewSize.height / imageSize.height
        let minScale = min(widthScale, heightScale)
        let maxScale = max(widthScale, heightScale)

        // Calc zoom scale change
        var zoomFactor = 1.0
        if scrollView.zoomScale > 1e-6, scrollView.minimumZoomScale > 1e-6 {
            zoomFactor = scrollView.zoomScale / scrollView.minimumZoomScale
        }

        // Set zoom scale range
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(maxScale, 1)

        // Next line calls scrollViewDidZoom() if zoomScale has changed
        let newZoomScale = minScale * zoomFactor
        if scrollView.zoomScale != newZoomScale {
            scrollView.zoomScale = newZoomScale
        } else {
            updateScrollViewInset()
        }
    }

    private func updateScrollViewInset() {
        guard let imageSize = imageView?.image?.size,
              imageSize.width != 0, imageSize.height != 0,
              scrollView.zoomScale != 0
        else { return }

        // Center image horizontally
        let imageWidth: CGFloat = imageSize.width * scrollView.zoomScale
        let leftWidth: CGFloat = (viewSize.width - imageWidth) / 2
        let horizontalSpace = max(0, leftWidth).rounded(.towardZero)
        scrollView.contentInset.left = horizontalSpace
        scrollView.contentInset.right = horizontalSpace
        if horizontalSpace > 0 {
            scrollView.contentOffset.x = -horizontalSpace
        }

        // Center image vertically
        let imageHeight: CGFloat = imageSize.height * scrollView.zoomScale
        let leftHeight: CGFloat = (viewSize.height - imageHeight) / 2
        let verticalSpace = max(0, leftHeight).rounded(.towardZero)
        scrollView.contentInset.top = verticalSpace
        scrollView.contentInset.bottom = verticalSpace
        if verticalSpace > 0 {
            scrollView.contentOffset.y = -verticalSpace
        }
    }

    func updateImageMetadata(with imageData: Image) {
        // Update image description
        descContainer.config(withImage: imageData, inViewController: self, forVideo: false)
    }


    // MARK: - Gestures Management
    func updateDescriptionVisibility() {
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


    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Apply changes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Configure the description view before layouting subviews
            self.descContainer.config(withImage: self.imageData, inViewController: self, forVideo: false)
        }
    }


    // MARK: - External Image Management
    @MainActor
    private func setExternalImageView() {
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
            imageVC.configImage()
        }
        else {
            // Create external display view controller
            let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
            guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController
            else { preconditionFailure("Could not load ExternalDisplayViewController") }
            imageVC.imageData = imageData

            // Create window and make it visible
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = imageVC
            sceneDelegate.initExternalDisplay(with: window)
        }
    }
}


// MARK: - UIScrollViewDelegate Methods
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension GifDetailViewController: UIScrollViewDelegate
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
            return
        }

        // Hide navigation bar, toolbar and description if needed
        if navigationController?.isNavigationBarHidden == false,
           scrollView.zoomScale > scrollView.minimumZoomScale {
            if let imageVC = parent?.parent as? ImageViewController {
                imageVC.didTapOnce()
            }
        }

        // Keep image centred
        updateScrollViewInset()
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
