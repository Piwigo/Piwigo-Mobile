//
//  UploadSettingsViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 31/05/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

extension UploadSettingsViewController {
    
    // MARK: - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("imageUploadHeaderTitle_upload", comment: "Upload Settings"))
        let text = NSLocalizedString("imageUploadHeaderText_upload", comment: "Please set the upload parameters to apply to the selection of photos/videos")
        return (title, text)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 3)) ? 1 : 0
        switch row {
        case 2 /* Upload Photo Size */,
             3 /* Upload Video Size */,
             6 /* Rename Filename Before Upload */:
            return true
        default:
            return false
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var row = indexPath.row
        row += (!resizeImageOnUpload && (row > 1)) ? 2 : 0
        row += (!compressImageOnUpload && (row > 3)) ? 1 : 0
        switch row {
        case 2 /* Upload Photo Size */:
            // Present the Upload Photo Size selector
            let uploadPhotoSizeSB = UIStoryboard(name: "UploadPhotoSizeViewController", bundle: nil)
            guard let uploadPhotoSizeVC = uploadPhotoSizeSB.instantiateViewController(withIdentifier: "UploadPhotoSizeViewController") as? UploadPhotoSizeViewController
            else { preconditionFailure("Could not load UploadPhotoSizeViewController") }
            uploadPhotoSizeVC.delegate = self
            uploadPhotoSizeVC.photoMaxSize = photoMaxSize
            navigationController?.pushViewController(uploadPhotoSizeVC, animated: true)
        case 3 /* Upload Video Size */:
            // Present the Upload Photo Size selector
            let uploadVideoSizeSB = UIStoryboard(name: "UploadVideoSizeViewController", bundle: nil)
            guard let uploadVideoSizeVC = uploadVideoSizeSB.instantiateViewController(withIdentifier: "UploadVideoSizeViewController") as? UploadVideoSizeViewController
            else { preconditionFailure("Could not load UploadVideoSizeViewController") }
            uploadVideoSizeVC.delegate = self
            uploadVideoSizeVC.videoMaxSize = videoMaxSize
            navigationController?.pushViewController(uploadVideoSizeVC, animated: true)
        case 6 /* Rename Filename Before Upload */:
            // Present the Rename File selector
            let filenameSB = UIStoryboard(name: "RenameFileViewController", bundle: nil)
            guard let filenameVC = filenameSB.instantiateViewController(withIdentifier: "RenameFileViewController") as? RenameFileViewController
            else { preconditionFailure("Could not load RenameFileViewController") }
            filenameVC.delegate = self
            filenameVC.startValue = startValue
            filenameVC.prefixBeforeUpload = prefixBeforeUpload
            filenameVC.prefixActions = prefixActions
            filenameVC.replaceBeforeUpload = replaceBeforeUpload
            filenameVC.replaceActions = replaceActions
            filenameVC.suffixBeforeUpload = suffixBeforeUpload
            filenameVC.suffixActions = suffixActions
            filenameVC.changeCaseBeforeUpload = changeCaseBeforeUpload
            filenameVC.caseOfFileExtension = caseOfFileExtension
            navigationController?.pushViewController(filenameVC, animated: true)
        default:
            break
        }
    }

    
    // MARK: - Footer
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
}
