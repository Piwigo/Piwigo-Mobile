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

@objc
class ImageCollectionViewCell: UICollectionViewCell {
    @objc var cellImage: UIImageView?
    @objc var imageData: PiwigoImageData?

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
                favBottom?.constant = -deltaY
            } else {
                // Place icon at the bottom but above the title
                let height = CGFloat(fmax(Float(bannerHeight + margin), Float(deltaY)))
                favBottom?.constant = -height
            }

            // Display/hide the favorite icon
            favBckg?.isHidden = !isFavorite
            favImg?.isHidden = !isFavorite
        }
    }
    
    // On iPad, thumbnails are presented with native aspect ratio
    private var size = CGSize.zero
    private var deltaX: CGFloat = 0.0
    private var deltaY: CGFloat = 0.0
    
    // Image title
    private var nameLabel: UILabel?
    private var bottomLayer: UIView?
    private var noDataLabel: UILabel?
    
    // Icon showing that it is a favorite
    private var favImg: UIImageView?
    private var favBckg: UIImageView?
    private var favLeft: NSLayoutConstraint?
    private var favBottom: NSLayoutConstraint?
    
    // Icon showing that it is a movie
    private var playImg: UIImageView?
    private var playBckg: UIImageView?
    private var playLeft: NSLayoutConstraint?
    private var playTop: NSLayoutConstraint?
    
    // Selected images are darkened
    private var selectedImg: UIImageView?
    private var selImgRight: NSLayoutConstraint?
    private var selImgTop: NSLayoutConstraint?
    private var darkenView: UIView?
    private var darkImgWidth: NSLayoutConstraint?
    private var darkImgHeight: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        clipsToBounds = true
        isSelection = false

        // Thumbnails
        cellImage = UIImageView()
        cellImage?.translatesAutoresizingMaskIntoConstraints = false
        if UIDevice.current.userInterfaceIdiom == .phone {
            cellImage?.contentMode = .scaleAspectFill
        } else {
            cellImage?.contentMode = .scaleAspectFit
        }
        cellImage?.image = UIImage(named: "placeholderImage")
        if let cellImage = cellImage {
            contentView.addSubview(cellImage)
            contentView.addConstraints(NSLayoutConstraint.constraintFillSize(cellImage)!)
        }

        // Movie type
        playBckg = UIImageView()
        playBckg?.setMovieIconImage()
        let scale = CGFloat(fmax(1.0, Float(traitCollection.displayScale)))
        var width = frame.size.width * playScale + (scale - 1)
        if let playBckg = playBckg {
            cellImage?.addSubview(playBckg)
        }
        var iconWidth = NSLayoutConstraint.constraintView(playBckg,
            toWidth: width + 2 * offset)
        var iconHeight = NSLayoutConstraint.constraintView(playBckg,
            toHeight: (width + 2 * offset) * playRatio)
        playLeft = NSLayoutConstraint.constraintView(fromLeft: playBckg, amount: margin)
        playTop = NSLayoutConstraint.constraintView(fromTop: playBckg, amount: margin)
        cellImage?.addConstraints([iconWidth, iconHeight, playLeft, playTop].compactMap { $0 })

        playImg = UIImageView()
        playImg?.setMovieIconImage()
        if let playImg = playImg {
            playBckg?.addSubview(playImg)
        }
        playBckg?.addConstraints(NSLayoutConstraint.constraintCenter(playImg)!)
        playBckg?.addConstraint(NSLayoutConstraint.constraintView(playImg, toWidth: width)!)
        playBckg?.addConstraint(NSLayoutConstraint.constraintView(playImg, toHeight: width * playRatio)!)

        // Favorite image
        favBckg = UIImageView()
        favBckg?.setFavoriteIconImage()
        width = frame.size.width * favScale + (scale - 1)
        if let favBckg = favBckg {
            cellImage?.addSubview(favBckg)
        }
        iconWidth = NSLayoutConstraint.constraintView(favBckg,
            toWidth: width + 2 * offset)
        iconHeight = NSLayoutConstraint.constraintView(favBckg,
            toHeight: (width + 2 * offset) * favRatio)
        favLeft = NSLayoutConstraint.constraintView(fromLeft: favBckg, amount: margin)
        favBottom = NSLayoutConstraint.constraintView(fromBottom: favBckg, amount: -margin)
        cellImage?.addConstraints([iconWidth, iconHeight, favLeft, favBottom].compactMap { $0 })

        favImg = UIImageView()
        favImg?.setFavoriteIconImage()
        if let favImg = favImg {
            favBckg?.addSubview(favImg)
        }
        favBckg?.addConstraints(NSLayoutConstraint.constraintCenter(favImg)!)
        favBckg?.addConstraint(NSLayoutConstraint.constraintView(favImg, toWidth: width)!)
        favBckg?.addConstraint(NSLayoutConstraint.constraintView(favImg, toHeight: width * favRatio)!)

        // Selected images are darker
        darkenView = UIView()
        darkenView?.translatesAutoresizingMaskIntoConstraints = false
        darkenView?.backgroundColor = UIColor(white: 0, alpha: 0.45)
        darkenView?.isHidden = true
        if let darkenView = darkenView {
            cellImage?.addSubview(darkenView)
        }
        darkImgWidth = NSLayoutConstraint.constraintView(
            darkenView,
            toWidth: frame.size.width)
        darkImgHeight = NSLayoutConstraint.constraintView(
            darkenView,
            toHeight: frame.size.height)
        cellImage?.addConstraints([darkImgWidth, darkImgHeight].compactMap { $0 })
        cellImage?.addConstraints(NSLayoutConstraint.constraintCenter(darkenView)!)

        // Banners at bottom of thumbnails
        bottomLayer = UIView()
        bottomLayer?.translatesAutoresizingMaskIntoConstraints = false
        bottomLayer?.alpha = 0.7
        if let bottomLayer = bottomLayer {
            cellImage?.addSubview(bottomLayer)
        }
        cellImage?.addConstraints(NSLayoutConstraint.constraintFillWidth(bottomLayer)!)
        cellImage?.addConstraint(NSLayoutConstraint.constraintView(fromBottom: bottomLayer, amount: 0)!)
        cellImage?.addConstraint(NSLayoutConstraint.constraintView(bottomLayer, toHeight: bannerHeight)!)

        // Title of images shown in banners
        nameLabel = UILabel(frame: CGRect(x: 0, y: 0, width: contentView.bounds.size.width, height: frame.size.height))
        nameLabel?.translatesAutoresizingMaskIntoConstraints = false
        nameLabel?.font = UIFont.piwigoFontTiny()
        nameLabel?.adjustsFontSizeToFitWidth = true
        nameLabel?.minimumScaleFactor = 0.7
        nameLabel?.numberOfLines = 1
        nameLabel?.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        if let nameLabel = nameLabel {
            bottomLayer?.addSubview(nameLabel)
        }
        bottomLayer?.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(nameLabel)!)
        bottomLayer?.addConstraint(NSLayoutConstraint.constraintView(fromBottom: nameLabel, amount: 1)!)
        if let nameLabel = nameLabel {
            bottomLayer?.addConstraint(
                NSLayoutConstraint(item: nameLabel, attribute: .left,
                    relatedBy: .greaterThanOrEqual, toItem: bottomLayer,
                    attribute: .left, multiplier: 1.0, constant: 3))
        }
        if let nameLabel = nameLabel {
            bottomLayer?.addConstraint(
                NSLayoutConstraint(
                    item: nameLabel, attribute: .right,
                    relatedBy: .lessThanOrEqual, toItem: bottomLayer,
                    attribute: .right,multiplier: 1.0, constant: 3))
        }

        if let bottomLayer = bottomLayer {
            cellImage?.addConstraint(NSLayoutConstraint(
                    item: bottomLayer, attribute: .centerY,
                    relatedBy: .equal, toItem: nameLabel,
                    attribute: .centerY, multiplier: 1.0, constant: 0))
        }

        // Selected image thumbnails
        selectedImg = UIImageView()
        selectedImg?.translatesAutoresizingMaskIntoConstraints = false
        selectedImg?.contentMode = .scaleAspectFit
        let checkMark = UIImage(named: "checkMark")
        selectedImg?.image = checkMark?.withRenderingMode(.alwaysTemplate)
        selectedImg?.tintColor = UIColor.piwigoColorOrange()
        selectedImg?.isHidden = true
        if let selectedImg = selectedImg {
            cellImage?.addSubview(selectedImg)
        }
        width = frame.size.width * selectScale + (scale - 1)
        cellImage?.addConstraint(NSLayoutConstraint.constraintView(selectedImg, toHeight: width)!)
        selImgRight = NSLayoutConstraint.constraintView(fromRight: selectedImg, amount: 0.0)
        selImgTop = NSLayoutConstraint.constraintView(fromTop: selectedImg, amount: 2 * margin)
        cellImage?.addConstraints([selImgRight, selImgTop].compactMap { $0 })
    }

    @objc func applyColorPalette() {
        bottomLayer?.backgroundColor = UIColor.piwigoColorBackground()
        nameLabel?.textColor = UIColor.piwigoColorLeftLabel()
        favBckg?.tintColor = UIColor(white: 0, alpha: 0.3)
        favImg?.tintColor = UIColor.white
    }

    @objc func config(with imageData: PiwigoImageData?, inCategoryId categoryId: Int, for size: CGSize) {
        // Do we have any info on that image ?
        guard let imageData = imageData else { return }
        if imageData.imageId == 0 { return }

        // Store image data
        self.size = size
        self.imageData = imageData
        isAccessibilityElement = true

        // Play button
        playImg?.isHidden = !(imageData.isVideo)
        playBckg?.isHidden = !(imageData.isVideo)

        // Title
        if AlbumVars.displayImageTitles ||
            (categoryId == kPiwigoVisitsCategoryId) ||
            (categoryId == kPiwigoBestCategoryId) ||
            (categoryId == kPiwigoRecentCategoryId) {
            bottomLayer?.isHidden = false
            nameLabel?.isHidden = false
            if categoryId == kPiwigoVisitsCategoryId {
                nameLabel?.text = String(format: "%ld %@", Int(imageData.visits), NSLocalizedString("categoryDiscoverVisits_legend", comment: "hits"))
            } else if categoryId == kPiwigoBestCategoryId {
//            self.nameLabel.text = [NSString stringWithFormat:@"(%.2f) %@", imageData.ratingScore, imageData.name];
                if let imageTitle = imageData.imageTitle, !imageTitle.isEmpty {
                    nameLabel?.text = imageTitle
                } else {
                    nameLabel?.text = imageData.fileName
                }
            } else if categoryId == kPiwigoRecentCategoryId,
                      let dateCreated = imageData.dateCreated {
                nameLabel?.text = DateFormatter.localizedString(from: dateCreated, dateStyle: .medium, timeStyle: .none)
            } else {
                if let imageTitle = imageData.imageTitle, !imageTitle.isEmpty {
                    nameLabel?.text = imageTitle
                } else {
                    nameLabel?.text = imageData.fileName
                }
            }
        } else {
            bottomLayer?.isHidden = true
            nameLabel?.isHidden = true
        }

        // Download the image of the requested resolution (or get it from the cache)
        switch kPiwigoImageSize(rawValue: AlbumVars.defaultThumbnailSize) {
        case kPiwigoImageSizeSquare:
            if AlbumVars.hasSquareSizeImages, let squarePath = imageData.squarePath, !squarePath.isEmpty {
                setImageFromPath(squarePath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeXXSmall:
            if AlbumVars.hasXXSmallSizeImages, let xxSmallPath = imageData.xxSmallPath, !xxSmallPath.isEmpty {
                setImageFromPath(xxSmallPath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeXSmall:
            if AlbumVars.hasXSmallSizeImages, let xSmallPath = imageData.xSmallPath, !xSmallPath.isEmpty {
                setImageFromPath(xSmallPath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeSmall:
            if AlbumVars.hasSmallSizeImages, let smallPath = imageData.smallPath, !smallPath.isEmpty {
                setImageFromPath(smallPath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeMedium:
            if AlbumVars.hasMediumSizeImages, let mediumPath = imageData.mediumPath, !mediumPath.isEmpty {
                setImageFromPath(mediumPath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeLarge:
            if AlbumVars.hasLargeSizeImages, let largePath = imageData.largePath, !largePath.isEmpty {
                setImageFromPath(largePath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeXLarge:
            if AlbumVars.hasXLargeSizeImages, let xLargePath = imageData.xLargePath, !xLargePath.isEmpty {
                setImageFromPath(xLargePath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeXXLarge:
            if AlbumVars.hasXXLargeSizeImages, let xxLargePath = imageData.xxLargePath, !xxLargePath.isEmpty {
                setImageFromPath(xxLargePath)
            } else if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        case kPiwigoImageSizeThumb, kPiwigoImageSizeFullRes:
            fallthrough
        default:
            if AlbumVars.hasThumbSizeImages, let thumbPath = imageData.thumbPath, !thumbPath.isEmpty {
                setImageFromPath(thumbPath)
            } else {
                noDataLabel?.isHidden = false
                return
            }
        }

        applyColorPalette()
    }

    private func setImageFromPath(_ imagePath: String) {
        // Do we have a correct URL?
        let placeHolderImage = UIImage(named: "placeholderImage")
        if imagePath.isEmpty {
            // No image thumbnail
            cellImage?.image = placeHolderImage
            return
        }

        // Retrieve the image file
        let scale = CGFloat(fmax(1.0, Float(traitCollection.displayScale)))
        guard let anURL = URL(string: imagePath) else { return }
        var request = URLRequest(url: anURL)
        request.addValue("image/*", forHTTPHeaderField: "Accept")
        cellImage?.setImageWith(request, placeholderImage: placeHolderImage,
            success: { [self] request, response, image in
                // Downsample image is necessary
                var displayedImage = image
                let maxDimensionInPixels = CGFloat(max(self.size.width, self.size.height)) * scale
                if CGFloat(max(image.size.width, image.size.height)) > maxDimensionInPixels {
                    displayedImage = ImageUtilities.downsample(image: image, to: size, scale: scale)
                }
                self.cellImage?.image = displayedImage

                // Favorite image position depends on device
                self.deltaX = margin
                self.deltaY = margin
                let imageScale = CGFloat(min(
                    self.size.width / displayedImage.size.width, self.size.height / displayedImage.size.height))
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // Case of an iPad: respect aspect ratio
                    // Image width…
                    let imageWidth = displayedImage.size.width * imageScale
                    self.darkImgWidth?.constant = imageWidth

                    // Horizontal correction?
                    if imageWidth < self.size.width {
                        // The image does not fill the cell horizontally
                        self.deltaX += (self.size.width - imageWidth) / 2.0
                    }

                    // Image height…
                    let imageHeight = displayedImage.size.height * imageScale
                    self.darkImgHeight?.constant = imageHeight

                    // Vertical correction?
                    if imageHeight < self.size.height {
                        // The image does not fill the cell vertically
                        self.deltaY += (self.size.height - imageHeight) / 2.0
                    }
                }

                // Update horizontal constraints
                self.selImgRight?.constant = -(self.deltaX)
                self.favLeft?.constant = self.deltaX
                self.playLeft?.constant = self.deltaX

                // Update vertical constraints
                self.selImgTop?.constant = self.deltaY + 2 * margin
                self.playTop?.constant = self.deltaY
                if self.bottomLayer?.isHidden ?? false {
                    // The title is not displayed
                    self.favBottom?.constant = -(self.deltaY)
                } else {
                    // The title is displayed
                    let deltaY = CGFloat(fmax(bannerHeight + margin, self.deltaY))
                    self.favBottom?.constant = -deltaY
                }
            },
        failure: { request, response, error in
            print("==> cell image: \(error.localizedDescription)")
        })
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

    @objc func highlight(onCompletion completion: @escaping () -> Void) {
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

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
