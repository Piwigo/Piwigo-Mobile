//
//  EditImageParamsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/12/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.3 by Eddy Lelièvre-Berna on 31/08/2021.
//

import UIKit
import piwigoKit

@objc protocol EditImageParamsDelegate: NSObjectProtocol {
    func didDeselectImage(withId imageId: Int64)
    func didChangeImageParameters(_ imageData: PiwigoImageData)
    func didFinishEditingParameters()
}

class EditImageParamsViewController: UIViewController
{
    var images = [PiwigoImageData]()
    var hasTagCreationRights = false
    weak var delegate: EditImageParamsDelegate?

    @IBOutlet private weak var editImageParamsTableView: UITableView!

    private var commonParameters = PiwigoImageData()
    private var imagesToUpdate = [PiwigoImageData]()
    private var hasDatePicker = false
    private var shouldUpdateTitle = false
    private var shouldUpdateAuthor = false
    private var shouldUpdateDateCreated = false
    private var oldCreationDate: Date?
    private var shouldUpdatePrivacyLevel = false
    private var shouldUpdateTags = false
    private var addedTags = [PiwigoTagData]()
    private var removedTags = [PiwigoTagData]()
    private var shouldUpdateComment = false
    private var hudViewController: UIViewController?
    private var nberOfSelectedImages = 0
    
    private let kEditImageParamsViewWidth: CGFloat = 512.0
    
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

        // Initialise common image properties, mostly from first supplied image
        commonParameters = PiwigoImageData()
        imagesToUpdate = [PiwigoImageData]()

        // Common title?
        shouldUpdateTitle = false
        commonParameters.imageTitle = images[0].imageTitle
        if images.contains(where: { $0.imageTitle != commonParameters.imageTitle }) {
            // Images titles are different
            commonParameters.imageTitle = ""
        }

        // Common author?
        shouldUpdateAuthor = false
        commonParameters.author = images[0].author
        if images.contains(where: { $0.author != commonParameters.author }) {
            // Images authors are different
            commonParameters.author = ""
        }

        // Common creation date is date of first image with non-nil value, or nil
        shouldUpdateDateCreated = false
        commonParameters.dateCreated = images.first(where: { $0.dateCreated != nil })?.dateCreated
        oldCreationDate = commonParameters.dateCreated

        // Common privacy?
        shouldUpdatePrivacyLevel = false
        commonParameters.privacyLevel = images[0].privacyLevel
        if images.contains(where: { $0.privacyLevel != commonParameters.privacyLevel}) {
            // Images privacy levels are different, display no level
            commonParameters.privacyLevel = kPiwigoPrivacyObjcUnknown
        }

        // Common tags?
        shouldUpdateTags = false
        commonParameters.tags = images[0].tags ?? []
        var commonTags = commonParameters.tags
        for index in 1..<images.count {
            // Get tags of next image
            guard let imageTags = images[index].tags else {
                // No tags —> next image
                continue
            }
            // Loop over the common tags
            let copyOfCommonTags = commonTags
            for tag in copyOfCommonTags ?? [] {
                // Remove tags not belonging to other images
                if !imageTags.contains(where: { $0.tagId == tag.tagId }) {
                    commonTags?.removeAll(where: { $0.tagId == tag.tagId })
                    // Done if empty list
                    if (commonTags?.count ?? 0) == 0 { break }
                }
            }
            
            // Done if empty list
            if (commonTags?.count ?? 0) == 0 { break }
        }
        commonParameters.tags = commonTags

        // Common comment?
        shouldUpdateComment = false
        commonParameters.comment = images[0].comment
        if images.contains(where: { $0.comment != commonParameters.comment}) {
            // Images comments are different, display no comment
            commonParameters.comment = ""
        }

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
                preferredContentSize = CGSize(width: kPiwigoPadSubViewWidth,
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
        if delegate?.responds(to: #selector(EditImageParamsDelegate.didFinishEditingParameters)) ?? false {
            delegate?.didFinishEditingParameters()
        }
    }

    deinit {
        debugPrint("EditImageParamsViewController of \(images.count) image(s) is being deinitialized.")
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    
    // MARK: - Edit image Methods

    @objc func cancelEdit() {
        // No change
        commonParameters = PiwigoImageData()

        // Return to image preview
        dismiss(animated: true)
    }

    @objc func doneEdit() {
        // Initialise new image list and time shift
        var updatedImages: [PiwigoImageData] = []
        var timeInterval: TimeInterval = 0.0
        if let _ = commonParameters.dateCreated,
           let oldCreationDate = oldCreationDate {
                timeInterval = commonParameters.dateCreated.timeIntervalSince(oldCreationDate)
        }

        // Update all images
        for imageData in images {
            // Update image title?
            if shouldUpdateTitle,
                let imageTitle = commonParameters.imageTitle {
                imageData.imageTitle = imageTitle
            }

            // Update image author?
            if shouldUpdateAuthor,
                let author = commonParameters.author {
                imageData.author = author
            }

            // Update image creation date?
            if shouldUpdateDateCreated {
                if commonParameters.dateCreated == nil {
                    imageData.dateCreated = nil
                } else if oldCreationDate == nil {
                    imageData.dateCreated = commonParameters.dateCreated
                } else {
                    imageData.dateCreated = imageData.dateCreated.addingTimeInterval(timeInterval)
                }
            }

            // Update image privacy level?
            if shouldUpdatePrivacyLevel,
                (commonParameters.privacyLevel != kPiwigoPrivacyObjcUnknown) {
                imageData.privacyLevel = commonParameters.privacyLevel
            }

            // Update image tags?
            if shouldUpdateTags {
                // Retrieve tags of current image
                if var imageTags = imageData.tags
                {
                    // Loop over the removed tags
                    for tag in removedTags {
                        imageTags.removeAll(where: { $0.tagId == tag.tagId })
                    }

                    // Loop over the added tags
                    for tag in addedTags {
                        if !imageTags.contains(where: { $0.tagId == tag.tagId }) {
                            imageTags.append(tag)
                        }
                    }

                    // Update image tags
                    imageData.tags = imageTags
                }
            }

            // Update image description?
            if shouldUpdateComment,
               let comment = commonParameters.comment {
                imageData.comment = comment
            }

            // Append image data
            updatedImages.append(imageData)
        }
        images = updatedImages
        imagesToUpdate = updatedImages.compactMap({$0})

        // Start updating Piwigo database
        if imagesToUpdate.isEmpty { return }

        // Display HUD during the update
        if imagesToUpdate.count > 1 {
            nberOfSelectedImages = imagesToUpdate.count
            showPiwigoHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .annularDeterminate)
        } else {
            showPiwigoHUD(withTitle: NSLocalizedString("editImageDetailsHUD_updatingSingle", comment: "Updating Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)
        }
        updateImageProperties()
    }

    func updateImageProperties() {
        // Any further image to update?
        if imagesToUpdate.isEmpty {
            // Done, hide HUD and dismiss controller
            self.updatePiwigoHUDwithSuccess { [unowned self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [unowned self] in
                    // Return to image preview or album view
                    self.dismiss(animated: true)
                }
            }
            return
        }

        // Retrieve image to update
        guard let image = imagesToUpdate.last else {
            // Next image?
            self.imagesToUpdate.removeLast()
            self.updatePiwigoHUD(withProgress: 1.0 - Float(imagesToUpdate.count) / Float(nberOfSelectedImages))
            self.updateImageProperties()
            return
        }

        // Update image info on server
        /// The cache will be updated by the parent view controller.
        setProperties(ofImage: image) { [self] in
            // Next image?
            if self.imagesToUpdate.isEmpty ==  false {
                self.imagesToUpdate.removeLast()
            }
            self.updatePiwigoHUD(withProgress: 1.0 - Float(imagesToUpdate.count) / Float(nberOfSelectedImages))
            self.updateImageProperties()
        }
        failure: { [unowned self] error in
            // Display error
            self.hidePiwigoHUD {
                self.showUpdatePropertiesError(error)
            }
        }
    }

    private func showUpdatePropertiesError(_ error: NSError) {
        // If there are images left, propose in addition to bypass the one creating problems
        let title = NSLocalizedString("editImageDetailsError_title", comment: "Failed to Update")
        var message = NSLocalizedString("editImageDetailsError_message", comment: "Failed to update your changes with your server. Try again?")
        if imagesToUpdate.count > 1 {
            cancelDismissRetryPiwigoError(withTitle: title, message: message,
                                          errorMessage: error.localizedDescription, cancel: {
            }, dismiss: { [unowned self] in
                // Bypass this image
                imagesToUpdate.removeLast()
                // Next image
                if imagesToUpdate.count != 0 { updateImageProperties() }
            }, retry: { [unowned self] in
                // Relogin and retry
                LoginUtilities.reloginAndRetry() { [unowned self] in
                    updateImageProperties()
                } failure: { [unowned self] error in
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
                    updateImageProperties()
                } failure: { [unowned self] error in
                    message = NSLocalizedString("internetErrorGeneral_broken", comment: "Sorry…")
                    dismissPiwigoError(withTitle: title, message: message,
                                       errorMessage: error?.localizedDescription ?? "") { }
                }
            })
        }
    }
    
    private func setProperties(ofImage imageData: PiwigoImageData,
                               completion: @escaping () -> Void,
                               failure: @escaping (NSError) -> Void) {
        // Image ID
        var paramsDict: [String : Any] = ["image_id" : "\(NSNumber(value: imageData.imageId))",
                                          "single_value_mode"   : "replace",
                                          "multiple_value_mode" : "replace"]
        // Update image title?
        if shouldUpdateTitle,
           let title = imageData.imageTitle {
            paramsDict["name"] = NetworkUtilities.utf8mb3String(from: title)
        }

        // Update image author?
        if shouldUpdateAuthor,
           var name = imageData.author {
            // We should never set NSNotFound in the database
            if name == "NSNotFound" { name = "" }
            paramsDict["author"] = NetworkUtilities.utf8mb3String(from: name)
        }

        // Update image creation date?
        if shouldUpdateDateCreated,
           let creationDate = imageData.dateCreated {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss"
            paramsDict["date_creation"] = dateFormat.string(from: creationDate)
        }

        // Update image privacy level?
        if shouldUpdatePrivacyLevel {
            paramsDict["level"] = "\(NSNumber(value: imageData.privacyLevel.rawValue))"
        }

        // Update image tags?
        if shouldUpdateTags {
            let tags = imageData.tags?.compactMap({$0}) ?? []
            paramsDict["tag_ids"] = String(tags.map({"\($0.tagId),"}).reduce("", +).dropLast(1))
        }

        // Update image description?
        if shouldUpdateComment,
           let desc = imageData.comment {
            paramsDict["comment"] = NetworkUtilities.utf8mb3String(from: desc)
        }
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) {
            // Notify album/image view of modification
            DispatchQueue.main.async {
//                self.delegate?.didChangeImageParameters(imageData)
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
            cell.config(
                withLabel: NSLocalizedString("editImageDetails_title", comment: "Title"),
                placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"),
                andImageDetail: commonParameters.imageTitle)
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
            cell.config(
                withLabel: NSLocalizedString("editImageDetails_author", comment: "Author"),
                placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"),
                andImageDetail: (commonParameters.author == "NSNotFound") ? "" : commonParameters.author)
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
            cell.config(
                withLabel: NSLocalizedString("editImageDetails_dateCreation", comment: "Creation Date"),
                placeHolder: "",
                andImageDetail: getStringFrom(commonParameters.dateCreated))
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
                cell.config(withDate: commonParameters.dateCreated, animated: false)
                cell.delegate = self
                tableViewCell = cell
                
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "DatePickerTableCell", for: indexPath) as? EditImageDatePickerTableViewCell else {
                    print("Error: tableView.dequeueReusableCell does not return a EditImageDatePickerTableViewCell!")
                    return EditImageDatePickerTableViewCell()
                }
                cell.config(withDate: commonParameters.dateCreated, animated: false)
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
            cell.setPrivacyLevel(with: kPiwigoPrivacy(rawValue: Int16(commonParameters.privacyLevel.rawValue)) ?? .everybody,
                inColor: shouldUpdatePrivacyLevel ? .piwigoColorOrange() : .piwigoColorRightLabel())
            tableViewCell = cell
            
        case .tags:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
                return EditImageTagsTableViewCell()
            }
            cell.config(withList: commonParameters.tags,
                inColor: shouldUpdateTags ? .piwigoColorOrange() : .piwigoColorRightLabel())
            tableViewCell = cell
            
        case .desc:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "description", for: indexPath) as? EditImageTextViewTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
                return EditImageTextViewTableViewCell()
            }
            cell.config(withText: commonParameters.comment,
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

    private func getStringFrom(_ date: Date?) -> String? {
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
            privacyVC.privacy = kPiwigoPrivacy(rawValue: Int16(commonParameters.privacyLevel.rawValue)) ?? .everybody
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
            let tagList: [Int32] = (commonParameters.tags ?? []).compactMap { Int32($0.tagId) }
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
            // The common date can be nil or past distant (i.e. unset)
            if commonParameters.dateCreated == nil {
                // Define date as today
                commonParameters.dateCreated = Date()
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
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
                commonParameters.imageTitle = finalString
            case .author:
                // Author
                if (finalString?.count ?? 0) > 0 {
                    commonParameters.author = finalString
                } else {
                    commonParameters.author = "NSNotFound"
                }
            default:
                break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch EditImageParamsOrder(rawValue: textField.tag) {
            case .imageName:
                // Title
                commonParameters.imageTitle = ""
            case .author:
                // Author
                commonParameters.author = "NSNotFound"
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
                commonParameters.imageTitle = textField.text
            case .author:
                // Author
                if (textField.text?.count ?? 0) > 0 {
                    commonParameters.author = textField.text
                } else {
                    commonParameters.author = "NSNotFound"
                }
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
        commonParameters.comment = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        editImageParamsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonParameters.comment = textView.text
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
        var newImages = images
        var timeInterval: TimeInterval? = nil
        if let oldCreationDate = oldCreationDate {
            timeInterval = commonParameters.dateCreated.timeIntervalSince(oldCreationDate)
        }
        for imageData in images {
            if imageData.imageId == imageId {
                newImages.removeAll { $0 as AnyObject === imageData as AnyObject }
                break
            }
        }
        images = newImages

        // Update common creation date if needed
        for imageData in images {
            // Keep first non-nil date value
            if imageData.dateCreated != nil {
                oldCreationDate = imageData.dateCreated
                commonParameters.dateCreated = oldCreationDate?.addingTimeInterval(timeInterval ?? 0.0)
                break
            }
        }
        if commonParameters.dateCreated == nil {
            oldCreationDate = nil
        }

        // Refresh table
        editImageParamsTableView.reloadData()

        // Deselect image in album view
        delegate?.didDeselectImage(withId: imageId)
    }

    func didRenameFileOfImage(_ imageData: PiwigoImageData) {
        // Update data source
        if let index = images.firstIndex(where: { $0.imageId == imageData.imageId }) {
            images[index] = imageData
        }

        // Update parent image view
//        delegate?.didChangeImageParameters(imageData)
    }
}


// MARK: -  EditImageDatePickerDelegate Methods
extension EditImageParamsViewController: EditImageDatePickerDelegate
{
    func didSelectDate(withPicker date: Date?) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonParameters.dateCreated = date

        // Update cell
        let indexPath = IndexPath(row: EditImageParamsOrder.date.rawValue, section: 0)
        editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
    }

    func didUnsetImageCreationDate() {
        commonParameters.dateCreated = nil
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
    func didSelectDate(withShiftPicker date: Date?) {
        // Apply new date
        shouldUpdateDateCreated = true
        commonParameters.dateCreated = date

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
        let privacyLevelObjc = kPiwigoPrivacyObjc(rawValue: Int32(privacyLevel.rawValue))
        if privacyLevelObjc != commonParameters.privacyLevel {
            // Remember to update image info
            shouldUpdatePrivacyLevel = true
            commonParameters.privacyLevel = privacyLevelObjc

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
    func didSelectTags(_ selectedTags: [Tag]) {
        // Check if the user decided to leave the Edit mode
        if !(navigationController?.visibleViewController is EditImageParamsViewController) {
            // Return updated parameters
            if delegate?.responds(to: #selector(EditImageParamsDelegate.didFinishEditingParameters)) ?? false {
                delegate?.didFinishEditingParameters()
            }
            return
        }

        // Convert tags: Tag —> PiwigoTagData
        var selectedPiwigoTags = [PiwigoTagData]()
        for selectedTag in selectedTags {
            let piwigoTag = PiwigoTagData()
            piwigoTag.tagId = Int(selectedTag.tagId)
            piwigoTag.tagName = selectedTag.tagName
            piwigoTag.lastModified = selectedTag.lastModified
            piwigoTag.numberOfImagesUnderTag = selectedTag.numberOfImagesUnderTag
            selectedPiwigoTags.append(piwigoTag)
        }
        
        // Build list of added tags
        addedTags = []
        for tag in selectedPiwigoTags {
            if !commonParameters.tags.contains(where: { $0.tagId == tag.tagId }) {
                addedTags.append(tag)
            }
        }

        // Build list of removed tags
        removedTags = []
        for tag in commonParameters.tags {
            if !selectedPiwigoTags.contains(where: { $0.tagId == tag.tagId }) {
                removedTags.append(tag)
            }
        }

        // Do we need to update images?
        if (addedTags.isEmpty == false) || (removedTags.isEmpty == false) {
            // Update common tag list and remember to update image info
            shouldUpdateTags = true
            commonParameters.tags = selectedPiwigoTags

            // Refresh table row
            var row: Int = EditImageParamsOrder.tags.rawValue
            row -= !hasDatePicker ? 1 : 0
            row -= !NetworkVars.hasAdminRights ? 1 : 0
            let indexPath = IndexPath(row: row, section: 0)
            editImageParamsTableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
}
