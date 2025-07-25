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
        if imageData.isNotImage, previewSize == .fullRes {
            previewSize = .xxLarge
        }
        
        // Check if we already have the high-resolution image in cache
        if let wantedImage = imageData.cachedThumbnail(ofSize: previewSize) {
            // Show high-resolution image in cache
            let cachedImage = ImageUtilities.downsample(image: wantedImage, to: viewSize)
            setImageView(with: cachedImage)
        } else {
            // Display thumbnail image which should be in cache
            let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
            self.setImageView(with: imageData.cachedThumbnail(ofSize: thumbSize) ?? pwgImageType.image.placeHolder)
            
            // Download high-resolution image
            if let imageURL = ImageUtilities.getPiwigoURL(imageData, ofMinSize: previewSize) {
                PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: previewSize, type: .image, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] cachedImageURL in
                    // Downsample image in the background
                    guard let self = self else { return }
                    DispatchQueue.global(qos: .userInitiated).async { [self] in
                        // Downsample image in cache
                        let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: viewSize, for: .image)

                        // Set image
                        DispatchQueue.main.async { [self] in
                            self.setImageView(with: cachedImage)
                        }
                    }
                } failure: { _ in }
            }
        }
    }
    
    private func setImageView(with image: UIImage) {
        self.imageView.image = image
        self.imageView.frame.size = image.size
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.imageView.clipsToBounds = true
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(imageView)

        NSLayoutConstraint.activate([
            self.imageView.leftAnchor.constraint(equalTo: view.leftAnchor),
            self.imageView.rightAnchor.constraint(equalTo: view.rightAnchor),
            self.imageView.topAnchor.constraint(equalTo: view.topAnchor),
            self.imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let width = view.bounds.width
        let height = width * aspectRatio
        self.preferredContentSize = CGSize(width: width, height: height)
    }
}
