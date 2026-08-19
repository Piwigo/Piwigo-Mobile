//
//  ImageViewController+PDF.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/08/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Video
extension ImageViewController
{
    // MARK: - PDF Page Count
    /// Like the duration of a video, the number of pages of a PDF is not stored in cache
    /// and is known only once the document is opened.
    @objc func didKnowPdfPageCount(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // NOP unless the count is the one of the presented document
            guard let pwgID = notification.userInfo?["pwgID"] as? Int64,
                  imageData?.pwgID == pwgID
            else { return }

            // The title view reads the count from the presented PDF view controller
            setTitleViewFromImageData()
        }
    }
}
