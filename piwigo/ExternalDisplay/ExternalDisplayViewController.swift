//
//  ExternalDisplayViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

protocol AlbumVideoControlsDelegate: NSObjectProtocol {
    func config(currentTime: TimeInterval, duration: TimeInterval, delegate: VideoControlsDelegate)
    func setCurrentTime(_ value: Double)
    func hideVideoControls()
}

class ExternalDisplayViewController: UIViewController {
    
    weak var albumVideoControlsDelegate: AlbumVideoControlsDelegate?

    var imageData: Image?
    var video: Video? {
        didSet {
            // Remove currently displayed video if needed
            if let oldVideo = oldValue, oldVideo.pwgID != video?.pwgID {
                playbackController.pause(contentOfVideo: oldVideo)
                playbackController.remove(contentOfVideo: oldVideo)
            }
        }
    }
    let playbackController = PlaybackController.shared

    private var imageURL: URL?
    private var privacyView: UIView?

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoContainerView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var helpLabel: UILabel!
    

    // MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        helpLabel.text = NSLocalizedString("help_externalDisplay", comment: "Tap the image you wish to display here.")
        imageView.layoutIfNeeded()   // Ensure imageView in its final size
        
        // Display image/video
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
    
    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)

        // Remove displayed video player
        albumVideoControlsDelegate?.hideVideoControls()
        if let video = video {
            playbackController.pause(contentOfVideo: video)
        }
        playbackController.removeAllEmbeddedViewControllers()
    }

    func configImage() {
        // Check provided image data
        guard let imageData = imageData else {
            // Show help message
            helpLabel.isHidden = false
            return
        }
        
        // Hide help message
        helpLabel.isHidden = true
 
        // Pause download if needed
        if let imageURL = imageURL {
            ImageSession.shared.pauseDownload(atURL: imageURL)
        }

        // Presents video if needed
        if imageData.isVideo, let video = imageData.video {
            self.video = video
            progressView.isHidden = true
            presentVideo(video)
            return
        }
        
        // Determine the optimum image size for that display
        let placeHolder = UIImage(named: "unknownImage")!
        let displaySize = AlbumUtilities.sizeOfPage(forView: view)
        let maxPixels = Int(max(displaySize.width, displaySize.height))
        guard let serverID = imageData.server?.uuid,
              let (optimumSize, imageURL) = ExternalDisplayUtilities.getOptimumSizeAndURL(imageData, ofMinSize: maxPixels) else {
            // Keep displaying what is presented
            return
        }
        
        // Store image URL for being able to pause the download
        self.imageURL = imageURL
        
        // Check if we already have the high-resolution image in cache
        let screenSize = view.bounds.size
        let scale = view.traitCollection.displayScale
        let wantedImage = imageData.cachedThumbnail(ofSize: optimumSize)
        if wantedImage == nil {
            // Present the preview image file if available
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
            if let previewImage = imageData.cachedThumbnail(ofSize: previewSize) {
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
                presentTemporaryImage(imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)
            }

            // Image of right size for that display
            ImageSession.shared.getImage(withID: imageData.pwgID, ofSize: optimumSize, atURL: imageURL,
                                         fromServer: serverID, fileSize: imageData.fileSize,
                                         placeHolder: placeHolder) { fractionCompleted in
                DispatchQueue.main.async {
                    self.progressView.progress = fractionCompleted
                }
            } completion: { cachedImageURL in
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: screenSize, scale: scale)
                DispatchQueue.main.async {
                    self.progressView.progress = 1.0
                    self.presentFinalImage(cachedImage)
                }
            } failure: { _ in
                DispatchQueue.main.async {
                    self.progressView.progress = 1.0
                    self.presentFinalImage(imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)
                }
            }
        } else {
            let cachedImage = ImageUtilities.downsample(image: wantedImage!, to: screenSize, scale: scale)
            self.progressView.progress = 1.0
            self.presentFinalImage(cachedImage)
        }
    }
    
    private func presentTemporaryImage(_ image: UIImage) {
        // Set image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve) {
            self.albumVideoControlsDelegate?.hideVideoControls()
        }
        completion: { [unowned self] _ in
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: image.size)
            imageView.layoutIfNeeded()
            view.layoutIfNeeded()
            self.progressView.isHidden = false
            self.videoContainerView.isHidden = true
        }
    }

    private func presentFinalImage(_ image: UIImage) {
        // Display final image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve) {
            self.albumVideoControlsDelegate?.hideVideoControls()
        }
        completion: { [unowned self] _ in
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: image.size)
            imageView.layoutIfNeeded()
            view.layoutIfNeeded()
            self.progressView.isHidden = true
            self.videoContainerView.isHidden = true
        }
    }
    
    private func presentVideo(_ video: Video) {
        // Already being displayed?
        if playbackController.coordinator(for: video).playerViewControllerIfLoaded?.viewIfLoaded?.isDescendant(of: videoContainerView) == true {
            playbackController.play(contentOfVideo: video)
        } else {
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
        // Hide image and show video
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve) {
        }
        completion: { [unowned self] _ in
            imageView.image = nil
            self.videoContainerView.isHidden = false
        }
    }
    
    func config(currentTime: TimeInterval, duration: TimeInterval) {
        video?.duration = duration
        albumVideoControlsDelegate?.config(currentTime: currentTime, duration: duration, delegate: self)
    }
    
    func setCurrentTime(_ value: Double) {
        albumVideoControlsDelegate?.setCurrentTime(value)
    }
}


// MARK: - VideoControlsDelegate Methods
extension ExternalDisplayViewController: VideoControlsDelegate
{
    func didChangeTime(value: Double) {
        if let video = video {
            playbackController.seek(contentOfVideo: video, toTimeFraction: value)
        }
    }
}
