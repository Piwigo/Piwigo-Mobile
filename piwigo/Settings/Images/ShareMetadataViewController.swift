//
//  ShareMetadataViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 04/04/2019.
//

import UIKit
import piwigoKit

let kPiwigoActivityTypeMessenger = UIActivity.ActivityType(rawValue: "com.facebook.Messenger.ShareExtension")
let kPiwigoActivityTypePostInstagram = UIActivity.ActivityType(rawValue: "com.burbn.instagram.shareextension")
let kPiwigoActivityTypePostToSignal = UIActivity.ActivityType(rawValue: "org.whispersystems.signal.shareextension")
let kPiwigoActivityTypePostToSnapchat = UIActivity.ActivityType(rawValue: "com.toyopagroup.picaboo.share")
let kPiwigoActivityTypePostToWhatsApp = UIActivity.ActivityType(rawValue: "net.whatsapp.WhatsApp.ShareExtension")
let kPiwigoActivityTypeOther = UIActivity.ActivityType(rawValue: "undefined.ShareExtension")

class ShareMetadataViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var shareMetadataTableView: UITableView!
    
    private var activitiesSharingMetadata = [UIActivity.ActivityType]()
    private var activitiesNotSharingMetadata = [UIActivity.ActivityType]()

    private var editBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?


// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
        
        // Buttons
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(stopEditingOptions))
    }

    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar appearence
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        shareMetadataTableView.separatorColor = .piwigoColorSeparator()
        shareMetadataTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        shareMetadataTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Add Edit button
        navigationItem.setRightBarButton(editBarButton, animated: false)

        // Prepare data source
        setDataSourceFromSettings()

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        //Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { context in
            // Reload table view
            self.shareMetadataTableView.reloadData()
        })
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    
// MARK: - Editing mode
    
    @objc func stopEditingOptions() {
        // Replace "Done" button with "Edit" button
        navigationItem.setRightBarButton(editBarButton, animated: true)

        // Refresh table to remove [+] and [-] buttons
        shareMetadataTableView.reloadData()

        // Show back button
        navigationItem.setHidesBackButton(false, animated: true)
    }

    
// MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        var title = "", text = ""
        switch section {
        case 0:
            title = String(format: "%@\n", NSLocalizedString("shareImageMetadata_Title", comment: "Share Metadata"))
            text = NSLocalizedString("shareImageMetadata_subTitle1", comment: "Actions sharing images with private metadata")
        case 1:
            text = NSLocalizedString("shareImageMetadata_subTitle2", comment: "Actions sharing images without private metadata")
        default:
            break
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }

    
// MARK: - UITableView - Rows
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = 0
        switch section {
            case 0:
                nberOfRows = activitiesSharingMetadata.count
            case 1:
                nberOfRows = activitiesNotSharingMetadata.count
            default:
                break
        }
        return nberOfRows
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ShareMetadataCell", for: indexPath) as? ShareMetadataCell else {
            print("Error: tableView.dequeueReusableCell does not return a ShareMetadataCell!")
            return ShareMetadataCell()
        }

        let width = view.bounds.size.width
        switch indexPath.section {
            case 0:
                let activity = activitiesSharingMetadata[indexPath.row]
                let activityName = getName(forActivity: activity, forWidth: width)
                cell.configure(with: activityName, andEditOption: cellIconType.remove)
            case 1:
                let activity = activitiesNotSharingMetadata[indexPath.row]
                let activityName = getName(forActivity: activity, forWidth: width)
                cell.configure(with: activityName, andEditOption: cellIconType.add)
            default:
                break
        }

        cell.accessibilityIdentifier = "shareMetadata"
        cell.isAccessibilityElement = true
        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var activitiesSharing = self.activitiesSharingMetadata
        var activitiesNotSharing = self.activitiesNotSharingMetadata

        switch indexPath.section {
        case 0: // Actions sharing photos with private metadata
            // Get tapped activity
            let activity = activitiesSharingMetadata[indexPath.row]
            
            // Update icon of tapped cell
            let cell = tableView.cellForRow(at: indexPath) as! ShareMetadataCell
            let width = view.bounds.size.width
            let activityName = getName(forActivity: activity, forWidth: width)
            cell.configure(with: activityName, andEditOption: cellIconType.add)

            // Switch activity state
            switchActivity(activity, toState: false)

            // Transfer activity to other section
            activitiesSharing = activitiesSharing.filter({ ($0) as AnyObject !== (activity) as AnyObject })
            activitiesNotSharing.append(activity)

            // Sort list of activities
            activitiesSharingMetadata = activitiesSharing.sorted()
            activitiesNotSharingMetadata = activitiesNotSharing.sorted()

            // Determine new indexPath of tapped activity
            let index = activitiesNotSharingMetadata.firstIndex(of: activity)
            let newIndexPath = IndexPath(row: index!, section: 1)

            // Move cell of tapped activity
            tableView.moveRow(at: indexPath, to: newIndexPath)

        case 1:     // Actions sharing photos without private metadata
            // Get tapped activity
            let activity = activitiesNotSharingMetadata[indexPath.row]

            // Update icon of tapped cell
            let cell = tableView.cellForRow(at: indexPath) as! ShareMetadataCell
            let width = view.bounds.size.width
            let activityName = getName(forActivity: activity, forWidth: width)
            cell.configure(with: activityName, andEditOption: cellIconType.remove)

            // Switch activity setting
            switchActivity(activity, toState: true)

            // Transfer activity to other section
            activitiesNotSharing = activitiesNotSharing.filter({ ($0) as AnyObject !== (activity) as AnyObject })
            activitiesSharing.append(activity)

            // Sort list of activities
            activitiesSharingMetadata = activitiesSharing.sorted()
            activitiesNotSharingMetadata = activitiesNotSharing.sorted()

            // Determine new indexPath of tapped activity
            let index = activitiesSharingMetadata.firstIndex(of: activity)
            let newIndexPath = IndexPath(row: index!, section: 0)

            // Move cell of tapped activity
            tableView.moveRow(at: indexPath, to: newIndexPath)

        default:
            return
        }
    }

    
// MARK: - Utilities
    
    private func setDataSourceFromSettings() {
        
        // Empty lists
        var activitiesSharing = [UIActivity.ActivityType]()
        var activitiesNotSharing = [UIActivity.ActivityType]()
        
        // Prepare data source from actual settings
        if ImageVars.shared.shareMetadataTypeAirDrop {
            activitiesSharing.append(.airDrop)
        } else {
            activitiesNotSharing.append(.airDrop)
        }
        if ImageVars.shared.shareMetadataTypeAssignToContact {
            activitiesSharing.append(.assignToContact)
        } else {
            activitiesNotSharing.append(.assignToContact)
        }
        if ImageVars.shared.shareMetadataTypeCopyToPasteboard {
            activitiesSharing.append(.copyToPasteboard)
        } else {
            activitiesNotSharing.append(.copyToPasteboard)
        }
        if ImageVars.shared.shareMetadataTypeMail {
            activitiesSharing.append(.mail)
        } else {
            activitiesNotSharing.append(.mail)
        }
        if ImageVars.shared.shareMetadataTypeMessage {
            activitiesSharing.append(.message)
        } else {
            activitiesNotSharing.append(.message)
        }
        if ImageVars.shared.shareMetadataTypePostToFacebook {
            activitiesSharing.append(.postToFacebook)
        } else {
            activitiesNotSharing.append(.postToFacebook)
        }
        if ImageVars.shared.shareMetadataTypeMessenger {
            activitiesSharing.append(kPiwigoActivityTypeMessenger)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypeMessenger)
        }
        if ImageVars.shared.shareMetadataTypePostToFlickr {
            activitiesSharing.append(.postToFlickr)
        } else {
            activitiesNotSharing.append(.postToFlickr)
        }
        if ImageVars.shared.shareMetadataTypePostInstagram {
            activitiesSharing.append(kPiwigoActivityTypePostInstagram)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostInstagram)
        }
        if ImageVars.shared.shareMetadataTypePostToSignal {
            activitiesSharing.append(kPiwigoActivityTypePostToSignal)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToSignal)
        }
        if ImageVars.shared.shareMetadataTypePostToSnapchat {
            activitiesSharing.append(kPiwigoActivityTypePostToSnapchat)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToSnapchat)
        }
        if ImageVars.shared.shareMetadataTypePostToTencentWeibo {
            activitiesSharing.append(.postToTencentWeibo)
        } else {
            activitiesNotSharing.append(.postToTencentWeibo)
        }
        if ImageVars.shared.shareMetadataTypePostToTwitter {
            activitiesSharing.append(.postToTwitter)
        } else {
            activitiesNotSharing.append(.postToTwitter)
        }
        if ImageVars.shared.shareMetadataTypePostToVimeo {
            activitiesSharing.append(.postToVimeo)
        } else {
            activitiesNotSharing.append(.postToVimeo)
        }
        if ImageVars.shared.shareMetadataTypePostToWeibo {
            activitiesSharing.append(.postToWeibo)
        } else {
            activitiesNotSharing.append(.postToWeibo)
        }
        if ImageVars.shared.shareMetadataTypePostToWhatsApp {
            activitiesSharing.append(kPiwigoActivityTypePostToWhatsApp)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypePostToWhatsApp)
        }
        if ImageVars.shared.shareMetadataTypeSaveToCameraRoll {
            activitiesSharing.append(.saveToCameraRoll)
        } else {
            activitiesNotSharing.append(.saveToCameraRoll)
        }
        if ImageVars.shared.shareMetadataTypeOther {
            activitiesSharing.append(kPiwigoActivityTypeOther)
        } else {
            activitiesNotSharing.append(kPiwigoActivityTypeOther)
        }
        
        activitiesSharingMetadata = activitiesSharing.sorted()
        activitiesNotSharingMetadata = activitiesNotSharing.sorted()
    }
    
    private func switchActivity(_ activity: UIActivity.ActivityType, toState newState: Bool) {
        // Change the boolean status of the selected activity
        switch activity {
        case .airDrop:
            ImageVars.shared.shareMetadataTypeAirDrop = newState
        case .assignToContact:
            ImageVars.shared.shareMetadataTypeAssignToContact = newState
        case .copyToPasteboard:
            ImageVars.shared.shareMetadataTypeCopyToPasteboard = newState
        case .mail:
            ImageVars.shared.shareMetadataTypeMail = newState
        case .message:
            ImageVars.shared.shareMetadataTypeMessage = newState
        case .postToFacebook:
            ImageVars.shared.shareMetadataTypePostToFacebook = newState
        case kPiwigoActivityTypeMessenger:
            ImageVars.shared.shareMetadataTypeMessenger = newState
        case .postToFlickr:
            ImageVars.shared.shareMetadataTypePostToFlickr = newState
        case kPiwigoActivityTypePostInstagram:
            ImageVars.shared.shareMetadataTypePostInstagram = newState
        case kPiwigoActivityTypePostToSignal:
            ImageVars.shared.shareMetadataTypePostToSignal = newState
        case kPiwigoActivityTypePostToSnapchat:
            ImageVars.shared.shareMetadataTypePostToSnapchat = newState
        case .postToTencentWeibo:
            ImageVars.shared.shareMetadataTypePostToTencentWeibo = newState
        case .postToTwitter:
            ImageVars.shared.shareMetadataTypePostToTwitter = newState
        case .postToVimeo:
            ImageVars.shared.shareMetadataTypePostToVimeo = newState
        case .postToWeibo:
            ImageVars.shared.shareMetadataTypePostToWeibo = newState
        case kPiwigoActivityTypePostToWhatsApp:
            ImageVars.shared.shareMetadataTypePostToWhatsApp = newState
        case .saveToCameraRoll:
            ImageVars.shared.shareMetadataTypeSaveToCameraRoll = newState
        case kPiwigoActivityTypeOther:
            ImageVars.shared.shareMetadataTypeOther = newState
            default:
                print("Error: Unknown activity \(String(describing: activity))")
        }

        // Clear URL requests to force reload images before sharing
        NetworkVarsObjc.imageCache?.removeAllCachedResponses()

        // Clean up /tmp directory where shared files are temporarily stored
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.cleanUpTemporaryDirectory(immediately: true)
    }

    private func getName(forActivity activity: UIActivity.ActivityType, forWidth width: CGFloat) -> String? {
        var name = ""
        // Return activity name of appropriate lentgh
        switch activity {
        case .airDrop:
            name = width > 375 ? NSLocalizedString("shareActivityCode_AirDrop>375px", comment: "Transfer images with AirDrop")
                               : NSLocalizedString("shareActivityCode_AirDrop", comment: "Transfer with AirDrop")
        case .assignToContact:
            name = width > 375 ? NSLocalizedString("shareActivityCode_AssignToContact>375px", comment: "Assign image to contact")
                               : NSLocalizedString("shareActivityCode_AssignToContact", comment: "Assign to contact")
        case .copyToPasteboard:
            name = width > 375 ? NSLocalizedString("shareActivityCode_CopyToPasteboard>375px", comment: "Copy images to Pasteboard")
                               : NSLocalizedString("shareActivityCode_CopyToPasteboard", comment: "Copy to Pasteboard")
        case .mail:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Mail>375px", comment: "Post images by email")
                               : NSLocalizedString("shareActivityCode_Mail", comment: "Post by email")
        case .message:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Message>375px", comment: "Post images with the Message app")
                               : NSLocalizedString("shareActivityCode_Message", comment: "Post with Message")
        case .postToFacebook:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Facebook>375px", comment: "Post images to Facebook")
                               : NSLocalizedString("shareActivityCode_Facebook", comment: "Post to Facebook")
        case kPiwigoActivityTypeMessenger:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Messenger>375px", comment: "Post images with the Messenger app")
                               : NSLocalizedString("shareActivityCode_Messenger", comment: "Post with Messenger")
        case .postToFlickr:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Flickr>375px", comment: "Post images to Flickr")
                               : NSLocalizedString("shareActivityCode_Flickr", comment: "Post to Flickr")
        case kPiwigoActivityTypePostInstagram:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Instagram>375px", comment: "Post images to Instagram")
                               : NSLocalizedString("shareActivityCode_Instagram", comment: "Post to Instagram")
        case kPiwigoActivityTypePostToSignal:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Signal>375px", comment: "Post images with the Signal app")
                               : NSLocalizedString("shareActivityCode_Signal", comment: "Post with Signal")
        case kPiwigoActivityTypePostToSnapchat:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Snapchat>375px", comment: "Post images to Snapchat app")
                               : NSLocalizedString("shareActivityCode_Snapchat", comment: "Post to Snapchat")
        case .postToTencentWeibo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_TencentWeibo>375px", comment: "Post images to TencentWeibo")
                               : NSLocalizedString("shareActivityCode_TencentWeibo", comment: "Post to TencentWeibo")
        case .postToTwitter:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Twitter>375px", comment: "Post images to Twitter")
                               : NSLocalizedString("shareActivityCode_Twitter", comment: "Post to Twitter")
        case .postToVimeo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Vimeo>375px", comment: "Post videos to Vimeo")
                               : NSLocalizedString("shareActivityCode_Vimeo", comment: "Post to Vimeo")
        case .postToWeibo:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Weibo>375px", comment: "Post images to Weibo")
                               : NSLocalizedString("shareActivityCode_Weibo", comment: "Post to Weibo")
        case kPiwigoActivityTypePostToWhatsApp:
            name = width > 375 ? NSLocalizedString("shareActivityCode_WhatsApp>375px", comment: "Post images with the WhatsApp app")
                               : NSLocalizedString("shareActivityCode_WhatsApp", comment: "Post with WhatsApp")
        case .saveToCameraRoll:
            name = width > 375 ? NSLocalizedString("shareActivityCode_CameraRoll>375px", comment: "Save images to Camera Roll")
                               : NSLocalizedString("shareActivityCode_CameraRoll", comment: "Save to Camera Roll")
        case kPiwigoActivityTypeOther:
            name = width > 375 ? NSLocalizedString("shareActivityCode_Other>375px", comment: "Share images with other apps")
                               : NSLocalizedString("shareActivityCode_Other", comment: "Share with other apps")
            default:
                print("Error: Unknown activity \(String(describing: activity))")
        }

        return name
    }
}
