//
//  AlbumCollectionViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 14/07/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgAPIKit
import PwgCacheKit
import PwgUIKit

class AlbumCollectionViewCell: UICollectionViewCell {
    
    var album: Album?
    var imageURL: URL?

    @IBOutlet weak var albumThumbnail: UIImageView!
    @IBOutlet weak var recentlyModified: UIImageView!
    @IBOutlet weak var albumName: UILabel!
    @IBOutlet weak var numberOfImages: UILabel!
    @IBOutlet weak var legendHeight: NSLayoutConstraint!
    
    func config(withAlbum album: Album?) {
        // Store album data
        self.album = album

        // General settings
        applyColorPalette()
        
        // Legend
        albumName.text = album?.name ?? "—?—"
        numberOfImages.text = getNberOfImages(fromAlbumData: album)
        legendHeight.constant = UIFont.preferredFont(forTextStyle: .headline).lineHeight + UIFont.preferredFont(forTextStyle: .footnote).lineHeight + 8.0

        // If requested, display recent icon when images have been uploaded recently
        let timeSinceLastUpload = Date.timeIntervalSinceReferenceDate - (album?.dateLast ?? TimeInterval(-3187296000))
        var indexOfPeriod: Int = ServerVars.shared.recentPeriodIndex
        indexOfPeriod = min(indexOfPeriod, ServerVars.shared.recentPeriodList.count - 1)
        indexOfPeriod = max(0, indexOfPeriod)
        let periodInDays: Int = ServerVars.shared.recentPeriodList[indexOfPeriod]
        let isRecent = timeSinceLastUpload < TimeInterval(24*3600*periodInDays)
        self.recentlyModified.isHidden = !isRecent

        // Can we add a representative if needed?
        if album?.thumbnailUrl == nil || album?.thumbnailId == Int64.zero,
           let images = album?.images, let firstImage = images.first {
            // Set representative (case where images were uploaded recently)
            album?.thumbnailId = firstImage.pwgID
            let thumnailSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
            album?.thumbnailUrl = firstImage.url(forMaxSize: thumnailSize) as NSURL?
        }
        
        // Retrieve image from cache or download it
        self.albumThumbnail.layoutIfNeeded()   // Ensure imageView in its final size
        let scale = max(self.albumThumbnail.traitCollection.displayScale, 1.0)
        let cellSize = CGSizeMake(self.albumThumbnail.bounds.size.width * scale, self.albumThumbnail.bounds.size.height * scale)
        let thumbSize = pwgImageSize(rawValue: AlbumVars.shared.defaultAlbumThumbnailSize) ?? .medium
        imageURL = album?.thumbnailUrl as? URL
        /// The cell identifies itself so that a new request replaces the handlers of its
        /// previous one, see ImageDownload.addHandlers().
        let requester = ObjectIdentifier(self)
        Task {
            let expectedURL = imageURL
            await ImageDownloader.shared.getImage(withID: album?.thumbnailId, ofSize: thumbSize, type: .album,
                                            atURL: imageURL, fromServer: album?.user?.server?.uuid,
                                            requestedBy: requester) { [weak self = self] cachedImageURL in
                // Downsample image in cache
                let cachedImage = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, for: .album)
                
                // Guard against cell reuse and set album thumbnail
                Task { @MainActor in
                    guard let self, self.imageURL == expectedURL else { return }
                    self.albumThumbnail.image = cachedImage
                }
            } failure: { [weak self = self] _ in
                // Set album thumbnail
                Task { @MainActor in
                    guard let self else { return }
                    self.albumThumbnail.image = pwgImageType.album.placeHolder
                }
            }
        }
    }

    @MainActor
    func applyColorPalette() {
        backgroundColor = PwgColor.background
        contentView.backgroundColor = PwgColor.cellBackground
        albumName.textColor = PwgColor.gray
        numberOfImages.textColor = PwgColor.rightLabel
        recentlyModified?.tintColor = UIColor.white
        recentlyModified?.layer.shadowColor = UIColor.black.cgColor
        recentlyModified?.layer.shadowOpacity = 1.0
    }
    
    private func getNberOfImages(fromAlbumData albumData: Album?) -> String {
        // Determine string
        var text = ""
        if albumData?.nbSubAlbums ?? Int32.zero == Int32.zero {
            // There are no sub-albums
            text = Localized.imageCount(Int(albumData?.nbImages ?? 0))
        }
        else if albumData?.totalNbImages ?? Int64.zero == Int64.zero {
            // There are no images but sub-albums
            text = Localized.subAlbumCount(Int(albumData?.nbSubAlbums ?? 0))
        }
        else {
            // There are images and sub-albums
            text = Localized.imageCount(Int(albumData?.totalNbImages ?? 0))
            text += ", "
            text += Localized.subAlbumCount(Int(albumData?.nbSubAlbums ?? 0))
        }
        return text
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Pause the ongoing image download if needed
//        if let imageURL = self.imageURL {
//            Task { await ImageDownloader.shared.pauseDownload(atURL: imageURL) }
//        }
        
        // Reset cell
        self.imageURL = nil
        self.albumName.text = Localized.loading
        self.numberOfImages.text = ""
        self.recentlyModified.isHidden = true
        self.albumThumbnail.image = pwgImageType.album.placeHolder
    }
}
