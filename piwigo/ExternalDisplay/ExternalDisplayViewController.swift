//
//  ExternalDisplayViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/05/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import PDFKit
import UIKit
import piwigoKit

protocol VideoDetailDelegate: NSObjectProtocol {
    func config(currentTime: TimeInterval, duration: TimeInterval, delegate: VideoControlsDelegate)
    func setCurrentTime(_ value: Double)
}

class ExternalDisplayViewController: UIViewController {
    
    weak var videoDetailDelegate: VideoDetailDelegate?

    var imageData: Image? {
        didSet {
            if oldValue?.pwgID != imageData?.pwgID {
                video = imageData?.video
            }
        }
    }
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
    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet weak var progressView: UIProgressView!
    

    // MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        imageView?.layoutIfNeeded()   // Ensure imageView in its final size
        
        // Pause download if needed
        if let imageURL = imageURL {
            PwgSession.shared.pauseDownload(atURL: imageURL)
        }

        // Configure image, video or PDF view
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
    
    @MainActor
    func configImage() {
        // Check provided image data
        guard let imageData = imageData
        else { return }
                
        // Type of file?
        let fileType = pwgImageFileType(rawValue: imageData.fileType) ?? .image
        switch fileType {
        case .image:
            // Determine the optimum image size for that display
            let displaySize = AlbumUtilities.sizeOfPage(forView: view)
            let maxPixels = Int(max(displaySize.width, displaySize.height))
            guard let serverID = imageData.server?.uuid,
                  let (optimumSize, imageURL) = ExternalDisplayUtilities.getOptimumImageSizeAndURL(imageData, ofMinSize: maxPixels) else {
                // Keep displaying what is presented
                return
            }

            // Check if we already have the high-resolution image in cache
            let scale = max(view.traitCollection.displayScale, 1.0)
            let screenSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale)
            if let wantedImage = imageData.cachedThumbnail(ofSize: optimumSize) {
                let cachedImage = ImageUtilities.downsample(image: wantedImage, to: screenSize)
                self.presentFinalImage(cachedImage)
                return
            }
            
            // Check if we already have an image of sufficient resolution
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
                presentTemporaryImage(imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
            }

            // Store image URL for being able to pause the download
            self.imageURL = imageURL

            // Download the image of right size for that display
            PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: optimumSize, type: .image, atURL: imageURL,
                                       fromServer: serverID, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.updateProgressView(with: fractionCompleted)
                }
            } completion: { [weak self] cachedImageURL in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.downsampleImage(atURL: cachedImageURL, to: screenSize)
                }
            } failure: { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.presentFinalImage(imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
                }
            }

        case .video:
            if let video = self.video {
                progressView.isHidden = true
                presentVideo(video)
            }
        case .pdf:
            // Check if we already have the PDF file in cache
            if let fileURL = imageData.cacheURL(ofSize: .fullRes),
               let document = PDFDocument(url: fileURL) {
                // Show PDF file in cache
                presentPDFdocument(document)
                return
            }
            
            // Check if we already have an image of sufficient resolution
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
            if let previewImage = imageData.cachedThumbnail(ofSize: previewSize) {
                // Display preview image
                self.presentFinalImage(previewImage)
            } else {
                // Thumbnail image should be available in cache
                self.presentTemporaryImage(imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
            }

            // Download PDF document
            if let imageURL = self.imageURL {
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .image, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
                    // Show download progress
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        debugPrint("••> Loading image \(imageData.pwgID): \(fractionCompleted)%")
                        self.progressView.progress = fractionCompleted
                    }
                } completion: { [weak self] cachedFileURL in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        // Hide progress view
                        self.progressView.isHidden = true

                        // Show PDF file in cache
                        guard let document = PDFDocument(url: cachedFileURL)
                        else { return }
                        self.presentPDFdocument(document)
                    }
                } failure: { _ in }
            }
        }
    }

    @MainActor
    private func updateProgressView(with fractionCompleted: Float) {
        // Show download progress
        self.progressView.progress = fractionCompleted
    }
    
    
    // MARK: - Photo
    @MainActor
    private func presentTemporaryImage(_ image: UIImage) {
        // Set image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [self] in
            self.imageView.image = image
//            self.imageView.frame = CGRect(origin: .zero, size: image.size)
//            self.imageView.layoutIfNeeded()
//            view.layoutIfNeeded()
            },
        completion: { [self] _ in
            self.progressView?.isHidden = false
            self.videoContainerView?.isHidden = true
            self.pdfView?.document = nil
            self.pdfView?.isHidden = true
        })
    }

    @MainActor
    private func downsampleImage(atURL fileURL: URL, to screenSize: CGSize) {
        let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: screenSize, for: .image)
        self.presentFinalImage(cachedImage)
    }
    
    @MainActor
    private func presentFinalImage(_ image: UIImage) {
        // Download completed
        self.progressView?.progress = 1.0
        
        // Display final image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [self] in
            self.imageView.image = image
//                self.imageView.frame = CGRect(origin: .zero, size: image.size)
//                self.imageView.layoutIfNeeded()
//                view.layoutIfNeeded()
        }, completion: { [self] _ in
            self.progressView?.isHidden = true
            self.videoContainerView?.isHidden = true
            self.pdfView?.document = nil
            self.pdfView?.isHidden = true
        })
    }
    

    // MARK: - Video
    @MainActor
    private func presentVideo(_ video: Video) {
        // Already being displayed?
        if playbackController.coordinator(for: video).playerViewControllerIfLoaded?.viewIfLoaded?.isDescendant(of: videoContainerView) == true {
            playbackController.play(contentOfVideo: video)
        } else {
            playbackController.embed(contentOfVideo: video, in: self, containerView: videoContainerView)
        }
        // Hide image and show video
        UIView.transition(with: videoContainerView, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [self] in
            self.imageView?.image = nil
            self.pdfView?.document = nil
            self.pdfView?.isHidden = true
            self.videoContainerView?.isHidden = false
        })
    }
    
    func config(currentTime: TimeInterval, duration: TimeInterval) {
        video?.duration = duration
        videoDetailDelegate?.config(currentTime: currentTime, duration: duration, delegate: self)
    }
    
    func setCurrentTime(_ value: Double) {
        videoDetailDelegate?.setCurrentTime(value)
    }
    
    
    // MARK: - PDF file
    @MainActor
    private func presentPDFdocument(_ document: PDFDocument) {
        // Download completed
        self.progressView?.progress = 1.0
        
        // Display final image
        UIView.transition(with: imageView, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [self] in
            pdfView?.document = document
            pdfView?.autoScales = true
            pdfView?.displayMode = .singlePageContinuous
            pdfView?.displaysPageBreaks = true
            pdfView?.displayDirection = .vertical
        }, completion: { [self] _ in
            self.progressView?.isHidden = true
            self.imageView?.image = nil
            self.videoContainerView?.isHidden = true
            pdfView?.isHidden = false
        })
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
