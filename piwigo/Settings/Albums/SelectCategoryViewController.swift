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

    // Category to be moved
    private var _currentCategory: Int?
    private var _selectedCategory: PiwigoAlbumData?
    @objc var currentCategory: Int {
        get {
            return _currentCategory ?? NSNotFound
        }
        set(currentCategory) {
            _currentCategory = currentCategory
            _selectedCategory = CategoriesData.sharedInstance().getCategoryById(currentCategory)
        }
    }
    
    // Actions to perform after selection
    private var _wantedAction = kPiwigoCategorySelectActionNone
    @objc var wantedAction: kPiwigoCategorySelectAction {
        get {
            return _wantedAction
        }
        set(action) {
            _wantedAction = action
        }
    }

    @IBOutlet var categoriesTableView: UITableView!

    private var categories: [PiwigoAlbumData] = []
    private var categoriesThatShowSubCategories: [Int] = []
    private var hudViewController: UIViewController?

    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_albums", comment: "Albums")
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

        //
        switch _wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // Set view title
            title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
        
        case kPiwigoCategorySelectActionMoveAlbum:
            // Set view title
            title = NSLocalizedString("moveCategory", comment:"Move Album")
        
            // Navigation "Cancel" button and identifier
            navigationItem.setLeftBarButton(cancelBarButton, animated: true)
            navigationController?.navigationBar.accessibilityIdentifier = "LocalAlbumsNav"
        
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Set view title
            title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
        default:
            title = ""
        }

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

    
    // MARK: - UITableView - Header
    
    private func setTableViewMainHeader() {
        switch _wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: NSLocalizedString("setDefaultCategory_select", comment: "Please select an album or sub-album which will become the new root album."))
            categoriesTableView.tableHeaderView = headerView
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: NSLocalizedString("settings_autoUploadDestinationInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            categoriesTableView.tableHeaderView = headerView
        case kPiwigoCategorySelectActionMoveAlbum:
            let headerView = SelectCategoryHeaderView(frame: .zero)
            headerView.configure(width: categoriesTableView.frame.size.width,
                                 text: String.init(format: NSLocalizedString("moveCategory_select", comment:"Please select an album or sub-album to move album \"%@\" into."), _selectedCategory?.name ?? ""))
            categoriesTableView.tableHeaderView = headerView
        default:
            categoriesTableView.tableHeaderView = nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let titleString: String
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0

        // 1st section
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

        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titleString: String
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

        // Title
        let headerAttributedString = NSMutableAttributedString(string: titleString)
        headerAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))

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
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryTableViewCell", for: indexPath) as? CategoryTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a CategoryTableViewCell!")
            return CategoryTableViewCell()
        }

        // Determine the depth before setting up the cell
        let categoryData = categories[indexPath.row]
        var depth = categoryData.getDepthOfCategory()
        let defaultCategoryData = categories[0]
        depth -= defaultCategoryData.getDepthOfCategory()
        cell.setup(withCategoryData: categoryData, atDepth: depth, withSubCategoryButton: true)

        // How should we present special categories?
        switch _wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // The current default category is not selectable
            if categoryData.albumId == _currentCategory {
                cell.isUserInteractionEnabled = false
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            }
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 {
                cell.isUserInteractionEnabled = false
                cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
            }
        default:
            break
        }

        // Switch between Open/Close cell disclosure
        cell.categoryDelegate = self
        if categoriesThatShowSubCategories.contains(categoryData.albumId) {
            if #available(iOS 13.0, *) {
                cell.upDownImage.image = UIImage(systemName: "multiply")
            } else {
                // Fallback on earlier versions
                cell.upDownImage.image = UIImage(named: "cellClose")
            }
        } else {
            if #available(iOS 13.0, *) {
                cell.upDownImage.image = UIImage(systemName: "plus")
            } else {
                // Fallback on earlier versions
                cell.upDownImage.image = UIImage(named: "cellOpen")
            }
        }

        cell.isAccessibilityElement = true
        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let categoryData = categories[indexPath.row]

        // What should we do with this selection?
        switch _wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // Request confirmation
            didSelectDefaultAlbum(withData: categoryData, at: indexPath)
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Return the selected album ID
            delegate?.didSelectCategory(withId: categoryData.albumId)
            navigationController?.popViewController(animated: true)
        default:
            break
        }
    }

    private func didSelectDefaultAlbum(withData categoryData:PiwigoAlbumData,
                                       at indexPath: IndexPath) -> Void {
        // Do nothing if this is the current default category
        if categoryData.albumId == _currentCategory { return }
        
        // Ask the user to confirm
        var message = ""
        if categoryData.albumId == 0 {
            message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), NSLocalizedString("categorySelection_root", comment: "Root Album"))
        } else {
            message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), categoryData.name)
        }

        let alert = UIAlertController(title: NSLocalizedString("setDefaultCategory_title", comment: "Default Album"),
                                      message: message,
                                      preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: { action in })
        let setCategoryAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler: { action in
            // Set new Default Album
            if categoryData.albumId != Model.sharedInstance().defaultCategory {
                self.delegate?.didSelectCategory(withId: categoryData.albumId)
            }
            // Return to Settings
            self.navigationController?.popViewController(animated: true)
        })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(setCategoryAction)

        // Determine position of cell in table view
        var rectOfCellInTableView = categoriesTableView.rectForRow(at: indexPath)

        // Determine width of text
        let cell = categoriesTableView.cellForRow(at: indexPath) as? CategoryTableViewCell
        let textString = cell?.categoryLabel.text
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let textRect = textString?.boundingRect(with: CGSize(width: categoriesTableView.frame.size.width - 30.0,
                                                             height: CGFloat.greatestFiniteMagnitude),
                                                options: .usesLineFragmentOrigin,
                                                attributes: textAttributes, context: context)

        // Calculate horizontal position of popover view
        rectOfCellInTableView.origin.x -= categoriesTableView.frame.size.width
            - (textRect?.size.width ?? 0.0) - categoriesTableView.layoutMargins.left - 12

        // Present popover view
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = categoriesTableView
        alert.popoverPresentationController?.permittedArrowDirections = .left
        alert.popoverPresentationController?.sourceRect = rectOfCellInTableView
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        })
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
                    hud?.hide(animated: true, afterDelay: 2.0)
                } else {
                    hud?.hide(animated: true)
                }
            }
            completion()
        })
    }

    func hideHUD() {
        // Hide and remove the HUD
        let hud = hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
        if hud != nil {
            hud?.hide(animated: true)
            hudViewController = nil
        }
    }

    
    // MARK: - Category List Builder
    
    func buildCategoryArray(usingCache useCache: Bool, untilCompletion completion: @escaping (_ result: Bool) -> Void, orFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        // Show loading HUD when not using cache option,
        if !(useCache && Model.sharedInstance().loadAllCategoryInfo && (Model.sharedInstance().defaultCategory == 0)) {
            // Show loading HD
            showHUDwithTitle(NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            // Reload category data and set current category
            //        NSLog(@"buildCategoryDf => getAlbumListForCategory(%ld,NO,YES)", (long)0);
            AlbumService.getAlbumList(forCategory: 0, usingCache: false, inRecursiveMode: Model.sharedInstance().loadAllCategoryInfo,
                    onCompletion: { task, albums in
                        // Build category array
                        self.buildCategoryArray()

                        // Hide loading HUD
                        self.hideHUD()
                        completion(true)
                    },
                    onFailure: { task, error in
#if DEBUG
                        print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
#endif
                        // Hide loading HUD
                        self.hideHUD()
                        fail(task, error!)
                    })
        } else {
            // Build category array from cache
            buildCategoryArray()
            completion(true)
        }
    }

    func buildCategoryArray() {
        
        categories = []

        // Build list of categories from complete known lists
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        let comCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().communityCategoriesForUploadOnly

        // Proposed list is collected in diff
        var diff: [PiwigoAlbumData] = []

        // Look for categories which are not already displayed
        /// - Smart albums should not be proposed
        /// - Non-admin Community users can only upload in specific albums
        allCategories.filter({ $0.albumId > kPiwigoSearchCategoryId })
            .filter({ Model.sharedInstance().hasAdminRights || $0.hasUploadRights })
            .forEach { category in
            // Is this category already in displayed list?
            if !categories.contains(where: { $0.albumId == category.albumId }) {
                diff.append(category)
            }
        }

        // Build list of categories to be displayed
        diff.forEach { category in
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
        if _wantedAction == kPiwigoCategorySelectActionSetDefaultAlbum {
            let rootAlbum = PiwigoAlbumData()
            rootAlbum.albumId = 0
            rootAlbum.name = NSLocalizedString("categorySelection_root", comment: "Root Album")
            categories.insert(rootAlbum, at: 0)
        }
    }

    
    // MARK: - CategoryCellDelegate Methods
    
    func tappedDisclosure(_ categoryTapped: PiwigoAlbumData) {
        
        // Build list of categories from list of known categories
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        var subcategories: [PiwigoAlbumData] = []

        // Look for known requested sub-categories
        subcategories.append(contentsOf: allCategories.filter({ $0.parentAlbumId == categoryTapped.albumId })
                                                      .filter({ $0.albumId != _currentCategory }))

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
                                        // Add sub-categories
                                        self.addSubCaterories(toCategoryID: categoryTapped)

                                        // Hide loading HUD
                                        self.hideHUD()
                                    },
                                      onFailure: { task, error in
#if DEBUG
                print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
#endif
                                        // Hide loading HUD
                                        self.hideHUD()
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
            .filter({ $0.albumId != _currentCategory})
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
                // Reload table view
                self.categoriesTableView.reloadData()

                // Hide loading HUD
                self.hideHUD()
            }, onFailure: { task, error in
            #if DEBUG
                print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
            #endif
                // Hide loading HUD
                self.hideHUD()
            })
        } else {
            // Reload table view
            categoriesTableView.reloadData()
        }
    }
}
