//
//  PdfDetailViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19 July 2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PDFKit
import UIKit
import piwigoKit

protocol PdfDetailDelegate: NSObjectProtocol {
    func updateProgressView(with fractionCompleted: Float)
    func setPdfView(with document: PDFDocument)
    func didSelectPageNumber(_ pageNumber: Int)
    func scrolled(_ height: Double, by offset: Double, max maxOffset: Double)
}

class PdfDetailViewController: UIViewController
{
    weak var pdfDetailDelegate: (any PdfDetailDelegate)?
    
    var indexPath = IndexPath(item: 0, section: 0)
    var imageData: Image! {
        didSet {
            imageURL = self.imageData.downloadUrl as URL?
        }
    }
    var imageURL: URL?
    private var scrollView: UIScrollView?
    
    @IBOutlet weak var placeHolderView: UIImageView!
    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet weak var descContainer: ImageDescriptionView!
    @IBOutlet weak var progressView: PieProgressView!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display thumbnail image which should be in cache
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        placeHolderView.image = imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder
        setPlaceHolderViewFrame()
        
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
        
        // Load andd display image (resume download if needed)
        loadAndDisplayPDFfile()
        
        // Configure the description view before layouting subviews
        descContainer.config(withImage: imageData, inViewController: self, forVideo: false)
        
        // Hide/show the description view with the navigation bar
        updateDescriptionVisibility()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Should this PDF file be also displayed on the external screen?
        self.setExternalPdfView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Get content position
        var contentHeight: Double = .zero
        var contentOffset: Double = .zero
        var maxContentOffset: Double = .zero
        if let scrollView = self.scrollView {
            contentHeight = scrollView.contentSize.height
            contentOffset = scrollView.contentOffset.y + Double(scrollView.adjustedContentInset.top)
            let viewHeight: Double = Double(scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom)
            maxContentOffset = contentHeight - viewHeight
        }

        // Animate change of view size and reposition video
        coordinator.animate(alongsideTransition: { [self] _ in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(withImage: imageData, inViewController: self, forVideo: false)
                descContainer.applyColorPalette(withImage: imageData)
            }
            
            // Set place holder view frame for this orientation
            setPlaceHolderViewFrame()
            
            // Reset PDF view
            loadAndDisplayPDFfile()
            
            // Return to position
            if maxContentOffset > 0, let scrollView = self.scrollView {
                // Apply content height ratio to scroll in sync
                let ratio = scrollView.contentSize.height / contentHeight
                var offset = contentOffset * ratio

                // Apply a linear correction so that the max offset will match the end of the document
                let diffHeight: Double = scrollView.contentSize.height - maxContentOffset * ratio - scrollView.bounds.height
                offset += contentOffset / maxContentOffset * diffHeight
                
                // Apply the offset
                scrollView.setContentOffset(CGPoint(x: 0, y: CGFloat(offset)), animated: false)
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Show image before beginning transition
        placeHolderView.isHidden = false
    }
    
    deinit {
        // Unregister all observers
        imageData = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - PDF View
    @MainActor
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
    
    @MainActor
    private func loadAndDisplayPDFfile() {
        // Check if we already have the PDF file in cache
        if let fileURL = imageData.cacheURL(ofSize: .fullRes),
           let document = PDFDocument(url: fileURL) {
            // Show PDF file in cache
            setPdfView(with: document)
        } else {
            // Download PDF document
            if let imageURL = self.imageURL {
                ImageDownloader.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .image, atURL: imageURL,
                                                fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
                    // Show download progress
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.progressView.progress = fractionCompleted
                        self.pdfDetailDelegate?.updateProgressView(with: fractionCompleted)
                    }
                } completion: { [weak self] cachedFileURL in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        // Hide progress view
                        self.progressView.isHidden = true
                        
                        // Show PDF file stored in cache
                        guard let document = PDFDocument(url: cachedFileURL)
                        else { return }
                        self.setPdfView(with: document)
                        
                        // Show PDF file on external screen if needed
                        self.pdfDetailDelegate?.setPdfView(with: document)
                    }
                } failure: { _ in }
            }
        }
    }
    
    @MainActor
    private func setPdfView(with document: PDFDocument) {
        // Initialiase the PDF view
        pdfView?.document = document
        pdfView?.autoScales = true
        pdfView?.displayMode = .singlePageContinuous
        pdfView?.displaysPageBreaks = true
        pdfView?.displayDirection = .vertical
        
        // Seek the scroll view associated to the PDFView
        /// This scrollview is not exposed as of iOS 18
        if let scrollView = pdfView?.subviews.compactMap({ $0 as? UIScrollView }).first {
            self.scrollView = scrollView
            self.scrollView?.delegate = self
        }
    }
    
    @MainActor
    func didSelectPageNumber(_ pageNumber: Int) {
        // Check number of pages
        guard let pageCount = self.pdfView?.document?.pageCount,
              pageCount > 0
        else { return }
        
        // Check requested page number
        let pageNumberToShow = min(max(1, pageNumber), pageCount)
        
        // Go to page different than current one
        guard let currentPageNumber = pdfView?.currentPage?.pageRef?.pageNumber,
              pageNumberToShow != currentPageNumber,
              let page = pdfView?.document?.page(at: pageNumberToShow - 1)
        else { return }
        pdfView?.go(to: page)
        pdfDetailDelegate?.didSelectPageNumber(pageNumberToShow)
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
    
    
    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        // Apply changes
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Configure the description view before layouting subviews
            self.descContainer.config(withImage: self.imageData, inViewController: self, forVideo: false)
        }
    }
    
    
    // MARK: - External PDF View
    @MainActor
    private func setExternalPdfView() {
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
        
        // Add PDF view to external screen
        if let imageVC = windowScene.rootViewController() as? ExternalDisplayViewController {
            // Configure external display view controller
            imageVC.imageData = imageData
            imageVC.document = pdfView?.document
            imageVC.configImage()
            pdfDetailDelegate = imageVC
        }
        else {
            // Create external display view controller
            let imageSB = UIStoryboard(name: "ExternalDisplayViewController", bundle: nil)
            guard let imageVC = imageSB.instantiateViewController(withIdentifier: "ExternalDisplayViewController") as? ExternalDisplayViewController
            else { preconditionFailure("Could not load ExternalDisplayViewController") }
            imageVC.imageData = imageData
            imageVC.document = pdfView?.document
            pdfDetailDelegate = imageVC
            
            // Create window and make it visible
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = imageVC
            sceneDelegate.initExternalDisplay(with: window)
        }
    }
}


// MARK: - UIScrollViewDelegate Methods
extension PdfDetailViewController: UIScrollViewDelegate
{
    // Scroll the PDF view on the external display if needed
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Get content height
        let contentHeight: Double = scrollView.contentSize.height
        // Get 'real' content offset
        let contentOffset: Double = scrollView.contentOffset.y + Double(scrollView.adjustedContentInset.top)
        // Get max 'real' content offset
        let viewHeight: Double = Double(scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom)
        let maxContentOffset: Double = contentHeight - viewHeight
        pdfDetailDelegate?.scrolled(contentHeight, by: contentOffset, max: maxContentOffset)
    }
}
