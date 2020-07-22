//
//  UploadParametersViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

enum EditImageDetailsOrder : Int {
    case imageName
    case author
    case privacy
    case tags
    case comment
    case count
}

class UploadParametersViewController: UITableViewController, UITextFieldDelegate, UITextViewDelegate, SelectPrivacyDelegate, TagsViewControllerDelegate {

    @IBOutlet var paramsTableView: UITableView!

    var commonTitle = ""
    private var shouldUpdateTitle = false
    var commonAuthor = Model.sharedInstance()?.defaultAuthor ?? ""
    private var shouldUpdateAuthor = false
    var commonPrivacyLevel: kPiwigoPrivacy = Model.sharedInstance()?.defaultPrivacyLevel ?? kPiwigoPrivacyEverybody
    private var shouldUpdatePrivacyLevel = false
    var commonTags = [Tag]()
    private var shouldUpdateTags = false
    var commonComment = ""
    private var shouldUpdateComment = false

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
                                                                                        // and prevent their selection
        // Collection view identifier
        paramsTableView.accessibilityIdentifier = "Parameters"
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        paramsTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        paramsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }


    // MARK: - UITableView - No Header & Footer
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section header
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section footer
    }


    // MARK: - UITableView - Rows
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return EditImageDetailsOrder.count.rawValue
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 44.0
        switch EditImageDetailsOrder(rawValue: indexPath.row) {
        case .privacy, .tags:
                height = 78.0
        case .comment:
                height = 428.0
            default:
                break
        }
        return height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var tableViewCell = UITableViewCell()

        switch EditImageDetailsOrder(rawValue: indexPath.row) {
        case .imageName:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath) as? EditImageTextFieldTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
            return EditImageTextFieldTableViewCell()
        }
        cell.setup(withLabel: NSLocalizedString("editImageDetails_title", comment: "Title:"),
                   placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"),
                   andImageDetail: commonTitle)
        cell.cellTextField.textColor = shouldUpdateTitle ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel()
        cell.cellTextField.tag = EditImageDetailsOrder.imageName.rawValue
        cell.cellTextField.delegate = self
        tableViewCell = cell

        case .author:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "author", for: indexPath) as? EditImageTextFieldTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
            return EditImageTextFieldTableViewCell()
        }
        cell.setup(withLabel: NSLocalizedString("editImageDetails_author", comment: "Author:"),
                   placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"),
                   andImageDetail: (commonAuthor == "NSNotFound") ? "" : commonAuthor)
        cell.cellTextField.textColor = shouldUpdateAuthor ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel()
        cell.cellTextField.tag = EditImageDetailsOrder.author.rawValue
        cell.cellTextField.delegate = self
        tableViewCell = cell

        case .privacy:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "privacy", for: indexPath) as? EditImagePrivacyTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImagePrivacyTableViewCell!")
            return EditImagePrivacyTableViewCell()
        }
        cell.setLeftLabelText(NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
        cell.setPrivacyLevel(commonPrivacyLevel, in: shouldUpdatePrivacyLevel ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
        tableViewCell = cell

        case .tags:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
            return EditImageTagsTableViewCell()
        }
        // Switch to old cache data format
        var tagList = [PiwigoTagData]()
        commonTags.forEach { (tag) in
            let newTag = PiwigoTagData.init()
            newTag.tagId = Int(tag.tagId)
            newTag.tagName = tag.tagName
            newTag.lastModified = tag.lastModified
            newTag.numberOfImagesUnderTag = Int(tag.numberOfImagesUnderTag)
            tagList.append(newTag)
        }
        cell.setTagList(tagList, in: shouldUpdateTags ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
        tableViewCell = cell

        case .comment:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
            return EditImageTagsTableViewCell()
        }
        cell.setComment(commonComment, in: shouldUpdateComment ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
        cell.textView.delegate = self
        tableViewCell = cell

        default:
            break
        }

        tableViewCell.backgroundColor = UIColor.piwigoColorCellBackground()
        tableViewCell.tintColor = UIColor.piwigoColorOrange()
        return tableViewCell
    }


    // MARK: - UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedAction = EditImageDetailsOrder(rawValue: indexPath.row)
        switch selectedAction {
        case .author:
        if (commonAuthor == "NSNotFound") {
            // only update if not yet set, dont overwrite
            if 0 < Model.sharedInstance()?.defaultAuthor.count ?? 1 {
                // must know the default author
                commonAuthor = Model.sharedInstance().defaultAuthor
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }

        case .privacy:
        // Dismiss the keyboard
        view.endEditing(true)

        // Create view controller
        let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
        let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController
        privacyVC?.delegate = self
        privacyVC?.setPrivacy(commonPrivacyLevel)
        if let privacyVC = privacyVC {
            navigationController?.pushViewController(privacyVC, animated: true)
        }

        case .tags:
        // Dismiss the keyboard
        view.endEditing(true)

        // Create view controller
        let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
        if let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController {
            tagsVC.delegate = self
            tagsVC.setSelectedTagIds(commonTags.map({$0.tagId}))
            navigationController?.pushViewController(tagsVC, animated: true)
        }
            
        default:
            return
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        var result: Bool
        switch EditImageDetailsOrder(rawValue: indexPath.row) {
        case .imageName, .author, .comment:
            result = false
        default:
            result = true
        }
        return result
    }


    // MARK: - UITextFieldDelegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let tag = EditImageDetailsOrder(rawValue: textField.tag)
        switch tag {
        case .imageName:
            // Title
            shouldUpdateTitle = true
        case .author:
            // Author
            shouldUpdateAuthor = true
        default:
            break
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) else {
            return true
        }
        let tag = EditImageDetailsOrder(rawValue: textField.tag)
        switch tag {
        case .imageName:
        commonTitle = finalString
        
        case .author:
        if finalString.count > 0 {
            commonAuthor = finalString
        } else {
            commonAuthor = "NSNotFound"
        }
        
        default:
            break
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        let tag = EditImageDetailsOrder(rawValue: textField.tag)
        switch tag {
        case .imageName:
        commonTitle = ""

        case .author:
        commonAuthor = "NSNotFound"

        default:
            break
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        paramsTableView.endEditing(true)
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let tag = EditImageDetailsOrder(rawValue: textField.tag)
        switch tag {
        case .imageName:
        if let typedText = textField.text {
            commonTitle = typedText
        }
        // Update cell
        let indexPath = IndexPath.init(row: EditImageDetailsOrder.imageName.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)

        case .author:
        if let typedText = textField.text, typedText.count > 0 {
            commonAuthor = typedText
        } else {
            commonAuthor = "NSNotFound"
        }
        // Update cell
        let indexPath = IndexPath.init(row: EditImageDetailsOrder.author.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)

        default:
            break
        }
    }

    
    // MARK: - UITextViewDelegate Methods

    func textViewDidBeginEditing(_ textView: UITextView) {
        shouldUpdateComment = true
        textView.textColor = UIColor.piwigoColorOrange()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let finalString = (textView.text as NSString).replacingCharacters(in: range, with: text)
        commonComment = finalString
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        paramsTableView.endEditing(true)
        return true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        commonComment = textView.text
    }


    // MARK: - SelectedPrivacyDelegate Methods
    func didSelectPrivacyLevel(_ privacyLevel: kPiwigoPrivacy) {
        // Update image parameter
        commonPrivacyLevel = privacyLevel

        // Remember to update image info
        shouldUpdatePrivacyLevel = true

        // Update cell
        let indexPath = IndexPath.init(row: EditImageDetailsOrder.privacy.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    
    // MARK: - TagsViewControllerDelegate Methods
    func didSelectTags(_ tags: [Tag]?) {
        // Update image parameter
        if let selectedTags = tags {
            commonTags = selectedTags
        } else {
            commonTags = [Tag]()
        }

        // Remember to update image info
        shouldUpdateTags = true

        // Update cell
        let indexPath = IndexPath.init(row: EditImageDetailsOrder.privacy.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
