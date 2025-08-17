//
//  AutoUploadViewController+UITableViewDelegate.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 02/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import UIKit
import piwigoKit

extension AutoUploadViewController: UITableViewDelegate
{
    // MARK: - Headers
    private func getContentOfHeader(inSection section: Int) -> String {
        var title = ""
        switch section {
        case 0:
            title = NSLocalizedString("settings_autoUploadLong", comment: "Auto Upload Photos")
        case 1:
            title = NSLocalizedString("tabBar_albums", comment: "Albums")
        case 2:
            title = NSLocalizedString("imageDetailsView_title", comment: "Properties")
        default:
            title = ""
        }
        return title
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title)
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 44.0
        switch indexPath.section {
        case 2:
            switch indexPath.row {
            case 0:
                height = 78.0
            case 1:
                height = 428.0
            default:
                break
            }
        default:
            break
        }
        return height
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0:
            return false
        case 2:
            switch indexPath.row {
            case 1:
                return false
            default:
                break
            }
        default:
            return true
        }
        return true
    }
    
    
    // MARK: - Footers
    private func getContentOfFooter(inSection section: Int) -> String {
        var footer = ""
        switch section {
        case 0:
            if UploadVars.shared.isAutoUploadActive {
                if NetworkVars.shared.serverFileTypes.contains("mp4") {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfoAll", comment: "Photos and videos will be automatically uploaded to your Piwigo.")
                } else {
                    footer = NSLocalizedString("settings_autoUploadEnabledInfo", comment: "Photos will be automatically uploaded to your Piwigo.")
                }
            } else {
                footer = NSLocalizedString("settings_autoUploadDisabledInfo", comment: "Photos will not be automatically uploaded to your Piwigo.")
            }
        default:
            footer = " "
        }
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.heightOfFooter(withText: footer, width: tableView.frame.width)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footer = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.viewOfFooter(withText: footer, alignment: .center)
    }
    
    
    // MARK: - Cell Management
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 1:
            switch indexPath.row {
            case 0 /* Select Photos Library album */ :
                // Check autorisation to access Photo Library before uploading
                PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: .readWrite, for: self) {
                    // Open local albums view controller
                    let localAlbumsSB = UIStoryboard(name: "LocalAlbumsViewController", bundle: nil)
                    guard let localAlbumsVC = localAlbumsSB.instantiateViewController(withIdentifier: "LocalAlbumsViewController") as? LocalAlbumsViewController else { return }
                    localAlbumsVC.categoryId = Int32.min
                    localAlbumsVC.user = self.user
                    localAlbumsVC.delegate = self
                    self.navigationController?.pushViewController(localAlbumsVC, animated: true)
                } onDeniedAccess: {
                    PhotosFetch.shared.requestPhotoLibraryAccess(in: self)
                }

            case 1 /* Select Piwigo album*/ :
                let categorySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
                if categoryVC.setInput(parameter: UploadVars.shared.autoUploadCategoryId,
                                       for: .setAutoUploadAlbum) {
                    categoryVC.delegate = self
                    categoryVC.user = user
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
                
            default:
                break
            }
            
        case 2:
            switch indexPath.row {
            case 0 /* Select Tags */ :
                // Create view controller
                let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
                if let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController {
                    tagsVC.delegate = self
                    tagsVC.user = user
                    tagsVC.setPreselectedTagIds(Set(UploadVars.shared.autoUploadTagIds
                                                        .components(separatedBy: ",")
                                                        .map { Int32($0) ?? nil }.compactMap {$0}))
                    navigationController?.pushViewController(tagsVC, animated: true)
                }

            default:
                break
            }
            
        default:
            break
        }
    }
}
