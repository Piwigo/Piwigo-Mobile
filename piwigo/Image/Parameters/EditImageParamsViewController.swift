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
    
//    var imageProvider: ImageProvider!
    var savingContext: NSManagedObjectContext!

    @IBOutlet private weak var editImageParamsTableView: UITableView!
    private var hudViewController: UIViewController?
    private let kEditImageParamsViewWidth: CGFloat = 512.0

    private var shouldUpdateTitle = false
    private var commonTitle = NSAttributedString()
    
    private var shouldUpdateAuthor = false
    private var commonAuthor = ""
    
    private var hasDatePicker = false
    private var shouldUpdateDateCreated = false
    private var commonDateCreated = Date.distantPast
    private var oldCreationDate = Date()
    private var timeOffset = TimeInterval.zero

    private var shouldUpdatePrivacyLevel = false
    private var commonPrivacyLevel = kPiwigoPrivacy.everybody.rawValue
    
    private var shouldUpdateTags = false
    private var commonTags = Set<Tag>()
    private var addedTags = Set<Tag>()
    private var removedTags = Set<Tag>()
    
    private var shouldUpdateComment = false
    private var commonComment = NSAttributedString()
    
    enum EditImageParamsOrder : Int {
        case thumbnails
        case imageName
        case author
        case date
        case datePicker
        case privacy
        case tags
        case desc
        case count
    }
    
    
    // MARK: - View Lifecycle
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()
        
        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
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
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Adjust content inset
        // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
        let navBarHeight = navigationController?.navigationBar.bounds.size.height ?? 0.0
        let tableHeight = editImageParamsTableView.bounds.size.height
        let viewHeight = view.bounds.size.height
        
        // On iPad, the form is presented in a popover view
        if UIDevice.current.userInterfaceIdiom == .pad {
            editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: CGFloat(max(0.0, tableHeight + navBarHeight - viewHeight)), right: 0.0)
        } else {
            let statBarHeight = UIApplication.shared.statusBarFrame.size.height
            editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: CGFloat(max(0.0, tableHeight + statBarHeight + navBarHeight - viewHeight)), right: 0.0)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            
            // Adjust content inset
            // See https://stackoverflow.com/questions/1983463/whats-the-uiscrollview-contentinset-property-for
            let navBarHeight = navigationController?.navigationBar.bounds.size.height ?? 0.0
            let tableHeight = editImageParamsTableView.bounds.size.height
            
            // On iPad, the form is presented in a popover view
            if UIDevice.current.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                preferredContentSize = CGSize(width: pwgPadSubViewWidth,
                                              height: ceil(mainScreenBounds.height * 2 / 3))
                editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: CGFloat(max(0.0, tableHeight + navBarHeight - size.height)), right: 0.0)
            } else {
                let statBarHeight = UIApplication.shared.statusBarFrame.size.height
                editImageParamsTableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: CGFloat(max(0.0, tableHeight + statBarHeight + navBarHeight - size.height)), right: 0.0)
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
        
        // Return updated parameters
        delegate?.didFinishEditingParameters()
    }
    
    deinit {
        debugPrint("EditImageParamsViewController of \(images.count) image(s) is being deinitialized.")
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
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
        
        // Common creation date is date of first image with non-nil value, or nil
        shouldUpdateDateCreated = false
        timeOffset = TimeInterval.zero
        commonDateCreated = images[0].dateCreated
        oldCreationDate = commonDateCreated
        
        // Common privacy?
        shouldUpdatePrivacyLevel = false
        commonPrivacyLevel = images[0].privacyLevel
        if images.contains(where: { $0.privacyLevel != commonPrivacyLevel}) {
            // Images privacy levels are different, display no level
            commonPrivacyLevel = kPiwigoPrivacy.unknown.rawValue
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
            showPiwigoHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .annularDeterminate)
        } else {
            showPiwigoHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingSingle", comment: "Updating Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        }

        // Determine common time offset to apply
        timeOffset = commonDateCreated.timeIntervalSince(oldCreationDate)
        
        // Update all images
        let index = 0
        updateImageProperties(fromIndex: index)
        
//        for (index, image) in images.enumerated() {
//            // Change properties
//            setProperties(ofImage: image, withTimeOffset: timeInterval) {
//                DispatchQueue.main.async {
//                    self.updatePiwigoHUD(withProgress: 1.0 - Float(index) / Float(self.nberOfSelectedImages))
//                }
//            } failure: { error in
//                // Display error
//                self.hidePiwigoHUD {
//                    self.showUpdatePropertiesError(error)
//                }
//                return
//            }

            // Update image title?
//            if shouldUpdateTitle,
//                let imageTitle = commonTitle {
//                imageData.imageTitle = imageTitle
//            }

            // Update image author?
//            if shouldUpdateAuthor,
//                let author = commonAuthor {
//                imageData.author = author
//            }

            // Update image creation date?
//            if shouldUpdateDateCreated {
//                if commonDateCreated == nil {
//                    imageData.dateCreated = nil
//                } else if oldCreationDate == nil {
//                    imageData.dateCreated = commonDateCreated
//                } else {
//                    imageData.dateCreated = imageData.dateCreated.addingTimeInterval(timeInterval)
//                }
//            }

            // Update image privacy level?
//            if shouldUpdatePrivacyLevel,
//                (commonPrivacyLevel != kPiwigoPrivacyObjcUnknown) {
//                imageData.privacyLevel = commonPrivacyLevel
//            }
//
            // Update image tags?
//            if shouldUpdateTags {
//                // Retrieve tags of current image
//                if var imageTags = imageData.tags
//                {
//                    // Loop over the removed tags
//                    for tag in removedTags {
//                        imageTags.removeAll(where: { $0.tagId == tag.tagId })
//                    }
//
//                    // Loop over the added tags
//                    for tag in addedTags {
//                        if !imageTags.contains(where: { $0.tagId == tag.tagId }) {
//                            imageTags.append(tag)
//                        }
//                    }
//
//                    // Update image tags
//                    imageData.tags = imageTags
//                }
//            }

            // Update image description?
//            if shouldUpdateComment,
//               let comment = commonComment {
//                imageData.comment = comment
//            }

            // Append image data
//            updatedImages.append(imageData)
//        }
//        images = updatedImages
//        imagesToUpdate = updatedImages.compactMap({$0})

        // Start updating Piwigo database
//        if imagesToUpdate.isEmpty { return }

//        updateImageProperties()
    }

    func updateImageProperties(fromIndex index: Int) {
        // Any further image to update?
            if index == images.count {
            // Done, hide HUD and dismiss controller
            self.updatePiwigoHUDwithSuccess { [self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [unowned self] in
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
            self.updatePiwigoHUD(withProgress: 1.0 - Float(index + 1) / Float(images.count))
            self.updateImageProperties(fromIndex: index + 1)
        }
        failure: { [unowned self] error in
            // Display error
            self.hidePiwigoHUD {
                self.showUpdatePropertiesError(error, atIndex: index)
            }
        }
    }

    private func showUpdatePropertiesError(_ error: NSError, atIndex index: Int) {
        // If there are images left, propose in addition to bypass the one creating problems
        let title = NSLocalizedString("editImageDetailsError_title", comment: "Failed to Update")
        var message = NSLocalizedString("editImageDetailsError_message", comment: "Failed to update your changes with your server. Try again?")
        if index + 1 < images.count {
            cancelDismissRetryPiwigoError(withTitle: title, message: message,
                                          errorMessage: error.localizedDescription, cancel: {
            }, dismiss: { [self] in
                // Bypass this image
                if index + 1 < images.count {
                    // Next image
                    updateImageProperties(fromIndex: index + 1)
                }
            }, retry: { [self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [self] in
                    updateImageProperties(fromIndex: index)
                } failure: { [self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { }
                }
            })
        } else {
            dismissRetryPiwigoError(withTitle: title, message: message,
                                    errorMessage: error.localizedDescription, dismiss: {
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    updateImageProperties(fromIndex: index)
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { }
                }
            })
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
            paramsDict["name"] = NetworkUtilities.utf8mb3String(from: commonTitle.string)
        }

        // Update image author? (We should never set NSNotFound in the database)
        if shouldUpdateAuthor || imageData.author == "NSNotFound" {
            paramsDict["author"] = NetworkUtilities.utf8mb3String(from: commonAuthor)
        }

        // Update image creation date?
        if shouldUpdateDateCreated {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateCreated = imageData.dateCreated.addingTimeInterval(timeOffset)
            paramsDict["date_creation"] = dateFormat.string(from: dateCreated)
        }

        // Update image privacy level?
        if shouldUpdatePrivacyLevel,
           commonPrivacyLevel != kPiwigoPrivacy.unknown.rawValue {
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
            paramsDict["tag_ids"] = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        }

        // Update image description?
        if shouldUpdateComment {
            paramsDict["comment"] = NetworkUtilities.utf8mb3String(from: commonComment.string)
        }
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [self] in
            DispatchQueue.main.async { [self] in
                // Update image title?
                if shouldUpdateTitle {
                    imageData.title = commonTitle
                }

                // Update image author? (We should never set NSNotFound in the database)
                if shouldUpdateAuthor || imageData.author == "NSNotFound" {
                    imageData.author = commonAuthor
                }

                // Update image creation date?
                if shouldUpdateDateCreated {
                    imageData.dateCreated.addTimeInterval(timeOffset)
                }

                // Update image privacy level?
                if shouldUpdatePrivacyLevel,
                   commonPrivacyLevel != kPiwigoPrivacy.unknown.rawValue {
                    imageData.privacyLevel = commonPrivacyLevel
                }

                // Update image tags?
                if shouldUpdateTags {
                    // Loop over the removed tags
                    for tag in removedTags {
                        imageData.removeFromTags(tag)
                    }
                    // Loop over the added tags
                    for tag in addedTags {
                        imageData.addToTags(tag)
                    }
                }

                // Update image description?
                if shouldUpdateComment {
                    imageData.comment = commonComment
                }

                // Notify album/image view of modification
                self.delegate?.didChangeImageParameters(imageData)
            }

            // Image properties successfully updated
            completion()
        } failure: { error in
            failure(error)
        }
    }
}


// MARK: - UITableViewDataSource Methods
extension EditImageParamsViewController: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var nberOfRows = EditImageParamsOrder.count.rawValue
        nberOfRows -= hasDatePicker ? 0 : 1
        nberOfRows -= NetworkVars.hasAdminRights ? 0 : 1
        return nberOfRows
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 44.0
        var row = indexPath.row
        row += (!hasDatePicker && (row > EditImageParamsOrder.date.rawValue)) ? 1 : 0
        row += (!NetworkVars.hasAdminRights && (row > EditImageParamsOrder.datePicker.rawValue)) ? 1 : 0
        switch EditImageParamsOrder(rawValue: row) {
            case .thumbnails:
                height = 188.0
            case .datePicker:
                if images.count > 1 {
                    // Time interval picker
                    height = 258.0
                } else {
                    // Date picker
                    height = 304.0
                }
            case .privacy, .tags:
                height = 73.0
            case .desc:
                height = 428.0
            default:
                break
        }

        return height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        var row = indexPath.row
        row += (!hasDatePicker && (row > EditImageParamsOrder.date.rawValue)) ? 1 : 0
        row += (!NetworkVars.hasAdminRights && (row > EditImageParamsOrder.datePicker.rawValue)) ? 1 : 0
        switch EditImageParamsOrder(rawValue: row) {
        case .thumbnails:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "EditImageThumbTableViewCell", for: indexPath) as? EditImageThumbTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageThumbTableViewCell!")
                return EditImageThumbTableViewCell()
            }
            cell.config(withImages: images)
            cell.delegate = self
            tableViewCell = cell
            
        case .imageName:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath) as? EditImageTextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
                return EditImageTextFieldTableViewCell()
            }
            let wholeRange = NSRange(location: 0, length: commonTitle.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.right
            let attributes = [
                NSAttributedString.Key.font: UIFont.piwigoFontNormal(),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let detail = NSMutableAttributedString(attributedString: commonTitle)
            detail.addAttributes(attributes, range: wholeRange)
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_title", comment: "Title")), placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"), andImageDetail: detail)
            if shouldUpdateTitle {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = row
            cell.cellTextField.delegate = self
            tableViewCell = cell
            
        case .author:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "author", for: indexPath) as? EditImageTextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
                return EditImageTextFieldTableViewCell()
            }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_author", comment: "Author")), placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"), andImageDetail: NSAttributedString(string: commonAuthor))
            if shouldUpdateAuthor {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = row
            cell.cellTextField.delegate = self
            tableViewCell = cell
            
        case .date:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "dateCreation", for: indexPath) as? EditImageTextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
                return EditImageTextFieldTableViewCell()
            }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_dateCreation", comment: "Creation Date")), placeHolder: "", andImageDetail: NSAttributedString(string: getStringFrom(commonDateCreated)))
            if shouldUpdateDateCreated {
                cell.cellTextField.textColor = .piwigoColorOrange()
            }
            cell.cellTextField.tag = row
            cell.cellTextField.delegate = self
            tableViewCell = cell
            
        case .datePicker:
            // Which picker?
            if images.count > 1 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "ShiftPickerTableCell", for: indexPath) as? EditImageShiftPickerTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageShiftPickerTableViewCell!")
                    return EditImageShiftPickerTableViewCell()
                }
                cell.config(withDate: commonDateCreated, animated: false)
                cell.delegate = self
                tableViewCell = cell
                
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerTableCell", for: indexPath) as? EditImageDatePickerTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageDatePickerTableViewCell!")
                    return EditImageDatePickerTableViewCell()
                }
                cell.config(withDate: commonDateCreated, animated: false)
                cell.setDatePickerButtons()
                cell.delegate = self
                tableViewCell = cell
            }
            
        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "privacy", for: indexPath) as? EditImagePrivacyTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImagePrivacyTableViewCell!")
                return EditImagePrivacyTableViewCell()
            }
            cell.setLeftLabel(withText: NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
            cell.setPrivacyLevel(with: kPiwigoPrivacy(rawValue: commonPrivacyLevel) ?? .everybody,
                                 inColor: shouldUpdatePrivacyLevel ? .piwigoColorOrange() : .piwigoColorRightLabel())
            tableViewCell = cell
            
        case .tags:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
                return EditImageTagsTableViewCell()
            }
            cell.config(withList: commonTags,
                        inColor: shouldUpdateTags ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
            tableViewCell = cell
            
        case .desc:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "description", for: indexPath) as? EditImageTextViewTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
                return EditImageTextViewTableViewCell()
            }
            cell.config(withText: commonComment,
                        inColor: shouldUpdateTags ? .piwigoColorOrange() : .piwigoColorRightLabel())
            cell.textView.delegate = self
            tableViewCell = cell
            
        default:
            break
        }

        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()
        return tableViewCell
    }

    private func getStringFrom(_ date: Date?) -> String {
        var dateStr = ""
        var timeStr = ""
        if let date = date {
            if view.bounds.size.width > 375 {
                // i.e. larger than iPhones 6,7,8 screen width
                dateStr = DateFormatter.localizedString(from: date, dateStyle: .long, timeStyle: .none)
                timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
            } else if view.bounds.size.width > 320 {
                // i.e. larger than iPhone 5 screen width
                dateStr = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
            } else {
                dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
                timeStr = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
            }
        }
        return "\(dateStr) - \(timeStr)"
    }
}
    
 
// MARK: - UITableViewDelegate Methods
extension EditImageParamsViewController: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section header
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section footer
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var row = indexPath.row
        row += (!hasDatePicker && (row > EditImageParamsOrder.date.rawValue)) ? 1 : 0
        row += (!NetworkVars.hasAdminRights && (row > EditImageParamsOrder.datePicker.rawValue)) ? 1 : 0
        switch EditImageParamsOrder(rawValue: row) {
        case .privacy:
            // Deselect row
            tableView.deselectRow(at: indexPath, animated: true)

            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
            guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController else { return }
            privacyVC.delegate = self
            privacyVC.privacy = kPiwigoPrivacy(rawValue: commonPrivacyLevel) ?? .everybody
            navigationController?.pushViewController(privacyVC, animated: true)
            
        case .tags:
            // Deselect row
            tableView.deselectRow(at: indexPath, animated: true)

            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
            guard let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController else { return }
            tagsVC.delegate = self
            let tagList: [Int32] = commonTags.compactMap { Int32($0.tagId) }
            tagsVC.setPreselectedTagIds(tagList)
            tagsVC.setTagCreationRights(hasTagCreationRights)
            navigationController?.pushViewController(tagsVC, animated: true)
            
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var result: Bool
        var row = indexPath.row
        row += (!hasDatePicker && (row > EditImageParamsOrder.date.rawValue)) ? 1 : 0
        row += (!NetworkVars.hasAdminRights && (row > EditImageParamsOrder.datePicker.rawValue)) ? 1 : 0
        switch EditImageParamsOrder(rawValue: row) {
            case .imageName, .author, .date, .datePicker, .desc:
                result = false
            default:
                result = true
        }

        return result
    }
}
    
 
// MARK: - UITextFieldDelegate Methods
extension EditImageParamsViewController: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.tag == EditImageParamsOrder.date.rawValue {
            // The common date can be distant past (i.e. unset)
            if commonDateCreated == .distantPast {
                // Define date as today
                commonDateCreated = Date()
                shouldUpdateDateCreated = true

                // Update creation date
                let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
                editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
            }

            // Show date or hide picker
            let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
            if hasDatePicker {
                // Found a picker, so remove it
                hasDatePicker = false
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            } else {
                // Didn't find a picker, so we should insert it
                hasDatePicker = true
                editImageParamsTableView.beginUpdates()
                editImageParamsTableView.insertRows(at: [indexPath], with: .fade)
                editImageParamsTableView.endUpdates()
            }

            // Prevent keyboard from opening
            return false
        }

        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
                shouldUpdateTitle = true
                textField.textColor = .piwigoColorOrange()
            case .author:
                // Author
                shouldUpdateAuthor = true
                textField.textColor = .piwigoColorOrange()
            default:
                break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            else { return false }
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
                commonTitle = finalString.htmlToAttributedString
            case .author:
                // Author
                commonAuthor = finalString
            default:
                break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
            commonTitle = "".htmlToAttributedString
            case .author:
                // Author
                commonAuthor = ""
            default:
                break
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
            commonTitle = (textField.text ?? "").htmlToAttributedString
            case .author:
                // Author
                commonAuthor = textField.text ?? ""
            default:
                break
        }
    }
}


// MARK: - UITextViewDelegate Methods
extension EditImageParamsViewController: UITextViewDelegate
{
    func textViewDidBeginEditing(_ textView: UITextView) {
        shouldUpdateComment = true
        textView.textColor = .piwigoColorOrange()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        commonComment = finalString.htmlToAttributedString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonComment = textView.text.htmlToAttributedString
    }
}


// MARK: - EditImageThumbnailCellDelegate Methods
extension EditImageParamsViewController: EditImageThumbnailCellDelegate
{
    func didDeselectImage(withId imageId: Int64) {
        // Hide picker if needed
        let indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
        if hasDatePicker {
            // Found a picker, so remove it
            hasDatePicker = false
            editImageParamsTableView.beginUpdates()
            editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
            editImageParamsTableView.endUpdates()
        }

        // Update data source
        let timeInterval = commonDateCreated.timeIntervalSince(oldCreationDate)
        images.removeAll(where: {$0.pwgID == imageId})

        // Update common creation date if needed
        oldCreationDate = images[0].dateCreated
        commonDateCreated = oldCreationDate.addingTimeInterval(timeInterval)

        // Refresh table
        editImageParamsTableView.reloadData()

        // Deselect image in album view
        delegate?.didDeselectImage(withId: imageId)
    }

    func didRenameFileOfImage(_ imageData: Image) {
        // Update data source
//        if let index = images.firstIndex(where: { $0.imageId == imageData.imageId }) {
//            images[index] = imageData
//        }
        do {
            try savingContext?.save()
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }

        // Update parent image view
        delegate?.didChangeImageParameters(imageData)
    }
}


// MARK: -  EditImageDatePickerDelegate Methods
extension EditImageParamsViewController: EditImageDatePickerDelegate
{
    func didSelectDate(withPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonDateCreated = date

        // Update cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func didUnsetImageCreationDate() {
        commonDateCreated = .distantPast
        shouldUpdateDateCreated = true

        // Close date picker
        var indexPath = IndexPath(row: EditImageParamsOrder.datePicker.rawValue, section: 0)
        if hasDatePicker {
            hasDatePicker = false
            editImageParamsTableView.beginUpdates()
            editImageParamsTableView.deleteRows(at: [indexPath], with: .fade)
            editImageParamsTableView.endUpdates()
        }

        // Update creation date cell
        indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}


// MARK: -  EditImageShiftPickerDelegate Methods
extension EditImageParamsViewController: EditImageShiftPickerDelegate
{
    func didSelectDate(withShiftPicker date: Date) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonDateCreated = date

        // Update cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}


// MARK: - SelectPrivacyObjcDelegate Methods
extension EditImageParamsViewController: SelectPrivacyDelegate
{
    func didSelectPrivacyLevel(_ privacyLevel: kPiwigoPrivacy) {
        // Check if the user decided to leave the Edit mode
        if !(navigationController?.visibleViewController is EditImageParamsViewController) {
            // Return updated parameters
            if delegate?.responds(to: #selector(EditImageParamsDelegate.didFinishEditingParameters)) ?? false {
                delegate?.didFinishEditingParameters()
            }
            return
        }

        // Update image parameter?
        if privacyLevel.rawValue != commonPrivacyLevel {
            // Remember to update image info
            shouldUpdatePrivacyLevel = true
            commonPrivacyLevel = privacyLevel.rawValue

            // Refresh table row
            let row = EditImageParamsOrder.privacy.rawValue - (hasDatePicker == false ? 1 : 0)
            let indexPath = IndexPath(row: row, section: 0)
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}


// MARK: - TagsViewControllerObjcDelegate Methods
extension EditImageParamsViewController: TagsViewControllerDelegate
{
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Check if the user decided to leave the Edit mode
        if !(navigationController?.visibleViewController is EditImageParamsViewController) {
            // Return updated parameters
            delegate?.didFinishEditingParameters()
            return
        }

        // Build list of added tags
        addedTags = []
        for tag in selectedTags {
            if commonTags.contains(where: { $0.tagId == tag.tagId }) == false {
                addedTags.insert(tag)
            }
        }

        // Build list of removed tags
        removedTags = []
        for tag in commonTags {
            if !selectedTags.contains(where: { $0.tagId == tag.tagId }) {
                removedTags.insert(tag)
            }
        }

        // Do we need to update images?
        if (addedTags.isEmpty == false) || (removedTags.isEmpty == false) {
            // Update common tag list and remember to update image info
            shouldUpdateTags = true
            commonTags = Set(selectedTags)

            // Refresh table row
            var row: Int = EditImageParamsOrder.tags.rawValue
            row -= !hasDatePicker ? 1 : 0
            row -= !NetworkVars.hasAdminRights ? 1 : 0
            let indexPath = IndexPath(row: row, section: 0)
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
