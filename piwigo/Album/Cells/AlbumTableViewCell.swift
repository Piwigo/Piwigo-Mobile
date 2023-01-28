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

        // Album name
        albumName.text = albumData?.name ?? "—?—"
        let fontSize = fontSizeFor(label: albumName, nberLines: 2)
        albumName.font = UIFont.systemFont(ofSize: fontSize)

        // Album description
        if let description = albumData?.comment, description.string.isEmpty == false {
            let desc = NSMutableAttributedString(attributedString: description)
            let wholeRange = NSRange(location: 0, length: desc.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorText(),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13),
                NSAttributedString.Key.paragraphStyle: style
            ]
            desc.addAttributes(attributes, range: wholeRange)
            albumComment.attributedText = desc
        }
        else {  // No description
            if NetworkVars.hasAdminRights {
                albumComment.text = NSLocalizedString("createNewAlbumDescription_noDescription", comment: "no description")
                albumComment.textColor = UIColor.piwigoColorRightLabel()
            } else {
                albumComment.text = ""
            }
        }
        albumComment.font = albumComment.font.withSize(UIFont.fontSizeFor(label: albumComment, nberLines: 3))

        // Number of images and sub-albums
        numberOfImages.textColor = UIColor.piwigoColorText()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        if albumData?.nbSubAlbums ?? 0 == 0 {
            // There are no sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.nbImages ?? 0))
            numberOfImages.text = (albumData?.nbImages ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
        }
        else if albumData?.totalNbImages ?? 0 == 0 {
            // There are no images but sub-albums
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            numberOfImages.text = (albumData?.nbSubAlbums ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums ?? "")
        }
        else {
            // There are images and sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.totalNbImages ?? 0))
            var nberOfImages = (albumData?.totalNbImages ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
            nberOfImages += ", "
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.nbSubAlbums ?? 0))
            nberOfImages += (albumData?.nbSubAlbums ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums ?? "")
            numberOfImages.text = nberOfImages
        }
        numberOfImages.font = numberOfImages.font.withSize(UIFont.fontSizeFor(label: numberOfImages, nberLines: 1))

        // Add renaming, moving and deleting capabilities when user has admin rights
        if let _ = albumData, NetworkVars.hasAdminRights {
            handleButton.isHidden = false
        }

        // Display recent icon when images have been uploaded recently
        DispatchQueue.global(qos: .userInteractive).async {
            guard let dateLast = albumData?.dateLast else { return }
            let timeSinceLastUpload: TimeInterval = dateLast.timeIntervalSinceNow
            var indexOfPeriod: Int = AlbumVars.shared.recentPeriodIndex
            indexOfPeriod = min(indexOfPeriod, AlbumVars.shared.recentPeriodList.count - 1)
            indexOfPeriod = max(0, indexOfPeriod)
            let periodInDays: Int = AlbumVars.shared.recentPeriodList[indexOfPeriod]
            if timeSinceLastUpload > TimeInterval(-24*3600*periodInDays) {
                DispatchQueue.main.async {
                    self.recentBckg.tintColor = UIColor(white: 0, alpha: 0.3)
                    self.recentImage.tintColor = UIColor.white
                    self.recentBckg.isHidden = false
                    self.recentImage.isHidden = false
                }
            }
        }
        
        // Display album image
        let placeHolder = UIImage(named: "placeholder")!

        // Do we have an URL? and all IDs for storing it (we should)?
        guard let thumbUrl = albumData?.thumbnailUrl,
              let thumbID = albumData?.thumbnailId,
              let serverID = albumData?.server?.uuid else {
            // No album thumbnail URL
            backgroundImage.image = placeHolder
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
                self.backgroundImage.image = placeHolder
            }
        }
        download?.getImage()
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

    
    func configImage(_ image: UIImage) {
        // Initialisation
        let size: CGSize = self.backgroundImage.bounds.size
        let scale = CGFloat(fmax(1.0, self.backgroundImage.traitCollection.displayScale))

        // Process image in the background
        DispatchQueue.global(qos: .userInitiated).async {
            // Process saliency
            var finalImage:UIImage = image
            if #available(iOS 13.0, *) {
                if let croppedImage = image.processSaliency() {
                    finalImage = croppedImage
                }
            }
            
            // Reduce size?
            let imageSize: CGSize = finalImage.size
            if fmax(imageSize.width, imageSize.height) > fmax(size.width, size.height) * scale {
                let albumImage = ImageUtilities.downsample(image: finalImage, to: size, scale: scale)
                DispatchQueue.main.async { [self] in
                    self.backgroundImage.image = albumImage
                }
            } else {
                DispatchQueue.main.async { [self] in
                    self.backgroundImage.image = finalImage
                }
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        download?.task?.cancel()
        download = nil
        backgroundImage.image = UIImage(named: "placeholder")
        albumName.text = ""
        numberOfImages.text = ""
        recentBckg.isHidden = true
        recentImage.isHidden = true
        handleButton.isHidden = true
    }
}
