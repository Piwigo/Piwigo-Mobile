//
//  UploadQueueViewController+Delegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit
import uploadKit

// MARK: - UITableViewDelegate Methods
extension UploadQueueViewController: UITableViewDelegate
{
    // MARK: - UITableView - Headers
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if #available(iOS 13.0, *) {
            let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot()
                                            .sectionIdentifiers[section]) ?? SectionKeys.Section4
            return TableViewUtilities.shared.heightOfHeader(withTitle: sectionKey.name,
                                                            width: tableView.frame.size.width)
        } else {
            // Fallback on earlier versions
            var sectionName = SectionKeys.Section4.name
            if let sectionInfo = uploads.sections?[section] {
                let sectionKey = SectionKeys(rawValue: sectionInfo.name) ?? SectionKeys.Section4
                sectionName = sectionKey.name
            }
            return TableViewUtilities.shared.heightOfHeader(withTitle: sectionName,
                                                            width: tableView.frame.size.width)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "UploadImageHeaderView") as? UploadImageHeaderView
        else { preconditionFailure("Error: tableView.dequeueReusableHeaderFooterView does not return a UploadImageHeaderView!") }
        if #available(iOS 13.0, *) {
            let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
            header.config(with: sectionKey)
            return header
        } else {
            // Fallback on earlier versions
            if let sectionInfo = uploads.sections?[section] {
                let sectionKey = SectionKeys(rawValue: sectionInfo.name) ?? SectionKeys.Section4
                header.config(with: sectionKey)
            } else {
                header.config(with: SectionKeys.Section4)
            }
            return header
        }
    }
    

    // MARK: - UITableView - Rows
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Retreive upload object
        guard let cell = tableView.cellForRow(at: indexPath) as? UploadImageTableViewCell,
              let objectID = cell.objectID,
              let upload = try? self.mainContext.existingObject(with: objectID) as? Upload
        else { preconditionFailure("Managed object should be available") }
        
        // Create retry upload action
        let retry = UIContextualAction(style: .normal, title: nil,
                                       handler: { action, view, completionHandler in
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
                UploadManager.shared.findNextImageToUpload()
            }
            completionHandler(true)
        })
        retry.backgroundColor = .piwigoColorBrown()
        retry.image = UIImage(named: "swipeRetry.png")
        
        // Create trash/cancel upload action
        let cancel = UIContextualAction(style: .normal, title: nil,
                                        handler: { action, view, completionHandler in
            let savingContext = upload.managedObjectContext
            savingContext?.delete(upload)
            try? savingContext?.save()
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
                UploadManager.shared.findNextImageToUpload()
            }
            completionHandler(true)
        })
        cancel.backgroundColor = .red
        cancel.image = UIImage(named: "swipeCancel.png")

        // Associate actions
        switch upload.state {
        case .preparing, .prepared, .uploading, .uploaded, .finishing:
            return UISwipeActionsConfiguration(actions: [retry])
        case .preparingError, .uploadingError, .finishingError:
            return UISwipeActionsConfiguration(actions: [retry, cancel])
        case .waiting, .preparingFail, .formatError, .uploadingFail, .finishingFail, .finished, .moderated:
            return UISwipeActionsConfiguration(actions: [cancel])
        }
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let localIdentifier =  notification.userInfo?["localIdentifier"] as? String, !localIdentifier.isEmpty ,
           let progressFraction = notification.userInfo?["progressFraction"] as? Float,
           let visibleCells = queueTableView.visibleCells as? [UploadImageTableViewCell],
           let cell = visibleCells.first(where: {$0.localIdentifier == localIdentifier}) {
            debugPrint("••> progressFraction = \(progressFraction) in applyUploadProgress()")
            cell.uploadingProgress?.setProgress(progressFraction, animated: true)
        }
    }
}
