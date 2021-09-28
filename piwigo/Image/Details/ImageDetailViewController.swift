//
//  ImageDetailViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit

let kPiwigoNotificationPinchedImage = "kPiwigoNotificationPinchedImage"
let kPiwigoNotificationUpdateImageFileName = "kPiwigoNotificationUpdateImageFileName"

@objc protocol ImageDetailDelegate: NSObjectProtocol {
    func didSelectImage(withId imageId: Int)
    func didDeleteImage(_ image: PiwigoImageData?, atIndex index: Int)
    func needToLoadMoreImages()
}

class ImageDetailViewController: UIViewController {
    
    @objc weak var imgDetailDelegate: ImageDetailDelegate?
    @objc var images = [PiwigoImageData]()
    @objc var categoryId = 0
    @objc var imageIndex = 0
    
    private var imageData = PiwigoImageData()
    private var progressBar = UIProgressView()
    private var editBarButton: UIBarButtonItem?
    private var deleteBarButton: UIBarButtonItem?
    private var shareBarButton: UIBarButtonItem?
    private var setThumbnailBarButton: UIBarButtonItem?
    private var moveBarButton: UIBarButtonItem?
    //private var favoriteBarButton: UIBarButtonItem?
    private var spaceBetweenButtons: UIBarButtonItem?
    private var isToolbarRequired = false

    private var pageViewController: UIPageViewController?

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.setProgress(0.0, animated: false)
        progressBar.isHidden = false
        view.addSubview(progressBar)
        view.addConstraints(NSLayoutConstraint.constraintFillWidth(progressBar)!)
        progressBar.addConstraint(NSLayoutConstraint.constraintView(progressBar, toHeight: 3)!)
        view.addConstraint(NSLayoutConstraint(item: progressBar, attribute: .top,
                                              relatedBy: .equal, toItem: view,
                                              attribute: .top, multiplier: 1.0, constant: 0))
        // Bar buttons
        editBarButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editImage))
        editBarButton?.accessibilityIdentifier = "edit"
        deleteBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteImage))
        deleteBarButton?.tintColor = UIColor.red
        deleteBarButton?.accessibilityIdentifier = "delete"
        shareBarButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareImage))
        shareBarButton?.tintColor = UIColor.piwigoColorOrange()
        shareBarButton?.accessibilityIdentifier = "share"
        if #available(iOS 13.0, *) {
            setThumbnailBarButton = UIBarButtonItem(image: UIImage(systemName: "rectangle.and.paperclip"), style: .plain, target: self, action: #selector(setAsAlbumImage))
        } else {
            // Fallback on earlier versions
            setThumbnailBarButton = UIBarButtonItem(image: UIImage(named: "imagePaperclip"), landscapeImagePhone: UIImage(named: "imagePaperclipCompact"), style: .plain, target: self, action: #selector(setAsAlbumImage))
        }
        setThumbnailBarButton?.tintColor = UIColor.piwigoColorOrange()
        setThumbnailBarButton?.accessibilityIdentifier = "albumThumbnail"
        moveBarButton = UIBarButtonItem(barButtonSystemItem: .reply, target: self, action: #selector(addImageToCategory))
        moveBarButton?.tintColor = UIColor.piwigoColorOrange()
        moveBarButton?.accessibilityIdentifier = "move"
//        self.favoriteBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"imageNotFavorite"] landscapeImagePhone:[UIImage imageNamed:@"imageNotFavoriteCompact"] style:UIBarButtonItemStylePlain target:self action:@selector(addToFavoritesImageWithId)];
//        self.favoriteBarButton.tintColor = [UIColor piwigoColorOrange];
//        [self.favoriteBarButton setAccessibilityIdentifier:@"favorite"];
        spaceBetweenButtons = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)

        // Current image
        var index = max(0, imageIndex)
        index = min(imageIndex, images.count - 1)
        imageData = images[index]

        // Initialise pageViewController
        pageViewController = children[0] as? UIPageViewController
        pageViewController!.delegate = self
        pageViewController!.dataSource = self

        // Load initial image preview view controller
        if let startingImage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController {
            startingImage.imagePreviewDelegate = self
            startingImage.imageIndex = index
            startingImage.imageData = imageData
    //        startingImage.setImageScrollViewWith(imageData)
            pageViewController!.setViewControllers( [startingImage], direction: .forward, animated: false)
        }
        
        // Retrieve complete image data if needed (buttons are greyed until job done)
        if imageData.fileSize == NSNotFound {
            retrieveCompleteImageDataOfImage(imageData)
        }

        // For managing taps
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapView)))

        // Register image pinches
        NotificationCenter.default.addObserver(self, selector: #selector(didPinchView), name: NSNotification.Name(kPiwigoNotificationPinchedImage), object: nil)

        // Register image data updates
        NotificationCenter.default.addObserver(self, selector: #selector(updateImageFileName(_:)), name: NSNotification.Name(kPiwigoNotificationUpdateImageFileName), object: nil)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Set background color according to navigation bar visibility
        if navigationController?.isNavigationBarHidden ?? false {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = .piwigoColorBackground()
        }

        // Navigation bar
        let navigationBar = navigationController?.navigationBar
        navigationBar?.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        navigationBar?.tintColor = .piwigoColorOrange()

        // Toolbar
        let toolbar = navigationController?.toolbar
        toolbar?.barStyle = AppVars.isDarkPaletteActive ? .black : .default
        toolbar?.tintColor = .piwigoColorOrange()

        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationBar?.titleTextAttributes = attributes
        setTitleViewFromImageData()
        if #available(iOS 11.0, *) {
            navigationBar?.prefersLargeTitles = false
        }

        if #available(iOS 13.0, *) {
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithTransparentBackground()
            barAppearance.backgroundColor = .piwigoColorBackground().withAlphaComponent(0.9)
            barAppearance.shadowColor = AppVars.isDarkPaletteActive ? .init(white: 1.0, alpha: 0.15) : .init(white: 0.0, alpha: 0.3)
            navigationBar?.standardAppearance = barAppearance
            navigationBar?.compactAppearance = barAppearance
            navigationBar?.scrollEdgeAppearance = barAppearance

            let toolbarAppearance = UIToolbarAppearance(barAppearance: barAppearance)
            toolbar?.barTintColor = .piwigoColorBackground().withAlphaComponent(0.9)
            toolbar?.standardAppearance = toolbarAppearance
            toolbar?.compactAppearance = toolbarAppearance
            if #available(iOS 15.0, *) {
                /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
                /// which by default produces a transparent background, to all navigation bars.
                toolbar?.scrollEdgeAppearance = toolbarAppearance
            }
        } else {
            navigationBar?.barTintColor = .piwigoColorBackground().withAlphaComponent(0.3)
            toolbar?.barTintColor = .piwigoColorBackground().withAlphaComponent(0.3)
        }

        // Progress bar
        progressBar.progressTintColor = .piwigoColorOrange()
        progressBar.trackTintColor = .piwigoColorRightLabel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Always open this view with a navigation bar
        // and never present video poster in full screen
        navigationController?.setNavigationBarHidden(false, animated: true)

        // Image options buttons
        updateNavBar()

        // Set colors, fonts, etc.
        applyColorPalette()

        // Scrolling
        if #available(iOS 12, *) {
            // Safe area already excluded in storyboard
        } else {
            // The view controller should automatically adjust its scroll view insets
            if self.responds(to: Selector(("automaticallyAdjustsScrollViewInsets"))) {
                automaticallyAdjustsScrollViewInsets = false
                edgesForExtendedLayout = []
            }
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Reload the tableview on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            updateNavBar()
            setTitleViewFromImageData()
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Should we update user interface based on the appearance?
        if #available(iOS 13.0, *) {
            let hasUserInterfaceStyleChanged = previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle
            if hasUserInterfaceStyleChanged {
                AppVars.isSystemDarkModeActive = (traitCollection.userInterfaceStyle == .dark)
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    deinit {
        // Unregister image pinches
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationPinchedImage), object: nil)

        // Unregister image data updates
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(kPiwigoNotificationUpdateImageFileName), object: nil)

        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }


    // MARK: - Navigation Bar & Toolbar
    func setTitleViewFromImageData() {
        // Create label programmatically
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = UIColor.piwigoColorWhiteCream()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.piwigoFontSmallSemiBold()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.allowsDefaultTighteningForTruncation = true
        if imageData.imageTitle.isEmpty {
            // No title => Use file name
            titleLabel.text = imageData.fileName
        } else {
            titleLabel.text = imageData.imageTitle
        }
        titleLabel.sizeToFit()

        // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            (UIApplication.shared.statusBarOrientation.isLandscape)) ||
            (imageData.dateCreated == imageData.datePosted) {
            let titleWidth = CGFloat(fmin(Float(titleLabel.bounds.size.width),
                                          Float(view.bounds.size.width * 0.4)))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            navigationItem.titleView = oneLineTitleView

            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
        }
        else {
            let subTitleLabel = UILabel(frame: CGRect(x: 0, y: titleLabel.frame.size.height, width: 0, height: 0))
            subTitleLabel.backgroundColor = UIColor.clear
            subTitleLabel.textColor = UIColor.piwigoColorWhiteCream()
            subTitleLabel.textAlignment = .center
            subTitleLabel.numberOfLines = 1
            subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            subTitleLabel.font = UIFont.piwigoFontTiny()
            subTitleLabel.adjustsFontSizeToFitWidth = false
            subTitleLabel.lineBreakMode = .byTruncatingTail
            subTitleLabel.allowsDefaultTighteningForTruncation = true
            if let dateCreated = imageData.dateCreated {
                subTitleLabel.text = DateFormatter.localizedString(from: dateCreated,
                                                                   dateStyle: .medium, timeStyle: .medium)
            }
            subTitleLabel.sizeToFit()

            var titleWidth = fmax(CGFloat(subTitleLabel.bounds.size.width),
                                  CGFloat(titleLabel.bounds.size.width))
            titleWidth = fmin(titleWidth, CGFloat((navigationController?.view.bounds.size.width ?? 0.0) * 0.4))
            let twoLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth),
                height: titleLabel.bounds.size.height + subTitleLabel.bounds.size.height))
            navigationItem.titleView = twoLineTitleView

            twoLineTitleView.addSubview(titleLabel)
            twoLineTitleView.addSubview(subTitleLabel)
            twoLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            twoLineTitleView.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(titleLabel)!)
            twoLineTitleView.addConstraint(NSLayoutConstraint.constraintCenterVerticalView(subTitleLabel)!)

            let views = ["title": titleLabel,
                         "subtitle": subTitleLabel]
            twoLineTitleView.addConstraints(
                NSLayoutConstraint.constraints(withVisualFormat: "V:|[title][subtitle]|",
                    options: [], metrics: nil, views: views))
        }
    }

    func updateNavBar() {
        // Interface depends on device and orientation
        if (UIDevice.current.userInterfaceIdiom == .phone) || (UIDevice.current.userInterfaceIdiom == .pad && UIDevice.current.orientation != .landscapeLeft && UIDevice.current.orientation != .landscapeRight) {

            // iPhone or iPad in portrait mode
            if NetworkVarsObjc.hasAdminRights {
                // User with admin rights can move, edit, delete images and set as album image
                navigationItem.rightBarButtonItems = [editBarButton].compactMap { $0 }
//                if ([@"2.10.0" compare:AppVars.version options:NSNumericSearch] == NSOrderedDescending) {
                toolbarItems = [shareBarButton, spaceBetweenButtons, moveBarButton,
                                spaceBetweenButtons, setThumbnailBarButton, spaceBetweenButtons,
                                deleteBarButton].compactMap { $0 }
//                } else {
//                    self.toolbarItems = @[self.shareBarButton, self.spaceBetweenButtons, self.moveBarButton, self.spaceBetweenButtons, self.favoriteBarButton, self.spaceBetweenButtons, self.setThumbnailBarButton, self.spaceBetweenButtons, self.deleteBarButton];
//                }

                // Present toolbar if needed
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else if NetworkVars.hasNormalRights &&
                    CategoriesData.sharedInstance().getCategoryById(categoryId).hasUploadRights {
                // WRONG =====> 'normal' user with upload access to the current category can edit images
                // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
                navigationItem.rightBarButtonItems = [editBarButton].compactMap { $0 }
                toolbarItems = [shareBarButton, spaceBetweenButtons, moveBarButton].compactMap { $0 }

                // Present toolbar if needed
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            } else {
                // User with no special access rights can only download images
                navigationItem.rightBarButtonItems = [shareBarButton].compactMap { $0 }

                // Hide toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: false)
            }
        } else {
            // iPad in landscape mode: buttons in navigation bar -> Hide toolbar
            isToolbarRequired = false
            navigationController?.setToolbarHidden(true, animated: true)

            if NetworkVars.hasAdminRights {
                // User with admin rights can edit, delete images and set as album image
                deleteBarButton?.tintColor = UIColor.red
                navigationItem.rightBarButtonItems = [editBarButton, deleteBarButton,
                                                      setThumbnailBarButton, moveBarButton,
                                                      shareBarButton].compactMap { $0 }
            }
            else if NetworkVars.hasNormalRights &&
                    CategoriesData.sharedInstance().getCategoryById(categoryId).hasUploadRights {
                // WRONG =====> 'normal' user with upload access to the current category can edit images
                // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
                navigationItem.rightBarButtonItems = [editBarButton, moveBarButton,
                                                      shareBarButton].compactMap { $0 }
            } else {
                // User with no special access rights can only download images
                navigationItem.rightBarButtonItems = [shareBarButton].compactMap { $0 }
            }
        }
    }

    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    func setEnableStateOfButtons(_ state: Bool) {
        editBarButton?.isEnabled = state
        shareBarButton?.isEnabled = state
        moveBarButton?.isEnabled = state
        setThumbnailBarButton?.isEnabled = state
        deleteBarButton?.isEnabled = state
//        favoriteBarButton.enabled = state;
    }

    private func retrieveCompleteImageDataOfImage(_ imageData: PiwigoImageData) {
        debugPrint("=> Retrieve complete image data for image \(imageData.imageId)")

        // Image data is not complete when retrieved using pwg.categories.getImages
        setEnableStateOfButtons(false)

        // Image data is not complete after an upload with pwg.images.upload
        let imageSize = kPiwigoImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize)
        let shouldUpdateImage = (imageData.getURLFromImageSizeType(imageSize) == nil)

        // Retrieve image/video infos
        ImageUtilities.getInfos(forID: imageData.imageId) { [unowned self] retrievedData in
            self.imageData = retrievedData

            DispatchQueue.main.async {
                if let index = self.images.firstIndex(where: { $0.imageId == self.imageData.imageId }) {
                    self.images[index] = self.imageData

                    // Refresh image if needed
                    if shouldUpdateImage {
                        for childVC in self.children {
                            if let previewVC = childVC as? ImagePreviewViewController,
                               previewVC.imageIndex == index {
                                previewVC.imageData = self.imageData
//                                previewVC.setImageScrollViewWith(self.imageData)
                            }
                        }
                    }
                }

                // Enable actions
                self.setEnableStateOfButtons(true)
            }
        } failure: { error in
            self.dismissRetryPiwigoError(withTitle: NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed"), message: NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed\nTry again?"), errorMessage: error.localizedDescription, dismiss: {
            }, retry: { [unowned self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    // Try relogin
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(completion: { [unowned self] in
                        self.retrieveCompleteImageDataOfImage(self.imageData)
                    })
                } else {
                    self.retrieveCompleteImageDataOfImage(self.imageData)
                }
            })
        }
    }


    // MARK: - Image Data Updates
    @objc
    func updateImageFileName(_ notification: Notification?) {
        // Extract notification user info
        if let notification = notification,
           let userInfo = notification.object as? [AnyHashable : Any] {

            // Right image Id?
            if let imageId = userInfo["imageId"] as? Int,
               imageId != imageData.imageId { return }

            // Update image data
            if let fileName = userInfo["fileName"] as? String {
                imageData.fileName = fileName
            }

            // Update title view
            setTitleViewFromImageData()
        }
    }

    
    // MARK: - User Interaction

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc func didTapView() {
        // Should we do something else?
        if imageData.isVideo {
            // User wants to play/replay the video
            let playVideo = ImagePreviewViewController()
            playVideo.startVideoPlayerView(with: imageData)
        }
        else {
            // Display/hide the navigation bar
            let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            navigationController?.setNavigationBarHidden(!isNavigationBarHidden, animated: true)

            // Display/hide home indicator
            if #available(iOS 11, *) {
                // Notify UIKit that this view controller updated its preference regarding the visual indicator
                setNeedsUpdateOfHomeIndicatorAutoHidden()
            }

            // Display/hide the toolbar on iPhone if required
            if isToolbarRequired {
                navigationController?.setToolbarHidden(!isNavigationBarHidden, animated: true)
            }

            // Set background color according to navigation bar visibility
            if navigationController?.isNavigationBarHidden ?? false {
                view.backgroundColor = .black
            } else {
                view.backgroundColor = .clear
            }
        }
    }

    // Display/hide status bar
    override var prefersStatusBarHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    // Display/hide home indicator
    override var prefersHomeIndicatorAutoHidden: Bool {
        return navigationController?.isNavigationBarHidden ?? false
    }

    @objc func didPinchView() {
        // Return to image collection
        navigationController?.popViewController(animated: true)
    }


    // MARK: - Edit, Remove, Delete Image

    @objc func editImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present EditImageDetails view
        let editImageSB = UIStoryboard(name: "EditImageParamsViewController", bundle: nil)
        guard let editImageVC = editImageSB.instantiateViewController(withIdentifier: "EditImageParamsViewController") as? EditImageParamsViewController else { return }
        editImageVC.images = [imageData]
        let albumHasUploadRights = CategoriesData.sharedInstance()
            .getCategoryById(categoryId).hasUploadRights
        editImageVC.hasTagCreationRights = NetworkVars.hasAdminRights ||
                                           (NetworkVars.hasNormalRights && albumHasUploadRights)
        editImageVC.delegate = self
        pushView(editImageVC, forButton: editBarButton)
    }

    @objc func deleteImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        let alert = UIAlertController(title: "",
            message: NSLocalizedString("deleteSingleImage_message", comment: "Are you sure you want to delete this image? This cannot be undone!"),
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })

        let removeAction = UIAlertAction(
            title: NSLocalizedString("removeSingleImage_title", comment: "Remove from Album"),
            style: .default, handler: { [self] action in
                removeImageFromCategory()
            })

        let deleteAction = UIAlertAction(
            title: NSLocalizedString("deleteSingleImage_title", comment: "Delete Image"),
            style: .destructive, handler: { [self] action in
                deleteImageFromDatabase()
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        if (imageData.categoryIds.count > 1) && (categoryId > 0) {
            // This image is used in another album
            // Proposes to remove it from the current album, unless it was selected from a smart album
            alert.addAction(removeAction)
        }

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = deleteBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    func removeImageFromCategory() {
        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("removeSingleImageHUD_removing", comment: "Removing Photo…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Update image category list
        guard var categoryIds = imageData.categoryIds else {
            dismissPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed")) {
                // Hide HUD
                self.hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }
            return
        }
        categoryIds.removeAll { $0 as AnyObject === NSNumber(value: categoryId) as AnyObject }

        // Prepare parameters for uploading image/video (filename key is kPiwigoImagesUploadParamFileName)
        let newImageCategories = categoryIds.compactMap({ $0.stringValue }).joined(separator: ";")
        let paramsDict: [String : Any] = ["image_id"            : imageData.imageId,
                                          "categories"          : newImageCategories,
                                          "multiple_value_mode" : "replace"]
        
        // Send request to Piwigo server
        ImageUtilities.setInfos(with: paramsDict) { [unowned self] in
            // Update image data
            self.imageData.categoryIds = categoryIds

            // Hide HUD
            self.updatePiwigoHUDwithSuccess { [unowned self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [unowned self] in
                    // Remove image from cache and update UI in main thread
                    CategoriesData.sharedInstance()
                        .removeImage(self.imageData, fromCategory: "\(self.categoryId)")
                    // Display preceding/next image or return to album view
                    self.didRemoveImage(withId: self.imageData.imageId)
                }
            }
        } failure: { [unowned self] error in
            self.dismissRetryPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed"), message: NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted"), errorMessage: error.localizedDescription, dismiss: { [unowned self] in
                // Hide HUD
                self.hidePiwigoHUD { [unowned self] in
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            }, retry: { [unowned self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    // Try relogin
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(completion: { [unowned self] in
                        self.removeImageFromCategory()
                    })
                } else {
                    self.removeImageFromCategory()
                }
            })
        }
    }

    func deleteImageFromDatabase() {
        // Display HUD during deletion
        showPiwigoHUD(withTitle: NSLocalizedString("deleteSingleImageHUD_deleting", comment: "Deleting Image…"), detail: "", buttonTitle: "", buttonTarget: nil, buttonSelector: nil, inMode: .indeterminate)

        // Send request to Piwigo server
        ImageUtilities.delete([imageData]) { [unowned self] in
            // Hide HUD
            self.updatePiwigoHUDwithSuccess { [unowned self] in
                self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                    // Display preceding/next image or return to album view
                    self.didRemoveImage(withId: imageData.imageId)
                }
            }
        } failure: { [unowned self] error in
            self.dismissRetryPiwigoError(withTitle: NSLocalizedString("deleteImageFail_title", comment: "Delete Failed"), message: NSLocalizedString("deleteImageFail_message", comment: "Image could not be deleted"), errorMessage: error.localizedDescription, dismiss: { [unowned self] in
                // Hide HUD
                self.updatePiwigoHUDwithSuccess { [unowned self] in
                    self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD) { [self] in
                        // Display preceding/next image or return to album view
                        self.didRemoveImage(withId: imageData.imageId)
                    }
                }
            }, retry: { [unowned self] in
                // Try relogin if unauthorized
                if error.code == 401 {
                    // Try relogin
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(completion: { [unowned self] in
                        self.deleteImageFromDatabase()
                    })
                } else {
                    self.deleteImageFromDatabase()
                }
            })
        }
    }

    
    // MARK: - Share Image

    @objc func shareImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Check autorisation to access Photo Library (camera roll)
        if #available(iOS 14, *) {
            PhotosFetch.shared.checkPhotoLibraryAuthorizationStatus(for: .addOnly, for: self,
                onAccess: { [unowned self] in
                    // User allowed to save image in camera roll
                    presentShareImageViewController(withCameraRollAccess: true)
                },
                onDeniedAccess: { [unowned self] in
                    // User not allowed to save image in camera roll
                    if Thread.isMainThread {
                        presentShareImageViewController(withCameraRollAccess: false)
                    } else {
                        DispatchQueue.main.async(execute: { [self] in
                            presentShareImageViewController(withCameraRollAccess: false)
                        })
                    }
                })
        } else {
            // Fallback on earlier versions
            PhotosFetch.shared.checkPhotoLibraryAccessForViewController(nil,
                onAuthorizedAccess: { [unowned self] in
                    // User allowed to save image in camera roll
                    presentShareImageViewController(withCameraRollAccess: true)
                },
                onDeniedAccess: { [unowned self] in
                    // User not allowed to save image in camera roll
                    if Thread.isMainThread {
                        presentShareImageViewController(withCameraRollAccess: false)
                    } else {
                        DispatchQueue.main.async(execute: { [self] in
                            presentShareImageViewController(withCameraRollAccess: false)
                        })
                    }
                })
        }
    }

    func presentShareImageViewController(withCameraRollAccess hasCameraRollAccess: Bool) {
        // To exclude some activity types
        var excludedActivityTypes = [UIActivity.ActivityType]()

        // Create new activity provider item to pass to the activity view controller
        var itemsToShare: [AnyHashable] = []
        if imageData.isVideo {
            // Case of a video
            let videoItemProvider = ShareVideoActivityItemProvider(placeholderImage: imageData)

            // Use delegation to monitor the progress of the item method
            videoItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(videoItemProvider)

            // Exclude "assign to contact" activity
            excludedActivityTypes.append(.assignToContact)
        }
        else {
            // Case of an image
            let imageItemProvider = ShareImageActivityItemProvider(placeholderImage: imageData)

            // Use delegation to monitor the progress of the item method
            imageItemProvider.delegate = self

            // Add to list of items to share
            itemsToShare.append(imageItemProvider)
        }

        // Create an activity view controller with the activity provider item.
        // ShareImageActivityItemProvider's superclass conforms to the UIActivityItemSource protocol
        let activityViewController = UIActivityViewController(activityItems: itemsToShare,
                                                              applicationActivities: nil)

        // Exclude some activity types if needed
        if !hasCameraRollAccess {
            // Exclude "camera roll" activity when the Photo Library is not accessible
            excludedActivityTypes.append(.saveToCameraRoll)
        }
        activityViewController.excludedActivityTypes = Array(excludedActivityTypes)

        // Delete image/video file and remove observers after dismissing activity view controller
        activityViewController.completionWithItemsHandler = { [self] activityType, completed, returnedItems, activityError in
//            debugPrint("Activity Type selected: \(activityType)")

            // Enable buttons after action
            setEnableStateOfButtons(true)

            // Remove observers
            let name = NSNotification.Name(kPiwigoNotificationDidShare)
            NotificationCenter.default.post(name: name, object: nil)

            if !completed {
                if activityType == nil {
                    debugPrint("User dismissed the view controller without making a selection.");
                } else {
                    debugPrint("Activity was not performed.")
                    // Cancel download task
                    let name = NSNotification.Name(kPiwigoNotificationCancelDownload)
                    NotificationCenter.default.post(name: name, object: nil)
                }
            }
        }

        // Present share image activity view controller
        activityViewController.popoverPresentationController?.barButtonItem = shareBarButton
        present(activityViewController, animated: true)
    }

    @objc func cancelShareImage() {
        // Cancel file donwload
        let name = NSNotification.Name(kPiwigoNotificationCancelDownload)
        NotificationCenter.default.post(name: name, object: nil)
    }

    
    // MARK: - Album Methods

    @objc func setAsAlbumImage() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Present SelectCategory view
        let setThumbSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
        guard let setThumbVC = setThumbSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
        setThumbVC.setInput(parameter:imageData, for: kPiwigoCategorySelectActionSetAlbumThumbnail)
        setThumbVC.delegate = self
        pushView(setThumbVC, forButton: setThumbnailBarButton)
    }

    @objc func addImageToCategory() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // If image selected from Search, immediatley propose to copy it
        if categoryId == kPiwigoSearchCategoryId {
            let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
            guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
            let parameter = [imageData, NSNumber(value: categoryId)]
            copyVC.setInput(parameter: parameter, for: kPiwigoCategorySelectActionCopyImage)
            copyVC.delegate = self // To re-enable toolbar
            copyVC.imageCopiedDelegate = self // To update image data after copy
            pushView(copyVC, forButton: moveBarButton)
            return
        }

        // Image selected from album collection
        let alert = UIAlertController(title: nil, message: nil,
            preferredStyle: .actionSheet)

        let cancelAction = UIAlertAction(
            title: NSLocalizedString("alertCancelButton", comment: "Cancel"),
            style: .cancel, handler: { [self] action in
                // Re-enable buttons
                setEnableStateOfButtons(true)
            })

        let copyAction = UIAlertAction(
            title: NSLocalizedString("copyImage_title", comment: "Copy to Album"),
            style: .default, handler: { [self] action in
                let copySB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let copyVC = copySB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
                let parameter = [imageData, NSNumber(value: categoryId)]
                copyVC.setInput(parameter: parameter, for: kPiwigoCategorySelectActionCopyImage)
                copyVC.delegate = self // To re-enable toolbar
                copyVC.imageCopiedDelegate = self // To update image data after copy
                pushView(copyVC, forButton: moveBarButton)
            })

        let moveAction = UIAlertAction(
            title: NSLocalizedString("moveImage_title", comment: "Move to Album"),
            style: .default, handler: { [self] action in
                let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
                guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController else { return }
                let parameter = [imageData, NSNumber(value: categoryId)]
                moveVC.setInput(parameter: parameter, for: kPiwigoCategorySelectActionMoveImage)
                moveVC.delegate = self // To re-enable toolbar
                moveVC.imageRemovedDelegate = self // To remove image after move
                pushView(moveVC, forButton: moveBarButton)
            })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(copyAction)
        alert.addAction(moveAction)

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = moveBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    
    // MARK: - (Add to) / (remove from) favorites

    func addToFavoritesImageWithId() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Send request to Piwigo server
//        ImageService.addToFavoritesImage(
//            withId: imageData.imageId,
//            onProgress: nil,
//            onCompletion: { [self] task, addedSuccessfully in
//                // Enable buttons during action
//                setEnableStateOfButtons(true)
//            },
//            onFailure: { [self] task, error in
//                // Enable buttons during action
//                setEnableStateOfButtons(true)
//            })
    }

    func removeImageFromFavorites() {
        // Disable buttons during action
        setEnableStateOfButtons(false)

        // Send request to Piwigo server
//        ImageService.removeImage(
//            fromFavorites: imageData,
//            onProgress: nil,
//            onCompletion: { [self] task, removedSuccessfully in
//                // Enable buttons during action
//                setEnableStateOfButtons(true)
//            },
//            onFailure: { [self] task, error in
//                // Enable buttons during action
//                setEnableStateOfButtons(true)
//            })
    }

    
    // MARK: - Push Views

    private func pushView(_ viewController: UIViewController?, forButton button: UIBarButtonItem?) {
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            if let vc = viewController as? SelectCategoryViewController {
                vc.modalPresentationStyle = .popover
                vc.popoverPresentationController?.barButtonItem = button
                    navigationController?.present(vc, animated: true)
            }
            else if let vc = viewController as? EditImageParamsViewController {
                // Push Edit view embedded in navigation controller
                let navController = UINavigationController(rootViewController: vc)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.barButtonItem = button
                navigationController?.present(navController, animated: true)
            } else {
                fatalError("!!! Unknown View Conntroller !!!")
            }
        } else {
            if let viewController = viewController {
                let navController = UINavigationController(rootViewController: viewController)
                navController.modalPresentationStyle = .popover
                navController.popoverPresentationController?.sourceView = view
                navController.modalTransitionStyle = .coverVertical
                present(navController, animated: true)
            }
        }
    }
}

// MARK: - UIPageViewControllerDelegate
extension ImageDetailViewController: UIPageViewControllerDelegate
{
    // Called before a gesture-driven transition begins
    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {

        // Retrieve complete image data if needed
        for pendingVC in pendingViewControllers {
            if let previewVC = pendingVC as? ImagePreviewViewController,
               previewVC.imageIndex < images.count {
                let imageData = images[previewVC.imageIndex]
                if imageData.fileSize == NSNotFound {
                    // Retrieve image data in case user will want to copy,
                    // edit, move, etc. the image
                    retrieveCompleteImageDataOfImage(imageData)
                }
            }
        }
    }

    // Called after a gesture-driven transition completes
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {

        guard let pvc = pageViewController.viewControllers?.first as? ImagePreviewViewController else {
            fatalError("!!! Wrong View Controller Type !!!")
        }
        var currentIndex = pvc.imageIndex
        // To prevent crash reported by AppStore here on August 26th, 2017
        currentIndex = max(0, currentIndex)
        // To prevent crash reported by AppleStore in November 2017
        currentIndex = min(currentIndex, images.count - 1)

        pvc.imagePreviewDelegate = self
        progressBar.isHidden = pvc.imageLoaded || imageData.isVideo
        imageData = images[currentIndex]
        setTitleViewFromImageData()

        // Scroll album collection view to keep the selected image centered on the screen
        if imgDetailDelegate?.responds(to: #selector(ImageDetailDelegate.didSelectImage(withId:))) ?? false {
            imgDetailDelegate?.didSelectImage(withId: imageData.imageId)
        }
    }
}


// MARK: - UIPageViewControllerDataSource
extension ImageDetailViewController: UIPageViewControllerDataSource
{
    // Returns the view controller after the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let pvc = pageViewController.viewControllers?.first as? ImagePreviewViewController else {
            fatalError("!!! Wrong View Controller Type !!!")
        }
        let currentIndex = pvc.imageIndex
        if (currentIndex >= images.count - 1) {
            // Reached the end of the category
            return nil
        }

        // Should we load more images?
        let imagesPerPage = Float(ImagesCollection.numberOfImagesPerPage(for: view, imagesPerRowInPortrait: AlbumVars.thumbnailsPerRowInPortrait))
        if (currentIndex > (images.count - Int(roundf(imagesPerPage / 3.0)))) &&
            (images.count != CategoriesData.sharedInstance().getCategoryById(categoryId).numberOfImages) {
            if imgDetailDelegate?.responds(to: #selector(ImageDetailDelegate.needToLoadMoreImages)) ?? false {
                imgDetailDelegate?.needToLoadMoreImages()
            }
        }

        // Retrieve data of next image (may be incomplete)
        let imageData = images[currentIndex + 1]

        // Create view controller for presenting next image
        debugPrint("=> Create preview view controller for next image \(imageData.imageId)")
        guard let nextImage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return nil }
        nextImage.imagePreviewDelegate = self
        nextImage.imageIndex = currentIndex + 1
        nextImage.imageData = imageData
        nextImage.imageLoaded = false
        return nextImage
//        let nextImage = ImagePreviewViewController()
//        nextImage.imageLoaded = false
//        nextImage.imageIndex = currentIndex + 1
//        nextImage.setImageScrollViewWith(imageData)
    }

    // Returns the view controller before the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let pvc = pageViewController.viewControllers?.first as? ImagePreviewViewController else {
            fatalError("!!! Wrong View Controller Type !!!")
        }
        let currentIndex = pvc.imageIndex
        if currentIndex - 1 < 0 {
            // Reached the beginning the category
            return nil
        }

        // Retrieve data of previous image (may be incomplete)
        let imageData = images[currentIndex - 1]

        // Create view controller
        debugPrint("=> Create preview view controller for previous image \(imageData.imageId)")
        guard let prevImage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return nil }
        prevImage.imagePreviewDelegate = self
        prevImage.imageIndex = currentIndex - 1
        prevImage.imageData = imageData
        prevImage.imageLoaded = false
        return prevImage
//        let prevImage = ImagePreviewViewController()
//        prevImage.imageLoaded = false
//        prevImage.imageIndex = currentIndex - 1
//        prevImage.setImageScrollViewWith(imageData)
//        return prevImage
    }

    // Returns the index of the selected item to be reflected in the page indicator
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        if let imageViewCtrl = pageViewController.viewControllers?[0] as? ImagePreviewViewController {
            // Return if exists
            return imageViewCtrl.imageIndex
        }
        return NSNotFound
    }
}


// MARK: - ImagePreviewDelegate Methods
extension ImageDetailViewController: ImagePreviewDelegate
{
    func downloadProgress(_ progress: CGFloat) {
        if (progress < 1.0) {
            progressBar.setProgress(Float(progress), animated: true)
        } else {
            progressBar.isHidden = true
        }
    }
}


// MARK: - EditImageParamsDelegate Methods
extension ImageDetailViewController: EditImageParamsDelegate
{
    func didDeselectImage(withId imageId: Int) {
        // Should never be called when the properties of a single image are edited
    }

    func didRenameFileOfImage(_ imageData: PiwigoImageData) {
        // Update image data
        if let fileName = imageData.fileName {
            self.imageData.fileName = fileName
        }

        // Update title view
        setTitleViewFromImageData()
    }

    func didChangeParamsOfImage(_ params: PiwigoImageData) {
        // Determine index of updated image
        if let indexOfUpdatedImage = images.firstIndex(where: { $0.imageId == params.imageId }) {
            // Update list and currently viewed image
            images[indexOfUpdatedImage] = params
            imageData = params

            // Update current view
            setTitleViewFromImageData()
        }
    }

    func didFinishEditingParameters() {
        // Enable buttons after action
        setEnableStateOfButtons(true)

        // Reload tab bar
        updateNavBar()
    }
}


// MARK: - SelectCategoryDelegate Methods
extension ImageDetailViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int) {
        setEnableStateOfButtons(true)
    }
}


// MARK: - SelectCategoryOfImageDelegate Methods
extension ImageDetailViewController: SelectCategoryImageCopiedDelegate
{
    func didCopyImage(withData imageData: PiwigoImageData) {
        // Update image data
        self.imageData = imageData

        // Re-enable buttons
        setEnableStateOfButtons(true)
    }
}


// MARK: - SelectCategoryImageRemovedDelegate Methods
extension ImageDetailViewController: SelectCategoryImageRemovedDelegate
{
    func didRemoveImage(withId imageID: Int) {
        // Determine index of the removed image
        guard let indexOfRemovedImage = images.firstIndex(where: { $0.imageId == imageID }) else { return }

        // Remove the image from the datasource
        images.remove(at: indexOfRemovedImage)

        // Return to the album view if the album is empty
        // or if we could not find the index of the removed image
        if images.isEmpty {
            // Return to the Album/Images collection view
            navigationController?.popViewController(animated: true)
            return
        }

        // Can we present the next image?
        if indexOfRemovedImage < images.count {
            // Retrieve data of next image (may be incomplete)
            let imageData = images[indexOfRemovedImage]

            // Create view controller for presenting next image
            guard let nextImage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return }
            nextImage.imagePreviewDelegate = self
            nextImage.imageIndex = indexOfRemovedImage
            nextImage.imageData = imageData
            nextImage.imageLoaded = false
//            let nextImage = ImagePreviewViewController()
//            nextImage.imageLoaded = false
//            nextImage.imageIndex = indexOfRemovedImage
//            nextImage.setImageScrollViewWith(imageData)

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers([nextImage], direction: .forward, animated: true) { [unowned self] finished in
                    // Update image data
                    self.imageData = self.images[indexOfRemovedImage]
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            return
        }

        // Can we present the preceding image?
        if indexOfRemovedImage > 0 {
            // Retrieve data of next image (may be incomplete)
            let imageData = images[indexOfRemovedImage - 1]

            // Create view controller for presenting next image
            guard let prevImage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return }
            prevImage.imagePreviewDelegate = self
            prevImage.imageIndex = indexOfRemovedImage - 1
            prevImage.imageData = imageData
            prevImage.imageLoaded = false
//            let prevImage = ImagePreviewViewController()
//            prevImage.imageLoaded = false
//            prevImage.imageIndex = indexOfRemovedImage - 1
//            prevImage.setImageScrollViewWith(imageData)

            // This changes the View Controller
            // and calls the presentationIndexForPageViewController datasource method
            pageViewController!.setViewControllers( [prevImage], direction: .reverse, animated: true) { [unowned self] finished in
                    // Update image data
                    self.imageData = self.images[indexOfRemovedImage - 1]
                    // Re-enable buttons
                    self.setEnableStateOfButtons(true)
                }
            return
        }
    }
}


// MARK: - ShareImageActivityItemProviderDelegate Methods
extension ImageDetailViewController: ShareImageActivityItemProviderDelegate
{
    func imageActivityItemProviderPreprocessingDidBegin(_ imageActivityItemProvider: UIActivityItemProvider?, withTitle title: String?) {
        guard let title = title else { return }
        // Show HUD to let the user know the image is being downloaded in the background.
        presentedViewController?.showPiwigoHUD(withTitle: title, detail: "", buttonTitle: NSLocalizedString("alertCancelButton", comment: "Cancel"), buttonTarget: self, buttonSelector: #selector(cancelShareImage), inMode: .annularDeterminate)
    }

    func imageActivityItemProvider(_ imageActivityItemProvider: UIActivityItemProvider?, preprocessingProgressDidUpdate progress: Float) {
        // Update HUD
        presentedViewController?.updatePiwigoHUD(withProgress: progress)
    }

    func imageActivityItemProviderPreprocessingDidEnd(_ imageActivityItemProvider: UIActivityItemProvider?, withImageId imageId: Int) {
        // Close HUD
        if imageActivityItemProvider?.isCancelled ?? false {
            presentedViewController?.hidePiwigoHUD(completion: {
            })
        } else {
            presentedViewController?.updatePiwigoHUDwithSuccess(completion: { [self] in
                presentedViewController?.hidePiwigoHUD(completion: {
                })
            })
        }
    }

    func showError(withTitle title: String?, andMessage message: String?) {
        guard let title = title, let message = message else { return }
        // Display error alert after trying to share image
        presentedViewController?.dismissPiwigoError(withTitle: title, message: message, errorMessage: "") { [unowned self] in
            // Closes ActivityView
            presentedViewController?.dismiss(animated: true)
        }
    }
}
