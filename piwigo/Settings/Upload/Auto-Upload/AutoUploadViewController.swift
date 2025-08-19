//
//  AutoUploadViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/03/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit

class AutoUploadViewController: UIViewController {

    @IBOutlet var autoUploadTableView: UITableView!
    
    var oldContentOffset = CGPoint.zero
    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            preconditionFailure("!!! Missing Managed Object Context !!!")
        }
        return context
    }()


    // MARK: - Core Data Providers
    lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()
    lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider.shared
        return provider
    }()

    private lazy var hasTagCreationRights: Bool = {
        // Depends on the user's rights
        switch NetworkVars.shared.userStatus {
        case .guest, .generic:
            return false
        case .admin, .webmaster:
            return true
        case .normal:
            // Community user with upload rights?
            if user.uploadRights.components(separatedBy: ",")
                .contains(String(UploadVars.shared.autoUploadCategoryId)) {
                return true
            }
        }
        return false
    }()


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_upload", comment: "Upload")
    }

    @MainActor
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background

        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)

        // Table view
        autoUploadTableView.separatorColor = PwgColor.separator
        autoUploadTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        autoUploadTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)

        // Register auto-upload option disabler
        NotificationCenter.default.addObserver(self, selector: #selector(disableAutoUpload),
                                               name: Notification.Name.pwgAutoUploadChanged, object: nil)
        
        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardAppear(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDisappear(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)

        // Pause UploadManager while changing settings
        UploadManager.shared.isPaused = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Check if the user is going to select a local album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is LocalAlbumsViewController { return }
            
        // Check if the user is going to select a Piwigo album
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is SelectCategoryViewController { return }

        // Check if the user is going to select/deselect tags
        if let visibleVC = navigationController?.visibleViewController,
           visibleVC is TagsViewController { return }

        // Restart UploadManager activities
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.isPaused = false
            UploadManager.shared.findNextImageToUpload()
        }
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }

    
    // MARK: - Auto-Upload option disabled during execution
    @objc func disableAutoUpload(_ notification: Notification) {
        // Change switch button state
        autoUploadTableView?.reloadSections(IndexSet(integer: 0), with: .automatic)
        
        // Inform user if an error was reported
        if view.window != nil,
           let title = notification.userInfo?["title"] as? String, title.isEmpty == false,
           let message = notification.userInfo?["message"] as? String {
            dismissPiwigoError(withTitle: title, message: message) { }
        }
    }
}
