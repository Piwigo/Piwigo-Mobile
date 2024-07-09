//
//  EditImageParamsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 31/08/2021.
//

import CoreData
import UIKit
import piwigoKit

@objc protocol EditImageParamsDelegate: NSObjectProtocol {
    func didDeselectImage(withId imageId: Int64)
    func didChangeImageParameters(_ imageData: Image)
    func didFinishEditingParameters()
}

class EditImageParamsViewController: UIViewController
{
    var images = [Image]()
    var hasTagCreationRights = false
    weak var delegate: EditImageParamsDelegate?
    
    @IBOutlet weak var editImageParamsTableView: UITableView!
    private var hudViewController: UIViewController?
    private let kEditImageParamsViewWidth: CGFloat = 512.0

    var shouldUpdateTitle = false
    var commonTitle = NSAttributedString()
    
    var shouldUpdateAuthor = false
    var commonAuthor = ""
    
    var hasDatePicker = false
    var shouldUpdateDateCreated = false
    var commonDateCreated = Date.distantPast
    var oldCreationDate = Date()
    private var timeOffset = TimeInterval.zero

    var shouldUpdatePrivacyLevel = false
    var commonPrivacyLevel = pwgPrivacy.everybody.rawValue
    
    var shouldUpdateTags = false
    var commonTags = Set<Tag>()
    var addedTags = Set<Tag>()
    var removedTags = Set<Tag>()
    
    var shouldUpdateComment = false
    var commonComment = NSAttributedString()
    
    enum EditImageParamsOrder : Int {
        case thumbnails
        case imageName
        case author
        case date
        case datePicker
        case tags
        case privacy
        case desc
        case count
    }

    // Tell which cell triggered the keyboard appearance
    var editedRow: IndexPath?
    
    
    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    
    // MARK: - Core Data Providers
    private lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()


    // MARK: - View Lifecycle
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()
        
        // Table view
        editImageParamsTableView.separatorColor = .piwigoColorSeparator()
        editImageParamsTableView.backgroundColor = .piwigoColorBackground()
        editImageParamsTableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("imageDetailsView_title", comment: "Properties")
        
        // Buttons
        let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelEdit))
        cancel.accessibilityIdentifier = "Cancel"
        let done = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(doneEdit))
        done.accessibilityIdentifier = "Done"
        
        // Navigation bar
        navigationController?.isNavigationBarHidden = false
        navigationItem.leftBarButtonItem = cancel
        navigationItem.rightBarButtonItem = done
        navigationController?.navigationBar.accessibilityIdentifier = "editParams"
        
        // Register thumbnails cell
        editImageParamsTableView.register(UINib(nibName: "EditImageThumbTableViewCell", bundle: nil), forCellReuseIdentifier: "EditImageThumbTableViewCell")
        
        // Register date picker cell
        editImageParamsTableView.register(UINib(nibName: "EditImageDatePickerTableViewCell", bundle: nil), forCellReuseIdentifier: "DatePickerTableCell")
        hasDatePicker = false
        
        // Register date interval picker cell
        editImageParamsTableView.register(UINib(nibName: "EditImageShiftPickerTableViewCell", bundle: nil), forCellReuseIdentifier: "ShiftPickerTableCell")
        
        // Reset common parameters
        resetCommonParameters()
        
        // Set colors, fonts, etc.
        applyColorPalette()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)

        // Register keyboard appearance/disappearance
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDidShow(_:)),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            
            // On iPad, the form is presented in a popover view
            if UIDevice.current.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                preferredContentSize = CGSize(width: pwgPadSubViewWidth,
                                              height: ceil(mainScreenBounds.height * 2 / 3))
                let navBarHeight = navigationController?.navigationBar.bounds.size.height ?? 0.0
                editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0,
                                                                     bottom: navBarHeight, right: 0.0)
            }
            
            // Reload table view
            editImageParamsTableView.reloadData()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Check if the user is still editing parameters
        if (navigationController?.visibleViewController is SelectPrivacyViewController) || (navigationController?.visibleViewController is TagsViewController) {
            return
        }
        
        // Returning to image
        delegate?.didFinishEditingParameters()
    }
    
    deinit {
        debugPrint("EditImageParamsViewController of \(images.count) image(s) is being deinitialized.")
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Edit image Methods
    
    private func resetCommonParameters() {
        // Common title?
        shouldUpdateTitle = false
        if images[0].title.string == "NSNotFound" {
            commonTitle = NSAttributedString()
        } else {
            commonTitle = images[0].title
        }
        if images.contains(where: {$0.title != commonTitle}) {
            // Images titles are different
            commonTitle = NSAttributedString()
        }
        
        // Common author?
        shouldUpdateAuthor = false
        commonAuthor = images[0].author
        if images.contains(where: { $0.author != commonAuthor }) {
            // Images authors are different
            commonAuthor = ""
        }
        if commonAuthor == "NSNotFound" {
            commonAuthor = ""
        }
        
        // Common creation date is date of first image with non-nil value, or nil
        shouldUpdateDateCreated = false
        timeOffset = TimeInterval.zero
        commonDateCreated = Date(timeIntervalSinceReferenceDate: images[0].dateCreated)
        oldCreationDate = commonDateCreated
        
        // Common privacy?
        shouldUpdatePrivacyLevel = false
        commonPrivacyLevel = images[0].privacyLevel
        if images.contains(where: { $0.privacyLevel != commonPrivacyLevel}) {
            // Images privacy levels are different, display no level
            commonPrivacyLevel = pwgPrivacy.unknown.rawValue
        }
        
        // Common tags?
        shouldUpdateTags = false
        commonTags = images[0].tags ?? Set<Tag>()
        for index in 1..<images.count {
            // Get tags of next image
            guard let imageTags = images[index].tags else {
                // No tags —> next image
                continue
            }
            // Remove non-common tags
            commonTags.formIntersection(imageTags)
        }
        
        // Common comment?
        shouldUpdateComment = false
        commonComment = images[0].comment
        if images.contains(where: { $0.comment != commonComment}) {
            // Images comments are different, display no comment
            commonComment = NSAttributedString()
        }
    }
    
    @objc func cancelEdit() {
        // No change
        resetCommonParameters()

        // Return to image preview
        dismiss(animated: true)
    }

    @objc func doneEdit() {
        // Display HUD during the update
        if images.count > 1 {
            showHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"),
                    inMode: .determinate)
        } else {
            showHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingSingle", comment: "Updating Photo…"))
        }

        // Determine common time offset to apply
        timeOffset = commonDateCreated.timeIntervalSince(oldCreationDate)
        
        // Update all images
        let index = 0
        PwgSession.checkSession(ofUser: user) { [self] in
            updateImageProperties(fromIndex: index)
        } failure: { [self] error in
            // Display error
            self.hideHUD {
                self.showUpdatePropertiesError(error, atIndex: index)
            }
        }
    }

    func updateImageProperties(fromIndex index: Int) {
        // Any further image to update?
        if index == images.count {
            // Done, save, hide HUD and dismiss controller
            self.updateHUDwithSuccess { [self] in
                // Save changes
                try? mainContext.save()
                // Close HUD
                self.hideHUD(afterDelay: pwgDelayHUD) { [unowned self] in
                    // Return to image preview or album view
                    self.dismiss(animated: true)
                }
            }
            return
        }

        // Update image info on server
        /// The cache will be updated by the parent view controller.
        setProperties(ofImage: images[index]) { [self] in
            // Next image?
            self.updateHUD(withProgress: Float(index + 1) / Float(images.count))
            self.updateImageProperties(fromIndex: index + 1)
        }
        failure: { [self] error in
            // Display error
            self.hideHUD {
                self.showUpdatePropertiesError(error, atIndex: index)
            }
        }
    }

    private func showUpdatePropertiesError(_ error: NSError, atIndex index: Int) {
        // If there are images left, propose in addition to bypass the one creating problems
        // Session logout required?
        if let pwgError = error as? PwgSessionError,
           [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
            .contains(pwgError) {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
            return
        }

        // Report error
        let title = NSLocalizedString("editImageDetailsError_title", comment: "Failed to Update")
        let message = NSLocalizedString("editImageDetailsError_message", comment: "Failed to update your changes with your server.")
        if index + 1 < images.count {
            cancelDismissPiwigoError(withTitle: title, message: message,
                                     errorMessage: error.localizedDescription) {
            } dismiss: { [self] in
                // Bypass this image
                if index + 1 < images.count {
                    // Next image
                    updateImageProperties(fromIndex: index + 1)
                }
            }
        } else {
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) {
            }
        }
    }
    
    private func setProperties(ofImage imageData: Image,
                               completion: @escaping () -> Void,
                               failure: @escaping (NSError) -> Void) {
        // Image ID
        var paramsDict: [String : Any] = ["image_id" : imageData.pwgID,
                                          "single_value_mode"   : "replace",
                                          "multiple_value_mode" : "replace"]
        // Update image title?
        if shouldUpdateTitle {
            paramsDict["name"] = PwgSession.utf8mb3String(from: commonTitle.string)
        }

        // Update image author? (We should never set NSNotFound in the database)
        if shouldUpdateAuthor || imageData.author == "NSNotFound" {
            paramsDict["author"] = PwgSession.utf8mb3String(from: commonAuthor)
        }

        // Update image creation date?
        if shouldUpdateDateCreated {
            paramsDict["date_creation"] = DateUtilities.string(from: imageData.dateCreated + timeOffset)
        }

        // Update image privacy level?
        if shouldUpdatePrivacyLevel,
           commonPrivacyLevel != pwgPrivacy.unknown.rawValue {
            paramsDict["level"] = commonPrivacyLevel
        }

        // Update image tags?
        if shouldUpdateTags {
            var tags = imageData.tags ?? Set<Tag>()
            // Loop over the removed tags
            for tag in removedTags {
                tags.remove(tag)
            }
            // Loop over the added tags
            for tag in addedTags {
                tags.insert(tag)
            }
            let tagIDs: String = tags.map({"\($0.tagId),"}).reduce("", +)
            paramsDict["tag_ids"] = String(tagIDs.dropLast(1))
        }

        // Update image description?
        if shouldUpdateComment {
            paramsDict["comment"] = PwgSession.utf8mb3String(from: commonComment.string)
        }
        
        // Send request to Piwigo server
        PwgSession.checkSession(ofUser: user) {  [self] in
            PwgSession.shared.setInfos(with: paramsDict) { [self] in
                DispatchQueue.main.async { [self] in
                    // Update image title?
                    if shouldUpdateTitle {
                        let newTitle = PwgSession.utf8mb4String(from: (paramsDict["name"] as! String))
                        imageData.title = newTitle.htmlToAttributedString
                    }
                    
                    // Update image author? (We should never set NSNotFound in the database)
                    if shouldUpdateAuthor || imageData.author == "NSNotFound" {
                        imageData.author = commonAuthor
                    }
                    
                    // Update image creation date?
                    if shouldUpdateDateCreated {
                        imageData.dateCreated += timeOffset
                    }
                    
                    // Update image privacy level?
                    if shouldUpdatePrivacyLevel,
                       commonPrivacyLevel != pwgPrivacy.unknown.rawValue {
                        imageData.privacyLevel = commonPrivacyLevel
                    }
                    
                    // Update image tags?
                    if shouldUpdateTags {
                        // Loop over the removed tags
                        for tag in removedTags {
                            // Dissociate tag from image
                            imageData.removeFromTags(tag)
                            if tag.numberOfImagesUnderTag != Int64.max,
                               tag.numberOfImagesUnderTag > (Int64.min + 1) {   // Avoids possible crash
                                tag.numberOfImagesUnderTag -= 1
                            }
                            // Remove image from album of tagged images
                            let catID = pwgSmartAlbum.tagged.rawValue - Int32(tag.tagId)
                            if let albums = imageData.albums,
                               let albumData = albums.first(where: {$0.pwgID == catID}) {
                                imageData.removeFromAlbums(albumData)
                                
                                // Update albums
                                self.albumProvider.updateAlbums(removingImages: 1, fromAlbum: albumData)
                            }
                        }
                        // Loop over the added tags
                        for tag in addedTags {
                            // Associate tag to image
                            imageData.addToTags(tag)
                            if tag.numberOfImagesUnderTag < (Int64.max - 1) {   // Avoids possible crash
                                tag.numberOfImagesUnderTag += 1
                            }
                            // Add image to album of tagged images if it exists
                            let catID = pwgSmartAlbum.tagged.rawValue - Int32(tag.tagId)
                            if let albumData = self.albumProvider.getAlbum(withId: catID) {
                                imageData.addToAlbums(albumData)
                                
                                // Update albums
                                self.albumProvider.updateAlbums(addingImages: 1, toAlbum: albumData)
                            }
                        }
                    }
                    
                    // Update image description?
                    if shouldUpdateComment {
                        let newComment = PwgSession.utf8mb4String(from: (paramsDict["comment"] as! String))
                        imageData.comment = newComment.htmlToAttributedString
                    }
                    
                    // Save changes
                    mainContext.saveIfNeeded()
                    
                    // Notify album/image view of modification
                    self.delegate?.didChangeImageParameters(imageData)
                }
                
                // Image properties successfully updated
                completion()
            } failure: { error in
                failure(error)
            }
        } failure: { error in
            failure(error)
        }
    }
}
