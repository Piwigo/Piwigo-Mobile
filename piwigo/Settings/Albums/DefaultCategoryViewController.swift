//
//  DefaultCategoryViewController
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 05/07/2018.
//  Copyright © 2018 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit

@objc
protocol DefaultCategoryDelegate: NSObjectProtocol {
    func didChangeDefaultCategory(_ category: Int)
}

@objc
class DefaultCategoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CategoryCellDelegate {

    @objc weak var delegate: DefaultCategoryDelegate?

    @objc func setCurrentCategory(_ currentCategory: Int) {
        _currentCategory = currentCategory
    }

    @IBOutlet var categoriesTableView: UITableView!

    private var _currentCategory: Int?
    private var currentCategory: Int {
        get {
            return _currentCategory ?? Model.sharedInstance().defaultCategory
        }
        set(currentCategory) {
            _currentCategory = currentCategory
        }
    }

    private var categories: [PiwigoAlbumData] = []
    private var categoriesThatShowSubCategories: [Int] = []
    private var hudViewController: UIViewController?

    
// MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_albums", comment: "Albums")
        categoriesTableView.register(UINib(nibName: "CategoryTableViewCell", bundle: nil), forCellReuseIdentifier: "CategoryTableViewCell")
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
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString = "\(NSLocalizedString("setDefaultCategory_title", comment: "Default Album"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("categoryUpload_defaultSelect", comment: "Please select the album or sub-album which will become your default album")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("setDefaultCategory_title", comment: "Default Album"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("categoryUpload_defaultSelect", comment: "Please select the album or sub-album which will become your default album")
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
        header.addConstraint(NSLayoutConstraint(item: headerLabel, attribute: .bottom, relatedBy: .equal, toItem: headerLabel.superview, attribute: .bottom, multiplier: 1.0, constant: -4))
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
            return ShareMetadataCell()
        }

        // Determine the depth before setting up the cell
        let categoryData = categories[indexPath.row]
        var depth = categoryData.getDepthOfCategory()
        let defaultCategoryData = categories[0]
        depth -= defaultCategoryData.getDepthOfCategory()
        cell.setup(withCategoryData: categoryData, atDepth: depth, withSubCategoryButton: true)

        // Cell accessory
        if categoryData.albumId == currentCategory {
            cell.isUserInteractionEnabled = false
            cell.categoryLabel.textColor = UIColor.piwigoColorRightLabel()
        }

        // Switch between Open/Close cell disclosure
        cell.categoryDelegate = self
        if categoriesThatShowSubCategories.contains(categoryData.albumId) {
            cell.upDownImage.image = UIImage(named: "cellClose")
        } else {
            cell.upDownImage.image = UIImage(named: "cellOpen")
        }

        cell.isAccessibilityElement = true
        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        var categoryData: PiwigoAlbumData
        categoryData = categories[indexPath.row]

        if categoryData.albumId == currentCategory {
            return
        }

        var message = ""
        if categoryData.albumId == 0 {
            message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), NSLocalizedString("categorySelection_root", comment: "Root Album"))
        } else {
            message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), categoryData.name)
        }
        
        let alert = UIAlertController(title: NSLocalizedString("setDefaultCategory_title", comment: "Default Album"), message: message,
                                      preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel,
                                         handler: { action in
            })

        let setCategoryAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler: { action in
                
            // Set new Default Album
            if (self.delegate?.responds(to: #selector(DefaultCategoryDelegate.didChangeDefaultCategory(_:))) ?? false) &&
                (categoryData.albumId != Model.sharedInstance().defaultCategory) {
                self.delegate?.didChangeDefaultCategory(categoryData.albumId)
            }

            // Return to Settings
            self.navigationController?.popViewController(animated: true)
        })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(setCategoryAction)

        // Determine position of cell in table view
        var rectOfCellInTableView = tableView.rectForRow(at: indexPath)

        // Determine width of text
        let cell = tableView.cellForRow(at: indexPath) as? CategoryTableViewCell
        let textString = cell?.categoryLabel.text
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let textRect = textString?.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)

        // Calculate horizontal position of popover view
        rectOfCellInTableView.origin.x -= tableView.frame.size.width - (textRect?.size.width ?? 0.0) - tableView.layoutMargins.left - 12

        // Present popover view
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.permittedArrowDirections = .left
        alert.popoverPresentationController?.sourceRect = rectOfCellInTableView
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        })
    }

    func changedDefaultCategory() {
        // Does the default album view controller already exists?
        var cur = 0
        var index = 0
        var rootAlbumViewController: AlbumImagesViewController? = nil
        for viewController in navigationController?.viewControllers ?? [] {

            // Look for AlbumImagesViewControllers
            if (viewController is AlbumImagesViewController) {
                let thisViewController = viewController as? AlbumImagesViewController

                // Is this the view controller of the default album?
                if thisViewController?.categoryId == Model.sharedInstance().defaultCategory {
                    // The view controller of the parent category already exist
                    rootAlbumViewController = thisViewController
                }

                // Is this the current view controller?
                if thisViewController?.categoryId == currentCategory {
                    // This current view controller will become the child view controller
                    index = cur
                }
            }
            cur += 1
        }

        // The view controller of the default album does not exist yet
        if rootAlbumViewController == nil {
            // Create an instance of the default album view controller
            rootAlbumViewController = AlbumImagesViewController(albumId: Model.sharedInstance().defaultCategory, inCache: false)
            // The existing album view controller must become a child of the default album view controller
            var arrayOfVC: [UIViewController]? = nil
            if let viewControllers = navigationController?.viewControllers {
                arrayOfVC = viewControllers
            }
            if let rootAlbumViewController = rootAlbumViewController {
                arrayOfVC?.insert(rootAlbumViewController, at: index)
            }
            if let arrayOfVC = arrayOfVC {
                navigationController?.viewControllers = arrayOfVC
            }
        }

        // Dismiss Settings and present default album
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationController?.dismiss(animated: true) {
                // Replace current album view with default album view
                let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationBackToDefaultAlbum)
                NotificationCenter.default.post(name: name, object: nil)
            }
        } else {
            if let rootAlbumViewController = rootAlbumViewController {
                navigationController?.popToViewController(rootAlbumViewController, animated: true)
            }
        }
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
            hud?.contentColor = UIColor.piwigoColorHudContent()
            hud?.bezelView.color = UIColor.piwigoColorHudBezelView()

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
                        print(String(format: "getAlbumListForCategory error %ld: %@", Int(error?.code ?? 0), error?.localizedDescription ?? ""))
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
        for category in allCategories {

            // Smart albums should not be proposed
            if category.albumId <= kPiwigoSearchCategoryId {
                continue
            }

            // Non-admin Community users can only upload in specific albums
            if !Model.sharedInstance().hasAdminRights && !category.hasUploadRights {
                continue
            }

            // Is this category already in displayed list?
            var doesNotExist = true
            for existingCat in categories {

                if category.albumId == existingCat.albumId {
                    doesNotExist = false
                    break
                }
            }
            if doesNotExist {
                diff.append(category)
            }
        }

        // Build list of categories to be displayed
        for category in diff {

            // Always add categories in default album
            if category.parentAlbumId == 0 {
                categories.append(category)
                continue
            }
        }

        // Add Community private categories
        for category in comCategories {

            // Is this category already in displayed list?
            var doesNotExist = true
            for existingCat in categories {

                if category.albumId == existingCat.albumId {
                    doesNotExist = false
                    break
                }
            }

            if doesNotExist {
                categories.append(category)
            }
        }

        // Add root album
        let rootAlbum = PiwigoAlbumData()
        rootAlbum.albumId = 0
        rootAlbum.name = NSLocalizedString("categorySelection_root", comment: "Root Album")
        categories.insert(rootAlbum, at: 0)
    }

    
// MARK: - CategoryCellDelegate Methods
    
    func tappedDisclosure(_ categoryTapped: PiwigoAlbumData) {
        
        // Build list of categories from list of known categories
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        var subcategories: [PiwigoAlbumData] = []

        // Look for known requested sub-categories
        for category in allCategories {

            // Only add sub-categories of tapped category
            if ((category.parentAlbumId != categoryTapped.albumId) ||
                (category.albumId == currentCategory)) {
                continue
            }
            subcategories.append(category)
        }

        // Look for sub-categories which are already displayed
        var nberDisplayedSubCategories = 0
        for category in subcategories {

            for existingCat in categories {

                if category.albumId == existingCat.albumId {
                    nberDisplayedSubCategories += 1
                    break
                }
            }
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
                print(String(format: "getAlbumListForCategory error %ld: %@", Int(error?.code ?? 0), error?.localizedDescription ?? ""))
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
        for category in allCategories {

            // Non-admin Community users can only upload in specific albums
            if !Model.sharedInstance().hasAdminRights && !category.hasUploadRights {
                continue
            }

            // Only add sub-categories of tapped category
            if ((category.nearestUpperCategory != categoryTapped.albumId) ||
                (category.albumId == currentCategory)) {
                continue
            }

            // Is this category already in displayed list?
            var doesNotExist = true
            for existingCat in categories {

                if category.albumId == existingCat.albumId {
                    doesNotExist = false
                    break
                }
            }
            if doesNotExist {
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
        for category in categories {

            // Keep the parent category
            if category.albumId == categoryTapped.albumId {
                continue
            }

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
                print(String(format: "getAlbumListForCategory error %ld: %@", Int(error?.code ?? 0), error?.localizedDescription ?? ""))
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
