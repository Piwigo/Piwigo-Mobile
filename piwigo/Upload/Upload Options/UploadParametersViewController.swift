//
//  UploadParametersViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 15/07/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
import piwigoKit

enum EditImageDetailsOrder : Int {
    case imageName
    case author
    case privacy
    case tags
    case comment
    case count
}

class UploadParametersViewController: UITableViewController, UITextFieldDelegate, UITextViewDelegate {

    @IBOutlet var paramsTableView: UITableView!

    var commonTitle = ""
    private var shouldUpdateTitle = false
    var commonAuthor = UploadVars.defaultAuthor
    private var shouldUpdateAuthor = false
    var commonPrivacyLevel = kPiwigoPrivacy(rawValue: UploadVars.defaultPrivacyLevel)
    private var shouldUpdatePrivacyLevel = false
    var commonTags = [Tag]()
    private var shouldUpdateTags = false
    var commonComment = ""
    private var shouldUpdateComment = false

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Collection view identifier
        paramsTableView.accessibilityIdentifier = "Parameters"
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        paramsTableView.separatorColor = UIColor.piwigoColorSeparator()
        paramsTableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
        paramsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }


    // MARK: - UITableView - Header
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString = "\(NSLocalizedString("imageDetailsView_title", comment: "Properties"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("imageUploadHeaderText_images", comment: "Please set the parameters to apply to the selection of photos/videos")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("imageDetailsView_title", comment: "Properties"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("imageUploadHeaderText_images", comment: "Please set the parameters to apply to the selection of photos/videos")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        headerAttributedString.append(textAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        }

        return header
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0 // To hide the section footer
    }


    // MARK: - UITableView - Rows
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Don't present privacy level choice to non-admin users
        var nberOfRows = EditImageDetailsOrder.count.rawValue
        nberOfRows -= (!NetworkVars.hasAdminRights ? 1 : 0)

        return nberOfRows
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!NetworkVars.hasAdminRights && (row > 1)) ? 1 : 0

        var height: CGFloat = 44.0
        switch EditImageDetailsOrder(rawValue: row) {
            case .privacy, .tags:
                height = 78.0
            case .comment:
                height = 428.0
                height += !NetworkVars.hasAdminRights ? 78.0 : 0.0
            default:
                break
        }
        return height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!NetworkVars.hasAdminRights && (row > 1)) ? 1 : 0

        var tableViewCell = UITableViewCell()
        switch EditImageDetailsOrder(rawValue: row) {
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
        cell.setLeftLabel(withText: NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
        let privLevelObjc = kPiwigoPrivacyObjc(rawValue: Int32(commonPrivacyLevel?.rawValue ?? 0))
        cell.setPrivacyLevel(with: privLevelObjc,
                             inColor: shouldUpdatePrivacyLevel ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
        tableViewCell = cell

        case .tags:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
            return EditImageTagsTableViewCell()
        }
        // Switch to old cache data format
        var tagList = [PiwigoTagData]()
        commonTags.forEach { (tag) in
            let newTag = PiwigoTagData()
            newTag.tagId = Int(tag.tagId)
            newTag.tagName = tag.tagName
            newTag.lastModified = tag.lastModified
            newTag.numberOfImagesUnderTag = tag.numberOfImagesUnderTag
            tagList.append(newTag)
        }
        cell.setTagList(fromList: tagList,
                        inColor: shouldUpdateTags ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
        tableViewCell = cell

        case .comment:
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
            return EditImageTextViewTableViewCell()
        }
        cell.setDescription(withText: commonComment,
                            inColor: shouldUpdateComment ? UIColor.piwigoColorOrange() : UIColor.piwigoColorRightLabel())
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

        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!NetworkVars.hasAdminRights && (row > 1)) ? 1 : 0

        switch EditImageDetailsOrder(rawValue: row) {
        case .author:
        if (commonAuthor == "NSNotFound") {
            // only update if not yet set, dont overwrite
            if 0 < UploadVars.defaultAuthor.count {
                // must know the default author
                commonAuthor = UploadVars.defaultAuthor
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
        privacyVC?.privacy = commonPrivacyLevel ?? .everybody
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
            tagsVC.setPreselectedTagIds(commonTags.map({$0.tagId}))
            // Can we propose to create tags?
            if let switchVC = parent as? UploadSwitchViewController {
                tagsVC.setTagCreationRights(switchVC.hasTagCreationRights)
            }
            navigationController?.pushViewController(tagsVC, animated: true)
        }
            
        default:
            return
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!NetworkVars.hasAdminRights && (row > 1)) ? 1 : 0

        var result: Bool
        switch EditImageDetailsOrder(rawValue: row) {
        case .imageName, .author, .comment:
            result = false
        default:
            result = true
        }
        return result
    }


    // MARK: - UITextFieldDelegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        switch EditImageDetailsOrder(rawValue: textField.tag) {
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
        switch EditImageDetailsOrder(rawValue: textField.tag) {
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
        switch EditImageDetailsOrder(rawValue: textField.tag) {
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
        switch EditImageDetailsOrder(rawValue: textField.tag) {
        case .imageName:
            if let typedText = textField.text {
                commonTitle = typedText
            }
            // Update cell
            let indexPath = IndexPath(row: EditImageDetailsOrder.imageName.rawValue, section: 0)
            paramsTableView.reloadRows(at: [indexPath], with: .automatic)
        case .author:
            if let typedText = textField.text, typedText.count > 0 {
                commonAuthor = typedText
            } else {
                commonAuthor = "NSNotFound"
            }
            // Update cell
            let indexPath = IndexPath(row: EditImageDetailsOrder.author.rawValue, section: 0)
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
}

// MARK: - SelectPrivacyDelegate Methods
extension UploadParametersViewController: SelectPrivacyDelegate {
    func didSelectPrivacyLevel(_ privacyLevel: kPiwigoPrivacy) {
        // Update image parameter
        commonPrivacyLevel = privacyLevel

        // Remember to update image info
        shouldUpdatePrivacyLevel = true

        // Update cell
        let indexPath = IndexPath(row: EditImageDetailsOrder.privacy.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - TagsViewControllerDelegate Methods
extension UploadParametersViewController: TagsViewControllerDelegate {
    func didSelectTags(_ selectedTags: [Tag]) {
        // Update image parameter
        commonTags = selectedTags

        // Remember to update image info
        shouldUpdateTags = true

        // Update cell
        let indexPath = IndexPath(row: EditImageDetailsOrder.tags.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
