//
//  LocalImagesViewController+UploadSwitchDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import PwgKit
import PwgCacheKit
import PwgUploadKit

// MARK: UploadSwitchDelegate Methods
extension LocalImagesViewController: UploadSwitchDelegate
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
        
        // Disable sleep mode if needed
        if #unavailable(iOS 26.0) {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        
        // Display help views only when uploads are launched
        if (self.uploads.fetchedObjects ?? []).isEmpty { return }
        
        // Display help views less than once a day
        let dateOfLastHelpView = AppVars.shared.dateOfLastHelpView
        let diff = Date().timeIntervalSinceReferenceDate - dateOfLastHelpView
        if diff > TimeInterval(86400) { return }
            
        // Determine which help pages should be presented
        var displayHelpPagesWithID: [UInt16] = []
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00010000) == 0 {
            displayHelpPagesWithID.append(5)     // i.e. submit upload requests and let it go
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00001000) == 0 {
            displayHelpPagesWithID.append(4)     // i.e. remove images from camera roll
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00100000) == 0 {
            displayHelpPagesWithID.append(6)     // i.e. manage upload requests in queue
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_00000010) == 0 {
            displayHelpPagesWithID.append(2)     // i.e. use background uploading
        }
        if (AppVars.shared.didWatchHelpViews & 0b00000000_01000000) == 0 {
            displayHelpPagesWithID.append(7)     // i.e. use auto-uploading
        }
        if displayHelpPagesWithID.count > 0 {
            // Present unseen upload management help views
            let helpVC = HelpUtilities.getHelpViewController(showingPagesWithIDs: displayHelpPagesWithID)
            if view.traitCollection.userInterfaceIdiom == .phone {
                helpVC.popoverPresentationController?.permittedArrowDirections = .up
                navigationController?.present(helpVC, animated:true)
            } else {
                helpVC.modalPresentationStyle = .formSheet
                helpVC.modalTransitionStyle = .coverVertical
                helpVC.popoverPresentationController?.sourceView = view
                navigationController?.present(helpVC, animated: true)
            }
        }
    }
}
