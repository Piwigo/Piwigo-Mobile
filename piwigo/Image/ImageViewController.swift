//
//  ImageViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/09/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit

protocol ImageDetailDelegate: NSObjectProtocol {
    func didSelectImage(atIndex imageIndex: Int)
}

class ImageViewController: UIViewController {
    
    weak var imgDetailDelegate: ImageDetailDelegate?
    var images: NSFetchedResultsController<Image>!
    var categoryId = Int32.zero
    var imageIndex = 0
    var userHasUploadRights = false
    var imageData: Image!
    var isToolbarRequired = false
    var didPresentPageAfter = true
    var pageViewController: UIPageViewController?

    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    
    // MARK: - Core Data Providers
    lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()
    
    private lazy var imageProvider: ImageProvider = {
        let provider : ImageProvider = ImageProvider.shared
        return provider
    }()

    
    // MARK: - Navigation Bar & Toolbar Buttons
    var actionBarButton: UIBarButtonItem?               // iPhone & iPad until iOS 13:
                                                        // - for editing image properties
                                                        // iPhone & iPad as from iOS 14:
                                                        // - for copying or moving images to other albums
                                                        // - for setting the image as album thumbnail
                                                        // - for editing image properties
    var favoriteBarButton: UIBarButtonItem?
    lazy var shareBarButton: UIBarButtonItem = getShareButton()
    lazy var setThumbnailBarButton: UIBarButtonItem = getSetThumbnailBarButton()
    lazy var moveBarButton: UIBarButtonItem = getMoveBarButton()
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Current image
        var index = max(0, imageIndex)
        index = min(imageIndex, (images.fetchedObjects?.count ?? 0) - 1)
        imageData = images.object(at: IndexPath(item: index, section: 0))
        if imageData.isFault {
            // imageData is not fired yet.
            imageData.willAccessValue(forKey: nil)
            imageData.didAccessValue(forKey: nil)
        }

        // Initialise pageViewController
        pageViewController = children[0] as? UIPageViewController
        pageViewController!.delegate = self
        pageViewController!.dataSource = self

        // Load initial image preview view controller
        if let startingImage = imagePageViewController(atIndex: index) {
            pageViewController!.setViewControllers( [startingImage], direction: .forward, animated: false)
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
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationBar?.titleTextAttributes = attributes
        setTitleViewFromImageData()
        navigationBar?.prefersLargeTitles = false

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
        setEnableStateOfButtons(imageData.fileSize != Int64.zero)
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
        print("••> ImageViewController is being deinitialized.")
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
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.allowsDefaultTighteningForTruncation = true
        if imageData.title.string.isEmpty == false {
            let wholeRange = NSRange(location: 0, length: imageData.title.string.count)
            let style = NSMutableParagraphStyle()
            style.alignment = NSTextAlignment.center
            let attributes = [
                NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                NSAttributedString.Key.paragraphStyle: style
            ]
            let attTitle = NSMutableAttributedString(attributedString: imageData.title)
            attTitle.addAttributes(attributes, range: wholeRange)
            titleLabel.attributedText = attTitle
        } else {
            // No title => Use file name
            titleLabel.text = imageData.fileName
        }
        titleLabel.sizeToFit()

        // Check that dates are accessible
        /// Will see if it fixes crash '#0    (null) in static Date._unconditionallyBridgeFromObjectiveC(_:) ()'
        var dateCondition = false
        let dateCreated: Date? = imageData.dateCreated
        let datePosted: Date? = imageData.datePosted
        if dateCreated != nil, datePosted != nil, dateCreated != datePosted {
            dateCondition = true
        }

        // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            (UIApplication.shared.statusBarOrientation.isLandscape)) ||
            dateCondition == false {
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
            subTitleLabel.font = .systemFont(ofSize: 10)
            subTitleLabel.adjustsFontSizeToFitWidth = false
            subTitleLabel.lineBreakMode = .byTruncatingTail
            subTitleLabel.allowsDefaultTighteningForTruncation = true
            subTitleLabel.text = DateFormatter.localizedString(from: imageData.dateCreated,
                                                               dateStyle: .medium, timeStyle: .medium)
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
        if #available(iOS 14, *) {
            // Interface depends on device and orientation
            let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
            
            // User with admin or upload rights can do everything
            if NetworkVars.hasAdminRights || userHasUploadRights {
                // The action button proposes:
                /// - to copy or move images to other albums
                /// - to set the image as album thumbnail
                /// - to edit image parameters,
                let menu = UIMenu(title: "", children: [albumMenu(), editMenu()].compactMap({$0}))
                actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
                actionBarButton?.accessibilityIdentifier = "actions"
                
                if orientation.isPortrait, view.bounds.size.width < 768 {
                    // Action button in navigation bar
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }

                    // Remaining buttons in navigation toolbar
                    var toolBarItems = [shareBarButton, UIBarButtonItem.space(), deleteBarButton]
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                        favoriteBarButton = getFavoriteBarButton()
                        toolBarItems.insert(contentsOf: [favoriteBarButton!, UIBarButtonItem.space()], at: 2)
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
                        rightBarButtonItems.insert(contentsOf: [favoriteBarButton!], at: 2)
                    }
                    navigationItem.setRightBarButtonItems(rightBarButtonItems.compactMap { $0 }, animated: true)

                    // No toolbar
                    isToolbarRequired = false
                    setToolbarItems([], animated: false)
                    navigationController?.setToolbarHidden(true, animated: true)
                }
            }
            else if NetworkVars.userStatus != .guest,
                    "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                favoriteBarButton = getFavoriteBarButton()
                if orientation.isPortrait, UIDevice.current.userInterfaceIdiom == .phone {
                    // No button on the right
                    navigationItem.rightBarButtonItems = []

                    // Remaining buttons in navigation toolbar
                    isToolbarRequired = true
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    setToolbarItems([shareBarButton, UIBarButtonItem.space(),
                                     favoriteBarButton!].compactMap { $0 }, animated: false)
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                }
                else {
                    // All buttons in navigation bar
                    navigationItem.setRightBarButtonItems([favoriteBarButton!, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    isToolbarRequired = false
                    navigationController?.setToolbarHidden(true, animated: false)
                }
            } else {
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
                var toolBarItems = [shareBarButton, UIBarButtonItem.space(), moveBarButton,
                                    UIBarButtonItem.space(), setThumbnailBarButton,
                                    UIBarButtonItem.space(), deleteBarButton].compactMap { $0 }
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    favoriteBarButton = getFavoriteBarButton()
                    toolBarItems.insert(contentsOf: [favoriteBarButton!, UIBarButtonItem.space()]
                        .compactMap { $0 }, at: 4)
                }
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else if userHasUploadRights {
                // WRONG =====> 'normal' user with upload access to the current category can edit images
                // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
                // Navigation bar
                // The action menu is simply an Edit button
                actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                                  target: self, action: #selector(editImage))
                actionBarButton?.accessibilityIdentifier = "edit"
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }

                // Navigation toolbar
                var toolBarItems = [shareBarButton, UIBarButtonItem.space(), moveBarButton].compactMap { $0 }
                // pwg.users.favorites… methods available from Piwigo version 2.10
                if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                    favoriteBarButton = getFavoriteBarButton()
                    toolBarItems.insert(contentsOf: [favoriteBarButton!, UIBarButtonItem.space()]
                        .compactMap { $0 }, at: 2)
                }
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                setToolbarItems(toolBarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else if NetworkVars.userStatus != .guest,
                    "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                favoriteBarButton = getFavoriteBarButton()
                if orientation.isPortrait {
                    // No button on the right
                    navigationItem.rightBarButtonItems = []

                    // Remaining buttons in navigation toolbar
                    isToolbarRequired = true
                    let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                    setToolbarItems([shareBarButton, UIBarButtonItem.space(),
                                     favoriteBarButton!].compactMap { $0 }, animated: false)
                    navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
                } else {
                    navigationItem.setRightBarButtonItems([favoriteBarButton!, shareBarButton].compactMap { $0 }, animated: true)

                    // Hide navigation toolbar
                    isToolbarRequired = false
                    navigationController?.setToolbarHidden(true, animated: false)
                }
            } else {
                // Hide navigation toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: false)
            }
        }
    }
    
    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    func setEnableStateOfButtons(_ state: Bool) {
        print("••> \(state ? "Enable" : "Disable") buttons")
        actionBarButton?.isEnabled = state
        shareBarButton.isEnabled = state
        moveBarButton.isEnabled = state
        setThumbnailBarButton.isEnabled = state
        deleteBarButton.isEnabled = state
        favoriteBarButton?.isEnabled = state
    }

    private func retrieveImageData(_ imageData: Image, isIncomplete: Bool) {
        // Retrieve image/video infos
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            NetworkUtilities.checkSession(ofUser: user) { [self] in
                let imageID = imageData.pwgID
                print("••> Retrieving data of image \(imageID)")
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.categoryId) {
                    DispatchQueue.main.async {
                        // Enable buttons
                        if let vcs = self.pageViewController?.viewControllers as? [ImagePreviewViewController],
                           let pvc = vcs.first(where: {$0.imageData.pwgID == imageID}) {
                            // Update image data
                            let index = pvc.imageIndex
                            pvc.imageData = self.images.object(at: IndexPath(item: index, section: 0))
                            if pvc.imageData.isFault {
                                // The album is not fired yet.
                                pvc.imageData.willAccessValue(forKey: nil)
                                pvc.imageData.didAccessValue(forKey: nil)
                            }
                            // Update navigation bar
                            self.updateNavBar()
                            self.setEnableStateOfButtons(true)
                        }
                    }
                } failure: { error in
                    // Display error only when image data is incomplete
                    if isIncomplete {
                        self.retrieveImageDataError(error)
                    }
                }
            } failure: { [self] error in
                // Don't display an error if there is no Internet connection
                if [NSURLErrorDataNotAllowed, NSURLErrorNotConnectedToInternet, NSURLErrorInternationalRoamingOff].contains(error.code) {
                    return
                }
                // Display error only once and when image data is incomplete
                if isIncomplete  {
                    self.retrieveImageDataError(error)
                }
            }
        }
    }

    private func retrieveImageDataError(_ error: NSError) {
        DispatchQueue.main.async { [self] in
            let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
            let message = NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed.")
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { }
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
            startVideoPlayerView(with: imageData)
        }
        else {
            // Display/hide the navigation bar
            let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            navigationController?.setNavigationBarHidden(!isNavigationBarHidden, animated: true)

            // Display/hide home indicator
            // Notify UIKit that this view controller updated its preference regarding the visual indicator
            setNeedsUpdateOfHomeIndicatorAutoHidden()

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
        
        guard let pvc = pageViewController.viewControllers?.first as? ImagePreviewViewController else {
            fatalError("!!! Wrong View Controller Type !!!")
        }

        // Pause download if needed
        if let imageURL = pvc.imageURL {
            ImageSession.shared.pauseDownload(atURL: imageURL)
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
        
        // Remember index of presented page
        print("••> Did finish animating page view controller for image at index \(pvc.imageIndex)")
        imageIndex = pvc.imageIndex

        // Sets new image data
        imageData = images.object(at: IndexPath(item: imageIndex, section: 0))
        if imageData.isFault {
            // The album is not fired yet.
            imageData.willAccessValue(forKey: nil)
            imageData.didAccessValue(forKey: nil)
        }

        // Initialise page view controller
        pvc.progressView.isHidden = pvc.imageLoaded || imageData.isVideo
        setTitleViewFromImageData()
        updateNavBar()
        setEnableStateOfButtons(imageData.fileSize != Int64.zero)

        // Scroll album collection view to keep the selected image centered on the screen
        imgDetailDelegate?.didSelectImage(atIndex: imageIndex)
    }
}


// MARK: - UIPageViewControllerDataSource
extension ImageViewController: UIPageViewControllerDataSource
{
    // Create view controller for presenting the image at the provided index
    func imagePageViewController(atIndex index:Int) -> ImagePreviewViewController? {
        print("••> Create page view controller for image at index \(index)")
        guard let imagePage = storyboard?.instantiateViewController(withIdentifier: "ImagePreviewViewController") as? ImagePreviewViewController else { return nil }

        // Retrieve up-to-date complete image data if needed
        let imageData = images.object(at: IndexPath(item: index, section: 0))
        if imageData.isFault {
            // The album is not fired yet.
            imageData.willAccessValue(forKey: nil)
            imageData.didAccessValue(forKey: nil)
        }
        if imageData.fileSize == Int64.zero {
            // Retrieve image data
            retrieveImageData(imageData, isIncomplete: true)
        } else if imageData.dateGetInfos.timeIntervalSinceNow < TimeInterval(-3600) {
            // Retrieve image data
            retrieveImageData(imageData, isIncomplete: false)
        }

        // Create image preview
        imagePage.imageIndex = index
        imagePage.imageData = imageData
        imagePage.imageLoaded = false
        return imagePage
    }
    
    // Returns the view controller after the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        // Did we reach the last image?
        let maxIndex = max(0, (images.fetchedObjects ?? []).count - 1)
        if (imageIndex + 1 > maxIndex) {
            // Reached the end of the category
            return nil
        }
        
        // Remember that the next page was presented
        didPresentPageAfter = true

        // Create view controller for presenting next image
        return imagePageViewController(atIndex: imageIndex + 1)
    }

    // Returns the view controller before the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        // Did we reach the first image?
        if imageIndex - 1 < 0 {
            return nil
        }
        
        // Remember that the previous page was presented
        didPresentPageAfter = false

        // Create view controller
        return imagePageViewController(atIndex: imageIndex - 1)
    }
}


// MARK: - SelectCategoryDelegate Methods
extension ImageViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int32) {
        setEnableStateOfButtons(true)
    }
}
