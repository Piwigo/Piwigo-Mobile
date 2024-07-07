//
//  ImageDetailViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 04/09/2021.
//

import UIKit
import piwigoKit

class ImageDetailViewController: UIViewController
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
        
    // Variable used to remember the position of the image on the screen
//    private var imagePosition = CGPoint(x: 0.5, y: 0.5)
    
    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)
    private var didRotateImage = false
    
    // Variable introduced to cope with iOS not updating view bounds
    // upon device rotation of preloaded page views
    private lazy var viewSize: CGSize =  {
        return view.bounds.size
    }()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get high-resolution image size
        let viewSize = view.bounds.size
        let scale = view.traitCollection.displayScale * pwgImageSize.maxZoomScale // to limit photo size in memory
        var previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        if imageData.isVideo, previewSize == .fullRes {
            previewSize = .xxLarge
        }
        
        // Check if we already have the high-resolution image in cache
        if let wantedImage = imageData.cachedThumbnail(ofSize: previewSize) {
            // Show high-resolution image in cache
            let cachedImage = ImageUtilities.downsample(image: wantedImage, to: viewSize, scale: scale)
            setImageView(with: cachedImage)
        } else {
            // Display thumbnail image which should be in cache
            let placeHolder = UIImage(named: "unknownImage")!
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            self.setImageView(with: self.imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)
            
            // Download high-resolution image
            imageURL = ImageUtilities.getURL(self.imageData, ofMinSize: previewSize)
            if let imageURL = self.imageURL {
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: previewSize, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                           placeHolder: placeHolder) { fractionCompleted in
                    DispatchQueue.main.async {
                        // Show download progress
                        self.progressView.progress = fractionCompleted
                    }
                } completion: { cachedImageURL in
                    let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: viewSize, scale: scale)
                    DispatchQueue.main.async {
                        // Hide progress view
                        self.progressView.isHidden = true
                        // Replace thumbnail with high-resolution image
                        self.setImageView(with: cachedImage)
                    }
                } failure: { _ in }
            }
        }
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.applyColorPalette()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Configure the description view before layouting subviews
        descContainer.config(with: imageData.comment, inViewController: self, forVideo: false)
        
        // Hide/show the description view with the navigation bar
        updateDescriptionVisibility()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Should this image be also displayed on the external screen?
        if #available(iOS 13.0, *) {
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Animate change of view size and reposition image
        coordinator.animate(alongsideTransition: { [self] context in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(with: imageData.comment, inViewController: self, forVideo: false)
                descContainer.applyColorPalette()
            }

            // Preloaded page views not updated as expected!
//            debugPrint("••> viewWillTransition: ")
//            debugPrint("    Size: \(size.width) x \(size.height)")
//            debugPrint("    Screen: \(view.bounds.width) x \(view.bounds.height)")

            // Update scale, insets and offsets
            self.viewSize = size
            configScrollView()
//            applyImagePositionInScrollView()
        })
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Image Management
    private func setImageView(with image: UIImage) {
        // Any change?
        if imageView.image?.size == image.size {
            return
        }

        // Set image view
        imageView.image = image
        imageView.frame.size = image.size
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height
//        debugPrint("••> imageView: \(image.size.width) x \(image.size.height)")
        
        // Set scroll view content size
        scrollView.contentSize = image.size

        // Prevents scrolling image at minimum scale
        // Will be unlocked when starting zooming
        scrollView.isScrollEnabled = false

        // Set scroll view scale and range
        configScrollView()
    }
    
    func rotateImageView(by angle: Double, completion: @escaping () -> Void) {
        // Download high-resolution image
        let viewSize = view.bounds.size
        let scale = view.traitCollection.displayScale * pwgImageSize.maxZoomScale // to limit photo size in memory
        let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        let placeHolder = imageView.image ?? UIImage(named: "unknownImage")!
        imageURL = ImageUtilities.getURL(self.imageData, ofMinSize: previewSize)
        if let imageURL = self.imageURL {
            PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: previewSize, atURL: imageURL,
                                       fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                       placeHolder: placeHolder) { fractionCompleted in
                DispatchQueue.main.async {
                    // Show download progress
                    self.progressView.progress = fractionCompleted
                }
            } completion: { cachedImageURL in
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: viewSize, scale: scale)
                DispatchQueue.main.async { [self] in
                    // Hide progress view
                    self.progressView.isHidden = true
                    
                    // Rotate image keeping it displayed in fullscreen
                    let aspectRatio = cachedImage.size.height / cachedImage.size.width
                    UIView.animate(withDuration: 0.5) { [self] in
                        let scale = scrollView.minimumZoomScale * aspectRatio
                        let angleRad = -angle * .pi / 180.0
                        imageView.transform = CGAffineTransform(rotationAngle: angleRad).scaledBy(x: scale, y: scale)
                    }
                    completion: { [self] _ in
                        // Reset image view with rotated image
                        didRotateImage = true
                        self.setImageView(with: cachedImage)

                        // Hide HUD
                        completion()
                    }
                }
            } failure: { _ in }
        }
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
//        debugPrint("••> Did reset scrollView scale: ")
//        debugPrint("    Scale: \(scrollView.minimumZoomScale) to \(scrollView.maximumZoomScale); now: \(scrollView.zoomScale); soon x \(zoomFactor)")
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
    
    private func updateScrollViewInset() {
        guard let imageSize = imageView?.image?.size,
              imageSize.width != 0, imageSize.height != 0,
              scrollView.zoomScale != 0
        else {
//            imagePosition = CGPoint.zero
            return
        }

        // Center image horizontally
        let imageWidth: CGFloat = imageSize.width * scrollView.zoomScale
        let leftWidth: CGFloat = (viewSize.width - imageWidth) / 2
        let horizontalSpace = max(0, leftWidth).rounded(.towardZero)
        scrollView.contentInset.left = horizontalSpace
        scrollView.contentInset.right = horizontalSpace
        if horizontalSpace > 0 {
            scrollView.contentOffset.x = -horizontalSpace
        } else if didRotateImage {
            scrollView.contentOffset.x = 0.0
        }
        
        // Center image vertically
        let imageHeight: CGFloat = imageSize.height * scrollView.zoomScale
        let leftHeight: CGFloat = (viewSize.height - imageHeight) / 2
        let verticalSpace = max(0, leftHeight).rounded(.towardZero)
        scrollView.contentInset.top = verticalSpace
        scrollView.contentInset.bottom = verticalSpace
        if verticalSpace > 0 {
            scrollView.contentOffset.y = -verticalSpace
        } else if didRotateImage {
            scrollView.contentOffset.y = 0.0
        }
        
        // Reset flag
         didRotateImage = false

        // For debugging
//        debugPrint("••> Did updateScrollViewInset: ")
//        debugPrint("    View: \(viewSize.width) x \(viewSize.height)")
//        debugPrint("    Offset: \(scrollView.contentOffset)")
//        debugPrint("    Inset : \(scrollView.contentInset)")

        // Remember position of image
//        calcImagePositionInScrollView()
    }
    
    func updateImageMetadata(with data: Image) {
        // Update image description
        descContainer.config(with: data.comment, inViewController: self, forVideo: false)
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
}


// MARK: - UIScrollViewDelegate Methods
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension ImageDetailViewController: UIScrollViewDelegate
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
    
//    private func calcImagePositionInScrollView() {
//        guard let imageSize = imageView?.image?.size,
//              imageSize.width != 0, imageSize.height != 0,
//              scrollView.zoomScale != 0
//        else {
//            imagePosition = CGPoint(x: 0.5, y: 0.5)
//            return
//        }
//
//        let displayedImageWidth = imageSize.width * scrollView.zoomScale
//        let displayedImageHeight = imageSize.height * scrollView.zoomScale
//        imagePosition = CGPoint(x: (scrollView.contentOffset.x + view.bounds.width / 2) / displayedImageWidth,
//                                y: (scrollView.contentOffset.y + view.bounds.height / 2) / displayedImageHeight)
//        debugPrint("    Position: \(imagePosition)")
//    }
    
//    private func applyImagePositionInScrollView() {
//        guard let imageSize = imageView?.image?.size,
//              imageSize.width != 0, imageSize.height != 0,
//              scrollView.zoomScale != 0
//        else {
//            imagePosition = CGPoint.zero
//            return
//        }
//
//        // Offset image position if needed
//        let displayedImageWidth = imageSize.width * scrollView.zoomScale
//        var horizontalOffset = imagePosition.x * displayedImageWidth - view.bounds.width / 2
//        let minX = (view.bounds.width + scrollView.contentInset.left / 2) / displayedImageWidth
//        if minX > 0, minX < 1 {
//            if imagePosition.x < minX {
//                horizontalOffset = minX * displayedImageWidth  - view.bounds.width / 2
//            } else if imagePosition.x > 1 - minX {
//                horizontalOffset = (1 - minX) * displayedImageWidth  - view.bounds.width / 2
//            }
//        }
//        horizontalOffset += scrollView.contentInset.left
//        debugPrint("••> horizontal: ", displayedImageWidth, imagePosition.x, minX, horizontalOffset)
//
//        let displayedImageHeight = imageSize.height * scrollView.zoomScale
//        var verticalOffset = imagePosition.y * displayedImageHeight - view.bounds.height / 2
//        let minY = (view.bounds.height + scrollView.contentInset.top / 2) / displayedImageHeight
//        if minY > 0, minY < 1 {
//            if imagePosition.y < minY {
//                verticalOffset = minY * displayedImageHeight  - view.bounds.height / 2
//            } else if imagePosition.y > 1 - minY {
//                verticalOffset = (1 - minY) * displayedImageHeight  - view.bounds.height / 2
//            }
//        }
//        verticalOffset += scrollView.contentInset.top
//        debugPrint("••> vertical: ", displayedImageHeight, imagePosition.y, minY, verticalOffset)
//
//        scrollView.contentOffset = CGPoint(x: horizontalOffset, y: verticalOffset)
//    }
}
