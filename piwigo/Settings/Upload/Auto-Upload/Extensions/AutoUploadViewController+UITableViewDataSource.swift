//
//  AutoUploadViewController+UITableViewDataSource.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit
import uploadKit

extension AutoUploadViewController: UITableViewDataSource
{
    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        case 2:
            return 2
        default:
            fatalError("Unknown section")
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()
        
        switch indexPath.section {
        case 0:     // Auto-Upload On/Off
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchTableViewCell", for: indexPath) as? SwitchTableViewCell
            else { preconditionFailure("Could not load a SwitchTableViewCell!") }
            let title = NSLocalizedString("settings_autoUpload", comment: "Auto Upload")
            cell.configure(with: title)
            cell.cellSwitch.setOn(UploadVars.shared.isAutoUploadActive, animated: true)
            cell.cellSwitchBlock = { switchState in
                // Enable/disable auto-upload option
                UploadManager.shared.backgroundQueue.async {
                    if switchState {
                        // Enable auto-uploading
                        UploadVars.shared.isAutoUploadActive = true
                        UploadManager.shared.appendAutoUploadRequests()
                        // Update Settings tableview
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .pwgAutoUploadChanged, object: nil, userInfo: nil)
                        }
                    } else {
                        // Disable auto-uploading
                        UploadManager.shared.disableAutoUpload()
                    }
                }
            }
            tableViewCell = cell
            
        case 1:     // Source & destination albums
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load a LabelTableViewCell!") }
            
            var title = "", detail = ""
            switch indexPath.row {
            case 0 /* Select Photos Library album */ :
                title = NSLocalizedString("settings_autoUploadSource", comment: "Source")
                let collectionID = UploadVars.shared.autoUploadAlbumId
                if collectionID.isEmpty == false,
                   let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [collectionID], options: nil).firstObject {
                    detail = collection.localizedTitle ?? ""
                } else {
                    // Did not find the Photo Library album
                    UploadVars.shared.autoUploadAlbumId = ""
                    UploadVars.shared.isAutoUploadActive = false
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell

            case 1 /* Select Piwigo album*/ :
                title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
                let categoryId = UploadVars.shared.autoUploadCategoryId
                if let albumData = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
                    detail = albumData.name
                } else {
                    // Did not find the Piwigo album
                    UploadVars.shared.autoUploadCategoryId = Int32.min
                    UploadVars.shared.isAutoUploadActive = false
                }
                cell.configure(with: title, detail: detail)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                tableViewCell = cell
            default:
                break
            }
            cell.configure(with: title, detail: detail)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            tableViewCell = cell

        case 2:     // Properties
            switch indexPath.row {
            case 0 /* Tags */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell
                else { preconditionFailure("Could not load a EditImageTagsTableViewCell!") }
                // Retrieve tags and switch to old cache data format
                let tags = tagProvider.getTags(withIDs: UploadVars.shared.autoUploadTagIds, taskContext: mainContext)
                cell.config(withList: tags, inColor: PwgColor.rightLabel)
                tableViewCell = cell

            case 1 /* Comments */ :
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell
                else { preconditionFailure("Could not load a EditImageTextViewTableViewCell!") }
                cell.config(withText: NSAttributedString(string: UploadVars.shared.autoUploadComments),
                            inColor: PwgColor.rightLabel)
                cell.textView.delegate = self
                tableViewCell = cell

            default:
                break
            }

        default:
            break
        }

        tableViewCell.backgroundColor = PwgColor.cellBackground
        tableViewCell.tintColor = PwgColor.orange
        return tableViewCell
    }
}
