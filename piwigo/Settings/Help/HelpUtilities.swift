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

struct HelpUtilities {
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
            helpVC.displayHelpPagesWithID = [8,1,5,6,2,4,7,9,3]
        }
        return helpVC
    }
}
