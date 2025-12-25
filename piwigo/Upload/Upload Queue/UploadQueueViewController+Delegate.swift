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
        let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
        return TableViewUtilities.heightOfHeader(withTitle: sectionKey.name,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "UploadImageHeaderView") as? UploadImageHeaderView
        else { preconditionFailure("Could not load a UploadImageHeaderView!") }
        let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
        header.config(with: sectionKey)
        return header
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
        else { return nil }
        
        // Image configuration
        var imageConfig: UIImage.SymbolConfiguration
        if #available(iOS 26.0, *) {
            imageConfig = UIImage.SymbolConfiguration(pointSize: 21.0, weight: .medium)
        } else {
            // Fallback on previous version
            imageConfig = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .regular)
        }
        
        // Create retry upload action
        let retry = UIContextualAction(style: .normal, title: nil,
                                       handler: { action, view, completionHandler in
            Task { @UploadManagerActor in
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
//                if #unavailable(iOS 26.0) {
                    UploadManager.shared.findNextImageToUpload()
//                }
            }
            completionHandler(true)
        })
        retry.backgroundColor = PwgColor.brown
        retry.image = UIImage(systemName: "arrow.uturn.forward", withConfiguration: imageConfig)
        
        // Create trash/cancel upload action
        let cancel = UIContextualAction(style: .normal, title: nil,
                                        handler: { action, view, completionHandler in
            let savingContext = upload.managedObjectContext
            savingContext?.delete(upload)
            savingContext?.saveIfNeeded()
            Task { @UploadManagerActor in
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
//                if #unavailable(iOS 26.0) {
                    UploadManager.shared.findNextImageToUpload()
//                }
            }
            completionHandler(true)
        })
        cancel.backgroundColor = .red
        if #available(iOS 26.0, *) {
            cancel.image = UIImage(systemName: "xmark", withConfiguration: imageConfig)
        } else {
            // Fallback on previous version
            cancel.image = UIImage(systemName: "xmark.circle.fill", withConfiguration: imageConfig)
        }

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
            cell.uploadingProgress?.setProgress(progressFraction, animated: true)
        }
    }
}
