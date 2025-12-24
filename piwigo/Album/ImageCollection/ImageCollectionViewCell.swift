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
    var imageURL: URL?

    @IBOutlet weak var cellImage: UIImageView!
    @IBOutlet weak var darkenView: UIView!
    @IBOutlet weak var darkImgWidth: NSLayoutConstraint!
    @IBOutlet weak var darkImgHeight: NSLayoutConstraint!
    
    // Image title
    @IBOutlet weak var bottomLayer: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var noDataLabel: UILabel!

    // Icon showing that it is a movie
    @IBOutlet weak var playIcon: UIView!
    @IBOutlet weak var playIconLeading: NSLayoutConstraint!
    @IBOutlet weak var playIconTop: NSLayoutConstraint!
    
    // Icon showing that it is a favorite
    @IBOutlet weak var favoriteIcon: UIImageView!
    @IBOutlet weak var favoriteLeading: NSLayoutConstraint!
    @IBOutlet weak var favoriteBottom: NSLayoutConstraint!
    
    // Selected images are darkened
    @IBOutlet weak var selectedIcon: UIView!
    @IBOutlet weak var selectedIconTrailing: NSLayoutConstraint!
    @IBOutlet weak var selectedIconBottom: NSLayoutConstraint!
        
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

    private var _isSelection = false
    var isSelection: Bool {
        get {
            _isSelection
        }
        set(isSelection) {
            _isSelection = isSelection
            selectedIcon?.isHidden = !isSelection
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
                favoriteBottom?.constant = deltaY
            } else {
                // Place icon at the bottom but above the title
                let height = CGFloat(fmax(bannerHeight, deltaY))
                favoriteBottom?.constant = height
            }

            // Display/hide the favorite icon
            favoriteIcon?.isHidden = !isFavorite
        }
    }
        
    @MainActor
    func applyColorPalette() {
        bottomLayer?.backgroundColor = PwgColor.background.withAlphaComponent(0.7)
        nameLabel?.textColor = PwgColor.leftLabel
        noDataLabel?.textColor = PwgColor.leftLabel
        selectedIcon?.layer.shadowColor = UIColor.white.cgColor
        favoriteIcon?.tintColor = .white
        favoriteIcon?.layer.shadowColor = UIColor.black.cgColor
        playIcon?.tintColor = .white
        playIcon?.layer.shadowColor = UIColor.black.cgColor
    }

    func config(withImageData imageData: Image, size: pwgImageSize, sortOption: pwgImageSort) {
        // Do we have any info on that image ?
        if imageData.pwgID == Int64.zero { return }

        // Store image data
        self.imageData = imageData
        noDataLabel?.isHidden = true
        noDataLabel?.text = ""
        isAccessibilityElement = true

        // Video icon
        playIcon?.isHidden = !(imageData.isVideo)

        // Title
        let title = getImageTitle(forSortOption: sortOption)
        accessibilityIdentifier = title.string
        accessibilityLabel = title.string
        if AlbumVars.shared.displayImageTitles {
            bottomLayer?.isHidden = false
            nameLabel?.attributedText = title
            nameLabel?.isHidden = false
        } else {
            bottomLayer?.isHidden = true
            nameLabel?.isHidden = true
        }

        // Thumbnails are not squared on iPad
        if traitCollection.userInterfaceIdiom == .pad {
            cellImage?.contentMode = .scaleAspectFit
        }
        
        // Retrieve image from cache or download it
        let scale = max(traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(self.bounds.size.width * scale, self.bounds.size.height * scale)
        imageURL = ImageUtilities.getPiwigoURL(imageData, ofMinSize: size)
        PwgSessionDelegate.shared.getImage(withID: imageData.pwgID, ofSize: size, type: .image, atURL: imageURL,
                                           fromServer: imageData.server?.uuid, fileSize: imageData.fileSize) { [weak self] cachedImageURL in
            // Downsample image in the background
            guard let self = self else { return }
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                // Downsample image in cache
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, for: .image)

                // Set image
                DispatchQueue.main.async { [self] in
                    self.configImage(cachedImage, withHiddenLabel: true)
                }
            }
        } failure: { [self] _ in
            DispatchQueue.main.async { [self] in
                self.configImage(pwgImageType.image.placeHolder, withHiddenLabel: false)
            }
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
            if imageData.titleStr.isEmpty == false {
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
            NSAttributedString.Key.foregroundColor: PwgColor.text,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .medium),
            NSAttributedString.Key.paragraphStyle: style
        ]
        attributedStr.addAttributes(attributes, range: wholeRange)
        return attributedStr
    }

    @MainActor
    func configImage(_ image: UIImage, withHiddenLabel isHidden: Bool) {
        // Set image and label
        self.cellImage?.image = image
        self.noDataLabel?.isHidden = isHidden
        
        // Some icons positions depend on device
        self.deltaX = CGFloat.zero
        self.deltaY = CGFloat.zero
        let imageScale = CGFloat(min(self.bounds.size.width / image.size.width,
                                     self.bounds.size.height / image.size.height))
        if traitCollection.userInterfaceIdiom == .pad {
            // Case of an iPad: respect aspect ratio
            let imageWidth = image.size.width * imageScale
            self.darkImgWidth?.constant = imageWidth
            self.deltaX += max(0, (self.bounds.size.width - imageWidth) / 2.0)
            
            let imageHeight = image.size.height * imageScale
            self.darkImgHeight?.constant = imageHeight
            self.deltaY += max(0, (self.bounds.size.height - imageHeight) / 2.0)
        }
        else {
            self.darkImgWidth?.constant = self.bounds.size.width
            self.darkImgHeight?.constant = self.bounds.size.height
        }
        
        // Update horizontal constraints
        let horOffset: CGFloat = 1.0 + self.deltaX
        self.selectedIconTrailing?.constant = horOffset
        self.favoriteLeading?.constant = horOffset
        self.playIconLeading?.constant = horOffset
        
        // Update vertical constraints
        let vertOffset: CGFloat = 1.0 + self.deltaY
        self.playIconTop?.constant = vertOffset
        if self.bottomLayer?.isHidden ?? false {
            // Image title not displayed
            self.favoriteBottom?.constant = 1.0 + vertOffset
            self.selectedIconBottom?.constant = 1.0 + vertOffset
        } else {
            // Image title displayed
            let banOffset: CGFloat = max(vertOffset, bannerHeight + 1.0)
            self.favoriteBottom?.constant = banOffset
            self.selectedIconBottom?.constant = banOffset
        }
        applyColorPalette()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()

        // Pause the ongoing image download if needed
        if let imageURL = self.imageURL {
            PwgSessionDelegate.shared.pauseDownload(atURL: imageURL)
        }

        // Reset cell
        self.nameLabel?.text = ""
        self.noDataLabel?.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        self.cellImage?.image = pwgImageType.image.placeHolder
        self.isFavorite = false
        self.isSelection = false
        self.isAccessibilityElement = false
        self.accessibilityIdentifier = ""
    }
    
    func highlight(onCompletion completion: @escaping () -> Void) {
        // Select cell of image of interest and apply effect
        self.backgroundColor = PwgColor.background
        self.contentMode = .scaleAspectFit
        UIView.animate(withDuration: 0.4, delay: 0.3, options: .allowUserInteraction, animations: { [self] in
            cellImage?.alpha = 0.2
        }) { [self] finished in
            UIView.animate(withDuration: 0.4, delay: 0.7, options: .allowUserInteraction, animations: { [self] in
                self.cellImage?.alpha = 1.0
            }) { finished in
                completion()
            }
        }
    }
}
