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
                // Reset progress value
                progressView?.progress = 0
                // Get new video if needed
                if imageData?.isVideo ?? false {
                    video = imageData?.video
                }
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
    var document: PDFDocument?

    private var imageURL: URL?
    private var privacyView: UIView?
    private var scrollView: UIScrollView?

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
                self.presentHighResPhoto(cachedImage)
                return
            }
            
            // Check if we already have an image of sufficient resolution
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
            if let previewImage = imageData.cachedThumbnail(ofSize: previewSize) {
                // Is this file of sufficient resolution?
                if previewSize >= optimumSize {
                    // Display preview image
                    presentHighResPhoto(previewImage)
                    return
                } else {
                    // Present preview image and download file of greater resolution
                    presentLowResPhoto(previewImage)
                }
            } else {
                // Thumbnail image should be available in cache
                presentLowResPhoto(imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
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
                    self.updateProgressView(with: 1.0)
                    self.downsampleHighResPhoto(atURL: cachedImageURL, to: screenSize)
                }
            } failure: { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let cachedImage = imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder
                    self.presentHighResPhoto(cachedImage)
                }
            }

        case .video:
            // Present the video player
            if let video = self.video {
                progressView.isHidden = true
                presentVideo(video)
            }
            
        case .pdf:
            // Determine the optimum image size for that display
            let displaySize = AlbumUtilities.sizeOfPage(forView: view)
            let maxPixels = Int(max(displaySize.width, displaySize.height))
            if let (optimumSize, imageURL) = ExternalDisplayUtilities.getOptimumImageSizeAndURL(imageData, ofMinSize: maxPixels) {
                // Check if we have the high-resolution image in cache
                let scale = max(view.traitCollection.displayScale, 1.0)
                let screenSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale)
                if let wantedImage = imageData.cachedThumbnail(ofSize: optimumSize) {
                    // Show high-resolution thumbnail of the PDF file
                    let cachedImage = ImageUtilities.downsample(image: wantedImage, to: screenSize)
                    self.presentPDFthumbnail(cachedImage)
                }
                else {
                    // Display image of lower resolution
                    let thumbnail = getLowResPDFthumbnail(of: imageData)
                    presentPDFthumbnail(thumbnail)
                    
                    // Download high-resolution thumbnail for next time
                    guard let serverID = imageData.server?.uuid
                    else { return }
                    
                    // Store image URL for being able to pause the download
                    self.imageURL = imageURL
                    
                    // Download the image of right size for that display
                    PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: optimumSize, type: .image, atURL: imageURL,
                                               fromServer: serverID, fileSize: imageData.fileSize) { _ in
                    } completion: { _ in
                    } failure: { _ in }
                }
            } else {
                // Display image of lower resolution
                let thumbnail = getLowResPDFthumbnail(of: imageData)
                presentPDFthumbnail(thumbnail)
            }

            // Check if we already have the PDF file in cache
            if let document = self.document {
                // Show PDF file in cache
                setPdfView(with: document)
            }
        }
    }
    
    
    // MARK: - Photo
    @MainActor
    private func presentLowResPhoto(_ image: UIImage) {
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
    private func downsampleHighResPhoto(atURL fileURL: URL, to screenSize: CGSize) {
        let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: screenSize, for: .image)
        self.presentHighResPhoto(cachedImage)
    }
    
    @MainActor
    private func presentHighResPhoto(_ image: UIImage) {
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
    
    
    // MARK: - PDF File
    @MainActor
    private func getLowResPDFthumbnail(of imageData: Image) -> UIImage {
        // Determine which thumbnail to use
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        let previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        if let previewImage = imageData.cachedThumbnail(ofSize: previewSize) {
            // Display preview image
            return previewImage
        } else {
            // Thumbnail image should be available in cache
            return imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder
        }
    }
    
    @MainActor
    private func presentPDFthumbnail(_ image: UIImage) {
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


// MARK: - PdfDisplayDetailDelegate Methods
extension ExternalDisplayViewController: @preconcurrency PdfDetailDelegate
{
    @MainActor
    func updateProgressView(with fractionCompleted: Float) {
        // Show download progress
        self.progressView?.isHidden = false
        self.progressView?.progress = fractionCompleted
    }
    
    @MainActor
    func setPdfView(with document: PDFDocument) {
        // New document?
        guard pdfView?.document != document
        else { return }
        self.document = document
        
        // Download completed
        self.progressView?.progress = 1.0
        
        // Display PDF document
        UIView.transition(with: pdfView, duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [self] in
            pdfView?.document = document
            if pdfView?.document?.pageCount == 1 {
                let viewHeight = pdfView?.bounds.height ?? 0
                let docHeight = pdfView?.document?.page(at: 0)?.bounds(for: .mediaBox).height ?? 0
                pdfView?.scaleFactor = viewHeight / docHeight
                pdfView?.displayMode = .singlePage
                pdfView?.displaysPageBreaks = false
            } else {
                pdfView?.autoScales = true
                pdfView?.displayMode = .singlePageContinuous
                pdfView?.displaysPageBreaks = true
                pdfView?.displayDirection = .vertical
            }
        }, completion: { [self] _ in
            self.progressView?.isHidden = true
            self.imageView?.image = nil
            self.videoContainerView?.isHidden = true
            pdfView?.isHidden = false

            // Seek the scroll view associated to the PDFview
            /// The scrollview associated with a PDFView is not exposed as of iOS 18
            if let scrollView = pdfView?.subviews.compactMap({ $0 as? UIScrollView }).first {
                self.scrollView = scrollView
            }
        })
    }
    
    @MainActor
    func didSelectPageNumber(_ pageNumber: Int) {
        // Go to page different than current one
        guard let currentPageNumber = pdfView?.currentPage?.pageRef?.pageNumber,
              pageNumber != currentPageNumber,
              let page = pdfView?.document?.page(at: pageNumber - 1)
        else { return }
        pdfView?.go(to: page)
    }
    
    @MainActor
    func scrolled(_ contentHeight: Double, by contentOffset: Double, max maxContentOffset: Double) {
        if let scrollView = pdfView?.subviews.compactMap({ $0 as? UIScrollView }).first {
            // Apply content height ratio to scroll in sync
            let ratio = scrollView.contentSize.height / contentHeight
            var offset = contentOffset * ratio

            // Apply a linear correction so that the max offset will match the end of the document
            let diffHeight: Double = scrollView.contentSize.height - maxContentOffset * ratio - scrollView.bounds.height
            offset += contentOffset / maxContentOffset * diffHeight
            
            // Apply the offset
            scrollView.setContentOffset(CGPoint(x: 0, y: CGFloat(offset)), animated: false)
        }
    }
}
