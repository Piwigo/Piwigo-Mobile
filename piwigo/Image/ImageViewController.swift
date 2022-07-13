//
//  ImageViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit

@objc protocol ImageDetailDelegate: NSObjectProtocol {
    func didSelectImage(withId imageId: Int)
    func didUpdateImage(withData imageData: PiwigoImageData)
    func needToLoadMoreImages()
}

@objc class ImageViewController: UIViewController {
    
    @objc weak var imgDetailDelegate: ImageDetailDelegate?
    @objc var images = [PiwigoImageData]()
    @objc var categoryId = 0
    @objc var imageIndex = 0
    
    var imageData = PiwigoImageData()
    private var progressBar = UIProgressView()
    var isToolbarRequired = false
    var pageViewController: UIPageViewController?
    lazy var userHasUploadRights = false

    
    // MARK: - Navigation Bar & Toolbar Buttons
    var actionBarButton: UIBarButtonItem?               // iPhone & iPad until iOS 13:
                                                        // - for editing image properties
                                                        // iPhone & iPad as from iOS 14:
                                                        // - for copying or moving images to other albums
                                                        // - for setting the image as album thumbnail
                                                        // - for editing image properties
    var favoriteBarButton: UIBarButtonItem?
    var shareBarButton: UIBarButtonItem?
    var setThumbnailBarButton: UIBarButtonItem?
    var moveBarButton: UIBarButtonItem?
    var deleteBarButton: UIBarButtonItem?
    
    
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
        // Current image
        var index = max(0, imageIndex)
        index = min(imageIndex, images.count - 1)
        imageData = images[index]

        // Initialise pageViewController
        pageViewController = children[0] as? UIPageViewController
        pageViewController!.delegate = self
        pageViewController!.dataSource = self

        // Initialise flags
        userHasUploadRights = CategoriesData.sharedInstance().getCategoryById(categoryId)?.hasUploadRights ?? false

        // Load initial image preview view controller
        if let startingImage = imagePageViewController(atIndex: index) {
            startingImage.imagePreviewDelegate = self
            pageViewController!.setViewControllers( [startingImage], direction: .forward, animated: false)
        }
        
        // Did we already load the list of favorite images?
        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending,
           !NetworkVars.hasGuestRights,
           CategoriesData.sharedInstance().getCategoryById(kPiwigoFavoritesCategoryId) == nil {
            // Show HUD during the download
            showPiwigoHUD(withTitle: NSLocalizedString("loadingHUD_label", comment:"Loading…"), inMode: .annularDeterminate)
            
            // Unknown list -> initialise album and download list
            let nberImagesPerPage = AlbumUtilities.numberOfImagesToDownloadPerPage()
            let favoritesAlbum: PiwigoAlbumData = PiwigoAlbumData(id: kPiwigoFavoritesCategoryId, andQuery: "")
            CategoriesData.sharedInstance().updateCategories([favoritesAlbum])
            CategoriesData.sharedInstance()
                .getCategoryById(kPiwigoFavoritesCategoryId)
                .loadAllCategoryImageData(withSort: kPiwigoSortObjc(UInt32(AlbumVars.shared.defaultSort)),
                                          forProgress: { [unowned self] onPage, outOf in
                    let fraction = Float(onPage) * Float(nberImagesPerPage) / Float(outOf)
                    self.updatePiwigoHUD(withProgress: fraction)
                }) { [unowned self] _ in
                    // Retrieve complete image data if needed (buttons are greyed until job done)
                    if self.imageData.fileSize == NSNotFound {
                        self.retrieveCompleteImageDataOfImage(self.imageData)
                    } else {
                        hidePiwigoHUD { [unowned self] in
                            let isFavorite = CategoriesData.sharedInstance()
                                .category(withId: kPiwigoFavoritesCategoryId, containsImagesWithId: [NSNumber(value: imageData.imageId)])
                            self.favoriteBarButton?.setFavoriteImage(for: isFavorite)
                        }
                    }
                } onFailure: { _, _ in }
        } else {
            // Retrieve complete image data if needed (buttons are greyed until job done)
            if imageData.fileSize == NSNotFound {
                retrieveCompleteImageDataOfImage(imageData)
            }
        }

        // Navigation bar
        let navigationBar = navigationController?.navigationBar
        navigationBar?.tintColor = .piwigoColorOrange()
        
        // Toolbar
        let toolbar = navigationController?.toolbar
        toolbar?.tintColor = .piwigoColorOrange()

        // Single taps display/hide the navigation bar, toolbar and description
        // Double taps zoom in/out the image
        let tapOnce = UITapGestureRecognizer(target: self, action: #selector(didTapOnce))
        let tapTwice = UITapGestureRecognizer(target: self, action: #selector(didTapTwice(_:)))
        tapOnce.numberOfTapsRequired = 1
        tapTwice.numberOfTapsRequired = 2
        tapOnce.require(toFail: tapTwice)
        view.addGestureRecognizer(tapOnce)
        view.addGestureRecognizer(tapTwice)

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
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
        navigationBar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default

        // Toolbar
        let toolbar = navigationController?.toolbar
        toolbar?.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default

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
            barAppearance.shadowColor = AppVars.shared.isDarkPaletteActive ? .init(white: 1.0, alpha: 0.15) : .init(white: 0.0, alpha: 0.3)
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

        // Set colors, fonts, etc.
        applyColorPalette()

        // Image options buttons
        updateNavBar()

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
        coordinator.animate(alongsideTransition: { [self] context in
            // Update image detail view
            updateNavBar()
            setTitleViewFromImageData()
            // Update image preview view
            if let pVC = pageViewController,
               let imagePVC = pVC.viewControllers?.first as? ImagePreviewViewController {
                imagePVC.didRotateDevice()
            }
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Should we update user interface based on the appearance?
        if #available(iOS 13.0, *) {
            let isSystemDarkModeActive = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            if AppVars.shared.isSystemDarkModeActive != isSystemDarkModeActive {
                AppVars.shared.isSystemDarkModeActive = isSystemDarkModeActive
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.screenBrightnessChanged()
            }
        }
    }

    deinit {
        debugPrint("••> ImageViewController of image \(imageData.imageId) is being deinitialized.")
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }


    // MARK: - Navigation Bar & Toolbar
    func setTitleViewFromImageData() {
        // Create label programmatically
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = .piwigoColorWhiteCream()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.piwigoFontSmallSemiBold()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.allowsDefaultTighteningForTruncation = true
        if let title = imageData.imageTitle, title.isEmpty == false {
            titleLabel.text = title
        } else {
            // No title => Use file name
            titleLabel.text = imageData.fileName
        }
        titleLabel.sizeToFit()

        // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            (UIApplication.shared.statusBarOrientation.isLandscape)) ||
            (imageData.dateCreated == imageData.datePosted) {
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width * 0.4))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            navigationItem.titleView = oneLineTitleView

            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
        }
        else {
            let subTitleLabel = UILabel(frame: CGRect(x: 0.0, y: titleLabel.frame.size.height, width: 0, height: 0))
            subTitleLabel.backgroundColor = UIColor.clear
            subTitleLabel.textColor = .piwigoColorWhiteCream()
            subTitleLabel.textAlignment = .center
            subTitleLabel.numberOfLines = 1
            subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            subTitleLabel.font = .piwigoFontTiny()
            subTitleLabel.adjustsFontSizeToFitWidth = false
            subTitleLabel.lineBreakMode = .byTruncatingTail
            subTitleLabel.allowsDefaultTighteningForTruncation = true
            if let dateCreated = imageData.dateCreated {
                subTitleLabel.text = DateFormatter.localizedString(from: dateCreated,
                                                                   dateStyle: .medium, timeStyle: .medium)
            }
            subTitleLabel.sizeToFit()

            var titleWidth = CGFloat(fmax(subTitleLabel.bounds.size.width, titleLabel.bounds.size.width))
            titleWidth = fmin(titleWidth, (navigationController?.view.bounds.size.width ?? 0.0) * 0.4)
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
        // Button displayed in all circumstances
        shareBarButton = UIBarButtonItem.shareImageButton(self, action: #selector(ImageViewController.shareImage))

        if #available(iOS 14, *) {
            // Interface depends on device and orientation
            let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
            
            // User with admin or upload rights can do everything
            if NetworkVars.hasAdminRights ||
                (NetworkVars.hasNormalRights && userHasUploadRights) {
                // The action button proposes:
                /// - to copy or move images to other albums
                /// - to set the image as album thumbnail
                /// - to edit image parameters,
                let menu = UIMenu(title: "", children: [albumMenu(), editMenu()].compactMap({$0}))
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
                actionBarButton?.accessibilityIdentifier = "actions"
                deleteBarButton = UIBarButtonItem.deleteImageButton(self, action: #selector(deleteImage))
                
                if orientation.isPortrait, view.bounds.size.width < 768 {
                    // Action button in navigation bar
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }

                    // Remaining buttons in navigation toolbar
                    var toolBarItems = [shareBarButton, UIBarButtonItem.space(), deleteBarButton]
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        toolBarItems.insert(contentsOf: [favoriteBarButton, UIBarButtonItem.space()], at: 2)
                    }
                    isToolbarRequired = true
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    setToolbarItems(toolBarItems.compactMap { $0 }, animated: false)
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                }
                else {
                    // All buttons in the navigation bar
                    var rightBarButtonItems = [actionBarButton, deleteBarButton, shareBarButton]
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        rightBarButtonItems.insert(contentsOf: [favoriteBarButton], at: 2)
                    }
                    navigationItem.setRightBarButtonItems(rightBarButtonItems.compactMap { $0 }, animated: true)

                    // No toolbar
                    isToolbarRequired = false
                    setToolbarItems([], animated: false)
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            }
            else if !NetworkVars.hasGuestRights,
                    "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                favoriteBarButton = getFavoriteBarButton()

                if orientation.isPortrait, UIDevice.current.userInterfaceIdiom == .phone {
                    // No button on the right
                    navigationItem.rightBarButtonItems = []

                    // Remaining buttons in navigation toolbar
                    isToolbarRequired = true
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    setToolbarItems([shareBarButton, UIBarButtonItem.space(),
                                     favoriteBarButton].compactMap { $0 }, animated: false)
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                }
                else {
                    // All buttons in navigation bar
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    isToolbarRequired = false
                    navigationController?.setToolbarHidden(true, animated: false)
                }
            } else {
                // Guest can only share images
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)
                
                // Hide navigation toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: false)
            }
        }
        else {
            // Fallback on earlier versions
            // Interface depends on device and orientation
            let orientation = UIApplication.shared.statusBarOrientation
            
            // User with admin rights can do everything
            if NetworkVars.hasAdminRights {
                // Navigation bar
                // The action menu is simply an Edit button
                actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                                  target: self, action: #selector(editImage))
                actionBarButton?.accessibilityIdentifier = "edit"
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }

                // Navigation toolbar
                deleteBarButton = UIBarButtonItem.deleteImageButton(self, action: #selector(deleteImage))
                moveBarButton = UIBarButtonItem.moveImageButton(self, action: #selector(addImageToCategory))
                setThumbnailBarButton = UIBarButtonItem.setThumbnailButton(self, action: #selector(setAsAlbumImage))
                var toolBarItems = [shareBarButton, UIBarButtonItem.space(), moveBarButton,
                                    UIBarButtonItem.space(), setThumbnailBarButton,
                                    UIBarButtonItem.space(), deleteBarButton].compactMap { $0 }
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    favoriteBarButton = getFavoriteBarButton()
                    toolBarItems.insert(contentsOf: [favoriteBarButton, UIBarButtonItem.space()].compactMap { $0 }, at: 4)
                }
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else if NetworkVars.hasNormalRights && userHasUploadRights {
                // WRONG =====> 'normal' user with upload access to the current category can edit images
                // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
                // Navigation bar
                // The action menu is simply an Edit button
                actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                                  target: self, action: #selector(editImage))
                actionBarButton?.accessibilityIdentifier = "edit"
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }

                // Navigation toolbar
                deleteBarButton = UIBarButtonItem.deleteImageButton(self, action: #selector(deleteImage))
                moveBarButton = UIBarButtonItem.moveImageButton(self, action: #selector(addImageToCategory))
                var toolBarItems = [shareBarButton, UIBarButtonItem.space(), moveBarButton].compactMap { $0 }
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    favoriteBarButton = getFavoriteBarButton()
                    toolBarItems.insert(contentsOf: [favoriteBarButton, UIBarButtonItem.space()].compactMap { $0 }, at: 2)
                }
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else if !NetworkVars.hasGuestRights,
                    "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                favoriteBarButton = getFavoriteBarButton()

                if orientation.isPortrait {
                    // No button on the right
                    navigationItem.rightBarButtonItems = []

                    // Remaining buttons in navigation toolbar
                    isToolbarRequired = true
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    setToolbarItems([shareBarButton, UIBarButtonItem.space(),
                                     favoriteBarButton].compactMap { $0 }, animated: false)
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                } else {
                    navigationItem.setRightBarButtonItems([favoriteBarButton, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    isToolbarRequired = false
                    navigationController?.setToolbarHidden(true, animated: false)
                }
            } else {
                // Guest can only share images
                navigationItem.setRightBarButtonItems([shareBarButton].compactMap { $0 }, animated: true)

                // Hide navigation toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: false)
            }
        }
    }
    
    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    func setEnableStateOfButtons(_ state: Bool) {
        actionBarButton?.isEnabled = state
        shareBarButton?.isEnabled = state
        moveBarButton?.isEnabled = state
        setThumbnailBarButton?.isEnabled = state
        deleteBarButton?.isEnabled = state
        favoriteBarButton?.isEnabled = state
    }

    private func retrieveCompleteImageDataOfImage(_ imageData: PiwigoImageData) {
        // Image data is not complete when retrieved using pwg.categories.getImages
        setEnableStateOfButtons(false)

        // Image data is not complete after an upload with pwg.images.upload
        let imageSize = kPiwigoImageSize(rawValue: ImageVars.shared.defaultImagePreviewSize)
        let shouldUpdateImage = (imageData.getURLFromImageSizeType(imageSize) == nil)

        // Retrieve image/video infos
        DispatchQueue.global(qos: .userInteractive).async {
            ImageUtilities.getInfos(forID: imageData.imageId,
                                    inCategoryId: self.categoryId) { [unowned self] retrievedData in
                self.imageData = retrievedData
                // Disable HUD if needed
                self.hidePiwigoHUD {
                    if let index = self.images.firstIndex(where: { $0.imageId == self.imageData.imageId }) {
                        self.images[index] = self.imageData
                        
                        // Set favorite button
                        let isFavorite = CategoriesData.sharedInstance()
                            .category(withId: kPiwigoFavoritesCategoryId,
                                      containsImagesWithId: [NSNumber(value: imageData.imageId)])
                        self.favoriteBarButton?.setFavoriteImage(for: isFavorite)

                        // Refresh image if needed
                        if shouldUpdateImage {
                            for childVC in self.children {
                                if let previewVC = childVC as? ImagePreviewViewController,
                                   previewVC.imageIndex == index {
                                    previewVC.imageData = self.imageData
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
                    // Try relogin
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.reloginAndRetry(afterRestoringScene: false) { [unowned self] in
                        self.retrieveCompleteImageDataOfImage(self.imageData)
                    }
                })
            }
        }
    }

    
    // MARK: - User Interaction
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc func didTapOnce() {
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
            
            // Display/hide the description if any
            if let pVC = pageViewController,
               let imagePVC = pVC.viewControllers?.first as? ImagePreviewViewController {
                imagePVC.didTapOnce()
            }

            // Set background color according to navigation bar visibility
            if navigationController?.isNavigationBarHidden ?? false {
                view.backgroundColor = .black
            } else {
                view.backgroundColor = .clear
            }
        }
    }
    
    @objc func didTapTwice(_ gestureRecognizer: UIGestureRecognizer) {
        // Should we do something else?
        if imageData.isVideo { return }

        // Zoom in/out the image if necessary
        if let pVC = pageViewController,
           let imagePVC = pVC.viewControllers?.first as? ImagePreviewViewController {
            imagePVC.didTapTwice(gestureRecognizer)
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

    
    // MARK: - Push Views
    func pushView(_ viewController: UIViewController?, forButton button: UIBarButtonItem?) {
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
extension ImageViewController: UIPageViewControllerDelegate
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
        // Remember index of presented page
        imageIndex = currentIndex
        imageData = images[currentIndex]

        pvc.imagePreviewDelegate = self
        progressBar.isHidden = pvc.imageLoaded || imageData.isVideo
        setTitleViewFromImageData()
        updateNavBar()

        // Scroll album collection view to keep the selected image centered on the screen
        if imgDetailDelegate?.responds(to: #selector(ImageDetailDelegate.didSelectImage(withId:))) ?? false {
            imgDetailDelegate?.didSelectImage(withId: imageData.imageId)
        }
    }
}


// MARK: - UIPageViewControllerDataSource
extension ImageViewController: UIPageViewControllerDataSource
{
    // Create view controller for presenting the image at the provided index
    func imagePageViewController(atIndex index:Int) -> ImagePreviewViewController? {
        guard let imagePage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return nil }
        imagePage.imageIndex = index
        imagePage.imageData = images[index]
        imagePage.imageLoaded = false
        return imagePage
    }
    
    // Returns the view controller after the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if (imageIndex >= images.count - 1) {
            // Reached the end of the category
            return nil
        }

        // Should we load more images?
        let albumData = CategoriesData.sharedInstance().getCategoryById(categoryId)
        let totalImageCount = albumData?.numberOfImages ?? 0
        let downloadedImageCount = albumData?.imageList?.count ?? 0
        if totalImageCount > 0, downloadedImageCount < totalImageCount,
           imgDetailDelegate?.responds(to: #selector(ImageDetailDelegate.needToLoadMoreImages)) ?? false {
                imgDetailDelegate?.needToLoadMoreImages()
        }

        // Create view controller for presenting next image
        return imagePageViewController(atIndex: imageIndex + 1)
    }

    // Returns the view controller before the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if imageIndex - 1 < 0 {
            // Reached the beginning the category
            return nil
        }

        // Create view controller
        return imagePageViewController(atIndex: imageIndex - 1)
    }
}


// MARK: - ImagePreviewDelegate Methods
extension ImageViewController: ImagePreviewDelegate
{
    func downloadProgress(_ progress: CGFloat) {
        if (progress < 1.0) {
            progressBar.setProgress(Float(progress), animated: true)
        } else {
            progressBar.isHidden = true
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension ImageViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int) {
        setEnableStateOfButtons(true)
    }
}
