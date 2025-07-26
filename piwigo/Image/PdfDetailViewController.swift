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

class PdfDetailViewController: UIViewController
{
    var indexPath = IndexPath(item: 0, section: 0)
    var imageData: Image! {
        didSet {
            imageURL = self.imageData.downloadUrl as URL?
        }
    }
    var imageURL: URL?
    
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
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // Update description view colors if necessary
        descContainer.applyColorPalette()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load andd display image (resume download if needed)
        loadAndDisplayPDFfile()
        
        // Configure the description view before layouting subviews
        descContainer.config(with: imageData.comment, inViewController: self, forVideo: false)
        
        // Hide/show the description view with the navigation bar
        updateDescriptionVisibility()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Should this PDF file be also displayed on the external screen?
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
                
            // Add PDF view to external screen
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
        
        // Animate change of view size and reposition video
        coordinator.animate(alongsideTransition: { [self] _ in
            // Should we update the description?
            if descContainer.descTextView.text.isEmpty == false {
                descContainer.config(with: imageData.comment, inViewController: self, forVideo: false)
                descContainer.applyColorPalette()
            }

            // Set place holder view frame for this orientation
            setPlaceHolderViewFrame()
            
            // Set scale to fullscreen if needed
            if pdfView.scaleFactor < pdfView.scaleFactorForSizeToFit {
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
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
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: .fullRes, type: .image, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] fractionCompleted in
                    // Show download progress
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        debugPrint("••> Loading image \(self.imageData.pwgID): \(fractionCompleted)%")
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
                        self.setPdfView(with: document)
                    }
                } failure: { _ in }
            }
        }
    }
    
    @MainActor
    private func setPdfView(with document: PDFDocument) {
        pdfView?.document = document
        pdfView?.autoScales = true
        pdfView?.displayMode = .singlePageContinuous
        pdfView?.displaysPageBreaks = true
        pdfView?.displayDirection = .vertical
    }
    
    
    // MARK: - Gestures Management
    func updateDescriptionVisibility() {
        // Hide/show the description view with the navigation bar
        if descContainer.descTextView.text.isEmpty == false {
            descContainer.isHidden = navigationController?.isNavigationBarHidden ?? false
        }
    }
}
