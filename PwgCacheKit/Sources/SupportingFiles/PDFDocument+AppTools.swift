//
//  PDFDocument+AppTools.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 14/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import PDFKit
import UIKit

extension PDFDocument {
    /// Returns an image of the first page of the document, or nil if it could not be created.
    public func extractedImage() -> UIImage? {
        guard let firstPage = page(at: 0)
        else { return nil }
        let pageSize = firstPage.bounds(for: .mediaBox).size
        return firstPage.thumbnail(of: pageSize, for: .mediaBox)
    }
}
