//
//  PdfPageViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 20/07/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import PDFKit

class PdfPageViewController: PDFPage {
    
    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        // Draw original content
        super.draw(with: box, to: context)

    }
}
