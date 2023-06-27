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
    var commonPrivacyLevel = pwgPrivacy(rawValue: UploadVars.defaultPrivacyLevel) ?? .everybody
    private var shouldUpdatePrivacyLevel = false
    var commonTags = Set<Tag>()
    private var shouldUpdateTags = false
    var commonComment = ""
    private var shouldUpdateComment = false
    private var user: User? {
        return (parent as? UploadSwitchViewController)?.user
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Collection view identifier
        paramsTableView.accessibilityIdentifier = "Parameters"
    }

    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = .piwigoColorBackground()

        // Table view
        paramsTableView.separatorColor = .piwigoColorSeparator()
        paramsTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        paramsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }


    // MARK: - UITableView - Header
    private func getContentOfHeader() -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("imageDetailsView_title", comment: "Properties"))
        let text = NSLocalizedString("imageUploadHeaderText_images", comment: "Please set the parameters to apply to the selection of photos/videos")
        return (title, text)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader()
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
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
        nberOfRows -= (!(user?.hasAdminRights ?? false) ? 1 : 0)

        return nberOfRows
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

        var height: CGFloat = 44.0
        switch EditImageDetailsOrder(rawValue: row) {
            case .privacy, .tags:
                height = 78.0
            case .comment:
                height = 428.0
                height += !(user?.hasAdminRights ?? false) ? 78.0 : 0.0
            default:
                break
        }
        return height
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

        var tableViewCell = UITableViewCell()
        switch EditImageDetailsOrder(rawValue: row) {
        case .imageName:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "title", for: indexPath) as? EditImageTextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
                return EditImageTextFieldTableViewCell()
            }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_title", comment: "Title:")),
                        placeHolder: NSLocalizedString("editImageDetails_titlePlaceholder", comment: "Title"),
                        andImageDetail: NSAttributedString(string: commonTitle))
            cell.cellTextField.textColor = shouldUpdateTitle ? .piwigoColorOrange() : .piwigoColorRightLabel()
            cell.cellTextField.tag = EditImageDetailsOrder.imageName.rawValue
            cell.cellTextField.delegate = self
            tableViewCell = cell

        case .author:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "author", for: indexPath) as? EditImageTextFieldTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextFieldTableViewCell!")
                return EditImageTextFieldTableViewCell()
            }
            cell.config(withLabel: NSAttributedString(string: NSLocalizedString("editImageDetails_author", comment: "Author:")),
                        placeHolder: NSLocalizedString("settings_defaultAuthorPlaceholder", comment: "Author Name"),
                        andImageDetail: NSAttributedString(string: commonAuthor))
            cell.cellTextField.textColor = shouldUpdateAuthor ? .piwigoColorOrange() : .piwigoColorRightLabel()
            cell.cellTextField.tag = EditImageDetailsOrder.author.rawValue
            cell.cellTextField.delegate = self
            tableViewCell = cell

        case .privacy:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "privacy", for: indexPath) as? EditImagePrivacyTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImagePrivacyTableViewCell!")
                return EditImagePrivacyTableViewCell()
            }
            cell.setLeftLabel(withText: NSLocalizedString("editImageDetails_privacyLevel", comment: "Who can see this photo?"))
            cell.setPrivacyLevel(with: commonPrivacyLevel,
                                 inColor: shouldUpdatePrivacyLevel ? .piwigoColorOrange() : .piwigoColorRightLabel())
            tableViewCell = cell

        case .tags:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "tags", for: indexPath) as? EditImageTagsTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTagsTableViewCell!")
                return EditImageTagsTableViewCell()
            }
            cell.config(withList: commonTags,
                        inColor: shouldUpdateTags ? .piwigoColorOrange() : .piwigoColorRightLabel())
            cell.accessibilityIdentifier = "setTags"
            tableViewCell = cell

        case .comment:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "comment", for: indexPath) as? EditImageTextViewTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a EditImageTextViewTableViewCell!")
                return EditImageTextViewTableViewCell()
            }
            cell.config(withText: NSAttributedString(string: commonComment),
                        inColor: shouldUpdateComment ? .piwigoColorOrange() : .piwigoColorRightLabel())
            cell.textView.delegate = self
            tableViewCell = cell

        default:
            break
        }

        tableViewCell.backgroundColor = .piwigoColorCellBackground()
        tableViewCell.tintColor = .piwigoColorOrange()
        return tableViewCell
    }


    // MARK: - UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

        switch EditImageDetailsOrder(rawValue: row) {
        case .author:
            // only update if not yet set, dont overwrite
            if commonAuthor.isEmpty,
               UploadVars.defaultAuthor.isEmpty == false {
                // must know the default author
                commonAuthor = UploadVars.defaultAuthor
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }

        case .privacy:
            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let privacySB = UIStoryboard(name: "SelectPrivacyViewController", bundle: nil)
                guard let privacyVC = privacySB.instantiateViewController(withIdentifier: "SelectPrivacyViewController") as? SelectPrivacyViewController else { return }
            privacyVC.delegate = self
            privacyVC.privacy = commonPrivacyLevel
            navigationController?.pushViewController(privacyVC, animated: true)

        case .tags:
            // Dismiss the keyboard
            view.endEditing(true)

            // Create view controller
            let tagsSB = UIStoryboard(name: "TagsViewController", bundle: nil)
            guard let tagsVC = tagsSB.instantiateViewController(withIdentifier: "TagsViewController") as? TagsViewController else { return }
            tagsVC.delegate = self
            tagsVC.user = user
            tagsVC.setPreselectedTagIds(Set(commonTags.map({$0.tagId})))
            navigationController?.pushViewController(tagsVC, animated: true)
            
        default:
            return
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Don't present privacy level choice to non-admin users
        var row = indexPath.row
        row += (!(user?.hasAdminRights ?? false) && (row > 1)) ? 1 : 0

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
            commonAuthor = finalString
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
            commonAuthor = ""
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
            if let typedText = textField.text {
                commonAuthor = typedText
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
        textView.textColor = .piwigoColorOrange()
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
    func didSelectPrivacyLevel(_ privacyLevel: pwgPrivacy) {
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
    func didSelectTags(_ selectedTags: Set<Tag>) {
        // Update image parameter
        commonTags = selectedTags

        // Remember to update image info
        shouldUpdateTags = true

        // Update cell
        let indexPath = IndexPath(row: EditImageDetailsOrder.tags.rawValue, section: 0)
        paramsTableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
