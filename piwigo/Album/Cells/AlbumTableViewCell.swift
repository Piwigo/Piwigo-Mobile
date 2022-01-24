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
    func config(with albumData: PiwigoAlbumData) {
        // General settings
        backgroundColor = UIColor.piwigoColorBackground()
        contentView.layer.cornerRadius = 14
        contentView.backgroundColor = UIColor.piwigoColorCellBackground()
        selectionStyle = UITableViewCell.SelectionStyle.none
        topCut.layer.cornerRadius = 7
        topCut.backgroundColor = UIColor.piwigoColorBackground()
        bottomCut.layer.cornerRadius = 7
        bottomCut.backgroundColor = UIColor.piwigoColorBackground()

        // Album name
        albumName.text = albumData.name
        albumName.font = UIFont.piwigoFontButton()
        albumName.textColor = UIColor.piwigoColorOrange()
        albumName.font =  albumName.font.withSize(UIFont.fontSizeFor(label: albumName, nberLines: 2))

        // Album comment
        if albumData.comment.count == 0 {
            if NetworkVarsObjc.hasAdminRights {
                albumComment.text = NSLocalizedString("createNewAlbumDescription_noDescription", comment: "no description")
                albumComment.textColor = UIColor.piwigoColorRightLabel()
            } else {
                albumComment.text = ""
            }
        } else {
            albumComment.text = albumData.comment
            albumComment.textColor = UIColor.piwigoColorText()
        }
        albumComment.font = UIFont.piwigoFontSmall()
        albumComment.font = albumComment.font.withSize(UIFont.fontSizeFor(label: albumComment, nberLines: 3))

        // Number of images and sub-albums
        numberOfImages.font = UIFont.piwigoFontTiny()
        numberOfImages.textColor = UIColor.piwigoColorText()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        if albumData.numberOfSubCategories == 0 {
            // There are no sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData.numberOfImages))
            numberOfImages.text = (albumData.numberOfImages > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
        }
        else if albumData.totalNumberOfImages == 0 {
            // There are no images but sub-albums
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData.numberOfSubCategories))
            numberOfImages.text = (albumData.numberOfSubCategories > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums ?? "")
        }
        else {
            // There are images and sub-albums
            let nberImages = numberFormatter.string(from: NSNumber(value: albumData.totalNumberOfImages))
            var nberOfImages = (albumData.totalNumberOfImages > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalImagesCount", comment: "%@ photos"), nberImages ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleImageCount", comment: "%@ photo"), nberImages ?? "")
            nberOfImages += ", "
            let nberAlbums = numberFormatter.string(from: NSNumber(value: albumData.numberOfSubCategories))
            nberOfImages += (albumData.numberOfSubCategories > 1)
                ? String.localizedStringWithFormat(NSLocalizedString("severalSubAlbumsCount", comment: "%@ sub-albums"), nberAlbums ?? "")
                : String.localizedStringWithFormat(NSLocalizedString("singleSubAlbumCount", comment: "%@ sub-album"), nberAlbums ?? "")
            numberOfImages.text = nberOfImages
        }
        numberOfImages.font = numberOfImages.font.withSize(UIFont.fontSizeFor(label: numberOfImages, nberLines: 1))

        // Add renaming, moving and deleting capabilities when user has admin rights
        if NetworkVarsObjc.hasAdminRights {
            // Handle
            handleButton.layer.cornerRadius = 7
            handleButton.backgroundColor = UIColor.piwigoColorOrange()
            handleButton.isHidden = false
        }

        // Display recent icon when images have been uploaded recently
        DispatchQueue.global(qos: .userInteractive).async {
            guard let dateLast = CategoriesData.sharedInstance()
                    .getDateLastOfCategories(inCategory: albumData.albumId) else { return }
            let timeSinceLastUpload = dateLast.timeIntervalSinceNow
            var indexOfPeriod = AlbumVars.recentPeriodIndex
            indexOfPeriod = min(indexOfPeriod, AlbumVars.recentPeriodList.count - 1)
            indexOfPeriod = max(0, indexOfPeriod)
            let periodInDays = AlbumVars.recentPeriodList[indexOfPeriod]
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
        backgroundImage.layer.cornerRadius = 10
        let placeHolder = UIImage(named: "placeholder")

        // Do we have a correct URL?
        guard let thumbUrlStr = albumData.albumThumbnailUrl,
              let thumbURL = URL(string: thumbUrlStr) else {
            // No album thumbnail URL
            albumData.categoryImage = placeHolder
            backgroundImage.image = placeHolder
            return
        }

        // Do we have the thumbnail in cache?
        if let cachedImage = albumData.categoryImage,
           (cachedImage.cgImage?.height ?? 0) * (cachedImage.cgImage?.bytesPerRow ?? 0) > 0,
           (albumData.categoryImage != placeHolder) {
            // Album thumbnail in memory
            backgroundImage.image = albumData.categoryImage
            return
        }

        // Retrieve the image file
        let size = backgroundImage.bounds.size
        let scale = CGFloat(fmax(1.0, backgroundImage.traitCollection.displayScale))
        var thumbRequest = URLRequest(url: thumbURL)
        thumbRequest.addValue("image/*", forHTTPHeaderField: "Accept")
        backgroundImage.setImageWith(thumbRequest,
                                     placeholderImage: placeHolder) { request, response, image in
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
                        albumData.categoryImage = albumImage
                        self.backgroundImage.image = albumImage
                    }
                } else {
                    DispatchQueue.main.async {
                        albumData.categoryImage = finalImage
                        self.backgroundImage.image = finalImage
                    }
                }
            }
        } failure: { _, _, error in
            #if DEBUG
            debugPrint("setupWithAlbumData — Fail to get album image at \(albumData.albumThumbnailUrl ?? "—?—")")
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
    }
}
