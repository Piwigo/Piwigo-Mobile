//
//  ExternalDisplayViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

class ExternalDisplayViewController: UIViewController {
    
    var imageData: Image?

    private var imageURL: URL?
    private let placeHolder = UIImage(named: "placeholderImage")!

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var helpLabel: UILabel!
    

    // MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        helpLabel.text = NSLocalizedString("help_externalDisplay", comment: "Tap the image you wish to display here.")
        imageView.layoutIfNeeded()   // Ensure imageView in its final size
        configImage()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if #available(iOS 13.0, *) {
            return .darkContent
        } else {
            // Fallback on earlier versions
            view.backgroundColor = .black
            return .default
        }
    }

    func configImage() {
        // Check provided image data
        guard let imageData = imageData else {
            // Show help message
            helpLabel.isHidden = false
            return
        }
        
        // Pause download if needed
        if let imageURL = imageURL {
            ImageSession.shared.pauseDownload(atURL: imageURL)
        }

        // Determine the optimum image size for that display
        let displaySize = AlbumUtilities.sizeOfPage(forView: view)
        let maxPixels = Int(max(displaySize.width, displaySize.height))
        guard let serverID = imageData.server?.uuid,
              let (optimumSize, imageURL) = ExternalDisplayUtilities.getOptimumSizeAndURL(imageData, ofMinSize: maxPixels) else {
            // Keep displaying what is presented
            return
        }
        
        // Store image URL for being able to pause the download
        self.imageURL = imageURL
        
        // Presents the video player if needed
        if imageData.isVideo {
            // Hide help message
            helpLabel.isHidden = true
            // Start playing video
            startVideoPlayerView(with: imageData)
            return
        }
        
        // Get URL of preview image file potentially in cache
        let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        let cacheDir = DataDirectories.shared.cacheDirectory.appendingPathComponent(serverID)
        let filePath = cacheDir.appendingPathComponent(previewSize.path)
            .appendingPathComponent(String(imageData.pwgID)).path

        // Present the preview image file if available
        if FileManager.default.fileExists(atPath: filePath),
           let previewImage = UIImage(contentsOfFile: filePath) {
            // Is this file of sufficient resolution?
            if previewSize >= optimumSize {
                // Display preview image
                presentFinalImage(previewImage)
                return
            } else {
                // Present preview image and download file of greater resolution
                presentTemporaryImage(previewImage)
            }
        } else {
            // Thumbnail image should be available in cache
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let fileURL = cacheDir.appendingPathComponent(thumbSize.path)
                .appendingPathComponent(String(imageData.pwgID))
            presentTemporaryImage(UIImage(contentsOfFile: fileURL.path) ?? placeHolder)
        }

        // Image of right size for that display
        let screenSize = view.bounds.size
        let scale = view.traitCollection.displayScale
        progressView?.progress = 0
        progressView?.isHidden = imageData.isVideo
        ImageSession.shared.getImage(withID: imageData.pwgID, ofSize: optimumSize, atURL: imageURL,
                                     fromServer: serverID, placeHolder: self.placeHolder) { fractionCompleted in
            DispatchQueue.main.async {
                self.progressView.progress = fractionCompleted
            }
        } completion: { cachedImageURL in
            let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: screenSize, scale: scale)
            DispatchQueue.main.async {
                self.progressView.progress = 1.0
                self.presentFinalImage(cachedImage)
            }
        } failure: { _ in }
    }
    
    private func presentTemporaryImage(_ image: UIImage) {
        // Hide help message
        helpLabel.isHidden = true
        // Set image
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.layoutIfNeeded()
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve) { }
        completion: { _ in
            // Show progress view
            self.progressView.isHidden = false
        }
    }

    private func presentFinalImage(_ image: UIImage) {
        // Hide help message
        helpLabel.isHidden = true
        // Set image
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        imageView.layoutIfNeeded()
        // Layout subviews
        view.layoutIfNeeded()
        // Display final image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve) { }
        completion: { _ in
            // Hide progress view
            self.progressView.isHidden = true
        }
    }
}
