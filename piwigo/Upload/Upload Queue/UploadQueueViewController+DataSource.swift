//
//  UploadQueueViewController+DataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// MARK: - UITableView - Diffable Data Source
extension UploadQueueViewController
{
    func configDataSource() -> DataSource {
        let dataSource = DataSource(tableView: queueTableView) { [self] (tableView, indexPath, objectID) -> UITableViewCell? in
            // Get data source item
            guard let upload = try? self.mainContext.existingObject(with: objectID) as? Upload
            else {
                debugPrint("Managed item should be available")
                return nil
            }
            // Configure cell
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell
            else { preconditionFailure("Could not load a UploadImageTableViewCell!") }
            cell.configure(with: upload, availableWidth: Int(tableView.bounds.size.width))
            return cell
        }
        dataSource.defaultRowAnimation = .fade
        return dataSource
    }
}
