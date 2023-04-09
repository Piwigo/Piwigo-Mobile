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

class AlbumTableViewCell: MGSwipeTableCell {
    
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var topCut: UIButton!
    @IBOutlet weak var bottomCut: UIButton!
    @IBOutlet weak var albumName: UILabel!
    @IBOutlet weak var albumComment: UILabel!
    @IBOutlet weak var numberOfImages: UILabel!
    @IBOutlet weak var handleButton: UIButton!
    @IBOutlet weak var recentBckg: UIImageView!
    @IBOutlet weak var recentImage: UIImageView!
    
    private var download: ImageDownload?

    func config(withAlbumData albumData: Album?) {
        // General settings
        backgroundColor = UIColor.piwigoColorBackground()
        contentView.backgroundColor = UIColor.piwigoColorCellBackground()
        selectionStyle = UITableViewCell.SelectionStyle.none
        topCut.backgroundColor = UIColor.piwigoColorBackground()
        bottomCut.backgroundColor = UIColor.piwigoColorBackground()
        recentBckg.tintColor = UIColor(white: 0, alpha: 0.3)
        recentImage.tintColor = UIColor.white

        // Album name (Piwigo orange colour)
        var text = albumData?.name ?? "—?—"
        if albumName.text != text {
            albumName.text = text
        }
        var fontSize = fontSizeFor(label: albumName, nberLines: 2)
        var font = UIFont.systemFont(ofSize: fontSize)
        if albumName.font != font {
            albumName.font = font
        }
        
        // Album description (colour depends on text content)
        let desc = getDescription(fromAlbumData: albumData)
        if albumComment.attributedText != desc {
            albumComment.attributedText = desc
        }
        fontSize = UIFont.fontSizeFor(label: albumComment, nberLines: 3)
        font = UIFont.systemFont(ofSize: fontSize)
        if albumComment.font != font {
            albumComment.font = font
        }

        // Number of images and sub-albums
        text = getNberOfImages(fromAlbumData: albumData)
        if numberOfImages.text != text {
            numberOfImages.text = text
        }
        let color = UIColor.piwigoColorText()
        if numberOfImages.textColor != color {
            numberOfImages.textColor = color
        }
        font = UIFont.systemFont(ofSize: 10, weight: .light)
        if numberOfImages.font != font {
            numberOfImages.font = font
        }

        // Add renaming, moving and deleting capabilities when user has admin rights
        if albumData != nil, handleButton.isHidden == NetworkVars.hasAdminRights {
            handleButton.isHidden = !NetworkVars.hasAdminRights
        }

        // Display recent icon when images have been uploaded recently
        DispatchQueue.global(qos: .userInteractive).async {
            self.showHideIsRecent(albumData: albumData)
        }
        
        // Display album image
        let placeHolder = UIImage(named: "placeholder")!

        // Can we add a representative if needed?
        if albumData?.thumbnailUrl == nil || albumData?.thumbnailId == Int64.zero,
           let images = albumData?.images, let firstImage = images.first {
            // Set representative (case where images were uploaded recently)
            albumData?.thumbnailId = firstImage.pwgID
            let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
            albumData?.thumbnailUrl = ImageUtilities.getURL(firstImage, ofMinSize: thumnailSize) as NSURL?
        }
        
        // Do we have a representative?
        guard let thumbUrl = albumData?.thumbnailUrl,
              let thumbID = albumData?.thumbnailId,
              let serverID = albumData?.user?.server?.uuid else {
            // No album thumbnail URL
            if backgroundImage.image != placeHolder {
                backgroundImage.image = placeHolder
            }
            return
        }

        // Retrieve image from cache or download it
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        download = ImageDownload(imageID: thumbID, ofSize: thumbSize, atURL: thumbUrl as URL,
                                 fromServer: serverID, placeHolder: placeHolder) { cachedImage in
            DispatchQueue.main.async {
                self.configImage(cachedImage)
            }
        } failure: { _ in
            DispatchQueue.main.async {
                // No album thumbnail URL
                if self.backgroundImage.image != placeHolder {
                    self.backgroundImage.image = placeHolder
                }
            }
        }
        download?.getImage()
    }
    
    private func getDescription(fromAlbumData albumData: Album?) -> NSAttributedString {
        var desc = NSMutableAttributedString()
        // Any provided description?
        if let description = albumData?.comment, description.string.isEmpty == false {
            desc = NSMutableAttributedString(attributedString: description)
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)
        }
        else if NetworkVars.hasAdminRights {
            let noDesc = NSLocalizedString("createNewAlbumDescription_noDescription", comment: "no description")
            desc = NSMutableAttributedString(string: noDesc)
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorRightLabel(),
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
        let singleImage = NSLocalizedString("severalImagesCount", comment: "%@ photos")
        let severalImages = NSLocalizedString("singleImageCount", comment: "%@ photo")
        let singleSubAlbum = NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album")
        let severalSubAlbums = NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums")
        // Determine string
        var text = ""
        if albumData?.nbSubAlbums ?? 0 == 0 {
            // There are no sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.nbImages ?? 0))
            text = (albumData?.nbImages ?? 0 > 1)
                ? String.localizedStringWithFormat(singleImage, nberImages ?? "")
                : String.localizedStringWithFormat(severalImages, nberImages ?? "")
        }
        else if albumData?.totalNbImages ?? 0 == 0 {
            // There are no images but sub-albums
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            text = (albumData?.nbSubAlbums ?? 0 > 1)
                ? String.localizedStringWithFormat(severalSubAlbums, nberAlbums ?? "")
                : String.localizedStringWithFormat(singleSubAlbum, nberAlbums ?? "")
        }
        else {
            // There are images and sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.totalNbImages ?? 0))
            text = (albumData?.totalNbImages ?? 0 > 1)
                ? String.localizedStringWithFormat(severalImages, nberImages ?? "")
                : String.localizedStringWithFormat(singleImage, nberImages ?? "")
            text += ", "
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            text += (albumData?.nbSubAlbums ?? 0 > 1)
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

    private func showHideIsRecent(albumData: Album?) {
        guard let dateLast = albumData?.dateLast else { return }
        let timeSinceLastUpload: TimeInterval = dateLast.timeIntervalSinceNow
        var indexOfPeriod: Int = AlbumVars.shared.recentPeriodIndex
        indexOfPeriod = min(indexOfPeriod, AlbumVars.shared.recentPeriodList.count - 1)
        indexOfPeriod = max(0, indexOfPeriod)
        let periodInDays: Int = AlbumVars.shared.recentPeriodList[indexOfPeriod]
        let isRecent = timeSinceLastUpload > TimeInterval(-24*3600*periodInDays)
        DispatchQueue.main.async {
            if self.recentBckg.isHidden == isRecent {
                self.recentBckg.isHidden = !isRecent
                self.recentImage.isHidden = !isRecent
            }
        }
    }
    
    private func configImage(_ image: UIImage) {
        // Process image in the background
        DispatchQueue.global(qos: .userInitiated).async {
            // Process saliency
            var finalImage:UIImage = image
            if #available(iOS 13.0, *) {
                if let croppedImage = image.processSaliency() {
                    finalImage = croppedImage
                }
            }

            // Set image
            DispatchQueue.main.async {
                self.backgroundImage.image = finalImage
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        download?.task?.cancel()
        download = nil
    }
}
