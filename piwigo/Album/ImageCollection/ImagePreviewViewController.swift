//
//  ImagePreviewViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class ImagePreviewViewController: UIViewController
{
    private var aspectRatio = 1.0
    private let imageView = UIImageView()
    
    init(imageData: Image) {
        super.init(nibName: nil, bundle: nil)
        
        // Retrieve image
        let scale = max(view.traitCollection.displayScale, 1.0)
        let viewSize = CGSizeMake(view.bounds.size.width * scale, view.bounds.size.height * scale)
        let sizes = imageData.sizes
        aspectRatio = sizes.medium?.aspectRatio ?? sizes.thumb?.aspectRatio ?? 1.0
        var previewSize = pwgImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize) ?? .medium
        if imageData.isVideo, previewSize == .fullRes {
            previewSize = .xxLarge
        }
        
        // Check if we already have the high-resolution image in cache
        if let wantedImage = imageData.cachedThumbnail(ofSize: previewSize) {
            // Show high-resolution image in cache
            let cachedImage = ImageUtilities.downsample(image: wantedImage, to: viewSize)
            setImageView(with: cachedImage)
        } else {
            // Display thumbnail image which should be in cache
            let placeHolder = UIImage(named: "unknownImage")!
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            self.setImageView(with: imageData.cachedThumbnail(ofSize: thumbSize) ?? placeHolder)
            
            // Download high-resolution image
            if let imageURL = ImageUtilities.getURL(imageData, ofMinSize: previewSize) {
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: previewSize, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                           placeHolder: placeHolder) { [weak self] cachedImageURL in
                    self?.downsampleImage(atURL: cachedImageURL, to: viewSize)
                } failure: { _ in }
            }
        }
    }
    
    private func downsampleImage(atURL fileURL: URL, to viewSize: CGSize) {
        DispatchQueue.main.async { [self] in
            let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: viewSize)
            self.setImageView(with: cachedImage)
        }
    }
    
    private func setImageView(with image: UIImage) {
        imageView.image = image
        imageView.frame.size = image.size
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let width = view.bounds.width
        let height = width * aspectRatio
        preferredContentSize = CGSize(width: width, height: height)
    }
}
