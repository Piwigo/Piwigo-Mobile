//
//  ImageCollectionViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 1/27/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 31/01/2022
//

import UIKit
import piwigoKit

class ImageCollectionViewCell: UICollectionViewCell {
    
    var imageData: Image!

    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var darkImgWidth: NSLayoutConstraint!
    @IBOutlet weak var darkImgHeight: NSLayoutConstraint!
    
    // Image title
    @IBOutlet weak var bottomLayer: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var noDataLabel: UILabel!

    // Icon showing that it is a movie
    @IBOutlet weak var playImg: UIImageView!
    @IBOutlet weak var playBckg: UIImageView!
    @IBOutlet weak var playLeft: NSLayoutConstraint!
    @IBOutlet weak var playTop: NSLayoutConstraint!
    
    // Icon showing that it is a favorite
    @IBOutlet weak var favImg: UIImageView!
    @IBOutlet weak var favBckg: UIImageView!
    @IBOutlet weak var favLeft: NSLayoutConstraint!
    @IBOutlet weak var favBottom: NSLayoutConstraint!
    
    // Selected images are darkened
    @IBOutlet weak var selectedImg: UIImageView!
    @IBOutlet weak var selImgRight: NSLayoutConstraint!
    @IBOutlet weak var selImgTop: NSLayoutConstraint!
    
    // On iPad, thumbnails are presented with native aspect ratio
    private var deltaX: CGFloat = 1.0       // Must be initialised with margin value
    private var deltaY: CGFloat = 1.0       // Must be initialised with margin value

    // Constants used to place and resize objects
    private let margin: CGFloat = 1.0
    private let offset: CGFloat = 1.0
    private let bannerHeight: CGFloat = 16.0
    private let favScale: CGFloat = 0.12
    private let favRatio: CGFloat = 1.0
    private let selectScale: CGFloat = 0.2
    private let playScale: CGFloat = 0.17
    private let playRatio: CGFloat = 0.9 // was 58/75 = 0.7733;

    private var _isSelection = false
    @objc var isSelection: Bool {
        get {
            _isSelection
        }
        set(isSelection) {
            _isSelection = isSelection

            selectedImg?.isHidden = !isSelection
            darkenView?.isHidden = !isSelection
        }
    }

    private var _isFavorite = false
    @objc var isFavorite: Bool {
        get {
            _isFavorite
        }
        set(isFavorite) {
            _isFavorite = isFavorite

            // Update the vertical constraint
            if bottomLayer?.isHidden ?? false {
                // Place icon at the bottom
                favBottom?.constant = deltaY
            } else {
                // Place icon at the bottom but above the title
                let height = CGFloat(fmax(bannerHeight + margin, deltaY))
                favBottom?.constant = height
            }

            // Display/hide the favorite icon
            favBckg?.isHidden = !isFavorite
            favImg?.isHidden = !isFavorite
        }
    }
        
    @objc func applyColorPalette() {
        bottomLayer?.backgroundColor = UIColor.piwigoColorBackground()
        nameLabel?.textColor = UIColor.piwigoColorLeftLabel()
        favBckg?.tintColor = UIColor(white: 0, alpha: 0.3)
        favImg?.tintColor = UIColor.white
    }

    func config(with imageData: Image, inCategoryId categoryId: Int32) {
        // Do we have any info on that image ?
        noDataLabel?.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        if imageData.pwgID == Int64.zero { return }

        // Store image data
        self.imageData = imageData
        noDataLabel.isHidden = true
        isAccessibilityElement = true

        // Play button
        playImg?.isHidden = !(imageData.isVideo)
        playBckg?.isHidden = !(imageData.isVideo)

        // Title
        if AlbumVars.shared.displayImageTitles ||
            (categoryId == kPiwigoVisitsCategoryId) ||
            (categoryId == kPiwigoBestCategoryId) ||
            (categoryId == kPiwigoRecentCategoryId) {
            bottomLayer?.isHidden = false
            nameLabel?.isHidden = false
            if categoryId == kPiwigoVisitsCategoryId {
                nameLabel?.text = String(format: "%ld %@", Int(imageData.visits), NSLocalizedString("categoryDiscoverVisits_legend", comment: "hits"))
            } else if categoryId == kPiwigoBestCategoryId {
//            self.nameLabel.text = [NSString stringWithFormat:@"(%.2f) %@", imageData.ratingScore, imageData.name];
                if imageData.title.string.isEmpty == false {
                    nameLabel?.attributedText = imageData.title
                } else {
                    nameLabel?.attributedText = NSAttributedString(string: imageData.fileName)
                }
            } else if categoryId == kPiwigoRecentCategoryId {
                nameLabel?.text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                                dateStyle: .medium, timeStyle: .none)
            } else {
                if imageData.title.string.isEmpty == false {
                    nameLabel?.attributedText = imageData.title
                } else {
                    nameLabel?.text = imageData.fileName
                }
            }
        } else {
            bottomLayer?.isHidden = true
            nameLabel?.isHidden = true
        }

        // Thumbnails are not squared on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            cellImage?.contentMode = .scaleAspectFit
        }
        
        // Download the image of the requested resolution (or get it from the cache)
        guard let serverID = imageData.server?.uuid,
              let _ = imageData.thumbRes?.uuid else {
            noDataLabel?.isHidden = false
            return
        }
        
        let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
        let thumbUrl = cacheDir.appendingPathComponent(pwgImageSize.thumb.path)
        switch kPiwigoImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if AlbumVars.shared.hasSquareSizeImages {
                setImage(withResolution: imageData.squareRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.square.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.shared.hasXXSmallSizeImages {
                setImage(withResolution: imageData.xxsmallRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.xxSmall.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.shared.hasXSmallSizeImages {
                setImage(withResolution: imageData.xsmallRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.xSmall.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.shared.hasSmallSizeImages {
                setImage(withResolution: imageData.smallRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.small.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeMedium:
            if AlbumVars.shared.hasMediumSizeImages {
                setImage(withResolution: imageData.mediumRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.medium.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeLarge:
            if AlbumVars.shared.hasLargeSizeImages {
                setImage(withResolution: imageData.largeRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.large.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeXLarge:
            if AlbumVars.shared.hasXLargeSizeImages {
                setImage(withResolution: imageData.xlargeRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.xLarge.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeXXLarge:
            if AlbumVars.shared.hasXXLargeSizeImages {
                setImage(withResolution: imageData.xxlargeRes,
                         cachingAtUrl: cacheDir.appendingPathComponent(pwgImageSize.xxLarge.path))
            } else if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        case kPiwigoImageSizeThumb, kPiwigoImageSizeFullRes:
            fallthrough
        default:
            if AlbumVars.shared.hasThumbSizeImages {
                setImage(withResolution: imageData.thumbRes, cachingAtUrl: thumbUrl)
            } else {
                noDataLabel?.isHidden = false
            }
        }

        applyColorPalette()
    }

    private func setImage(withResolution resolution: Resolution?, cachingAtUrl cacheUrl: URL) {
        // Display album image
        let placeHolderImage = UIImage(named: "placeholderImage")!

        // Do we have an URL? and all IDs for storing it (we should)?
        guard let imageID = resolution?.uuid,
              let imageUrl = resolution?.url as? URL else {
            // No image thumbnail
            cellImage?.image = placeHolderImage
            return
        }

        // Get cached image
        let fileUrl = cacheUrl.appendingPathComponent(imageID)
        if let cachedImage: UIImage = UIImage(contentsOfFile: fileUrl.path),
            let cgImage = cachedImage.cgImage, cgImage.height * cgImage.bytesPerRow > 0,
            cachedImage != placeHolderImage {
            // Image thumbnail in cache
            print("••> Image \(imageID) retrieved from cache.")
            cellImage?.image = cachedImage
            return
        }

        // Retrieve the image file
        print("••> download image at \(imageUrl.absoluteString)")
        let scale = CGFloat(fmax(1.0, Float(traitCollection.displayScale)))
        ImageSession.shared.downloadImage(atURL: imageUrl, cachingAtURL: fileUrl) { [self] image in
            // Display
            DispatchQueue.main.async { [self] in
                // Downsample image if necessary
                var displayedImage = image
                let maxDimensionInPixels = CGFloat(max(self.bounds.size.width, self.bounds.size.height)) * scale
                if CGFloat(max(image.size.width, image.size.height)) > maxDimensionInPixels {
                    displayedImage = ImageUtilities.downsample(image: image, to: self.bounds.size, scale: scale)
                }
                self.cellImage?.image = displayedImage
                
                // Favorite image position depends on device
                self.deltaX = self.margin
                self.deltaY = self.margin
                let imageScale = CGFloat(min(self.bounds.size.width / displayedImage.size.width,
                                             self.bounds.size.height / displayedImage.size.height))
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // Case of an iPad: respect aspect ratio
                    // Image width smaller than collection view cell?
                    let imageWidth = displayedImage.size.width * imageScale
                    if imageWidth < self.bounds.size.width {
                        // The image does not fill the cell horizontally
                        self.darkImgWidth?.constant = imageWidth
                        self.deltaX += (self.bounds.size.width - imageWidth) / 2.0
                    }

                    // Image height smaller than collection view cell?
                    let imageHeight = displayedImage.size.height * imageScale
                    if imageHeight < self.bounds.size.height {
                        // The image does not fill the cell vertically
                        self.darkImgHeight?.constant = imageHeight
                        self.deltaY += (self.bounds.size.height - imageHeight) / 2.0
                    }
                }

                // Update horizontal constraints
                self.selImgRight?.constant = self.deltaX
                self.favLeft?.constant = self.deltaX
                self.playLeft?.constant = self.deltaX

                // Update vertical constraints
                self.selImgTop?.constant = self.deltaY + 2 * margin
                self.playTop?.constant = self.deltaY
                if self.bottomLayer?.isHidden ?? false {
                    // The title is not displayed
                    self.favBottom?.constant = self.deltaY
                } else {
                    // The title is displayed
                    let deltaY = CGFloat(fmax(bannerHeight + margin, self.deltaY))
                    self.favBottom?.constant = deltaY
                }
            }
        } failure: { error in
            debugPrint("••> cell image: \(error?.localizedDescription ?? "Unknown!")")
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageData = nil
        cellImage?.image = nil
        deltaX = margin
        deltaY = margin
        isSelection = false
        isFavorite = false
        playImg?.isHidden = true
        noDataLabel?.isHidden = true
    }

    func highlight(onCompletion completion: @escaping () -> Void) {
        // Select cell of image of interest and apply effect
        backgroundColor = UIColor.piwigoColorBackground()
        contentMode = .scaleAspectFit
        UIView.animate(withDuration: 0.4, delay: 0.3, options: .allowUserInteraction, animations: { [self] in
            cellImage?.alpha = 0.2
        }) { [self] finished in
            UIView.animate(withDuration: 0.4, delay: 0.7, options: .allowUserInteraction, animations: { [self] in
                cellImage?.alpha = 1.0
            }) { finished in
                completion()
            }
        }
    }
}
