//
//  PasteboardImagesViewController+UploadSwitchDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit

// MARK: - UploadSwitchDelegate Methods
extension PasteboardImagesViewController: UploadSwitchDelegate
{
    @objc func didSelectCurrentCounter(value: Int64) {
        albumDelegate?.didSelectCurrentCounter(value: value)
    }
    
    @objc func uploadOptionsViewDidDisappear(withUploadsQueued uploadsQueued: Bool) {
        // Deselect cells when an error was encountered
        if uploadsQueued == false { self.cancelSelect() }
        
        // Release memory
        self.uploadRequests = []
        
        // Update the navigation bar
        updateNavBar()
    }
}
