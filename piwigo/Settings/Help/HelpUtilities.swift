//
//  HelpUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/10/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class HelpUtilities {
    // Return appropriate help view controller
    static func getHelpViewController(showingPagesWithIDs pageIDs: [UInt16]? = nil) -> HelpViewController {
        let helpSB = UIStoryboard(name: "HelpViewController", bundle: nil)
        guard let helpVC = helpSB.instantiateViewController(withIdentifier: "HelpViewController") as? HelpViewController
        else { preconditionFailure("Could not load HelpViewController from storyboard")}

        // Update this list after deleting/creating Help##ViewControllers
        if let pageIDs {
            helpVC.displayHelpPagesWithID = pageIDs
        }
        else {
            if NetworkVars.shared.usesUploadAsync {
                helpVC.displayHelpPagesWithID = [8,1,5,6,2,4,7,3,9]
            } else {
                helpVC.displayHelpPagesWithID = [8,1,5,6,4,3,9]
            }
        }
        return helpVC
    }
}
