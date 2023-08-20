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
    var imageIndex = 0
    var imageData: Image!
    var imageURL: URL?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var progressView: PieProgressView!
        
    // Variable used to know when the scale should be calculated
    private var shouldSetZoomScale: Bool = true
    
    // Variable used to dismiss the view when the scale is reduced
    // from less than 1.1 x miminumZoomScale to less than 0.9 x miminumZoomScale
    private var startingZoomScale = CGFloat(1)
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Display thumbnail image which should be in cache
        let placeHolder = UIImage(named: "placeholderImage")!
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        self.setImageView(with: self.imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)

        // Get high-resolution image from cache or download it
        let viewSize = view.bounds.size
        let scale = view.traitCollection.displayScale
        var previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        if imageData.isVideo, previewSize == .fullRes {
            previewSize = .xxLarge
        }
        imageURL = ImageUtilities.getURL(self.imageData, ofMinSize: previewSize)
        if let imageURL = self.imageURL {
            ImageSession.shared.getImage(withID: imageData.pwgID, ofSize: previewSize, atURL: imageURL,
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

        // Configure the description view before layouting subviews
        descContainer.configDescription(with: imageData.comment, inViewController: self)
        
        // Hide/show the description view with the navigation bar
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
        }
        
        // Set colors, fonts, etc.
        applyColorPalette()
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
    
    
    // MARK: - Image Management
    private func setImageView(with image: UIImage) {
        // Set image view
        imageView.image = image
        imageView.frame.size = image.size
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height
        debugPrint("••> imageView: \(image.size.width) x \(image.size.height)")

        // Set scroll view content size
        scrollView.contentSize = image.size

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
        guard let image = imageView?.image else { return }

        // Initialisation
        scrollView.isPagingEnabled = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // Calc the zoom scale range
        scrollView.bounds = view.bounds
        let widthScale = view.bounds.size.width / image.size.width
        let heightScale = view.bounds.size.height / image.size.height
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
            scrollView.zoomScale *= minScale / oldZoomMinimumScale      // Will call scrollViewDidZoom()
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
    
    private func updateScrollViewInset() {
        guard let image = imageView?.image else { return }
        
        // Center image horizontally in scrollview
        let imageWidth = image.size.width * scrollView.zoomScale
        let horizontalSpace = max(0, (view.bounds.width - imageWidth) / 2)
        scrollView.contentInset.left = horizontalSpace
        scrollView.contentInset.right = horizontalSpace

        // Center image vertically  in scrollview
        let imageHeight = image.size.height * scrollView.zoomScale
        let verticalSpace = max(0, (view.bounds.height - imageHeight) / 2)
        scrollView.contentInset.top = verticalSpace
        scrollView.contentInset.bottom = verticalSpace

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
