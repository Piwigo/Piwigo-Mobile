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
@available(iOS 13.0, *)
extension UploadQueueViewController
{
    func configDataSource() -> DataSource {
        let dataSource = DataSource(tableView: queueTableView) { [self] (tableView, indexPath, objectID) -> UITableViewCell? in
            // Get data source item
            guard let upload = try? self.mainContext.existingObject(with: objectID) as? Upload
            else { preconditionFailure("Managed item should be available") }
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


// MARK: - UITableViewDataSource Methods
// Exclusively for iOS 12.x
extension UploadQueueViewController: UITableViewDataSource
{
    func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = uploads.sections {
            return sections.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = uploads.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell
        else { preconditionFailure("Could not load a UploadImageTableViewCell!") }
        cell.configure(with: uploads.object(at: indexPath),
                       availableWidth: Int(tableView.bounds.size.width))
        return cell
    }
}
