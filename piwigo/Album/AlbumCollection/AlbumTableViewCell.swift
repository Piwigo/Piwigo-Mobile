//
//  AlbumTableViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 1/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 16/01/2022
//

import UIKit
import piwigoKit

class AlbumTableViewCell: UITableViewCell {
    
    var imageURL: URL?

    @IBOutlet weak var albumView: UIView!
    @IBOutlet weak var albumName: UILabel!
    @IBOutlet weak var albumComment: UILabel!
    @IBOutlet weak var albumThumbnail: UIImageView!
    @IBOutlet weak var numberOfImages: UILabel!
    @IBOutlet weak var recentlyModified: UIImageView!
    @IBOutlet weak var binding1: UIView!
    @IBOutlet weak var binding2: UIView!
    
    func config(withAlbumData albumData: Album?) {
        // General settings
        selectionStyle = UITableViewCell.SelectionStyle.none
        albumView?.backgroundColor = PwgColor.cellBackground
        binding1?.backgroundColor = PwgColor.background
        binding2?.backgroundColor = PwgColor.background

        // Album name (Piwigo orange colour)
        albumName.text = albumData?.name ?? "—?—"
        var fontSize = fontSizeFor(label: albumName, nberLines: 2)
        albumName.font = UIFont.systemFont(ofSize: fontSize)
        
        // Album description (colour depends on text content)
        albumComment.attributedText = getDescription(fromAlbumData: albumData)
        fontSize = UIFont.fontSizeFor(label: albumComment, nberLines: 3)
        albumComment.font = UIFont.systemFont(ofSize: fontSize)

        // Number of images and sub-albums
        numberOfImages.text = getNberOfImages(fromAlbumData: albumData)
        numberOfImages.textColor = PwgColor.text
        numberOfImages.font = UIFont.systemFont(ofSize: 10, weight: .light)

        // If requested, display recent icon when images have been uploaded recently
        let timeSinceLastUpload = Date.timeIntervalSinceReferenceDate - (albumData?.dateLast ?? TimeInterval(-3187296000))
        var indexOfPeriod: Int = CacheVars.shared.recentPeriodIndex
        indexOfPeriod = min(indexOfPeriod, CacheVars.shared.recentPeriodList.count - 1)
        indexOfPeriod = max(0, indexOfPeriod)
        let periodInDays: Int = CacheVars.shared.recentPeriodList[indexOfPeriod]
        let isRecent = timeSinceLastUpload < TimeInterval(24*3600*periodInDays)
        self.recentlyModified.isHidden = !isRecent
        self.recentlyModified?.tintColor = UIColor.white
        self.recentlyModified?.layer.shadowColor = UIColor.black.cgColor
        self.recentlyModified?.layer.shadowOpacity = 1.0

        // Can we add a representative if needed?
        if albumData?.thumbnailUrl == nil || albumData?.thumbnailId == Int64.zero,
           let images = albumData?.images, let firstImage = images.first {
            // Set representative (case where images were uploaded recently)
            albumData?.thumbnailId = firstImage.pwgID
            let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
            albumData?.thumbnailUrl = ImageUtilities.getPiwigoURL(firstImage, ofMinSize: thumnailSize) as NSURL?
        }
        
        // Retrieve image from cache or download it
        self.albumThumbnail.layoutIfNeeded()   // Ensure imageView in its final size
        let scale = max(self.albumThumbnail.traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(self.albumThumbnail.bounds.size.width * scale, self.albumThumbnail.bounds.size.height * scale)
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        imageURL = albumData?.thumbnailUrl as? URL
        PwgSession.shared.getImage(withID: albumData?.thumbnailId, ofSize: thumbSize, type: .album,
                                   atURL: imageURL, fromServer: albumData?.user?.server?.uuid) { [weak self] cachedImageURL in
            // Process image in the background (.userInitiated leads to concurrency issues)
            // Can be called too many times leading to thread management issues
            guard let self = self else { return }
            DispatchQueue.global(qos: .default).async { [self] in
                // Downsample image in cache
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, for: .album)
                
                // Set backgoround image
                DispatchQueue.main.async { [self] in
                    self.albumThumbnail.image = cachedImage
                }
            }
        } failure: { [self] _ in
            // Set backgoround image
            DispatchQueue.main.async { [self] in
                self.albumThumbnail.image = pwgImageType.album.placeHolder
            }
        }
    }

    private func getDescription(fromAlbumData albumData: Album?) -> NSAttributedString {
        var desc = NSMutableAttributedString()
        // Any provided description?
        if let description = albumData?.commentHTML, description.string.isEmpty == false {
            desc = NSMutableAttributedString(attributedString: description)
        }
        else if let description = albumData?.comment, description.string.isEmpty == false {
            desc = NSMutableAttributedString(attributedString: description)
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: PwgColor.text,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)
        }
        else if albumData?.user?.hasAdminRights ?? false {
//            let noDesc = NSLocalizedString("createNewAlbumDescription_noDescription", comment: "no description")
            desc = NSMutableAttributedString(string: "")
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: PwgColor.rightLabel,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)
        }
        return desc
    }
    
    private func getNberOfImages(fromAlbumData albumData: Album?) -> String {
        // Constants
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        let singleImage = String(localized: "singleImageCount", bundle: piwigoKit, comment: "%@ photo")
        let severalImages = String(localized: "severalImagesCount", bundle: piwigoKit, comment: "%@ photos")
        let singleSubAlbum = NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album")
        let severalSubAlbums = NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums")
        // Determine string
        var text = ""
        if albumData?.nbSubAlbums ?? Int32.zero == Int32.zero {
            // There are no sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.nbImages ?? 0))
            text = (albumData?.nbImages ?? 0 > 1)
                ? String.localizedStringWithFormat(severalImages, nberImages ?? "")
                : String.localizedStringWithFormat(singleImage, nberImages ?? "")
        }
        else if albumData?.totalNbImages ?? Int64.zero == Int64.zero {
            // There are no images but sub-albums
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            text = (albumData?.nbSubAlbums ?? Int32.zero > 1)
                ? String.localizedStringWithFormat(severalSubAlbums, nberAlbums ?? "")
                : String.localizedStringWithFormat(singleSubAlbum, nberAlbums ?? "")
        }
        else {
            // There are images and sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.totalNbImages ?? 0))
            text = (albumData?.totalNbImages ?? Int64.zero > 1)
                ? String.localizedStringWithFormat(severalImages, nberImages ?? "")
                : String.localizedStringWithFormat(singleImage, nberImages ?? "")
            text += ", "
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            text += (albumData?.nbSubAlbums ?? Int32.zero > 1)
                ? String.localizedStringWithFormat(severalSubAlbums, nberAlbums ?? "")
                : String.localizedStringWithFormat(singleSubAlbum, nberAlbums ?? "")
        }
        return text
    }
    
    private func fontSizeFor(label: UILabel?, nberLines: Int) -> CGFloat {
        // Check label is not nil
        guard let label = label else { return 17.0 }
        let font = UIFont.systemFont(ofSize: 17)
        
        // Check that we can adjust the font
        if (label.adjustsFontSizeToFitWidth == false) ||
            (label.minimumScaleFactor >= 1.0) {
            // Font adjustment is disabled
            return font.pointSize
        }

        // Should we scale the font?
        var unadjustedWidth: CGFloat = 1.0
        if let text = label.text {
            unadjustedWidth = text.size(withAttributes: [NSAttributedString.Key.font: font]).width
        }
        let width: CGFloat = label.frame.size.width
        let height: CGFloat = unadjustedWidth / CGFloat(nberLines)
        var scaleFactor: CGFloat = width / height
        if scaleFactor >= 1.0 {
            // The text already fits at full font size
            return font.pointSize
        }

        // Respect minimumScaleFactor
        scaleFactor = fmax(scaleFactor, label.minimumScaleFactor)
        let newFontSize: CGFloat = font.pointSize * scaleFactor

        // Uncomment this if you insist on integer font sizes
        //newFontSize = floor(newFontSize);

        return newFontSize
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Pause the ongoing image download if needed
        if let imageURL = self.imageURL {
            PwgSession.shared.pauseDownload(atURL: imageURL)
        }
        
        // Reset cell
        self.albumName.text = NSLocalizedString("loadingHUD_label", comment: "Loading…")
        self.albumComment.attributedText = NSAttributedString()
        self.albumThumbnail.image = pwgImageType.album.placeHolder
        self.numberOfImages.text = ""
        self.recentlyModified.isHidden = true
    }
}


extension UIView {
    func addInnerShadowToRoundedView() {
        let innerShadowLayer = CAShapeLayer()
        innerShadowLayer.frame = bounds
        
        // Constants
        let cornerRadius = self.layer.cornerRadius
        let color = AppVars.shared.isDarkPaletteActive ? UIColor.white.cgColor : UIColor.black.cgColor
        let opacity: Float = AppVars.shared.isDarkPaletteActive ? 0.3 : 0.2

        // Create rounded rect path
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        let outerPath = UIBezierPath(roundedRect: bounds.insetBy(dx: -20, dy: -20), cornerRadius: cornerRadius)
        
        outerPath.append(path.reversing())

        innerShadowLayer.path = outerPath.cgPath
        innerShadowLayer.fillRule = .evenOdd
        innerShadowLayer.shadowColor = color
        innerShadowLayer.shadowOffset = CGSize(width: 0, height: 0)
        innerShadowLayer.shadowOpacity = opacity
        innerShadowLayer.shadowRadius = 3
        innerShadowLayer.fillColor = color
        
        // Mask to the rounded bounds
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        innerShadowLayer.mask = maskLayer
        
        layer.addSublayer(innerShadowLayer)
    }
}
