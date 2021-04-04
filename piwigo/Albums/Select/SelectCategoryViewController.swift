//
//  SelectCategoryViewController
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit

@objc
protocol SelectCategoryDelegate: NSObjectProtocol {
    func didSelectCategory(withId category: Int)
}

@objc
class SelectCategoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate {

    @objc weak var delegate: SelectCategoryDelegate?
    
    private var wantedAction = kPiwigoCategorySelectActionNone  // Action to perform after category selection
    private var currentCategoryId: Int = NSNotFound             // Category to be moved
    private var currentCategoryData: PiwigoAlbumData!
    private var currentImageData: PiwigoImageData!              // Image to be used to set a category thumbnail
    
    @objc func setInput(parameter:Any, for action:kPiwigoCategorySelectAction) {
        wantedAction = action
        switch action {
        case kPiwigoCategorySelectActionSetDefaultAlbum,
             kPiwigoCategorySelectActionSetAutoUploadAlbum:
            guard let categoryId = parameter as? Int else {
                fatalError("Input parameter expected to be an Int")
            }
            currentCategoryId = categoryId
            currentCategoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
            
        case kPiwigoCategorySelectActionMoveAlbum:
            guard let categoryData = parameter as? PiwigoAlbumData else {
                fatalError("Input parameter expected to be of PiwigoAlbumData type")
            }
            currentCategoryId = categoryData.albumId
            currentCategoryData = categoryData
            
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            guard let imageData = parameter as? PiwigoImageData else {
                fatalError("Input parameter expected to be of type PiwigoImageData")
            }
            currentImageData = imageData
            
        default:
            fatalError("Called setParameter before setting wanted action")
        }
    }

    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?

    private var recentCategories: [PiwigoAlbumData] = []        // Recent categories presented in 1st section
    private var categories: [PiwigoAlbumData] = []              // Categories presented in 2nd section
    private var categoriesThatShowSubCategories: [Int] = []
    private var hudViewController: UIViewController?

    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Build list of recent categories (1st section)
        buildRecentCategoryArray()
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "Cancel"

        // Register CategoryTableViewCell
        categoriesTableView.register(UINib(nibName: "CategoryTableViewCell", bundle: nil),
                                     forCellReuseIdentifier: "CategoryTableViewCell")
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        setTableViewMainHeader()
        categoriesTableView.separatorColor = UIColor.piwigoColorSeparator()
        categoriesTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        buildCategoryArray(usingCache: true, untilCompletion: { result in
            // Build complete list
            self.categoriesTableView.reloadData()
        }, orFailure: { task, error in
            // Invite users to refresh?
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set title and buttons
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // Set view title
            title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
        
        case kPiwigoCategorySelectActionMoveAlbum:
            // Set view title
            title = NSLocalizedString("moveCategory", comment:"Move Album")
        
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // Set view title
            title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Set view title
            title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
            
        default:
            title = ""
        }

        // Navigation "Cancel" button and identifier
        navigationItem.setRightBarButton(cancelBarButton, animated: true)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { context in

            // On iPad, the Settings section is presented in a centered popover view
            if UIDevice.current.userInterfaceIdiom == .pad {
                let mainScreenBounds = UIScreen.main.bounds
                self.popoverPresentationController?.sourceRect = CGRect(x: mainScreenBounds.midX,
                                                                        y: mainScreenBounds.midY,
                                                                        width: 0, height: 0)
                self.preferredContentSize = CGSize(width: kPiwigoPadSubViewWidth,
                                                   height: ceil(mainScreenBounds.height*2/3));
            }

            // Reload table view
            self.setTableViewMainHeader()
            self.categoriesTableView?.reloadData()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Re-enable tollbar items in image preview mode
        if wantedAction == kPiwigoCategorySelectActionSetAlbumThumbnail {
            self.delegate?.didSelectCategory(withId: NSNotFound)
        }

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }
    
    @objc
    func cancelSelect() -> Void {
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum,
             kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Return to Settings
            navigationController?.popViewController(animated: true)
        
        case kPiwigoCategorySelectActionMoveAlbum:
            // Return to Album/Images collection
            dismiss(animated: true)

        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // Re-enable toolbar items and return to albums/images collection
            self.delegate?.didSelectCategory(withId: NSNotFound)
            dismiss(animated: true)

        default:
            break
        }
    }

    
    // MARK: - UITableView - Header
    
    private func setTableViewMainHeader() {
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: NSLocalizedString("setDefaultCategory_select", comment: "Please select an album or sub-album which will become the new root album."))
            categoriesTableView.tableHeaderView = headerView

        case kPiwigoCategorySelectActionMoveAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: String.init(format: NSLocalizedString("moveCategory_select", comment:"Please select an album or sub-album to move album \"%@\" into."), currentCategoryData.name))
            categoriesTableView.tableHeaderView = headerView

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: NSLocalizedString("settings_autoUploadDestinationInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            categoriesTableView.tableHeaderView = headerView
        
        default:
            categoriesTableView.tableHeaderView = nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let titleString: String
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // 1st section —> Albums containing image
            let textString: String
            if section == 0 {
                // Title
                titleString = String(format: "%@\n", NSLocalizedString("tabBar_albums", comment:"Albums"))
                let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
                let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

                // Text
                if currentImageData.categoryIds.count > 1 {
                    textString = NSLocalizedString("categorySelection_one", comment:"Select one of the albums containing this image")
                } else {
                    textString = NSLocalizedString("categorySelection_current", comment:"Select the current album for this image")
                }
                let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
                let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
                return fmax(44.0, ceil(titleRect.size.height + textRect.size.height))
            }
            
            // Text
            textString = NSLocalizedString("categorySelection_other", comment:"or select another album for this image")
            let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
            let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
            return fmax(44.0, ceil(textRect.size.height))
        default:
            // 1st section —> Recent albums
            if section == 0 {
                // Do we have recent albums to show?
                if recentCategories.count > 0 {
                    // Present recent albums
                    titleString = NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums")
                } else {
                    // Present all albums
                    titleString = NSLocalizedString("tabBar_albums", comment: "Albums")
                }
            } else {
                // 2nd section
                titleString = NSLocalizedString("categorySelection_allAlbums", comment: "All Albums")
            }

            let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
            let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
            return CGFloat(ceil(titleRect.size.height))
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titleString: String
        let headerAttributedString = NSMutableAttributedString(string: "")

        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // 1st section —> Albums containing image
            var textString: String
            if section == 0 {
                // Title
                titleString = String(format: "%@\n", NSLocalizedString("tabBar_albums", comment:"Albums"))
                let titleAttributedString = NSMutableAttributedString(string: titleString)
                titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
                headerAttributedString.append(titleAttributedString)

                // Text
                if currentImageData.categoryIds.count > 1 {
                    textString = NSLocalizedString("categorySelection_one", comment:"Select one of the albums containing this image")
                } else {
                    textString = NSLocalizedString("categorySelection_current", comment:"Select the current album for this image")
                }
            } else {
                // Text
                textString = NSLocalizedString("categorySelection_other", comment:"or select another album for this image")
            }

            let textAttributedString = NSMutableAttributedString(string: textString)
            textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
            headerAttributedString.append(textAttributedString)

        default:
            // 1st section
            if section == 0 {
                // Do we have recent albums to show?
                if recentCategories.count > 0 {
                    // Present recent albums
                    titleString = NSLocalizedString("maxNberOfRecentAlbums>320px", comment: "Recent Albums")
                } else {
                    // Present all albums
                    titleString = NSLocalizedString("categorySelection_allAlbums", comment: "All Albums")
                }
            } else {
                // 2nd section
                titleString = NSLocalizedString("categorySelection_allAlbums", comment: "All Albums")
            }
            let titleAttributedString = NSMutableAttributedString(string: titleString)
            titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
            headerAttributedString.append(titleAttributedString)
        }

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

    
    // MARK: - UITableView - Rows
    
    func numberOfSections(in tableView: UITableView) -> Int {
        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            return 2
        default:    // Present recent albums if any
            return 1 + (recentCategories.count > 0 ? 1 : 0)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            if section == 0 {
                return currentImageData.categoryIds.count
            } else {
                return categories.count
            }
        default:    // Present recent albums if any
            if (recentCategories.count > 0) && (section == 0) {
                return recentCategories.count
            } else {
                return categories.count
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryTableViewCell", for: indexPath) as? CategoryTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a CategoryTableViewCell!")
            return CategoryTableViewCell()
        }

        var depth = 0
        let categoryData:PiwigoAlbumData
        if (indexPath.section == 0) && (wantedAction == kPiwigoCategorySelectActionSetAlbumThumbnail) {
            let categoryId = currentImageData.categoryIds[indexPath.row].intValue
            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
            cell.configure(with: categoryData, atDepth: 0, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
        }
        else if (recentCategories.count > 0) && (indexPath.section == 0) {
            categoryData = recentCategories[indexPath.row]
            cell.configure(with: categoryData, atDepth: 0, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
        }
        else {
            // Determine the depth before setting up the cell
            categoryData = categories[indexPath.row]
            if let upperCat = categoryData.upperCategories {
                depth += upperCat.filter({ $0 != String(categoryData.albumId )}).count
            }
            if let defaultCategoryData = CategoriesData.sharedInstance().getCategoryById(Model.sharedInstance().defaultCategory), let upperCat = defaultCategoryData.upperCategories {
                depth -= upperCat.filter({ $0 != String(Model.sharedInstance().defaultCategory )}).count
            }
        }
        
        // How should we present special categories?
        cell.delegate = self
        let buttonState = categoriesThatShowSubCategories.contains(categoryData.albumId) ? kPiwigoCategoryTableCellButtonStateHideSubAlbum : kPiwigoCategoryTableCellButtonStateShowSubAlbum
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // The current default category is not selectable
            if categoryData.albumId == currentCategoryId {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if (recentCategories.count > 0) && (indexPath.section == 0) {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                } else {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case kPiwigoCategorySelectActionMoveAlbum:
            // User cannot move album to current parent album or in itself
            if categoryData.albumId == 0 {  // upperCategories is nil for root
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                if currentCategoryData.parentAlbumId == 0 {
                    cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
                }
            } else if (categoryData.albumId == currentCategoryData.parentAlbumId) ||
                categoryData.upperCategories.contains(String(currentCategoryId)) {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if (recentCategories.count > 0) && (indexPath.section == 0) {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                } else {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // The root album is not available
            if indexPath.section == 0 {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
            } else {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
            }
            if categoryData.albumId == 0 {
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            }
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if (recentCategories.count > 0) && (indexPath.section == 0) {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                } else {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                }
            }
        default:
            break
        }

        cell.isAccessibilityElement = true
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Retrieve album data
        let categoryData:PiwigoAlbumData
        if (indexPath.section == 0) && (wantedAction == kPiwigoCategorySelectActionSetAlbumThumbnail) {
            let categoryId = currentImageData.categoryIds[indexPath.row].intValue
            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        }
        else if (self.recentCategories.count > 0) && (indexPath.section == 0) {
            categoryData = recentCategories[indexPath.row]
        } else {
            categoryData = categories[indexPath.row]
        }
        
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // The current default category is not selectable
            if categoryData.albumId == currentCategoryId { return false }
            
        case kPiwigoCategorySelectActionMoveAlbum:
            // Do nothing if this is the current default category
            if categoryData.albumId == currentCategoryId { return false }
            // User cannot move album to current parent album or in itself
            if categoryData.albumId == 0 {  // upperCategories is nil for root
                if currentCategoryData.parentAlbumId == 0 { return false }
            } else if (categoryData.albumId == currentCategoryData.parentAlbumId) ||
                        categoryData.upperCategories.contains(String(currentCategoryId)) { return false }
            
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 { return false }

        default:
            break
        }
        return true;
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let categoryData:PiwigoAlbumData
        if (indexPath.section == 0) && (wantedAction == kPiwigoCategorySelectActionSetAlbumThumbnail) {
            let categoryId = currentImageData.categoryIds[indexPath.row].intValue
            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        }
        else if (indexPath.section == 0) && (self.recentCategories.count > 0) {
            categoryData = recentCategories[indexPath.row]
        } else {
            categoryData = categories[indexPath.row]
        }

        // What should we do with this selection?
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // Do nothing if this is the current default category
            if categoryData.albumId == currentCategoryId { return }
            
            // Ask confirmation
            let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
            let message:String
            if categoryData.albumId == 0 {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), NSLocalizedString("categorySelection_root", comment: "Root Album"))
            } else {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), categoryData.name)
            }
            requestConfirmation(withTitle: title, message: message, handler: { _ in
                // Set new Default Album
                if categoryData.albumId != Model.sharedInstance().defaultCategory {
                    self.delegate?.didSelectCategory(withId: categoryData.albumId)
                }
                // Return to Settings
                self.navigationController?.popViewController(animated: true)
            }, forCategory: categoryData, at: indexPath)

        case kPiwigoCategorySelectActionMoveAlbum:
            // Do nothing if this is the current default category
            if categoryData.albumId == currentCategoryId { return }

            // User must not move album to current parent album or in itself
            if wantedAction == kPiwigoCategorySelectActionMoveAlbum {
                if categoryData.albumId == 0 {  // upperCategories is nil for root
                    if currentCategoryData.nearestUpperCategory == 0 { return }
                } else if (categoryData.albumId == currentCategoryData.parentAlbumId) ||
                    categoryData.upperCategories.contains(String(currentCategoryId)) { return }
            }

            // Ask user to confirm
            let title = NSLocalizedString("moveCategory", comment: "Move Album")
            let message = String(format: NSLocalizedString("moveCategory_message", comment: "Are you sure you want to move \"%@\" into the album \"%@\"?"), currentCategoryData.name, categoryData.name)
            requestConfirmation(withTitle: title, message: message, handler: { _ in
                // Add category to list of recent albums
                let userInfo = ["categoryId": String(categoryData.albumId)]
                let name = NSNotification.Name(rawValue: kPiwigoNotificationAddRecentAlbum)
                NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)

                // Move album to selected category
                self.moveCategory(intoCategory: categoryData)
            }, forCategory: categoryData, at: indexPath)

        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // Ask user to confirm
            let title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")
            let message = String(format: NSLocalizedString("categoryImageSet_message", comment:"Are you sure you want to set this image for the album \"%@\"?"), categoryData.name)
            requestConfirmation(withTitle: title, message: message, handler: { _ in
                // Add category to list of recent albums
                self.setRepresentative(for: categoryData)
            }, forCategory: categoryData, at: indexPath)

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            
            // Return the selected album ID
            delegate?.didSelectCategory(withId: categoryData.albumId)
            navigationController?.popViewController(animated: true)
        default:
            break
        }
    }
    
    private func requestConfirmation(withTitle title:String, message:String, handler:((UIAlertAction) -> Void)? = nil,
                                     forCategory categoryData: PiwigoAlbumData, at indexPath:IndexPath) -> Void {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: { action in })
        let performAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler:handler)
    
        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(performAction)

        // Present popover view
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = categoriesTableView
        alert.popoverPresentationController?.sourceRect = categoriesTableView.rectForRow(at: indexPath)
        alert.popoverPresentationController?.permittedArrowDirections = [.left, .right]
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        })
    }

    private func moveCategory(intoCategory parentCatData:PiwigoAlbumData) {
        // Display HUD during the update
        DispatchQueue.main.async {
            self.showHUDwithTitle(NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))
        }

        AlbumService.moveCategory(currentCategoryId,
                                  intoCategory: parentCatData.albumId) { task, movedSuccessfully in
            if movedSuccessfully {
                // Update cached old parent categories, except root album
                for oldParentStr in self.currentCategoryData.upperCategories {
                    guard let oldParentID = Int(oldParentStr) else { continue }
                    // Check that it is not the root album, nor the moved album
                    if (oldParentID == 0) || (oldParentID == self.currentCategoryData.albumId) { continue }

                    // Remove number of moved sub-categories and images
                    CategoriesData.sharedInstance()?.getCategoryById(oldParentID).numberOfSubCategories -= self.currentCategoryData.numberOfSubCategories + 1
                    CategoriesData.sharedInstance()?.getCategoryById(oldParentID).totalNumberOfImages -= self.currentCategoryData.totalNumberOfImages
                }
                
                // Update cached new parent categories, except root album
                var newUpperCategories = [String]()
                if parentCatData.albumId != 0 {
                    // Parent category in which we moved the category
                    newUpperCategories = CategoriesData.sharedInstance().getCategoryById(parentCatData.albumId).upperCategories ?? []
                    for newParentStr in newUpperCategories {
                        // Check that it is not the root album, nor the moved album
                        guard let newParentId = Int(newParentStr) else { continue }
                        if (newParentId == 0) || (newParentId == self.currentCategoryId) { continue }
                        
                        // Add number of moved sub-categories and images
                        CategoriesData.sharedInstance()?.getCategoryById(newParentId).numberOfSubCategories += self.currentCategoryData.numberOfSubCategories + 1;
                        CategoriesData.sharedInstance()?.getCategoryById(newParentId).totalNumberOfImages += self.currentCategoryData.totalNumberOfImages
                    }
                }

                // Update upperCategories of moved sub-categories
                var upperCatToRemove:[String] = self.currentCategoryData.upperCategories ?? []
                upperCatToRemove.removeAll(where: {$0 == String(self.currentCategoryId)})
                var catToUpdate = [PiwigoAlbumData]()
                
                if self.currentCategoryData.numberOfSubCategories > 0 {
                    let subCategories:[PiwigoAlbumData] = CategoriesData.sharedInstance().getCategoriesForParentCategory(self.currentCategoryId) ?? []
                    for subCategory in subCategories {
                        // Replace list of upper categories
                        var upperCategories = subCategory.upperCategories ?? []
                        upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                        upperCategories.append(contentsOf: newUpperCategories)
                        subCategory.upperCategories = upperCategories
                        catToUpdate.append(subCategory)
                    }
                }

                // Replace upper category of moved album
                var upperCategories = self.currentCategoryData.upperCategories ?? []
                upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                upperCategories.append(contentsOf: newUpperCategories)
                self.currentCategoryData.upperCategories = upperCategories
                self.currentCategoryData.nearestUpperCategory = parentCatData.albumId
                self.currentCategoryData.parentAlbumId = parentCatData.albumId
                catToUpdate.append(self.currentCategoryData)

                // Update cache
                CategoriesData.sharedInstance().updateCategories(catToUpdate)
                self.hideHUDwithSuccess(true, completion: {
                    let deadlineTime = DispatchTime.now() + .milliseconds(500)
                    DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                        self.hideHUD {
                            self.dismiss(animated: true)
                        }
                    }
                })
            } else {
                self.hideHUD {
                    self.showError()
                }
            }
        } onFailure: { [unowned self] task, error in
            self.hideHUD {
                guard let error = error as NSError? else {
                    self.showError()
                    return
                }
                self.showError(with: error.localizedDescription)
            }
        }
    }

    private func setRepresentative(for categoryData:PiwigoAlbumData) {
        // Display HUD during the update
        DispatchQueue.main.async {
            self.showHUDwithTitle(NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        }
        
        // Set image as representative
        AlbumService.setCategoryRepresentativeForCategory(categoryData.albumId,
                        forImageId: currentImageData.imageId) { task, didSucceed in
            if didSucceed {
                // Update image Id of album
                categoryData.albumThumbnailId = self.currentImageData.imageId

                // Update image URL of album
                categoryData.albumThumbnailUrl = self.currentImageData.thumbPath;

                // Image will be downloaded when displaying list of albums
                categoryData.categoryImage = nil
                
                // Close HUD
                self.hideHUDwithSuccess(true) {
                    let deadlineTime = DispatchTime.now() + .milliseconds(500)
                    DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                        self.hideHUD {
                            // Inform Album/Images view controller & dismiss view
                            self.delegate?.didSelectCategory(withId: categoryData.albumId)
                            self.dismiss(animated: true)
                        }
                    }
                }
            } else {
                // Close HUD and inform user
                self.hideHUD {
                    self.showError()
                }
            }
        } onFailure: { task, error in
            // Close HUD and inform user
            self.hideHUD {
                guard let error = error as NSError? else {
                    self.showError()
                    return
                }
                self.showError(with: error.localizedDescription)
            }
        }
    }
    
    private func showError(with message:String = "") {
        // Title and message
        let title:String
        var mainMessage:String
        switch wantedAction {
        case kPiwigoCategorySelectActionMoveAlbum:
            title = NSLocalizedString("moveCategoryError_title", comment:"Move Fail")
            mainMessage = NSLocalizedString("moveCategoryError_message", comment:"Failed to move your album")
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            title = NSLocalizedString("categoryImageSetError_title", comment:"Image Set Error")
            mainMessage = NSLocalizedString("categoryImageSetError_message", comment:"Failed to set the album image")
        default:
            return
        }
        if message.count > 0 {
            mainMessage.append("\n\(message)")
        }
        
        // Present alert
        let alert = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
        let dismissAction = UIAlertAction.init(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                               style: .cancel) { _ in }
        alert.addAction(dismissAction)
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
        navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: - HUD methods
    
    func showHUDwithTitle(_ title: String?) {
        // Determine the present view controller if needed (not necessarily self.view)
        if hudViewController == nil {
            hudViewController = UIApplication.shared.keyWindow?.rootViewController
            while hudViewController?.presentedViewController != nil {
                hudViewController = hudViewController?.presentedViewController
            }
        }

        // Create the login HUD if needed
        var hud = hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
        if hud == nil {
            // Create the HUD
            hud = MBProgressHUD.showAdded(to: (hudViewController?.view)!, animated: true)
            hud?.tag = loadingViewTag

            // Change the background view shape, style and color.
            hud?.isSquare = false
            hud?.animationType = MBProgressHUDAnimation.fade
            hud?.backgroundView.style = MBProgressHUDBackgroundStyle.solidColor
            hud?.backgroundView.color = UIColor(white: 0.0, alpha: 0.5)
            hud?.contentColor = UIColor.piwigoColorText()
            hud?.bezelView.color = UIColor.piwigoColorText()
            hud?.bezelView.style = MBProgressHUDBackgroundStyle.solidColor
            hud?.bezelView.backgroundColor = UIColor.piwigoColorCellBackground()

            // Will look best, if we set a minimum size.
            hud?.minSize = CGSize(width: 200.0, height: 100.0)
        }

        // Set title
        hud?.label.text = title
        hud?.label.font = UIFont.piwigoFontNormal()
    }

    func hideHUDwithSuccess(_ success: Bool, completion: @escaping () -> Void) {
        DispatchQueue.main.async(execute: {
            // Hide and remove the HUD
            let hud = self.hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
            if hud != nil {
                if success {
                    let image = UIImage(named: "completed")?.withRenderingMode(.alwaysTemplate)
                    let imageView = UIImageView(image: image)
                    hud?.customView = imageView
                    hud?.mode = MBProgressHUDMode.customView
                    hud?.label.text = NSLocalizedString("completeHUD_label", comment: "Complete")
                }
            }
            completion()
        })
    }

    func hideHUD(completion: @escaping () -> Void) {
        // Hide and remove the HUD
        let hud = hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
        if hud != nil {
            hud?.hide(animated: true)
            hudViewController = nil
        }
        completion()
    }

    
    // MARK: - Category List Builder
    
    private func buildCategoryArray(usingCache useCache: Bool,
                                    untilCompletion completion: @escaping (_ result: Bool) -> Void,
                                    orFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        // Show loading HUD when not using cache option,
        if !(useCache && Model.sharedInstance().loadAllCategoryInfo && (Model.sharedInstance().defaultCategory == 0)) {
            // Show loading HD
            showHUDwithTitle(NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            // Reload category data and set current category
            //        NSLog(@"buildCategoryDf => getAlbumListForCategory(%ld,NO,YES)", (long)0);
            AlbumService.getAlbumList(forCategory: 0, usingCache: false, inRecursiveMode: Model.sharedInstance().loadAllCategoryInfo,
                    onCompletion: { task, albums in
                        // Hide loading HUD
                        self.hideHUD {
                            // Build category array
                            self.buildCategoryArray()
                            completion(true)
                        }
                    },
                    onFailure: { task, error in
                        // Hide loading HUD
                        self.hideHUD {
                            print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
                            fail(task, error!)
                        }
                    })
        } else {
            // Build category array from cache
            buildCategoryArray()
            completion(true)
        }
    }

    private func buildCategoryArray() {
        categories = []

        // Build list of categories from complete known lists
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        let comCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().communityCategoriesForUploadOnly

        // Proposed list is collected in diff
        var diff: [PiwigoAlbumData] = []

        // Look for categories which are not already displayed
        /// - Smart albums should not be proposed
        /// - Non-admin Community users can only upload in specific albums
        let filteredCat = allCategories.filter({ $0.albumId > kPiwigoSearchCategoryId })
            .filter({ Model.sharedInstance().hasAdminRights || $0.hasUploadRights })
        for category in filteredCat {   // Don't use forEach to keep the order
            // Is this category already in displayed list?
            if !categories.contains(where: { $0.albumId == category.albumId }) {
                diff.append(category)
            }
        }

        // Build list of categories to be displayed
        for category in diff {   // Don't use forEach to keep the order
            if category.parentAlbumId == 0 {
                categories.append(category)
            }
        }

        // Add Community private categories
        for category in comCategories {
            // Is this category already in displayed list?
            if !categories.contains(where: { $0.albumId == category.albumId }) {
                categories.append(category)
            }
        }

        // Add root album if needed
        if [kPiwigoCategorySelectActionSetDefaultAlbum,
            kPiwigoCategorySelectActionMoveAlbum].contains(wantedAction) {
            let rootAlbum = PiwigoAlbumData()
            rootAlbum.albumId = 0
            rootAlbum.name = NSLocalizedString("categorySelection_root", comment: "Root Album")
            categories.insert(rootAlbum, at: 0)
        }
    }
    
    private func buildRecentCategoryArray() -> Void {
        // Current recent categories
        guard let recentCatIds = Model.sharedInstance()?.recentCategories.components(separatedBy: ","),
              !recentCatIds.isEmpty else { return }

        // Build list of recent categories
        for catIdStr in recentCatIds {
            // Get category ID
            guard let catId = Int(catIdStr) else { continue }
            
            // Exclude current category
            if catId == currentCategoryId { continue }
            
            // Get category data
            guard let categoryData = CategoriesData.sharedInstance()?.getCategoryById(catId) else { continue }
            
            // User cannot move album to current parent album or in itself
            if wantedAction == kPiwigoCategorySelectActionMoveAlbum,
               (categoryData.albumId == currentCategoryData.parentAlbumId) ||
                categoryData.upperCategories.contains(String(currentCategoryId)) { continue }
            
            // Add category existing in cache
            recentCategories.append(categoryData)

            // Reach max number of recent categories?
            if recentCategories.count == Model.sharedInstance().maxNberRecentCategories { break }
        }
    }

    
    // MARK: - CategoryCellDelegate Methods
    
    func tappedDisclosure(of categoryTapped: PiwigoAlbumData) {
        
        // Build list of categories from list of known categories
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        var subcategories: [PiwigoAlbumData] = []

        // Look for known requested sub-categories
        subcategories.append(contentsOf: allCategories.filter({ $0.parentAlbumId == categoryTapped.albumId })
                                                      .filter({ $0.albumId != currentCategoryId }))

        // Look for sub-categories which are already displayed
        var nberDisplayedSubCategories = 0
        subcategories.forEach { category in
            nberDisplayedSubCategories += categories.filter({ $0.albumId == category.albumId}).count
        }

        // This test depends on the caching option loadAllCategoryInfo:
        // => if YES: compare number of sub-albums inside category to be closed
        // => if NO: compare number of sub-sub-albums inside category to be closed
        if (subcategories.count > 0) && (subcategories.count == nberDisplayedSubCategories) {
            // User wants to hide sub-categories
            removeSubCategories(toCategoryID: categoryTapped)
        } else if subcategories.count > 0 {
            // Sub-categories are already known
            addSubCaterories(toCategoryID: categoryTapped)
        } else {
            // Sub-categories are not known
            //        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

            // Show loading HD
            showHUDwithTitle(NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            AlbumService.getAlbumList(forCategory: categoryTapped.albumId,
                                      usingCache: Model.sharedInstance().loadAllCategoryInfo,
                                      inRecursiveMode: false,
                                      onCompletion: { task, albums in
                                        // Hide loading HUD
                                        self.hideHUD {
                                            // Add sub-categories
                                            self.addSubCaterories(toCategoryID: categoryTapped)
                                        }
                                    },
                                      onFailure: { task, error in
                                        // Hide loading HUD
                                        self.hideHUD {
                                            print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
                                        }
                                    })
        }
    }

    func addSubCaterories(toCategoryID categoryTapped: PiwigoAlbumData) {
        // Build list of categories from complete known list
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories

        // Proposed list is collected in diff
        var diff: [PiwigoAlbumData] = []

        // Look for categories which are not already displayed
        /// - Non-admin Community users can only upload in specific albums
        /// - Only add sub-categories of tapped category
        /// - Do not add the current category
        let filteredCat = allCategories.filter({ Model.sharedInstance().hasAdminRights || $0.hasUploadRights })
            .filter({ $0.nearestUpperCategory == categoryTapped.albumId })
        for category in filteredCat {   // Don't use forEach to keep the order
            // Is this category already in displayed list?
            if !categories.contains(where: { $0.albumId == category.albumId }) {
                diff.append(category)
            }
        }

        // Build list of categories to be displayed
        for category in diff {
            // Should we add sub-categories?
            if category.upperCategories.count > 0 {
                var indexOfParent = 0
                for existingCategory in categories {
                    if category.containsUpperCategory(existingCategory.albumId) {
                        categories.insert(category, at: indexOfParent + 1)
                        break
                    }
                    indexOfParent += 1
                }
            }
        }

        // Add tapped category to list of categories having shown sub-categories
        categoriesThatShowSubCategories.append(categoryTapped.albumId)

        // Reload table view
        categoriesTableView.reloadData()
    }

    func removeSubCategories(toCategoryID categoryTapped: PiwigoAlbumData) {
        // Proposed list is collected in diff
        var diff: [PiwigoAlbumData] = []

        // Look for sub-categories to remove
        categories.filter({ $0.albumId != categoryTapped.albumId}).forEach { category in
            // Remove the sub-categories
            let upperCategories = category.upperCategories
            if upperCategories?.contains(String(format: "%ld", Int(categoryTapped.albumId))) ?? false {
                diff.append(category)
            }
        }

        // Remove objects from displayed list
        categories = categories.filter({ !diff.contains($0) })

        // Remove tapped category from list of categories having shown sub-categories
        if categoriesThatShowSubCategories.contains(categoryTapped.albumId) {
            categoriesThatShowSubCategories.removeAll { $0 as AnyObject === NSNumber(value: categoryTapped.albumId) as AnyObject }
        }

        // Sub-categories will not be known if user closes several layers at once
        // and caching option loadAllCategoryInfo is not activated
        if !Model.sharedInstance().loadAllCategoryInfo {
            //        NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

            // Show loading HD
            showHUDwithTitle(NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            AlbumService.getAlbumList(forCategory: categoryTapped.albumId,
                                      usingCache: false,
                                      inRecursiveMode: Model.sharedInstance().loadAllCategoryInfo,
                                      onCompletion: { task, albums in
                // Hide loading HUD
                self.hideHUD {
                    // Reload table view
                    self.categoriesTableView.reloadData()
                }
            }, onFailure: { task, error in
                // Hide loading HUD
                self.hideHUD {
                    print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
                }
            })
        } else {
            // Reload table view
            categoriesTableView.reloadData()
        }
    }
}
