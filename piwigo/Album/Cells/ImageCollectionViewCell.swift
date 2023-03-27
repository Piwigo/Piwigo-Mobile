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
    private var download: ImageDownload?

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
    var isSelection: Bool {
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
    var isFavorite: Bool {
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
        
    func applyColorPalette() {
        bottomLayer?.backgroundColor = UIColor.piwigoColorBackground()
        nameLabel?.textColor = UIColor.piwigoColorLeftLabel()
        favBckg?.tintColor = UIColor(white: 0, alpha: 0.3)
        favImg?.tintColor = UIColor.white
        playImg?.tintColor = UIColor.white
    }

    func config(with imageData: Image, inCategoryId categoryId: Int32) {
        // Do we have any info on that image ?
        if imageData.pwgID == Int64.zero { return }

        // Store image data
        self.imageData = imageData
        if noDataLabel.isHidden == false {
            noDataLabel.isHidden = true
            isAccessibilityElement = true
        }

        // Play button
        if playImg?.isHidden == imageData.isVideo {
            playImg?.isHidden = !(imageData.isVideo)
            playBckg?.isHidden = !(imageData.isVideo)
        }

        // Title
        let albumType = pwgSmartAlbum(rawValue: categoryId) ?? .root
        let displayTitle = AlbumVars.shared.displayImageTitles ||
                            [.visits, .best, .recent].contains(albumType)
        if displayTitle {
            let title = getImageTitle(forAlbumType: albumType)
            if nameLabel?.attributedText != title {
                nameLabel?.attributedText = title
            }
        }
        if displayTitle, bottomLayer?.isHidden != displayTitle {
            bottomLayer?.isHidden = displayTitle
            nameLabel?.isHidden = displayTitle
        }

        // Thumbnails are not squared on iPad
        if UIDevice.current.userInterfaceIdiom == .pad,
           cellImage?.contentMode != .scaleAspectFit {
            cellImage?.contentMode = .scaleAspectFit
        }
        
        // Retrieve image URLs (Piwigo server or cache)
        let size = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
        guard let serverID = imageData.server?.uuid,
              let imageURL = ImageUtilities.getURLs(imageData, ofMinSize: size) else {
            self.noDataLabel?.isHidden = false
            applyColorPalette()
            return
        }

        // Retrieve image from cache or download it
        let placeHolder = UIImage(named: "placeholderImage")!
        download = ImageDownload(imageID: imageData.pwgID, ofSize: size, atURL: imageURL as URL, fromServer: serverID, fileSize: imageData.fileSize, placeHolder: placeHolder) { cachedImage in
            DispatchQueue.main.async {
                self.configImage(cachedImage)
            }
        } failure: { error in
            // No image available
            DispatchQueue.main.async {
                self.noDataLabel?.isHidden = false
                self.applyColorPalette()
            }
        }
        download?.getImage()
    }
    
    private func getImageTitle(forAlbumType type: pwgSmartAlbum) -> NSAttributedString {
        var title = NSAttributedString()
        switch type {
        case .visits:
            let hits = NSLocalizedString("categoryDiscoverVisits_legend", comment: "hits")
            let text = String(format: "%ld %@", Int(imageData.visits), hits)
            title = attributedTitle(NSAttributedString(string: text))
        case .best:
            if imageData.title.string.isEmpty == false {
                title = attributedTitle(imageData.title)
                // Rate score unknown until pwg.images.getInfo is called
//              nameLabel?.text = String(format: "(%.2f) %@", imageData.ratingScore, imageData.title.string)
            } else {
                // Rate score unknown until pwg.images.getInfo is called
                title = attributedTitle(NSAttributedString(string: imageData.fileName))
//              nameLabel?.text = String(format: "(%.2f) %@", imageData.ratingScore, imageData.fileName)
            }
        case .recent:
            let text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                     dateStyle: .medium, timeStyle: .none)
            title = attributedTitle(NSAttributedString(string: text))
        default:
            if imageData.title.string.isEmpty == false {
                title = attributedTitle(imageData.title)
            } else {
                title = attributedTitle(NSAttributedString(string: imageData.fileName))
            }
        }
        return title
    }
    
    private func attributedTitle(_ title: NSAttributedString) -> NSAttributedString {
        let attributedStr = NSMutableAttributedString(attributedString: title)
        let wholeRange = NSRange(location: 0, length: attributedStr.string.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .medium),
            NSAttributedString.Key.paragraphStyle: style
        ]
        attributedStr.addAttributes(attributes, range: wholeRange)
        return attributedStr
    }

    private func configImage(_ image: UIImage) {
        // Downsample image if necessary
        var displayedImage = image
        let scale = CGFloat(fmax(1.0, Float(traitCollection.displayScale)))
        let maxDimensionInPixels = CGFloat(max(self.bounds.size.width, self.bounds.size.height)) * scale
        if CGFloat(max(image.size.width, image.size.height)) > maxDimensionInPixels {
            displayedImage = ImageUtilities.downsample(image: image,
                                                        to: self.bounds.size, scale: scale)
        }
        changeCellImageIfNeeded(withImage: displayedImage)
        
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
                if self.darkImgWidth?.constant ?? -1 != imageWidth {
                    self.darkImgWidth?.constant = imageWidth
                }
                self.deltaX += (self.bounds.size.width - imageWidth) / 2.0
            }
            // Image height smaller than collection view cell?
            let imageHeight = displayedImage.size.height * imageScale
            if imageHeight < self.bounds.size.height {
                // The image does not fill the cell vertically
                if self.darkImgHeight?.constant ?? -1 != imageHeight {
                    self.darkImgHeight?.constant = imageHeight
                }
                self.deltaY += (self.bounds.size.height - imageHeight) / 2.0
            }
        }
        
        // Update horizontal constraints
        if self.selImgRight?.constant ?? -1 != self.deltaX {
            self.selImgRight?.constant = self.deltaX
            self.favLeft?.constant = self.deltaX
            self.playLeft?.constant = self.deltaX
        }
        
        // Update vertical constraints
        if self.playTop?.constant ?? -1 != self.deltaY {
            self.selImgTop?.constant = self.deltaY + 2 * margin
            self.playTop?.constant = self.deltaY
        }
        if self.bottomLayer?.isHidden ?? false {
            // The title is not displayed
            if self.favBottom?.constant ?? -1 != self.deltaY {
                self.favBottom?.constant = self.deltaY
            }
        } else {
            // The title is displayed
            let deltaYmax = CGFloat(fmax(bannerHeight + margin, self.deltaY))
            if self.favBottom?.constant ?? -1 != deltaYmax {
                self.favBottom?.constant = deltaYmax
            }
        }
        applyColorPalette()
    }

    private func changeCellImageIfNeeded(withImage image: UIImage) {
        if let oldImage = self.cellImage.image {
            if oldImage.isEqual(image) == false {
                self.cellImage.image = image
            }
        } else {
            self.cellImage.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        download = nil
        isAccessibilityElement = false
        noDataLabel?.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
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
