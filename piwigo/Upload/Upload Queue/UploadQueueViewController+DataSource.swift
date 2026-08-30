//
//  UploadQueueViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import PwgKit
import PwgCacheKit

// MARK: - UITableView - Diffable Data Source
extension UploadQueueViewController
{
    func configDataSource() -> DataSource {
        guard let queueTableView else { preconditionFailure("queueTableView should be set") }
        
        /// The data source is retained by this view controller, so its provider must not
        /// retain it in return — this view controller would otherwise never be released.
        let dataSource = DataSource(tableView: queueTableView) { [weak self] (tableView, indexPath, objectID) -> UITableViewCell? in
            guard let self
            else { return nil }

            // Get data source item
            guard let upload = try? self.mainContext.existingObject(with: objectID) as? Upload
            else {
                #if DEBUG
                debugPrint("Managed item should be available")
                #endif
                return nil
            }
            // Configure cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell
            else { preconditionFailure("Could not load a UploadImageTableViewCell!") }
            
            // Large corners since iOS 26
            var maskedCorner: CACornerMask = []
            let nberOfRows = tableView.numberOfRows(inSection: indexPath.section)
            if indexPath.row == 0 {
                maskedCorner.insert(.layerMinXMinYCorner)
            } else if indexPath.row == nberOfRows - 1 {
                maskedCorner.insert(.layerMinXMaxYCorner)
            }
            cell.configure(with: upload, availableWidth: Int(tableView.bounds.size.width), maskedCorner: maskedCorner)
            return cell
        }
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }
}
