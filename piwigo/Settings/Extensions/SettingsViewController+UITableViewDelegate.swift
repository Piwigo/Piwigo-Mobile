//
//  SettingsViewController+UITableView.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/01/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import MessageUI
import piwigoKit

extension SettingsViewController: UITableViewDelegate
{
    // MARK: - Headers
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        // Header strings
        var title = "", text = ""
        switch activeSection(section) {
        case .server:
            title = String(format: "%@ %@",
                           NSLocalizedString("settingsHeader_server", comment: "Piwigo Server"),
                           NetworkVars.shared.pwgVersion)
            if (NetworkVars.shared.serverProtocol == "http://") {
                title += "\n"
                text = NSLocalizedString("settingsHeader_notSecure", comment: "Website Not Secure!")
            }
            if NetworkVars.shared.pwgVersion.compare(pwgRecentVersion, options: .numeric) == .orderedAscending {
                if !title.contains("\n") { title += "\n" }
                if !text.isEmpty { text += " — " }
                text += NSLocalizedString("serverVersionOld_title", comment: "Server Update Available")
            }
        case .albums:
            title = String(localized: "tabBar_albums", bundle: piwigoKit, comment: "Albums")
        case .images:
            title = NSLocalizedString("severalImages", comment: "Images")
        case .videos:
            title = NSLocalizedString("severalVideos", comment: "Videos")
        case .imageUpload:
            title = NSLocalizedString("settingsHeader_upload", comment: "Default Upload Settings")
        case .appearance:
            title = NSLocalizedString("settingsHeader_appearance", comment: "Appearance")
        case .privacy:
            title = NSLocalizedString("settingsHeader_privacy", comment: "Privacy")
        case .cache:
            title = NSLocalizedString("settingsHeader_cache", comment: "Cache Settings")
        case .about:
            title = NSLocalizedString("settingsHeader_about", comment: "Information")
        case .troubleshoot:
            title = NSLocalizedString("settingsHeader_troubleshoot", comment: "Troubleshooting")
        case .logout, .clear:
            fallthrough
        default:
            break
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        if title.isEmpty, text.isEmpty {
            return CGFloat(1)
        } else {
            return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                            width: tableView.frame.size.width)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var result = true
        switch activeSection(indexPath.section) {
            // MARK: Server
        case .server /* Piwigo Server */:
            result = false
        case .logout /* Logout Button */:
            result = true
            
        // MARK: Albums
        case .albums /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */,
                 1 /* Thumbnail File */:
                result = true
            default:
                result = false
            }
            
        // MARK: Images
        case .images /* Images */:
            var row = indexPath.row
            row += defaultSortUnknown ? 0 : 1
            switch row {
            case 0 /* Default Sort */,
                 1 /* Thumbnail File */,
                 3 /* Preview File */:
                result = true
            default:
                result = false
            }
        
        // MARK: Videos
        case .videos /* Videos */:
            switch indexPath.row {
            default:
                result = false
            }
            
        // MARK: Upload Settings
        case .imageUpload /* Default Upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.shared.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.shared.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UIDevice.current.hasCellular && (row > 8)) ? 1 : 0
            row += (!NetworkVars.shared.usesUploadAsync && (row > 9)) ? 1 : 0
            switch row {
            case 1  /* Privacy Level */,
                4  /* Upload Photo Size */,
                5  /* Upload Video Size */,
                8  /* Rename Filename Before Upload */,
                10 /* Auto upload */:
                result = true
            default:
                result = false
            }
            
            // MARK: Privacy
        case .privacy   /* Privacy */:
            result = true
            
            // MARK: Appearance
        case .appearance /* Appearance */:
            result = true
            
            // MARK: Cache
        case .cache /* Cache Settings */:
            result = false
        case .clear /* Cache Settings */:
            result = true
            
        // MARK: Information
        case .about /* Information */:
            switch indexPath.row {
            case 0 /* Twitter */,
                1 /* Rate Piwigo Mobile */,
                2 /* Translate Piwigo Mobile */,
                3 /* Release Notes */,
                4 /* Acknowledgements */,
                5 /* Privacy Policy */:
                result = true
            default:
                result = false
            }

        // MARK: Troubleshoot
        case .troubleshoot /* Troubleshoot */:
            switch indexPath.row {
            case 0 /* Error Logs */,
                1 /* Support Forum */:
                result = true
            case 2 /* Contact Support */:
                result = MFMailComposeViewController.canSendMail() ? true : false
            default:
                result = false
            }

        default:
            result = false
        }
        return result
    }
    
    
    // MARK: - Footers
    private func getContentOfFooter(inSection section: Int) -> String {
        var footer = ""
        switch activeSection(section) {
        case .logout:
            if NetworkVars.shared.serverFileTypes.isEmpty == false {
                if #available(iOS 16.0, *) {
                    footer = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(NetworkVars.shared.serverFileTypes.replacing(",", with: ", "))."
                } else {
                    // Fallback on earlier versions
                    footer = "\(NSLocalizedString("settingsFooter_formats", comment: "The server accepts the following file formats")): \(NetworkVars.shared.serverFileTypes.replacingOccurrences(of: ",", with: ", "))."
                }
            }
        case .about:
            footer = NetworkVars.shared.pwgStatistics
        default:
            footer = ""
        }
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.heightOfFooter(withText: text,
                                                        width: tableView.frame.width)
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter(inSection: section)
        return TableViewUtilities.shared.viewOfFooter(withText: text, alignment: .center)
    }
    
    
    // MARK: - Cell Management
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch activeSection(indexPath.section) {
        // MARK: Server
        case .server /* Piwigo Server */:
            break

        // MARK: Logout
        case .logout /* Logout */:
            loginLogout()

        // MARK: Albums
        case .albums /* Albums */:
            switch indexPath.row {
            case 0 /* Default album */:
                let categorySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController
                else { preconditionFailure("Could not load SelectCategoryViewController") }
                categoryVC.user = user
                if categoryVC.setInput(parameter: AlbumVars.shared.defaultCategory,
                                       for: .setDefaultAlbum) {
                    categoryVC.delegate = self
                    navigationController?.pushViewController(categoryVC, animated: true)
                }
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultAlbumThumbnailSizeViewController", bundle: nil)
                guard let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultAlbumThumbnailSizeViewController") as? DefaultAlbumThumbnailSizeViewController
                else { preconditionFailure("Could not load DefaultAlbumThumbnailSizeViewController") }
                defaultThumbnailSizeVC.delegate = self
                navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
            default:
                break
            }

        // MARK: Images
        case .images /* Images */:
            var row = indexPath.row
            row += defaultSortUnknown ? 0 : 1
            switch row {
            case 0 /* Sort method selection */:
                let categorySB = UIStoryboard(name: "CategorySortViewController", bundle: nil)
                guard let categoryVC = categorySB.instantiateViewController(withIdentifier: "CategorySortViewController") as? CategorySortViewController
                else { preconditionFailure("Could not load CategorySortViewController") }
                categoryVC.sortDelegate = self
                navigationController?.pushViewController(categoryVC, animated: true)
            case 1 /* Thumbnail file selection */:
                let defaultThumbnailSizeSB = UIStoryboard(name: "DefaultImageThumbnailSizeViewController", bundle: nil)
                guard let defaultThumbnailSizeVC = defaultThumbnailSizeSB.instantiateViewController(withIdentifier: "DefaultImageThumbnailSizeViewController") as? DefaultImageThumbnailSizeViewController
                else { preconditionFailure("Could not load DefaultImageThumbnailSizeViewController") }
                defaultThumbnailSizeVC.delegate = self
                navigationController?.pushViewController(defaultThumbnailSizeVC, animated: true)
            case 3 /* Preview file selection */:
                let defaultImageSizeSB = UIStoryboard(name: "DefaultImageSizeViewController", bundle: nil)
                guard let defaultImageSizeVC = defaultImageSizeSB.instantiateViewController(withIdentifier: "DefaultImageSizeViewController") as? DefaultImageSizeViewController
                else { preconditionFailure("Could not load DefaultImageSizeViewController") }
                defaultImageSizeVC.delegate = self
                navigationController?.pushViewController(defaultImageSizeVC, animated: true)
            default:
                break
            }

        // MARK: Videos
        case .videos :
            switch indexPath.row {
            default:
                break
            }
        
        // MARK: Upload Settings
        case .imageUpload /* Default upload Settings */:
            var row = indexPath.row
            row += (!user.hasAdminRights && (row > 0)) ? 1 : 0
            row += (!UploadVars.shared.resizeImageOnUpload && (row > 3)) ? 2 : 0
            row += (!UploadVars.shared.compressImageOnUpload && (row > 6)) ? 1 : 0
            row += (!UIDevice.current.hasCellular && (row > 8)) ? 1 : 0
            row += (!NetworkVars.shared.usesUploadAsync && (row > 9)) ? 1 : 0
            switch row {
            case 1 /* Default privacy selection */:
                let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
                guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController
                else { preconditionFailure("Could not load SelectPrivacyViewController") }
                privacyVC.delegate = self
                privacyVC.privacy = pwgPrivacy(rawValue: UploadVars.shared.defaultPrivacyLevel) ?? .everybody
                navigationController?.pushViewController(privacyVC, animated: true)
            case 4 /* Upload Photo Size */:
                let uploadPhotoSizeSB = UIStoryboard(name: "UploadPhotoSizeViewController", bundle: nil)
                guard let uploadPhotoSizeVC = uploadPhotoSizeSB.instantiateViewController(withIdentifier: "UploadPhotoSizeViewController") as? UploadPhotoSizeViewController
                else { preconditionFailure("Could not load UploadPhotoSizeViewController") }
                uploadPhotoSizeVC.delegate = self
                uploadPhotoSizeVC.photoMaxSize = UploadVars.shared.photoMaxSize
                navigationController?.pushViewController(uploadPhotoSizeVC, animated: true)
            case 5 /* Upload Video Size */:
                let uploadVideoSizeSB = UIStoryboard(name: "UploadVideoSizeViewController", bundle: nil)
                guard let uploadVideoSizeVC = uploadVideoSizeSB.instantiateViewController(withIdentifier: "UploadVideoSizeViewController") as? UploadVideoSizeViewController
                else { preconditionFailure("Could not load UploadVideoSizeViewController") }
                uploadVideoSizeVC.delegate = self
                uploadVideoSizeVC.videoMaxSize = UploadVars.shared.videoMaxSize
                navigationController?.pushViewController(uploadVideoSizeVC, animated: true)
            case 8 /* Rename Filename Before Upload */:
                let filenameSB = UIStoryboard(name: "RenameFileViewController", bundle: nil)
                guard let filenameVC = filenameSB.instantiateViewController(withIdentifier: "RenameFileViewController") as? RenameFileViewController
                else { preconditionFailure("Could not load RenameFileViewController") }
                filenameVC.delegate = self
                filenameVC.currentCounter = UploadVars.shared.categoryCounterInit
                filenameVC.prefixBeforeUpload = UploadVars.shared.prefixFileNameBeforeUpload
                filenameVC.prefixActions = UploadVars.shared.prefixFileNameActionList.actions
                filenameVC.replaceBeforeUpload = UploadVars.shared.replaceFileNameBeforeUpload
                filenameVC.replaceActions = UploadVars.shared.replaceFileNameActionList.actions
                filenameVC.suffixBeforeUpload = UploadVars.shared.suffixFileNameBeforeUpload
                filenameVC.suffixActions = UploadVars.shared.suffixFileNameActionList.actions
                filenameVC.changeCaseBeforeUpload = UploadVars.shared.changeCaseOfFileExtension
                filenameVC.caseOfFileExtension = FileExtCase(rawValue: UploadVars.shared.caseOfFileExtension) ?? .keep
                navigationController?.pushViewController(filenameVC, animated: true)
            case 10 /* Auto Upload */:
                let autoUploadSB = UIStoryboard(name: "AutoUploadViewController", bundle: nil)
                guard let autoUploadVC = autoUploadSB.instantiateViewController(withIdentifier: "AutoUploadViewController") as? AutoUploadViewController
                else { preconditionFailure("Could not load AutoUploadViewController") }
                autoUploadVC.user = user
                navigationController?.pushViewController(autoUploadVC, animated: true)
            default:
                break
            }

        // MARK: Privacy
        case .privacy   /* Privacy */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                // Display numpad for setting up a passcode
                let appLockSB = UIStoryboard(name: "LockOptionsViewController", bundle: nil)
                guard let appLockVC = appLockSB.instantiateViewController(withIdentifier: "LockOptionsViewController") as? LockOptionsViewController
                else { preconditionFailure("Could not load LockOptionsViewController") }
                appLockVC.delegate = self
                navigationController?.pushViewController(appLockVC, animated: true)
            case 1 /* Clear Clipboard */:
                // Display list of delays
                let delaySB = UIStoryboard(name: "ClearClipboardViewController", bundle: nil)
                guard let delayVC = delaySB.instantiateViewController(withIdentifier: "ClearClipboardViewController") as? ClearClipboardViewController
                else { preconditionFailure("Could not load ClearClipboardViewController") }
                delayVC.delegate = self
                navigationController?.pushViewController(delayVC, animated: true)
            case 2 /* Share image metadata options */:
                let metadataOptionsSB = UIStoryboard(name: "ShareMetadataViewController", bundle: nil)
                guard let metadataOptionsVC = metadataOptionsSB.instantiateViewController(withIdentifier: "ShareMetadataViewController") as? ShareMetadataViewController
                else { preconditionFailure("Could not load ShareMetadataViewController") }
                navigationController?.pushViewController(metadataOptionsVC, animated: true)

            default:
                break
            }

        // MARK: Appearance
        case .appearance /* Appearance */:
            let colorPaletteSB = UIStoryboard(name: "ColorPaletteViewController", bundle: nil)
            guard let colorPaletteVC = colorPaletteSB.instantiateViewController(withIdentifier: "ColorPaletteViewController") as? ColorPaletteViewController
            else { preconditionFailure("Could not load ColorPaletteViewController") }
            navigationController?.pushViewController(colorPaletteVC, animated: true)

        // MARK: Cache
        case .clear /* Cache Clear */:
            switch indexPath.row {
            case 0 /* Clear cache */:
                // Determine position of cell in table view
                let rowAtIndexPath = IndexPath(row: 0, section: SettingsSection.clear.rawValue)
                let rectOfCellInTableView = settingsTableView?.rectForRow(at: rowAtIndexPath)

                // Present list of actions
                let alert = getClearCacheAlert()
                alert.view.tintColor = PwgColor.tintColor
                alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
                alert.popoverPresentationController?.sourceView = settingsTableView
                alert.popoverPresentationController?.permittedArrowDirections = [.up, .down]
                alert.popoverPresentationController?.sourceRect = rectOfCellInTableView ?? CGRect.zero
                present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = PwgColor.tintColor
                })
            default:
                break
            }

        // MARK: Information
        case .about /* About — Informations */:
            switch indexPath.row {
            case 0 /* Open piwigo.org webpage */:
                if let url = URL(string: NSLocalizedString("settings_pwgURL", comment: "https://piwigo.org")) {
                    UIApplication.shared.open(url)
                }
            case 1 /* Open Piwigo App Store page for rating */:
                // See https://itunes.apple.com/us/app/piwigo/id472225196?ls=1&mt=8
                if let url = URL(string: "itms-apps://itunes.apple.com/app/piwigo/id472225196?action=write-review") {
                    UIApplication.shared.open(url)
                }
            case 2 /* Open Piwigo Crowdin page for translating */:
                if let url = URL(string: "https://crowdin.com/project/piwigo-mobile") {
                    UIApplication.shared.open(url)
                }
            case 3 /* Open Release Notes page */:
                let releaseNotesSB = UIStoryboard(name: "ReleaseNotesViewController", bundle: nil)
                guard let releaseNotesVC = releaseNotesSB.instantiateViewController(withIdentifier: "ReleaseNotesViewController") as? ReleaseNotesViewController
                else { preconditionFailure("Could not load ReleaseNotesViewController") }
                navigationController?.pushViewController(releaseNotesVC, animated: true)
            case 4 /* Open Acknowledgements page */:
                let aboutSB = UIStoryboard(name: "AboutViewController", bundle: nil)
                guard let aboutVC = aboutSB.instantiateViewController(withIdentifier: "AboutViewController") as? AboutViewController
                else { preconditionFailure("Could not load AboutViewController") }
                navigationController?.pushViewController(aboutVC, animated: true)
            case 5 /* Open Privacy Policy page */:
                let privacyPolicySB = UIStoryboard(name: "PrivacyPolicyViewController", bundle: nil)
                guard let privacyPolicyVC = privacyPolicySB.instantiateViewController(withIdentifier: "PrivacyPolicyViewController") as? PrivacyPolicyViewController
                else { preconditionFailure("Could not load PrivacyPolicyViewController") }
                navigationController?.pushViewController(privacyPolicyVC, animated: true)
            default:
                break
            }

        // MARK: Troubleshoot
        case .troubleshoot /* Troubleshoot */:
            switch indexPath.row {
            case 0 /* Open Logs page */:
                let errorLogsSB = UIStoryboard(name: "TroubleshootingViewController", bundle: nil)
                guard let errorLogsVC = errorLogsSB.instantiateViewController(withIdentifier: "TroubleshootingViewController") as? TroubleshootingViewController
                else { preconditionFailure("Could not load TroubleshootingViewController") }
                navigationController?.pushViewController(errorLogsVC, animated: true)
            case 1 /* Open Piwigo support forum webpage with default browser */:
                if let url = URL(string: NSLocalizedString("settings_pwgForumURL", comment: "http://piwigo.org/forum")) {
                    UIApplication.shared.open(url)
                }
            case 2 /* Prepare draft email */:
                // Get mail composer if possible
                guard let composeVC = SettingsUtilities.getMailComposer() else { return }
                composeVC.mailComposeDelegate = self

                // Present the view controller modally.
                present(composeVC, animated: true)
            default:
                break
            }
        
        default:
            break
        }
    }
}
