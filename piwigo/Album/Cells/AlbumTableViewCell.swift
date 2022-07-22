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

@objc
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

    @objc
    func config(withAlbumData albumData: PiwigoAlbumData?) {
        // General settings
        backgroundColor = UIColor.piwigoColorBackground()
        contentView.backgroundColor = UIColor.piwigoColorCellBackground()
        selectionStyle = UITableViewCell.SelectionStyle.none
        topCut.backgroundColor = UIColor.piwigoColorBackground()
        bottomCut.backgroundColor = UIColor.piwigoColorBackground()

        // Album name
        albumName.text = albumData?.name ?? "—?—"
        albumName.font =  albumName.font.withSize(UIFont.fontSizeFor(label: albumName, nberLines: 2))

        // Album comment
        if let comment = albumData?.comment, comment.isEmpty == false {
            albumComment.attributedText = comment.htmlToAttributedString
            albumComment.textColor = UIColor.piwigoColorText()
        }
        else {  // No comment
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
        if albumData?.numberOfSubCategories ?? 0 == 0 {
            // There are no sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.numberOfImages ?? 0))
            numberOfImages.text = (albumData?.numberOfImages ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
        }
        else if albumData?.totalNumberOfImages ?? 0 == 0 {
            // There are no images but sub-albums
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.numberOfSubCategories ?? 0))
            numberOfImages.text = (albumData?.numberOfSubCategories ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums ?? "")
        }
        else {
            // There are images and sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData?.totalNumberOfImages ?? 0))
            var nberOfImages = (albumData?.totalNumberOfImages ?? 0 > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
            nberOfImages += ", "
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData?.numberOfSubCategories ?? 0))
            nberOfImages += (albumData?.numberOfSubCategories ?? 0 > 1)
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
            guard let catId = albumData?.albumId,
                  let dateLast = CategoriesData.sharedInstance()
                                    .getDateLastOfCategories(inCategory: catId) else { return }
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
        let placeHolder = UIImage(named: "placeholder")

        // Do we have a correct URL?
        guard let thumbUrlStr: String = albumData?.albumThumbnailUrl,
              let thumbURL = URL(string: thumbUrlStr) else {
            // No album thumbnail URL
            albumData?.categoryImage = placeHolder
            backgroundImage.image = placeHolder
            return
        }

        // Do we have the thumbnail in cache?
        if let cachedImage: UIImage = albumData?.categoryImage,
           let cgImage = cachedImage.cgImage, cgImage.height * cgImage.bytesPerRow > 0,
           (albumData?.categoryImage != placeHolder) {
            // Album thumbnail in memory
            backgroundImage.image = albumData?.categoryImage
            return
        }

        // Retrieve the image file
        let size: CGSize = backgroundImage.bounds.size
        let scale = CGFloat(fmax(1.0, backgroundImage.traitCollection.displayScale))
        var thumbRequest = URLRequest(url: thumbURL)
        thumbRequest.addValue("image/*", forHTTPHeaderField: "Accept")
        backgroundImage.setImageWith(thumbRequest, placeholderImage: placeHolder)
        { _, _, image in
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
                    DispatchQueue.main.async {
                        albumData?.categoryImage = albumImage
                        self.backgroundImage.image = albumImage
                    }
                } else {
                    DispatchQueue.main.async {
                        albumData?.categoryImage = finalImage
                        self.backgroundImage.image = finalImage
                    }
                }
            }
        } failure: { _, _, error in
            #if DEBUG
            debugPrint("setupWithAlbumData — Fail to get album image at \(albumData?.albumThumbnailUrl ?? "—?—")")
            #endif
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        backgroundImage.cancelImageDownloadTask()
        backgroundImage.image = UIImage(named: "placeholder")
        albumName.text = ""
        numberOfImages.text = ""
        recentBckg.isHidden = true
        recentImage.isHidden = true
        handleButton.isHidden = true
    }
}
