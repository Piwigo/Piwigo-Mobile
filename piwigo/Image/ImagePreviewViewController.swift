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

protocol ImagePreviewDelegate: NSObjectProtocol {
    func downloadProgress(_ progress: Float)
}

class ImagePreviewViewController: UIViewController
{
    weak var imagePreviewDelegate: ImagePreviewDelegate?

    var imageIndex = 0
    var imageLoaded = false
    var imageData: Image!

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playImage: UIImageView!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    
    private var download: ImageDownload?
    private var userdidTapOnce: Bool = false        // True if the user did tap the view
    private var userDidRotateDevice: Bool = false   // True if the user did rotate the device


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retrieve server ID
        let placeHolder = UIImage(named: "placeholderImage")!
        guard let serverID = imageData.server?.uuid else {
            // Configure the description view before layouting subviews
            descContainer.configDescription(with: imageData.comment) {
                self.configScrollView(with: placeHolder)
            }
            return
        }

        // Thumbnail image should be available in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
        let fileURL = cacheDir.appendingPathComponent(thumbSize.path).appendingPathComponent(String(imageData.pwgID))
        
        // Configure the description view before layouting subviews
        let thumbImage = UIImage(contentsOfFile: fileURL.path) ?? placeHolder
        descContainer.configDescription(with: imageData.comment) {
            self.configScrollView(with: thumbImage)
        }

        // Previewed image
        let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        guard let imageURL = ImageUtilities.getURLs(imageData, ofMinSize: previewSize) else {
            return
        }
        download = ImageDownload(imageID: imageData.pwgID, ofSize: previewSize, atURL: imageURL as URL,
                                 fromServer: serverID, placeHolder: placeHolder) { fractionCompleted in
            DispatchQueue.main.async {
                self.imagePreviewDelegate?.downloadProgress(fractionCompleted)
            }
        } completion: { cachedImage in
            DispatchQueue.main.async {
                self.configImage(cachedImage)
            }
        }
        download?.getImage()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    func configImage(_ image: UIImage) {
        // Set image view content
        self.configScrollView(with: image)
        // Layout subviews
        self.view.layoutIfNeeded()
        
        // Hide progress bar
        self.imageLoaded = true
        self.imagePreviewDelegate?.downloadProgress(1.0)
        
        // Display "play" button if video
        self.playImage.isHidden = !self.imageData.isVideo
    }
    
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.setDescriptionColor()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()

        // Show/hide the description
        guard let comment = imageData?.comment,
                comment.string.isEmpty == false else {
            descContainer.isHidden = true
            return
        }
        descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if userdidTapOnce {
            userdidTapOnce = false
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

    deinit {
        // Cancel download if needed
        download = nil
        
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }
    
    
    // MARK: - Scroll View

    private func configScrollView(with image: UIImage) {
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageViewWidthConstraint.constant = image.size.width
        imageViewHeightConstraint.constant = image.size.height
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
        
        // Don't adjust the insets when showing or hiding the navigation bar/toolbar
        scrollView.contentInset = .zero
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Define the zoom scale range
        let widthScale = view.bounds.size.width / image.size.width
        let heightScale = view.bounds.size.height / image.size.height
        let minScale = min(widthScale, heightScale)
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(2.0, 4 * minScale)
        scrollView.zoomScale = minScale     // Will trigger the scrollViewDidZoom() method
//        debugPrint("=> scrollView: \(scrollView.bounds.size.width) x \(scrollView.bounds.size.height), imageView: \(imageView.frame.size.width) x \(imageView.frame.size.height), minScale: \(minScale)")
    }
    
    private func centerImageView() {
        guard let image = imageView?.image else { return }

        // Determine the orientation of the device
        let orientation: UIInterfaceOrientation
        if #available(iOS 14, *) {
            orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        // Determine if the toolbar is presented
        var isToolbarRequired = false
        if let viewControllers = navigationController?.viewControllers.filter({ $0.isKind(of: ImageViewController.self)}), let vc = viewControllers.first as? ImageViewController {
            isToolbarRequired = vc.isToolbarRequired
        }

        // Determine the available spaces around the image
        var spaceLeading: CGFloat = 0, spaceTrailing: CGFloat = 0
        var spaceTop:CGFloat = 0, spaceBottom:CGFloat = 0
        if let nav = navigationController {
            // Remove the heights of the navigation bar and toolbar
            spaceTop += nav.navigationBar.bounds.height
            spaceBottom += isToolbarRequired ? nav.toolbar.bounds.height : 0
        }

        // Takes into account the safe area insets
        if let root = topMostViewController()?.view?.window?.topMostViewController() {
            spaceTop += orientation.isLandscape ? 0 : root.view.safeAreaInsets.top
            spaceBottom += isToolbarRequired ? root.view.safeAreaInsets.bottom : 0
            spaceLeading += orientation.isLandscape ? 0 : root.view.safeAreaInsets.left
            spaceTrailing += orientation.isLandscape ? 0 : root.view.safeAreaInsets.right
        }
        
        // Horizontal constraints
        let imageWidth = image.size.width * scrollView.zoomScale
        let horizontalSpaceAvailable = view.bounds.width - (spaceLeading + imageWidth + spaceTrailing)
        spaceLeading += horizontalSpaceAvailable/2
        spaceTrailing += horizontalSpaceAvailable/2
        
        // Vertical constraints
        let imageHeight = image.size.height * scrollView.zoomScale
        var verticalSpaceAvailable = view.bounds.height - (spaceTop + imageHeight + spaceBottom)
        var descHeight: CGFloat = 0.0
        if let comment = imageData?.comment, comment.string.isEmpty == false {
            descHeight = descContainer.descHeight.constant + 8
        }
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
        
        // Center image horizontally in scrollview
        scrollView.contentInset.left = max(0, spaceLeading)
        scrollView.contentInset.right = max(0, spaceTrailing)
        
        // Center image vertically  in scrollview
        scrollView.contentInset.top = max(0, spaceTop)
        scrollView.contentInset.bottom = max(0, spaceBottom)
    }
        
    
    // MARK: - Image Metadata
    func didTapOnce() {
        // Remember that user did tap the view
        userdidTapOnce = true
        
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
    }
    
    func updateImageMetadata(with data: Image) {
        // Update image description
        descContainer.configDescription(with: data.comment) {
            self.view.layoutIfNeeded()
        }
    }
}


// MARK: - UIScrollViewDelegate Methods
/// https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/UIScrollView_pg/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008179-CH1-SW1
extension ImagePreviewViewController: UIScrollViewDelegate
{
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        // Limit the zoom scale
        if scale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
            centerImageView()
        } else if scale > scrollView.maximumZoomScale {
            scrollView.zoomScale = scrollView.maximumZoomScale
            centerImageView()
        }
    }
}
