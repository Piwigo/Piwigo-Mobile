//
//  AlbumCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/07/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class AlbumCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var albumThumbnail: UIImageView!
    @IBOutlet weak var albumName: UILabel!
    @IBOutlet weak var numberOfImages: UILabel!
    @IBOutlet weak var recentBckg: UIImageView!
    @IBOutlet weak var recentImage: UIImageView!
    
    func config(withAlbumData albumData: Album?) {
        // General settings
        recentBckg.tintColor = UIColor(white: 0, alpha: 0.3)
        recentImage.tintColor = UIColor.white
        applyColorPalette()
        
        // Album name (Piwigo orange colour)
        albumName.text = albumData?.name ?? "—?—"
        
        // Number of images and sub-albums
        numberOfImages.text = getNberOfImages(fromAlbumData: albumData)
        
        // Added "0 day" option in version 3.1.2 for allowing user to disable "recent" icon
        if CacheVars.shared.recentPeriodIndexCorrectedInVersion321 == false,
           let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           version.compare(CacheVars.shared.recentPeriodListChangedInVersion312) == .orderedSame {
            CacheVars.shared.recentPeriodIndex += 1
            CacheVars.shared.recentPeriodIndexCorrectedInVersion321 = true
        }
        
        // If requested, display recent icon when images have been uploaded recently
        let timeSinceLastUpload = Date.timeIntervalSinceReferenceDate - (albumData?.dateLast ?? TimeInterval(-3187296000))
        var indexOfPeriod: Int = CacheVars.shared.recentPeriodIndex
        indexOfPeriod = min(indexOfPeriod, CacheVars.shared.recentPeriodList.count - 1)
        indexOfPeriod = max(0, indexOfPeriod)
        let periodInDays: Int = CacheVars.shared.recentPeriodList[indexOfPeriod]
        let isRecent = timeSinceLastUpload < TimeInterval(24*3600*periodInDays)
        if self.recentBckg.isHidden == isRecent {
            self.recentBckg.isHidden = !isRecent
            self.recentImage.isHidden = !isRecent
        }
        
        // Can we add a representative if needed?
        if albumData?.thumbnailUrl == nil || albumData?.thumbnailId == Int64.zero,
           let images = albumData?.images, let firstImage = images.first {
            // Set representative (case where images were uploaded recently)
            albumData?.thumbnailId = firstImage.pwgID
            let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
            albumData?.thumbnailUrl = ImageUtilities.getURL(firstImage, ofMinSize: thumnailSize) as NSURL?
        }
        
        // Retrieve image from cache or download it
        self.albumThumbnail.layoutIfNeeded()   // Ensure imageView in its final size
        let placeHolder = UIImage(named: "placeholder")!
        let scale = max(self.albumThumbnail.traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(self.albumThumbnail.bounds.size.width * scale, self.albumThumbnail.bounds.size.height * scale)
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        PwgSession.shared.getImage(withID: albumData?.thumbnailId, ofSize: thumbSize,
                                   atURL: albumData?.thumbnailUrl as? URL,
                                   fromServer: albumData?.user?.server?.uuid,
                                   placeHolder: placeHolder) { [weak self] cachedImageURL in
            self?.downsampleImage(atURL: cachedImageURL, to: cellSize)
        } failure: { [weak self] _ in
            self?.setThumbnailWithImage(placeHolder)
        }
    }
    
    private func downsampleImage(atURL fileURL: URL, to cellSize: CGSize) {
        // Process image in the background
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            // Downsample image in cache
            let cachedImage = ImageUtilities.downsample(imageAt: fileURL, to: cellSize)
            
            // Process saliency if needed
            if #available(iOS 13.0, *) {
                self.setThumbnailWithImage(cachedImage.processSaliency() ?? cachedImage)
            } else {
                self.setThumbnailWithImage(cachedImage)
            }
        }
    }
    
    private func setThumbnailWithImage(_ image: UIImage) {
        DispatchQueue.main.async { [self] in
            self.albumThumbnail.image = image
        }
    }

    func applyColorPalette() {
        backgroundColor = UIColor.piwigoColorBackground()
        contentView.backgroundColor = UIColor.piwigoColorCellBackground()
        albumName.textColor = UIColor.piwigoColorText()
        numberOfImages.textColor = UIColor.piwigoColorText()
    }
    
    private func getNberOfImages(fromAlbumData albumData: Album?) -> String {
        // Constants
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        let singleImage = NSLocalizedString("singleImageCount", comment: "%@ photo")
        let severalImages = NSLocalizedString("severalImagesCount", comment: "%@ photos")
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

    override func prepareForReuse() {
        super.prepareForReuse()
        albumThumbnail.image = nil
    }
}
