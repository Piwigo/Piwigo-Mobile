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
        bottomLayer?.backgroundColor = UIColor.piwigoColorBackground()
        nameLabel?.textColor = UIColor.piwigoColorLeftLabel()
        favBckg?.tintColor = UIColor(white: 0, alpha: 0.3)
        favImg?.tintColor = UIColor.white
    }

    func config(with imageData: Image, placeHolder: UIImage, size: pwgImageSize, sortOption: pwgImageSort) {
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
#if DEBUG
        // Used for selecting cells in piwigoAppStore
        let title = getImageTitle(forSortOption: sortOption)
        if title.string.contains("Clos de Vougeot") {
            self.accessibilityIdentifier = "Clos de Vougeot"
        } else if title.string.contains("Hotel de Coimbra") {
            self.accessibilityIdentifier = "Hotel de Coimbra"
        }
#endif
        if AlbumVars.shared.displayImageTitles {
            nameLabel?.attributedText = getImageTitle(forSortOption: sortOption)
            bottomLayer?.isHidden = false
            nameLabel?.isHidden = false
        } else {
            bottomLayer?.isHidden = true
            nameLabel?.isHidden = true
        }

        // Thumbnails are not squared on iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            cellImage?.contentMode = .scaleAspectFit
        }
        
        // Retrieve image from cache or download it
        let placeHolder = UIImage(named: "unknownImage")!
        let cellSize = self.bounds.size
        let scale = self.traitCollection.displayScale
        let imageURL = ImageUtilities.getURL(imageData, ofMinSize: size)
        PwgSession.shared.getImage(withID: imageData.pwgID, ofSize: size, atURL: imageURL,
                                   fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                   placeHolder: placeHolder) { cachedImageURL in
            let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, scale: scale)
            DispatchQueue.main.async {
                self.configImage(cachedImage)
            }
        } failure: { _ in
            // No image available
            DispatchQueue.main.async {
                self.configImage(placeHolder)
                self.noDataLabel?.isHidden = false
                self.applyColorPalette()
            }
        }
    }
    
    private func getImageTitle(forSortOption sortOption: pwgImageSort) -> NSAttributedString {
        var title = NSAttributedString()
        switch sortOption {
        case .visitsAscending, .visitsDescending:
            let hits = NSLocalizedString("categoryDiscoverVisits_legend", comment: "hits")
            let text = String(format: "%ld %@", Int(imageData.visits), hits)
            title = attributedTitle(NSAttributedString(string: text))
        case .ratingScoreAscending, .ratingScoreDescending:
            if imageData.title.string.isEmpty == false {
                title = attributedTitle(imageData.title)
                // Rate score unknown until pwg.images.getInfo is called
//              nameLabel?.text = String(format: "(%.2f) %@", imageData.ratingScore, imageData.title.string)
            } else {
                // Rate score unknown until pwg.images.getInfo is called
                title = attributedTitle(NSAttributedString(string: imageData.fileName))
//              nameLabel?.text = String(format: "(%.2f) %@", imageData.ratingScore, imageData.fileName)
            }
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
        // Set image
        self.cellImage?.image = image

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

    override func prepareForReuse() {
        super.prepareForReuse()

        isAccessibilityElement = false
        cellImage.image = nil
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
