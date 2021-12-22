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
import piwigoKit
import CoreMedia

//enum kPiwigoCategorySelectAction {
//    case none
//    case setDefaultAlbum, moveAlbum, setAlbumThumbnail, setAutoUploadAlbum
//    case copyImage, moveImage, copyImages, moveImages
//}

@objc
protocol SelectCategoryDelegate: NSObjectProtocol {
    func didSelectCategory(withId category: Int)
}

@objc
protocol SelectCategoryImageCopiedDelegate: NSObjectProtocol {
    func didCopyImage(withData imageData: PiwigoImageData)
}

@objc
protocol SelectCategoryImageRemovedDelegate {
    func didRemoveImage(withId imageId: Int)
}

@objc
class SelectCategoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @objc weak var delegate: SelectCategoryDelegate?
    @objc weak var imageCopiedDelegate: SelectCategoryImageCopiedDelegate?
    @objc weak var imageRemovedDelegate: SelectCategoryImageRemovedDelegate?

    private var wantedAction = kPiwigoCategorySelectActionNone  // Action to perform after category selection
    private var inputCategoryId: Int = NSNotFound
    private var inputCategoryData: PiwigoAlbumData!
    private var inputImageData: PiwigoImageData!
    private var inputImageIds: [Int]!
    private var inputImagesData = [PiwigoImageData]()
    private var totalNumberOfImages: Float = 0.0
    private var selectedCategoryId = NSNotFound

    @objc func setInput(parameter:Any, for action:kPiwigoCategorySelectAction) {
        wantedAction = action
        switch action {
        case kPiwigoCategorySelectActionSetDefaultAlbum,
             kPiwigoCategorySelectActionSetAutoUploadAlbum:
            guard let categoryId = parameter as? Int else {
                fatalError("Input parameter expected to be an Int")
            }
            // Actual default album or actual album in which photos are auto-uploaded
            // to be replaced by the selected one
            inputCategoryId = categoryId
            inputCategoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
            
        case kPiwigoCategorySelectActionMoveAlbum:
            guard let categoryData = parameter as? PiwigoAlbumData else {
                fatalError("Input parameter expected to be of PiwigoAlbumData type")
            }
            // Album which will be moved into the selected one
            inputCategoryId = categoryData.albumId
            inputCategoryData = categoryData
            
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            guard let imageData = parameter as? PiwigoImageData else {
                fatalError("Input parameter expected to be of type PiwigoImageData")
            }
            // Image which will be set thumbnail of the selected album
            inputImageData = imageData
            
        case kPiwigoCategorySelectActionCopyImage:
            guard let array = parameter as? [Any],
                  let imageData = array[0] as? PiwigoImageData,
                  let categoryId = array[1] as? Int else {
                fatalError("Input parameter expected to be of type [PiwigoImageData, Int]")
            }
            // Image of the category ID which will be copied to the selected album
            inputImageData = imageData
            inputCategoryId = categoryId

        case kPiwigoCategorySelectActionMoveImage:
            guard let array = parameter as? [Any],
                  let imageData = array[0] as? PiwigoImageData,
                  let categoryId = array[1] as? Int else {
                fatalError("Input parameter expected to be of type [PiwigoImageData, Int]")
            }
            // Image of the category ID which will be moved to the selected album
            inputImageData = imageData
            inputCategoryId = categoryId

        case kPiwigoCategorySelectActionCopyImages:
            guard let array = parameter as? [Any],
                  let imageIds = array[0] as? [NSNumber],
                  let categoryId = array[1] as? Int else {
                fatalError("Input parameter expected to be of type [[String], Int]")
            }
            // Image IDs of the category ID which will be copied to the selected album
            inputImageIds = imageIds.map({$0.intValue}).filter({ $0 != NSNotFound})
            inputImageData = CategoriesData.sharedInstance().getImageForCategory(categoryId, andId: inputImageIds[0])
            inputCategoryId = categoryId

        case kPiwigoCategorySelectActionMoveImages:
            guard let array = parameter as? [Any],
                  let imageIds = array[0] as? [NSNumber],
                  let categoryId = array[1] as? Int else {
                fatalError("Input parameter expected to be of type [[String], Int]")
            }
            // Image IDs of the category ID which will be moved to the selected album
            inputImageIds = imageIds.map({$0.intValue}).filter({ $0 != NSNotFound})
            inputImageData = CategoriesData.sharedInstance().getImageForCategory(categoryId, andId: inputImageIds[0])
            inputCategoryId = categoryId

        default:
            fatalError("Called setParameter before setting wanted action")
        }
    }

    @IBOutlet var categoriesTableView: UITableView!
    private var cancelBarButton: UIBarButtonItem?

    private var recentCategories: [PiwigoAlbumData] = []        // Recent categories presented in 1st section
    private var categories: [PiwigoAlbumData] = []              // Categories presented in 2nd section
    private var categoriesThatShowSubCategories = Set<Int>()
    private var nberOfSelectedImages = Float(0)

    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Build list of recent categories (1st section)
        buildRecentCategoryArray()
        
        // Button for returning to albums/images collections
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "CancelSelect"

        // Register CategoryTableViewCell
        categoriesTableView.register(UINib(nibName: "CategoryTableViewCell", bundle: nil),
                                     forCellReuseIdentifier: "CategoryTableViewCell")

        // Set title and buttons
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
        
        case kPiwigoCategorySelectActionMoveAlbum:
            title = NSLocalizedString("moveCategory", comment:"Move Album")
        
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            title = NSLocalizedString("settings_autoUploadDestination", comment: "Destination")
            
        case kPiwigoCategorySelectActionCopyImage,
             kPiwigoCategorySelectActionCopyImages:
            title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            
        case kPiwigoCategorySelectActionMoveImage,
             kPiwigoCategorySelectActionMoveImages:
            title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            
        default:
            title = ""
        }

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = UIColor.piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        setTableViewMainHeader()
        categoriesTableView.separatorColor = .piwigoColorSeparator()
        categoriesTableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
        buildCategoryArray(usingCache: true, untilCompletion: { result in
            // Build complete list
            self.categoriesTableView.reloadData()
        }, orFailure: { task, error in
            // Invite users to refresh?
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Navigation "Cancel" button and identifier
        navigationItem.setRightBarButton(cancelBarButton, animated: true)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
        
        // Retrieve image data if needed
        if [kPiwigoCategorySelectActionCopyImages,
            kPiwigoCategorySelectActionMoveImages].contains(wantedAction) {
            totalNumberOfImages = Float(inputImageIds.count)
            if totalNumberOfImages > 1 {
                showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment:"Loading…"), inMode: .annularDeterminate)
            } else {
                showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment:"Loading…"), inMode: .indeterminate)
            }
            inputImagesData = []
            retrieveImageData()
        }
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
                switch self.wantedAction {
                case kPiwigoCategorySelectActionSetDefaultAlbum,
                     kPiwigoCategorySelectActionSetAutoUploadAlbum:
                    self.preferredContentSize = CGSize(width: kPiwigoPadSettingsWidth,
                                                       height: ceil(mainScreenBounds.height*2/3));
                default:
                    self.preferredContentSize = CGSize(width: kPiwigoPadSubViewWidth,
                                                       height: ceil(mainScreenBounds.height*2/3));
                }
            }

            // Reload table view
            self.setTableViewMainHeader()
            self.categoriesTableView?.reloadData()
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Re-enable toolbar items in image preview mode
        if [kPiwigoCategorySelectActionMoveAlbum,
            kPiwigoCategorySelectActionSetAlbumThumbnail,
            kPiwigoCategorySelectActionCopyImage,
            kPiwigoCategorySelectActionCopyImages,
            kPiwigoCategorySelectActionMoveImage,
            kPiwigoCategorySelectActionMoveImages].contains(wantedAction) {
            self.delegate?.didSelectCategory(withId: selectedCategoryId)
        }
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    @objc
    func cancelSelect() -> Void {
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum,
             kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Return to Settings
            navigationController?.popViewController(animated: true)

        default:
            // Return to Album/Images collection
            dismiss(animated: true)
        }
    }
    
    
    // MARK: - Retrieve Image Data
    private func retrieveImageData() {
        // Job done?
        if inputImageIds.count == 0 {
            self.hidePiwigoHUD { self.categoriesTableView.reloadData() }
            return
        }
        
        // Check list of IDs
        if inputImageIds.last == NSNotFound {
            inputImageIds.removeLast()
            retrieveImageData()
        }
        
        // Image data are not complete when retrieved using pwg.categories.getImages
        // Required by Copy, Delete, Move actions (may also be used to show albums image belongs to)
        ImageUtilities.getInfos(forID: inputImageIds.last!) { imageData in
            // Store image data
            self.inputImagesData.append(imageData)
            
            // Determine in which albums all images belong to
            let set1:NSMutableSet = NSMutableSet(array: self.inputImageData.categoryIds.map { $0.intValue })
            let set2 = Set(imageData.categoryIds.map { $0.intValue })
            set1.intersect(set2)
            self.inputImageData.categoryIds = set1.allObjects.map { NSNumber(integerLiteral: $0 as! Int) }

            // Image info retrieved
            self.inputImageIds.removeLast()
            
            // Update HUD
            self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImageIds.count) / self.totalNumberOfImages)
            
            // Next image
            self.retrieveImageData()
            
        } failure: { error in
            DispatchQueue.main.async {
                self.couldNotRetrieveImageData(with: error.localizedDescription)
            }
        }
    }

    private func couldNotRetrieveImageData(with message:String = "") {
        // Failed — Ask user if he/she wishes to retry
        let title = NSLocalizedString("imageDetailsFetchError_title", comment:"Image Details Fetch Failed")
        var mainMessage = NSLocalizedString("imageDetailsFetchError_retryMessage", comment:"Fetching the image data failed\nTry again?")
        if message.count > 0 { mainMessage.append("\n\(message)") }

        let alert = UIAlertController(title: title, message: mainMessage, preferredStyle: .alert)
        let retryAction = UIAlertAction(title: NSLocalizedString("alertRetryButton", comment:"Retry"),
                                        style: .default, handler: { _ in self.retrieveImageData() })
        let dismissAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment:"Dismiss"),
                                               style: .cancel) { _ in
            self.hidePiwigoHUD {
                self.dismiss(animated: true) { }
            }
        }
        alert.addAction(retryAction)
        alert.addAction(dismissAction)
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }
    

    // MARK: - UITableView - Header
    
    private func setTableViewMainHeader() {
        let headerView = SelectCategoryHeaderView(frame: .zero)
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSettingsWidth),
                                 text: NSLocalizedString("setDefaultCategory_select", comment: "Please select an album or sub-album which will become the new root album."))

        case kPiwigoCategorySelectActionMoveAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveCategory_select", comment:"Please select an album or sub-album to move album \"%@\" into."), inputCategoryData.name))

        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("categorySelection_setThumbnail", comment:"Please select the album which will use the photo \"%@\" as a thumbnail."), inputImageData.imageTitle.count > 0 ? inputImageData.imageTitle : inputImageData.fileName))

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSettingsWidth),
                                 text: NSLocalizedString("settings_autoUploadDestinationInfo", comment: "Please select the album or sub-album into which photos and videos will be auto-uploaded."))
            
        case kPiwigoCategorySelectActionCopyImage:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("copySingleImage_selectAlbum", comment:"Please, select the album in which you wish to copy the photo \"%@\"."), inputImageData.imageTitle.count > 0 ? inputImageData.imageTitle : inputImageData.fileName))

        case kPiwigoCategorySelectActionMoveImage:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: String(format: NSLocalizedString("moveSingleImage_selectAlbum", comment:"Please, select the album in which you wish to move the photo \"%@\"."), inputImageData.imageTitle.count > 0 ? inputImageData.imageTitle : inputImageData.fileName))

        case kPiwigoCategorySelectActionCopyImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: NSLocalizedString("copySeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        case kPiwigoCategorySelectActionMoveImages:
            headerView.configure(width: min(categoriesTableView.frame.size.width, kPiwigoPadSubViewWidth),
                                 text: NSLocalizedString("moveSeveralImages_selectAlbum", comment: "Please, select the album in which you wish to copy the photos."))

        default:
            fatalError("Action not configured in setTableViewMainHeader().")
        }
        categoriesTableView.tableHeaderView = headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let titleString: String
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let maxWidth = CGSize(width: tableView.frame.size.width - 30.0,
                              height: CGFloat.greatestFiniteMagnitude)

        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // 1st section —> Albums containing image
            let textString: String
            if section == 0 {
                // Title
                titleString = String(format: "%@\n", NSLocalizedString("tabBar_albums", comment:"Albums"))
                let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
                let titleRect = titleString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

                // Text
                if inputImageData.categoryIds.count > 1 {
                    textString = NSLocalizedString("categorySelection_one", comment:"Select one of the albums containing this image")
                } else {
                    textString = NSLocalizedString("categorySelection_current", comment:"Select the current album for this image")
                }
                let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
                let textRect = textString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
                return CGFloat(ceil(titleRect.size.height + textRect.size.height))
            }
            
            // Text
            textString = NSLocalizedString("categorySelection_other", comment:"or select another album for this image")
            let textAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontSmall()]
            let textRect = textString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
            return CGFloat(ceil(textRect.size.height))
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
            let titleRect = titleString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
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
                if inputImageData.categoryIds.count > 1 {
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
        headerLabel.textColor = .piwigoColorHeader()
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
                return inputImageData.categoryIds.count
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
            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        }
        else if (recentCategories.count > 0) && (indexPath.section == 0) {
            categoryData = recentCategories[indexPath.row]
        }
        else {
            // Determine the depth before setting up the cell
            categoryData = categories[indexPath.row]
            if categoryData.parentAlbumId != 0,
               let upperCat = categoryData.upperCategories {
                depth += upperCat.filter({ $0 != String(categoryData.albumId )}).count
            }
        }
        
        // No button if the user does not have upload rights
        var buttonState = kPiwigoCategoryTableCellButtonStateNone
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        let filteredCat = allCategories.filter({ NetworkVars.hasAdminRights ||
                                                (NetworkVars.hasNormalRights && $0.hasUploadRights) })
        if filteredCat.count > 0 {
            buttonState = categoriesThatShowSubCategories.contains(categoryData.albumId) ? kPiwigoCategoryTableCellButtonStateHideSubAlbum : kPiwigoCategoryTableCellButtonStateShowSubAlbum
        }

        // How should we present the category
        cell.delegate = self
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // The current default category is not selectable
            if categoryData.albumId == inputCategoryId {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
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
            if categoryData.albumId == 0 {  // Special case: upperCategories is nil for root
                // Root album => No button
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                // Is the root album parent of the input album?
                if inputCategoryData.parentAlbumId == 0 {
                    // Yes => Change text colour
                    cell.categoryLabel.textColor = .piwigoColorRightLabel()
                }
            }
            else if (recentCategories.count > 0) && (indexPath.section == 0) {
                // Don't present sub-albums in Recent Albums section
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
            }
            else if categoryData.albumId == inputCategoryData.parentAlbumId {
                // This album is the parent of the input album => Change text colour
                cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
            }
            else if categoryData.upperCategories.contains(String(inputCategoryId)) {
                // This album is a sub-album of the input album => No button
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Not a parent of a sub-album of the input album
                cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
            }
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // The root album is not available
            if indexPath.section == 0 {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
            } else {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
            }
            if categoryData.albumId == 0 {
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
            }
        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 {
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if (recentCategories.count > 0) && (indexPath.section == 0) {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                } else {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                }
            }
        case kPiwigoCategorySelectActionCopyImage,
             kPiwigoCategorySelectActionCopyImages,
             kPiwigoCategorySelectActionMoveImage,
             kPiwigoCategorySelectActionMoveImages:
            // User cannot copy/move the image to the root album or in albums it already belongs to
            if categoryData.albumId == 0 {  // Should not be presented but in case…
                cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                cell.categoryLabel.textColor = .piwigoColorRightLabel()
            } else {
                // Don't present sub-albums in Recent Albums section
                if (recentCategories.count > 0) && (indexPath.section == 0) {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: kPiwigoCategoryTableCellButtonStateNone)
                } else {
                    cell.configure(with: categoryData, atDepth: depth, andButtonState: buttonState)
                }
                // Albums containing the image are not selectable
                if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) {
                    cell.categoryLabel.textColor = .piwigoColorRightLabel()
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
            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
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
            if categoryData.albumId == inputCategoryId { return false }
            
        case kPiwigoCategorySelectActionMoveAlbum:
            // Do nothing if this is the input category
            if categoryData.albumId == inputCategoryId { return false }
            // User cannot move album to current parent album or in itself
            if categoryData.albumId == 0 {  // upperCategories is nil for root
                if inputCategoryData.parentAlbumId == 0 { return false }
            } else if (categoryData.albumId == inputCategoryData.parentAlbumId) ||
                        categoryData.upperCategories.contains(String(inputCategoryId)) { return false }
            
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 { return false }

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 { return false }

        case kPiwigoCategorySelectActionCopyImage,
             kPiwigoCategorySelectActionCopyImages,
             kPiwigoCategorySelectActionMoveImage,
             kPiwigoCategorySelectActionMoveImages:
            // The root album is not selectable (should not be presented but in case…)
            if categoryData.albumId == 0 { return false }
            // Albums containing all the images are not selectable
            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return false }

        default:
            return false
        }
        return true;
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)

        // Get selected category
        let categoryData:PiwigoAlbumData
        if (indexPath.section == 0) && (wantedAction == kPiwigoCategorySelectActionSetAlbumThumbnail) {
            let categoryId = inputImageData.categoryIds[indexPath.row].intValue
            categoryData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        }
        else if (indexPath.section == 0) && (self.recentCategories.count > 0) {
            categoryData = recentCategories[indexPath.row]
        } else {
            categoryData = categories[indexPath.row]
        }
        
        // Remember the choice
        selectedCategoryId = categoryData.albumId

        // What should we do with this selection?
        switch wantedAction {
        case kPiwigoCategorySelectActionSetDefaultAlbum:
            // Do nothing if this is the current default category
            if categoryData.albumId == inputCategoryId { return }
            
            // Ask user to confirm
            let title = NSLocalizedString("setDefaultCategory_title", comment: "Default Album")
            let message:String
            if categoryData.albumId == 0 {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), NSLocalizedString("categorySelection_root", comment: "Root Album"))
            } else {
                message = String(format: NSLocalizedString("setDefaultCategory_message", comment: "Are you sure you want to set the album %@ as default album?"), categoryData.name)
            }
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath, handler: { _ in
                // Set new Default Album
                if categoryData.albumId != AlbumVars.defaultCategory {
                    self.delegate?.didSelectCategory(withId: categoryData.albumId)
                }
                // Return to Settings
                self.navigationController?.popViewController(animated: true)
            })

        case kPiwigoCategorySelectActionMoveAlbum:
            // Do nothing if this is the current default category
            if categoryData.albumId == inputCategoryId { return }

            // User must not move album to current parent album or in itself
            if wantedAction == kPiwigoCategorySelectActionMoveAlbum {
                if categoryData.albumId == 0 {  // upperCategories is nil for root
                    if inputCategoryData.nearestUpperCategory == 0 { return }
                } else if (categoryData.albumId == inputCategoryData.parentAlbumId) ||
                    categoryData.upperCategories.contains(String(inputCategoryId)) { return }
            }

            // Ask user to confirm
            let title = NSLocalizedString("moveCategory", comment: "Move Album")
            let message = String(format: NSLocalizedString("moveCategory_message", comment: "Are you sure you want to move \"%@\" into the album \"%@\"?"), inputCategoryData.name, categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath, handler: { _ in
                // Move album to selected category
                self.moveCategory(intoCategory: categoryData)
            })

        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            // Ask user to confirm
            let title = NSLocalizedString("categoryImageSet_title", comment:"Album Thumbnail")
            let message = String(format: NSLocalizedString("categoryImageSet_message", comment:"Are you sure you want to set this image for the album \"%@\"?"), categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath, handler: { _ in
                // Add category to list of recent albums
                self.setRepresentative(for: categoryData)
            })

        case kPiwigoCategorySelectActionSetAutoUploadAlbum:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            
            // Return the selected album ID
            delegate?.didSelectCategory(withId: categoryData.albumId)
            navigationController?.popViewController(animated: true)
            
        case kPiwigoCategorySelectActionCopyImage:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySingleImage_message", comment:"Are you sure you want to copy the photo \"%@\" to the album \"%@\"?"), inputImageData.imageTitle.count > 0 ? inputImageData.imageTitle : inputImageData.fileName, categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath, handler: { _ in
                // Copy single image to selected album
                self.copySingleImage(toCategory: categoryData)
            })

        case kPiwigoCategorySelectActionMoveImage:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            // Do nothing if the image already belongs to the selected album
            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSingleImage_message", comment:"Are you sure you want to move the photo \"%@\" to the album \"%@\"?"), inputImageData.imageTitle.count > 0 ? inputImageData.imageTitle : inputImageData.fileName, categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath) { _ in
                // Move single image to selected album
                self.moveSingleImage(toCategory: categoryData)
            }

        case kPiwigoCategorySelectActionCopyImages:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            // Do nothing if the images already belong to the selected album
            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return }

            // Ask user to confirm
            let title = NSLocalizedString("copyImage_title", comment:"Copy to Album")
            let message = String(format: NSLocalizedString("copySeveralImages_message", comment:"Are you sure you want to copy the photos to the album \"%@\"?"), categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath, handler: { _ in
                // Initialise counter and display HUD
                self.nberOfSelectedImages = Float(self.inputImagesData.count)
                self.showPiwigoHUD(withTitle: NSLocalizedString("copySeveralImagesHUD_copying", comment: "Copying Photos…"),
                                   inMode: .annularDeterminate)

                // Copy several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.copySeveralImages(toCategory: categoryData)
                }
            })

        case kPiwigoCategorySelectActionMoveImages:
            // Do nothing if this is the root album
            if categoryData.albumId == 0 { return }
            // Do nothing if the images already belong to the selected album
            if inputImageData.categoryIds.contains(NSNumber(value: categoryData.albumId)) { return }

            // Ask user to confirm
            let title = NSLocalizedString("moveImage_title", comment:"Move to Album")
            let message = String(format: NSLocalizedString("moveSeveralImages_message", comment:"Are you sure you want to move the photos to the album \"%@\"?"), categoryData.name)
            requestConfirmation(withTitle: title, message: message,
                                forCategory: categoryData, at: indexPath) { _ in
                // Initialise counter and display HUD
                self.nberOfSelectedImages = Float(self.inputImagesData.count)
                self.showPiwigoHUD(withTitle: NSLocalizedString("moveSeveralImagesHUD_moving", comment: "Moving Photos…"),
                                   inMode: .annularDeterminate)
                
                // Move several images to selected album
                DispatchQueue.global(qos: .userInitiated).async {
                    self.moveSeveralImages(toCategory: categoryData)
                }
            }

        default:
            break
        }
    }
    
    private func requestConfirmation(withTitle title:String, message:String,
                                     forCategory categoryData: PiwigoAlbumData, at indexPath:IndexPath,
                                     handler:((UIAlertAction) -> Void)? = nil) -> Void {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
                                         style: .cancel, handler: {_ in 
                                            // Forget the choice
                                            self.selectedCategoryId = NSNotFound
                                         })
        let performAction = UIAlertAction(title: NSLocalizedString("alertYesButton", comment: "Yes"), style: .default, handler:handler)
    
        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(performAction)

        // Present popover view
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.sourceView = categoriesTableView
        alert.popoverPresentationController?.sourceRect = categoriesTableView.rectForRow(at: indexPath)
        alert.popoverPresentationController?.permittedArrowDirections = [.left, .right]
        present(alert, animated: true, completion: {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        })
    }

    private func showError(with error:String = "") {
        // Title and message
        let title:String
        var message:String
        switch wantedAction {
        case kPiwigoCategorySelectActionMoveAlbum:
            title = NSLocalizedString("moveCategoryError_title", comment:"Move Fail")
            message = NSLocalizedString("moveCategoryError_message", comment:"Failed to move your album")
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            title = NSLocalizedString("categoryImageSetError_title", comment:"Image Set Error")
            message = NSLocalizedString("categoryImageSetError_message", comment:"Failed to set the album image")
        case kPiwigoCategorySelectActionCopyImage:
            title = NSLocalizedString("copyImageError_title", comment:"Copy Fail")
            message = NSLocalizedString("copySingleImageError_message", comment:"Failed to copy your photo")
        case kPiwigoCategorySelectActionCopyImages:
            title = NSLocalizedString("copyImageError_title", comment:"Copy Fail")
            message = NSLocalizedString("copySeveralImagesError_message", comment:"Failed to copy some photos")
        case kPiwigoCategorySelectActionMoveImage:
            title = NSLocalizedString("moveImageError_title", comment:"Move Fail")
            message = NSLocalizedString("moveSingleImageError_message", comment:"Failed to copy your photo")
        case kPiwigoCategorySelectActionMoveImages:
            title = NSLocalizedString("moveImageError_title", comment:"Move Fail")
            message = NSLocalizedString("moveSeveralImagesError_message", comment:"Failed to move some photos")
        default:
            return
        }
        
        // Present alert
        self.dismissPiwigoError(withTitle: title, message: message, errorMessage: error) {
            // Forget the choice
            self.selectedCategoryId = NSNotFound
            // Dismiss the view
            self.dismiss(animated: true, completion: {})
        }
    }
    

    // MARK: - Move Category Methods
    private func moveCategory(intoCategory parentCatData:PiwigoAlbumData) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("moveCategoryHUD_moving", comment: "Moving Album…"))

        DispatchQueue.global(qos: .userInitiated).async {
            // Add category to list of recent albums
            let userInfo = ["categoryId": parentCatData.albumId]
            NotificationCenter.default.post(name: PwgNotifications.addRecentAlbum, object: nil, userInfo: userInfo)

            AlbumService.moveCategory(self.inputCategoryId,
                                      intoCategory: parentCatData.albumId) { task, movedSuccessfully in
                if movedSuccessfully {
                    // Update cached old parent categories, except root album
                    for oldParentStr in self.inputCategoryData.upperCategories {
                        guard let oldParentID = Int(oldParentStr) else { continue }
                        // Check that it is not the root album, nor the moved album
                        if (oldParentID == 0) || (oldParentID == self.inputCategoryData.albumId) { continue }

                        // Remove number of moved sub-categories and images
                        CategoriesData.sharedInstance()?.getCategoryById(oldParentID).numberOfSubCategories -= self.inputCategoryData.numberOfSubCategories + 1
                        CategoriesData.sharedInstance()?.getCategoryById(oldParentID).totalNumberOfImages -= self.inputCategoryData.totalNumberOfImages
                    }
                    
                    // Update cached new parent categories, except root album
                    var newUpperCategories = [String]()
                    if parentCatData.albumId != 0 {
                        // Parent category in which we moved the category
                        newUpperCategories = CategoriesData.sharedInstance().getCategoryById(parentCatData.albumId).upperCategories ?? []
                        for newParentStr in newUpperCategories {
                            // Check that it is not the root album, nor the moved album
                            guard let newParentId = Int(newParentStr) else { continue }
                            if (newParentId == 0) || (newParentId == self.inputCategoryId) { continue }
                            
                            // Add number of moved sub-categories and images
                            CategoriesData.sharedInstance()?.getCategoryById(newParentId).numberOfSubCategories += self.inputCategoryData.numberOfSubCategories + 1;
                            CategoriesData.sharedInstance()?.getCategoryById(newParentId).totalNumberOfImages += self.inputCategoryData.totalNumberOfImages
                        }
                    }

                    // Update upperCategories of moved sub-categories
                    var upperCatToRemove:[String] = self.inputCategoryData.upperCategories ?? []
                    upperCatToRemove.removeAll(where: {$0 == String(self.inputCategoryId)})
                    var catToUpdate = [PiwigoAlbumData]()
                    
                    if self.inputCategoryData.numberOfSubCategories > 0 {
                        let subCategories:[PiwigoAlbumData] = CategoriesData.sharedInstance().getCategoriesForParentCategory(self.inputCategoryId) ?? []
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
                    var upperCategories = self.inputCategoryData.upperCategories ?? []
                    upperCategories.removeAll(where: { upperCatToRemove.contains($0) })
                    upperCategories.append(contentsOf: newUpperCategories)
                    self.inputCategoryData.upperCategories = upperCategories
                    self.inputCategoryData.nearestUpperCategory = parentCatData.albumId
                    self.inputCategoryData.parentAlbumId = parentCatData.albumId
                    catToUpdate.append(self.inputCategoryData)

                    // Update cache (will refresh album/images view)
                    CategoriesData.sharedInstance().updateCategories(catToUpdate, andUpdateUI: true)
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                } else {
                    self.hidePiwigoHUD { self.showError() }
                }
            } onFailure: { [unowned self] task, error in
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Set Album Thumbnail Methods
    private func setRepresentative(for categoryData:PiwigoAlbumData) {
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("categoryImageSetHUD_updating", comment:"Updating Album Thumbnail…"))
        
        // Set image as representative
        DispatchQueue.global(qos: .userInitiated).async {
            AlbumService.setCategoryRepresentativeForCategory(categoryData.albumId,
                                  forImageId: self.inputImageData.imageId) { _, didSucceed in
                if didSucceed {
                    // Update image Id of album
                    categoryData.albumThumbnailId = self.inputImageData.imageId

                    // Update image URL of album
                    categoryData.albumThumbnailUrl = self.inputImageData.thumbPath;

                    // Image will be downloaded when displaying list of albums
                    categoryData.categoryImage = nil
                    
                    // Close HUD
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                } else {
                    // Close HUD and inform user
                    self.hidePiwigoHUD { self.showError() }
                }
            } onFailure: { _, error in
                // Close HUD and inform user
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Copy Images Methods
    private func copySingleImage(toCategory categoryData:PiwigoAlbumData) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": categoryData.albumId]
        NotificationCenter.default.post(name: PwgNotifications.addRecentAlbum, object: nil, userInfo: userInfo)

        // Check image data
        guard let imageData = self.inputImageData else {
            self.showError()
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("copySingleImageHUD_copying", comment:"Copying Photo…"))
        
        // Copy image to selected album
        DispatchQueue.global(qos: .userInitiated).async {
            self.copyImage(imageData, toCategory: categoryData) { didSucceed in
                if didSucceed {
                    // Close HUD
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                } else {
                    // Close HUD and inform user
                    self.hidePiwigoHUD { self.showError() }
                }
            } onFailure: { error in
                // Close HUD and inform user
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }
    
    private func copySeveralImages(toCategory categoryData:PiwigoAlbumData) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": categoryData.albumId]
        NotificationCenter.default.post(name: PwgNotifications.addRecentAlbum, object: nil, userInfo: userInfo)

        // Jobe done?
        if inputImagesData.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true)
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImagesData.last else {
            // Close HUD and inform user
            self.hidePiwigoHUD { self.showError() }
            return
        }

        // Copy next image to seleted album
        self.copyImage(imageData, toCategory: categoryData) { didSucceed in
            if didSucceed {
                // Next image…
                self.inputImagesData.removeLast()
                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImagesData.count) / self.nberOfSelectedImages)
                self.copySeveralImages(toCategory: categoryData)
            } else {
                // Close HUD and inform user
                self.hidePiwigoHUD { self.showError() }
            }
        } onFailure: { error in
            // Close HUD and inform user
            self.hidePiwigoHUD {
                guard let error = error as NSError? else {
                    self.showError()
                    return
                }
                self.showError(with: error.localizedDescription)
            }
        }
    }
    
    private func copyImage(_ imageData:PiwigoImageData, toCategory categoryData:PiwigoAlbumData,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard var categoryIds = imageData.categoryIds else {
            self.showError()
            return
        }
        categoryIds.append(NSNumber(value: categoryData.albumId))

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            imageData.categoryIds = categoryIds
            // Add image to selected category and update corresponding Album/Images collection
            CategoriesData.sharedInstance().addImage(imageData)
            
            // Update image data in current view (ImageDetailImage view or Album/Images collection)
            DispatchQueue.main.async {
                self.imageCopiedDelegate?.didCopyImage(withData: imageData)
            }
            completion(true)
        } failure: { error in
            fail(error)
        }
    }
    
    // MARK: - Move Images Methods
    private func moveSingleImage(toCategory categoryData:PiwigoAlbumData) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": categoryData.albumId]
        NotificationCenter.default.post(name: PwgNotifications.addRecentAlbum, object: nil, userInfo: userInfo)

        // Check image data
        guard let imageData = self.inputImageData else {
            self.showError()
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("moveSingleImageHUD_moving", comment:"Moving Photo…"))
        
        // Move image to selected album
        DispatchQueue.global(qos: .userInitiated).async {
            self.moveImage(imageData, toCategory: categoryData) { didSucceed in
                if didSucceed {
                    // Close HUD
                    self.updatePiwigoHUDwithSuccess() {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                            self.dismiss(animated: true)
                        }
                    }
                } else {
                    // Close HUD and inform user
                    self.hidePiwigoHUD { self.showError() }
                }
            } onFailure: { error in
                // Close HUD and inform user
                self.hidePiwigoHUD {
                    guard let error = error as NSError? else {
                        self.showError()
                        return
                    }
                    self.showError(with: error.localizedDescription)
                }
            }
        }
    }
    
    private func moveSeveralImages(toCategory categoryData:PiwigoAlbumData) {
        // Add category to list of recent albums
        let userInfo = ["categoryId": categoryData.albumId]
        NotificationCenter.default.post(name: PwgNotifications.addRecentAlbum, object: nil, userInfo: userInfo)

        // Jobe done?
        if inputImagesData.count == 0 {
            // Close HUD
            updatePiwigoHUDwithSuccess() {
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) {
                    self.dismiss(animated: true)
                }
            }
            return
        }
        
        // Check image data
        guard let imageData = inputImagesData.last else {
            // Close HUD and inform user
            self.hidePiwigoHUD { self.showError() }
            return
        }

        // Move next image to seleted album
        moveImage(imageData, toCategory: categoryData) { didSucceed in
            if didSucceed {
                // Next image…
                self.inputImagesData.removeLast()
                self.updatePiwigoHUD(withProgress: 1.0 - Float(self.inputImagesData.count) / self.nberOfSelectedImages)
                self.moveSeveralImages(toCategory: categoryData)
            } else {
                // Close HUD and inform user
                self.hidePiwigoHUD { self.showError() }
            }
        } onFailure: { error in
            // Close HUD and inform user
            self.hidePiwigoHUD {
                guard let error = error as NSError? else {
                    self.showError()
                    return
                }
                self.showError(with: error.localizedDescription)
            }
        }
    }
    
    private func moveImage(_ imageData:PiwigoImageData, toCategory categoryData:PiwigoAlbumData,
                           onCompletion completion: @escaping (_ success: Bool) -> Void,
                           onFailure fail: @escaping (_ error: NSError?) -> Void) {
        // Append selected category ID to image category list
        guard var categoryIds = imageData.categoryIds else {
            self.showError()
            return
        }
        categoryIds.append(NSNumber(value: categoryData.albumId))
        
        // Remove current categoryId from image category list
        categoryIds.removeAll(where: {$0 == NSNumber(value: inputCategoryId)} )

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            imageData.categoryIds = categoryIds
            // Add image to selected category
            CategoriesData.sharedInstance().addImage(imageData, toCategory: String(categoryData.albumId))

            // Remove image from current category if needed
            CategoriesData.sharedInstance().removeImage(imageData, fromCategory: String(self.inputCategoryId))
                            
            // Remove image from ImageDetailImage view
            DispatchQueue.main.async {
                self.imageRemovedDelegate?.didRemoveImage(withId: imageData.imageId)
            }
            completion(true)
        } failure: { error in
            fail(error)
        }
    }

    
    // MARK: - Category List Builder
    
    private func buildCategoryArray(usingCache useCache: Bool,
                                    untilCompletion completion: @escaping (_ result: Bool) -> Void,
                                    orFailure fail: @escaping (_ task: URLSessionTask?, _ error: Error?) -> Void) {
        // Show loading HUD when not using cache option,
        if !(useCache && (AlbumVars.defaultCategory == 0)) {
            // Show loading HD
            showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            // Reload category data and set current category
            //        NSLog(@"buildCategoryDf => getAlbumListForCategory(%ld,NO,YES)", (long)0);
            AlbumService.getAlbumList(forCategory: 0, usingCache: false, inRecursiveMode: true,
                    onCompletion: { task, albums in
                        // Hide loading HUD
                        self.hidePiwigoHUD {
                            // Build category array
                            self.buildCategoryArray()
                            completion(true)
                        }
                    },
                    onFailure: { task, error in
                        // Hide loading HUD
                        self.hidePiwigoHUD {
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
            .filter({ NetworkVars.hasAdminRights ||
                        (NetworkVars.hasNormalRights && $0.hasUploadRights) })
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
        let recentCatIds = AlbumVars.recentCategories.components(separatedBy: ",")
        if !recentCatIds.isEmpty { return }

        // Build list of recent categories
        for catIdStr in recentCatIds {
            // Get category ID
            guard let catId = Int(catIdStr) else { continue }
            
            // Exclude current category
            if catId == inputCategoryId { continue }
            
            // Get category data
            guard let categoryData = CategoriesData.sharedInstance()?.getCategoryById(catId) else { continue }
            
            // User cannot move album to current parent album or in itself
            if wantedAction == kPiwigoCategorySelectActionMoveAlbum,
               (categoryData.albumId == inputCategoryData.parentAlbumId) ||
                categoryData.upperCategories.contains(String(inputCategoryId)) { continue }
            
            // Add category existing in cache
            recentCategories.append(categoryData)

            // Reach max number of recent categories?
            if recentCategories.count == AlbumVars.maxNberRecentCategories { break }
        }
    }

    
    // MARK: - Sub-Categories Addition/Removal
    
    func addSubCaterories(toCategoryID categoryTapped: PiwigoAlbumData) {
        // Build list of categories from complete known list
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories

        // Proposed list is collected in diff
        var diff: [PiwigoAlbumData] = []

        // Look for categories which are not already displayed
        /// - Non-admin Community users can only upload in specific albums
        /// - Only add sub-categories of tapped category
        let filteredCat = allCategories
            .filter({ NetworkVars.hasAdminRights ||
                        (NetworkVars.hasNormalRights && $0.hasUploadRights) })
            .filter({ $0.nearestUpperCategory == categoryTapped.albumId })
        for category in filteredCat {   // Don't use forEach to keep the order
            // Is this category already in displayed list?
            if !categories.contains(where: { $0.albumId == category.albumId }) {
                diff.append(category)
            }
        }

        // Build new list of categories to be displayed
        guard let indexOfParent = categories.firstIndex(where: { $0.albumId == categoryTapped.albumId }) else { return }
        categories.insert(contentsOf: diff, at: indexOfParent + 1)

        // Add tapped category to list of categories having shown sub-categories
        categoriesThatShowSubCategories.insert(categoryTapped.albumId)

        // Get section in which sub-categories will be inserted
        var section = 0
        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            section = 1
        default:    // Present recent albums if any
            section = (recentCategories.count > 0 ? 1 : 0)
        }
        
        // Compile indexPaths of rows to insert
        let indexPaths: [IndexPath] = (indexOfParent + 1...indexOfParent + diff.count)
            .map { IndexPath(row: $0, section: section)}

        // Insert sub-categories in table view
        categoriesTableView.insertRows(at: indexPaths, with: .automatic)
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

        // Get section in which sub-categories will be inserted
        var section = 0
        switch wantedAction {
        case kPiwigoCategorySelectActionSetAlbumThumbnail:
            section = 1
        default:    // Present recent albums if any
            section = (recentCategories.count > 0 ? 1 : 0)
        }
        
        // Compile indexPaths of rows to remove
        var indexPaths = [IndexPath]()
        for cat in diff {
            if let row = categories.firstIndex(where: { $0.albumId == cat.albumId }) {
                indexPaths.append(IndexPath(row: row, section: section))
            }
        }

        // Remove objects from displayed list
        categories.removeAll(where: { diff.contains($0) })

        // Remove tapped category from list of categories having shown sub-categories
        if categoriesThatShowSubCategories.contains(categoryTapped.albumId) {
            categoriesThatShowSubCategories.remove(categoryTapped.albumId)
        }

        // Remove sub-categories from table view
        categoriesTableView.deleteRows(at: indexPaths, with: .automatic)
    }
}


// MARK: - CategoryCellDelegate Methods
extension SelectCategoryViewController: CategoryCellDelegate {
    // Called when the user taps a sub-category button
    func tappedDisclosure(of categoryTapped: PiwigoAlbumData) {
        
        // Build list of categories from list of known categories
        let allCategories: [PiwigoAlbumData] = CategoriesData.sharedInstance().allCategories
        var subcategories: [PiwigoAlbumData] = []

        // Look for known requested sub-categories
        subcategories.append(contentsOf: allCategories.filter({ $0.parentAlbumId == categoryTapped.albumId }))

        // Look for sub-categories which are already displayed
        var nberDisplayedSubCategories = 0
        subcategories.forEach { category in
            nberDisplayedSubCategories += categories.filter({ $0.albumId == category.albumId}).count
        }

        // Compare number of sub-albums inside category to be closed
        if (subcategories.count > 0) && (subcategories.count == nberDisplayedSubCategories) {
            // User wants to hide sub-categories
            removeSubCategories(toCategoryID: categoryTapped)
        } else if subcategories.count > 0 {
            // Sub-categories are already known
            addSubCaterories(toCategoryID: categoryTapped)
        } else {
            // Sub-categories are not known
            // NSLog(@"subCategories => getAlbumListForCategory(%ld,NO,NO)", (long)categoryTapped.albumId);

            // Show loading HD
            showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"))

            AlbumService.getAlbumList(forCategory: categoryTapped.albumId,
                                      usingCache: true,
                                      inRecursiveMode: false,
                                      onCompletion: { task, albums in
                                        // Hide loading HUD
                                        self.hidePiwigoHUD {
                                            // Add sub-categories
                                            self.addSubCaterories(toCategoryID: categoryTapped)
                                        }
                                    },
                                      onFailure: { task, error in
                                        // Hide loading HUD
                                        self.hidePiwigoHUD {
                                            print(String(format: "getAlbumListForCategory: %@", error?.localizedDescription ?? ""))
                                        }
                                    })
        }
    }
}
