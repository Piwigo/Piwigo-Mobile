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
    @IBOutlet weak var playBckg: UIView!
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
    @IBOutlet weak var selImgBot: NSLayoutConstraint!
    
    // On iPad, thumbnails are presented with native aspect ratio
    private var deltaX: CGFloat = 0.0       // Extra horizotal offset
    private var deltaY: CGFloat = 0.0       // Extra vertical offset

    // Constants used to place and resize objects
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
                let height = CGFloat(fmax(bannerHeight, deltaY))
                favBottom?.constant = height
            }

            // Display/hide the favorite icon
            favBckg?.isHidden = !isFavorite
            favImg?.isHidden = !isFavorite
        }
    }
        
    func applyColorPalette() {
        bottomLayer?.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.7)
        nameLabel?.textColor = UIColor.piwigoColorLeftLabel()
        noDataLabel?.textColor = UIColor.piwigoColorLeftLabel()
        favBckg?.tintColor = UIColor(white: 0, alpha: 0.3)
        favImg?.tintColor = UIColor.white
        playImg?.tintColor = UIColor.white
    }

    func config(withImageData imageData: Image, size: pwgImageSize, sortOption: pwgImageSort) {
        // Do we have any info on that image ?
        if imageData.pwgID == Int64.zero { return }

        // Store image data
        self.imageData = imageData
        if noDataLabel?.isHidden == false {
            noDataLabel?.isHidden = true
            isAccessibilityElement = true
        }

        // Video icon
        if playImg?.isHidden == imageData.isVideo {
            playImg?.isHidden = !(imageData.isVideo)
            playBckg?.isHidden = !(imageData.isVideo)
        }

        // Title
        let title = getImageTitle(forSortOption: sortOption)
        if AlbumVars.shared.displayImageTitles {
            bottomLayer?.isHidden = false
            nameLabel?.attributedText = title
            nameLabel?.isHidden = false
            noDataLabel?.isHidden = true
        } else {
            bottomLayer?.isHidden = true
            nameLabel?.isHidden = true
            noDataLabel?.isHidden = true
        }
#if DEBUG
        // Used for selecting cells in piwigoAppStore
        if title.string.contains("Clos de Vougeot") {
            self.accessibilityIdentifier = "Clos de Vougeot"
        } else if title.string.contains("Hotel de Coimbra") {
            self.accessibilityIdentifier = "Hotel de Coimbra"
        }
#endif

        // Thumbnails are not squared on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            cellImage?.contentMode = .scaleAspectFit
        }
        
        // Retrieve image from cache or download it
        let scale = max(traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(self.bounds.size.width * scale, self.bounds.size.height * scale)
        let imageURL = ImageUtilities.getURL(imageData, ofMinSize: size)
        PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: size, type: .image, atURL: imageURL,
                                   fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] cachedImageURL in
            self?.downsampleImage(atURL: cachedImageURL, to: cellSize)
        } failure: { [weak self] _ in
            self?.configImage(pwgImageType.image.placeHolder, withHiddenLabel: false)
        }
    }
        
    private func getImageTitle(forSortOption sortOption: pwgImageSort) -> NSAttributedString {
        switch sortOption {
        case .visitsAscending, .visitsDescending:
            let hits = NSLocalizedString("categoryDiscoverVisits_legend", comment: "hits")
            let text = String(format: "%ld %@", Int(imageData.visits), hits)
            return attributedTitle(NSAttributedString(string: text))
        
        case .ratingScoreAscending, .ratingScoreDescending:
            // Rate score unknown until pwg.images.getInfo is called
            if imageData.ratingScore > 0.0 {
                let rate = NSMutableAttributedString(string: String(format: "(%.2f) ", imageData.ratingScore))
                if imageData.title.string.isEmpty {
                    rate.append(NSMutableAttributedString(string: imageData.fileName))
                } else {
                    rate.append(imageData.title)
                }
                return attributedTitle(rate)
            }
            fallthrough

        default:
            if imageData.title.string.isEmpty == false {
                return attributedTitle(imageData.title)
            } else {
                return attributedTitle(NSAttributedString(string: imageData.fileName))
            }
        }
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

    private func downsampleImage(atURL fileURL: URL, to cellSize: CGSize) {
        // Process image in the background
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Downsample image in cache
            let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: cellSize)

            // Set image
            self.configImage(cachedImage, withHiddenLabel: true)
        }
    }
    
    private func configImage(_ image: UIImage, withHiddenLabel isHidden: Bool) {
        DispatchQueue.main.async { [self] in
            // Set image and label
            self.cellImage?.image = image
            self.noDataLabel?.isHidden = isHidden
            
            // Favorite image position depends on device
            self.deltaX = CGFloat.zero
            self.deltaY = CGFloat.zero
            let imageScale = CGFloat(min(self.bounds.size.width / image.size.width,
                                         self.bounds.size.height / image.size.height))
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Case of an iPad: respect aspect ratio
                let imageWidth = image.size.width * imageScale
                self.darkImgWidth?.constant = imageWidth
                self.deltaX += max(0, (self.bounds.size.width - imageWidth) / 2.0)
                
                let imageHeight = image.size.height * imageScale
                self.darkImgHeight?.constant = imageHeight
                self.deltaY += max(0, (self.bounds.size.height - imageHeight) / 2.0)
            }
            
            // Update horizontal constraints
            let horOffset: CGFloat = 3.0 + self.deltaX
            self.selImgRight?.constant = horOffset
            self.favLeft?.constant = horOffset
            self.playLeft?.constant = horOffset
            
            // Update vertical constraints
            let vertOffset: CGFloat = 3.0 + self.deltaY
            self.playTop?.constant = vertOffset
            if self.bottomLayer?.isHidden ?? false {
                // Image title not displayed
                self.favBottom?.constant = vertOffset
                self.selImgBot?.constant = vertOffset
            } else {
                // Image title displayed
                let banOffset: CGFloat = max(vertOffset, bannerHeight + 3.0)
                self.favBottom?.constant = banOffset
                self.selImgBot?.constant = banOffset
            }
            applyColorPalette()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        isAccessibilityElement = false
        noDataLabel?.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        accessibilityIdentifier = ""
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
