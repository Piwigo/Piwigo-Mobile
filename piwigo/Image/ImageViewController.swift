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
    func didSelectImage(atIndexPath indexPath: IndexPath)
}

class ImageViewController: UIViewController {
    
    weak var imgDetailDelegate: ImageDetailDelegate?
    var images: NSFetchedResultsController<Image>!
    var categoryId = Int32.zero
    var indexPath = IndexPath(item: 0, section: 0)
    var imageData: Image!
    var isToolbarRequired = false
    var didPresentNextPage = true
    var pageViewController: UIPageViewController?
    let playbackController = PlaybackController.shared

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
    
    lazy var imageProvider: ImageProvider = {
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
    lazy var backButton: UIBarButtonItem = {
        return UIBarButtonItem.backImageButton(target: self, action: #selector(returnToAlbum))
    }()
    lazy var shareBarButton: UIBarButtonItem = getShareButton()
    lazy var setThumbnailBarButton: UIBarButtonItem = getSetThumbnailBarButton()
    lazy var moveBarButton: UIBarButtonItem = getMoveBarButton()
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    var favoriteBarButton: UIBarButtonItem?
    var playBarButton: UIBarButtonItem?
    var muteBarButton: UIBarButtonItem?
    
    // MARK: - Rotate View & Buttons
    var rotateView: UIView?
    var rotateLeftButton: UIButton?
    var rotateRightButton: UIButton?
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialise video players and PiP management
        playbackController.videoItemDelegate = self

        // Initialise pageViewController
        pageViewController = children[0] as? UIPageViewController
        pageViewController?.delegate = self
        pageViewController?.dataSource = self

        // Load initial image preview view controller
        imageData = getImageData(atIndexPath: indexPath)
        if imageData.isVideo {
            if let videoDVC = videoDetailViewController(ofImage: imageData, atIndexPath: indexPath) {
                pageViewController?.setViewControllers([videoDVC], direction: .forward, animated: false)
            }
        } else {
            if let imageDVC = imageDetailViewController(ofImage: imageData, atIndexPath: indexPath) {
                pageViewController!.setViewControllers([imageDVC], direction: .forward, animated: false)
            }
        }
                
        // Update server statistics
        logImageVisitIfNeeded(imageData.pwgID)

        // Navigation bar
        let navigationBar = navigationController?.navigationBar
        navigationBar?.tintColor = .piwigoColorOrange()
        
        // Toolbar
        let toolbar = navigationController?.toolbar
        toolbar?.tintColor = .piwigoColorOrange()

        // Single taps display/hide the navigation bar, toolbar and description
        let tapOnce = UITapGestureRecognizer(target: self, action: #selector(didTapOnce))
        tapOnce.numberOfTapsRequired = 1

        // Double taps zoom in/out the image
        let tapTwice = UITapGestureRecognizer(target: self, action: #selector(didTapTwice(_:)))
        tapTwice.numberOfTapsRequired = 2
        tapOnce.require(toFail: tapTwice)

        // Down swipes return to album view
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(didSwipeDown(_:)))
        swipeDown.numberOfTouchesRequired = 1
        swipeDown.direction = .down
        tapOnce.require(toFail: swipeDown)
        
        // Add gestures to view
        view.gestureRecognizers = [tapOnce, tapTwice, swipeDown]

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register video player changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangePlaybackStatus),
                                               name: Notification.Name.pwgVideoPlaybackStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeMuteOption),
                                               name: Notification.Name.pwgVideoMutedOrNot, object: nil)
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
        // and never present video in full screen
        navigationController?.setNavigationBarHidden(false, animated: true)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Image options buttons
        updateNavBar()
        setEnableStateOfButtons(imageData.fileSize != Int64.zero)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [self] _ in
            // Update image detail view
            updateNavBar()
            setTitleViewFromImageData()
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
    
    override func viewDidDisappear(_ animated: Bool) {
        // Was this image displayed on the external screen?
        if #available(iOS 13.0, *) {
            var wantedRole: UISceneSession.Role!
            if #available(iOS 16.0, *) {
                wantedRole = .windowExternalDisplayNonInteractive
            } else {
                // Fallback on earlier versions
                wantedRole = .windowExternalDisplay
            }
            let scenes = UIApplication.shared.connectedScenes.filter({$0.session.role == wantedRole})
            guard let sceneDelegate = scenes.first?.delegate as? ExternalDisplaySceneDelegate
                else { return }
            
            // Return to basic screen sharing
            sceneDelegate.window?.windowScene = nil
        }
    }
    
    deinit {
//        debugPrint("••> ImageViewController is being deinitialized.")
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }


    // MARK: - Image Data
//    func getIndexPath(atOrBefore indexPath: IndexPath) -> IndexPath? {
//        // Any image left?
//        if images?.fetchedObjects?.count ?? 0 == 0 {
//            return nil
//        }
//
//        // Select the current section, or the previous one if not available
//        guard let sections = images.sections
//        else { preconditionFailure("No sections in fetchedResultsController")}
//        let section = min(indexPath.section, sections.count - 1)
//        
//        // Images still available in the current section?
//        let count = sections[indexPath.section].numberOfObjects
//        if section == indexPath.section {
//            // Select the item the nearest to the current one
//            let item = min(indexPath.item, count - 1)
//            return IndexPath(item: item, section: section)
//        } else {
//            // Select the last item of a previous section
//            let count = sections[indexPath.section].numberOfObjects
//            return IndexPath(item: count - 1, section: section)
//        }
//    }
    
    func getIndexPath(after indexPath: IndexPath) -> IndexPath? {
        // Check that the current section is still accessible
        guard let sections = images.sections,
              sections.count > indexPath.section
        else { return nil}
        
        // Return the next image of the current section if available
        let nextItem = indexPath.item + 1
        if nextItem  < sections[indexPath.section].numberOfObjects {
            return IndexPath(item: nextItem, section: indexPath.section)
        }
        
        // Return the first image of the next section if available
        let nextSection = indexPath.section + 1
        if nextSection < sections.count,
           sections[nextSection].numberOfObjects > 0 {
            return IndexPath(item: 0, section: nextSection)
        }
        
        return nil
    }
    
    func getIndexPath(before indexPath: IndexPath) -> IndexPath? {
        // Retrieve available sections
        guard let sections = images.sections
        else { return nil}
        
        // Return the previous image of the current section if available
        var section = indexPath.section
        if section < sections.count {
            let previousItem = indexPath.item - 1
            if previousItem >= 0, previousItem < sections[section].numberOfObjects {
                return IndexPath(item: previousItem, section: section)
            }
        }
        
        // Return the last image of a previous section if possible
        repeat {
            section -= 1
            if section >= 0, section < sections.count,
               sections[section].numberOfObjects > 0 {
                return IndexPath(item: sections[section].numberOfObjects - 1, section: section)
            }
        } while (section > 1)
        
        return nil
    }
    
    func getImageData(atIndexPath indexPath: IndexPath) -> Image {
        // Retrieve image data
        let imageData = images.object(at: indexPath)
        if imageData.isFault {
            // The album is not fired yet.
            imageData.willAccessValue(forKey: nil)
            imageData.didAccessValue(forKey: nil)
        }

        // Retrieve up-to-date complete image data if needed
        if imageData.fileSize == Int64.zero {
            // Image data is incomplete — retrieve it
            retrieveImageData(imageData, isIncomplete: true)
        } else if Date.timeIntervalSinceReferenceDate - imageData.dateGetInfos > TimeInterval(86400) {
            // Image data retrieved more than a day ago — retrieve it
            retrieveImageData(imageData, isIncomplete: false)
        }

        return imageData
    }
    
    private func retrieveImageData(_ imageData: Image, isIncomplete: Bool) {
        // Retrieve image/video infos
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            PwgSession.checkSession(ofUser: user) { [self] in
                let imageID = imageData.pwgID
                self.imageProvider.getInfos(forID: imageID, inCategoryId: self.categoryId) { [self] in
                    DispatchQueue.main.async { [self] in
                        // Look for the corresponding view controller
                        guard let vcs = self.pageViewController?.viewControllers else { return }
                        for vc in vcs {
                            if let pvc = vc as? ImageDetailViewController, pvc.imageData.pwgID == imageID,
                               let updatedImage = self.images.fetchedObjects?.first(where: { $0.pwgID == imageID }) {
                                // Update image data
                                if updatedImage.isFault {
                                    // The image is not fired yet.
                                    updatedImage.willAccessValue(forKey: nil)
                                    updatedImage.didAccessValue(forKey: nil)
                                }
                                pvc.imageData = updatedImage
                                // Update navigation bar and enable buttons
                                self.updateNavBar()
                                self.setEnableStateOfButtons(true)
                                break
                            } else if let pvc = vc as? VideoDetailViewController, pvc.imageData.pwgID == imageID,
                                      let updatedImage = self.images.fetchedObjects?.first(where: { $0.pwgID == imageID }){
                                // Update image data
                                if updatedImage.isFault {
                                    // The image is not fired yet.
                                    updatedImage.willAccessValue(forKey: nil)
                                    updatedImage.didAccessValue(forKey: nil)
                                }
                                pvc.imageData = updatedImage
                                // Update navigation bar and enable buttons
                                self.updateNavBar()
                                self.setEnableStateOfButtons(true)
                                break
                            }
                        }
                    }
                } failure: { [self] error in
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
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Report error
            let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
            let message = NSLocalizedString("imageDetailsFetchError_retryMessage", comment: "Fetching the image data failed.")
            dismissPiwigoError(withTitle: title, message: message,
                               errorMessage: error.localizedDescription) { }
        }
    }

    func logImageVisitIfNeeded(_ imageID: Int64, asDownload: Bool = false) {
        PwgSession.checkSession(ofUser: user) { [unowned self] in
            if NetworkVars.saveVisits {
                PwgSession.shared.logVisitOfImage(withID: imageID, asDownload: asDownload) {
                    // Statistics updated
                } failure: { [self] error in
                    // Session logout required?
                    if let pwgError = error as? PwgSessionError,
                       [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                        .contains(pwgError) {
                        ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                        return
                    }
                    
                    // Statistics not updated ► No error reported
                }
            }
        } failure: { [unowned self] error in
            // Session logout required?
            if let pwgError = error as? PwgSessionError,
               [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                .contains(pwgError) {
                ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                return
            }

            // Statistics not updated ► No error reported
        }
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

        // There is no subtitle in landscape mode on iPhone or when the creation date is unknown
        if ((UIDevice.current.userInterfaceIdiom == .phone) &&
            (UIApplication.shared.statusBarOrientation.isLandscape)) ||
            imageData.dateCreated < DateUtilities.weekAfterInterval { // i.e. a week after unknown date
            let titleWidth = CGFloat(fmin(titleLabel.bounds.size.width, view.bounds.size.width * 0.4))
            titleLabel.sizeThatFits(CGSize(width: titleWidth, height: titleLabel.bounds.size.height))
            let oneLineTitleView = UIView(frame: CGRect(x: 0, y: 0, width: CGFloat(titleWidth), height: titleLabel.bounds.size.height))
            navigationItem.titleView = oneLineTitleView

            oneLineTitleView.addSubview(titleLabel)
            oneLineTitleView.addConstraint(NSLayoutConstraint.constraintView(titleLabel, toWidth: titleWidth)!)
            oneLineTitleView.addConstraints(NSLayoutConstraint.constraintCenter(titleLabel)!)
        }
        else {
            let dateCreated = Date(timeIntervalSinceReferenceDate: imageData.dateCreated)
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
            let dateFormatter = DateUtilities.dateFormatter()
            if UIDevice.current.userInterfaceIdiom == .pad {
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .medium   // Without time zone (unknown)
                subTitleLabel.text = dateFormatter.string(from: dateCreated)
            } else {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .medium
                subTitleLabel.text = dateFormatter.string(from: dateCreated)
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
        // Favorites button depends on Piwigo server version, user role and image data
        favoriteBarButton = getFavoriteBarButton()

        if #available(iOS 14, *) {
            updateNavBarNew()
        } else {
            // Fallback on earlier versions
            updateNavBarOld()
        }
    }
    
    @available(iOS 14, *)
    private func updateNavBarNew() {
        // Interface depends on device and orientation
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        
        // User with admin or upload rights can do everything
        if user.hasUploadRights(forCatID: categoryId) {
            // The action button proposes:
            /// - to copy or move images to other albums
            /// - to set the image as album thumbnail
            /// - to edit image parameters,
            let menu = UIMenu(title: "", children: [albumMenu(), editMenu()].compactMap({$0}))
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
            actionBarButton?.accessibilityIdentifier = "actions"
            
            if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                // Buttons in the navigation bar
                navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [actionBarButton].compactMap {$0}

                // Remaining buttons in navigation toolbar
                /// Fixed space added on both sides of play/pause button so that its global width
                /// matches the width of the mute/unmute button.
                isToolbarRequired = true
                var toolbarItems = [UIBarButtonItem?]()
                toolbarItems.append(contentsOf: [shareBarButton, .space()])
                toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .fixedSpace(4.3333)])
                toolbarItems.append(contentsOf: [playBarButton, playBarButton == nil ? nil : .space()])
                toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .fixedSpace(4.3333)])
                toolbarItems.append(contentsOf: [favoriteBarButton, favoriteBarButton == nil ? nil : .space()])
                toolbarItems.append(contentsOf: [muteBarButton, muteBarButton == nil ? nil : .space()])
                toolbarItems.append(deleteBarButton)
                setToolbarItems(toolbarItems.compactMap { $0 }, animated: false)
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else {
                // Buttons in the navigation bar
                navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [actionBarButton, deleteBarButton, favoriteBarButton, shareBarButton].compactMap { $0 }

                // No toolbar
                isToolbarRequired = false
                setToolbarItems([], animated: false)
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }
        else if favoriteBarButton != nil {
            if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                // Buttons in the navigation bar
                navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                navigationItem.rightBarButtonItems = []
                
                // Remaining buttons in navigation toolbar
                /// Fixed space added on both sides of play/pause button so that its global width
                /// matches the width of the mute/unmute button.
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                var toolbarItems = [UIBarButtonItem?]()
                toolbarItems.append(contentsOf: [shareBarButton, .space()])
                toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .fixedSpace(4.3333)])
                toolbarItems.append(contentsOf: [playBarButton, playBarButton == nil ? nil : .space()])
                toolbarItems.append(contentsOf: [playBarButton == nil ? nil : .fixedSpace(4.3333)])
                toolbarItems.append(contentsOf: [muteBarButton, muteBarButton == nil ? nil : .space()])
                toolbarItems.append(favoriteBarButton)
                setToolbarItems(toolbarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            }
            else {
                // All buttons in navigation bar
                navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [favoriteBarButton, shareBarButton].compactMap { $0 }
                
                // Hide navigation toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }
        else if NetworkVars.userStatus != .guest {
            // All buttons in navigation bar
            navigationItem.leftBarButtonItems = [backButton, playBarButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [shareBarButton, muteBarButton].compactMap { $0 }
            
            // Hide navigation toolbar
            isToolbarRequired = false
            navigationController?.setToolbarHidden(true, animated: false)
        }
        else {
            // All buttons in navigation bar
            navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [playBarButton, muteBarButton].compactMap {$0}

            // Hide navigation toolbar
            isToolbarRequired = false
            navigationController?.setToolbarHidden(true, animated: false)
        }
    }
    
    private func updateNavBarOld() {
        // Interface depends on device and orientation
        let orientation = UIApplication.shared.statusBarOrientation
        
        // User with admin or upload rights can do everything
        // WRONG =====> 'normal' user with upload access to the current category can edit images
        // SHOULD BE => 'normal' user having uploaded images can edit them. This requires 'user_id' and 'added_by' values of images for checking rights
        if user.hasUploadRights(forCatID: categoryId) {
            // Navigation bar
            // The action menu is simply an Edit button
            actionBarButton = UIBarButtonItem(barButtonSystemItem: .edit,
                                              target: self, action: #selector(editImage))
            actionBarButton?.accessibilityIdentifier = "edit"
            navigationItem.leftBarButtonItems = [backButton, playBarButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [actionBarButton, muteBarButton].compactMap { $0 }

            // Navigation toolbar
            isToolbarRequired = true
            let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
            var toolbarItems = [UIBarButtonItem?]()
            toolbarItems.append(contentsOf: [shareBarButton, .space()])
            toolbarItems.append(contentsOf: [moveBarButton, .space()])
            toolbarItems.append(contentsOf: [favoriteBarButton, favoriteBarButton == nil ? nil : .space()])
            toolbarItems.append(contentsOf: [setThumbnailBarButton, .space()])
            toolbarItems.append(deleteBarButton)
            setToolbarItems(toolbarItems.compactMap { $0 }, animated: false)
            navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
        }
        else if favoriteBarButton != nil {
            if UIDevice.current.userInterfaceIdiom == .phone, orientation.isPortrait {
                // Navigation bar
                navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
                navigationItem.rightBarButtonItems = []

                // Remaining buttons in navigation toolbar
                isToolbarRequired = true
                let isNavigationBarHidden = navigationController?.isNavigationBarHidden ?? false
                var toolbarItems = [UIBarButtonItem?]()
                toolbarItems.append(contentsOf: [shareBarButton, .space()])
                toolbarItems.append(contentsOf: [playBarButton, playBarButton == nil ? nil : .space()])
                toolbarItems.append(contentsOf: [muteBarButton, muteBarButton == nil ? nil : .space()])
                toolbarItems.append(favoriteBarButton)
                setToolbarItems(toolbarItems.compactMap { $0 }, animated: false)
                navigationController?.setToolbarHidden(isNavigationBarHidden, animated: true)
            } else {
                navigationItem.leftBarButtonItems = [backButton, playBarButton, muteBarButton].compactMap {$0}
                navigationItem.rightBarButtonItems = [favoriteBarButton, shareBarButton].compactMap { $0 }

                // Hide navigation toolbar
                isToolbarRequired = false
                navigationController?.setToolbarHidden(true, animated: true)
            }
        }
        else if NetworkVars.userStatus != .guest {
            // All buttons in navigation bar
            navigationItem.leftBarButtonItems = [backButton, playBarButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [shareBarButton, muteBarButton].compactMap { $0 }
            
            // Hide navigation toolbar
            isToolbarRequired = false
            navigationController?.setToolbarHidden(true, animated: false)
        }
        else {
            // All buttons in navigation bar
            navigationItem.leftBarButtonItems = [backButton].compactMap {$0}
            navigationItem.rightBarButtonItems = [playBarButton, muteBarButton].compactMap {$0}

            // Hide navigation toolbar
            isToolbarRequired = false
            navigationController?.setToolbarHidden(true, animated: false)
        }
    }
    
    // Buttons are disabled (greyed) when retrieving image data
    // They are also disabled during an action
    func setEnableStateOfButtons(_ state: Bool) {
//        debugPrint("••> \(state ? "Enable" : "Disable") buttons")
        actionBarButton?.isEnabled = state
        shareBarButton.isEnabled = state
        moveBarButton.isEnabled = state
        setThumbnailBarButton.isEnabled = state
        deleteBarButton.isEnabled = state
        favoriteBarButton?.isEnabled = state
        playBarButton?.isEnabled = state
        muteBarButton?.isEnabled = state
    }

    
    // MARK: - User Interaction
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc func didTapOnce() {
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
        if let imagePVC = pageViewController?.viewControllers?.first {
            (imagePVC as? ImageDetailViewController)?.updateDescriptionVisibility()
            (imagePVC as? VideoDetailViewController)?.updateDescriptionControlsVisibility()
        }

        // Set background color according to navigation bar visibility
        if navigationController?.isNavigationBarHidden ?? false {
            view.backgroundColor = .black
        } else {
            view.backgroundColor = .piwigoColorBackground()
        }
    }
    
    @objc func didTapTwice(_ gestureRecognizer: UIGestureRecognizer) {
        // Zoom in/out the image if necessary
        if let imagePVC = pageViewController?.viewControllers?.first {
            (imagePVC as? ImageDetailViewController)?.didTapTwice(gestureRecognizer)
            (imagePVC as? VideoDetailViewController)?.didTapTwice(gestureRecognizer)
        }
    }

    @objc func didSwipeDown(_ gestureRecognizer: UIGestureRecognizer) {
        // Return to the album view
        returnToAlbum()
    }
    
    @objc func returnToAlbum() {
        self.dismiss(animated: true)
    }
    
    // Display/hide status bar
    override var prefersStatusBarHidden: Bool {
        let orientation: UIInterfaceOrientation
        if #available(iOS 14, *) {
            orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            orientation = UIApplication.shared.statusBarOrientation
        }
        let phoneInLandscape = UIDevice.current.userInterfaceIdiom == .phone && orientation.isLandscape
        return phoneInLandscape || navigationController?.isNavigationBarHidden ?? false
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
        // Image disappearing
        if let imageDVC = pageViewController.viewControllers?.first as? ImageDetailViewController,
           let imageURL = imageDVC.imageURL {
            // Pause download
            PwgSession.shared.pauseDownload(atURL: imageURL)
        }
    }
    
    // Called after a gesture-driven transition completes
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        // Check if the user completed the page-turn gesture
        if completed == false { return }
        
        // Case of an image
        if let imageDVC = pageViewController.viewControllers?.first as? ImageDetailViewController {
            // Store index and image data of presented page
            indexPath = imageDVC.indexPath
            imageData = imageDVC.imageData
            
            // Reset video player buttons
            playBarButton = nil
            muteBarButton = nil
        }
        else if let videoDVC = pageViewController.viewControllers?.first as? VideoDetailViewController {
            // Store index and image data of presented page
            indexPath = videoDVC.indexPath
            imageData = videoDVC.imageData
            
            // Set video player buttons
            playBarButton = UIBarButtonItem.playImageButton(self, action: #selector(playVideo))
            muteBarButton = UIBarButtonItem.muteAudioButton(VideoVars.shared.isMuted, target: self, action: #selector(muteUnmuteAudio))
        } else {
            return
        }
        
        // Set title and buttons
//        debugPrint("••> Did finish animating page view controller for image at index \(indexPath)")
        setTitleViewFromImageData()
        updateNavBar()
        setEnableStateOfButtons(imageData.fileSize != Int64.zero)
        
        // Determine if the page-turn gesture is in forward or reverse direction
        if let imageDVC = previousViewControllers.first as? ImageDetailViewController {
            didPresentNextPage = indexPath > imageDVC.indexPath
        }
        else if let videoDVC = previousViewControllers.first as? VideoDetailViewController {
            didPresentNextPage = indexPath > videoDVC.indexPath
        }

        // Scroll album collection view to keep the selected image centered on the screen
        imgDetailDelegate?.didSelectImage(atIndexPath: indexPath)
        
        // Update server statistics
        logImageVisitIfNeeded(imageData.pwgID)
    }
}


// MARK: - UIPageViewControllerDataSource
extension ImageViewController: UIPageViewControllerDataSource
{
    // Create view controller for presenting the image at the provided index
    func imageDetailViewController(ofImage imageData: Image, atIndexPath indexPath: IndexPath) -> ImageDetailViewController? {
//        debugPrint("••> Create page view controller for image #\(imageData.pwgID) at index \(indexPath)")
        guard let imageDVC = storyboard?.instantiateViewController(withIdentifier: "ImageDetailViewController") as? ImageDetailViewController
        else { return nil }

        // Create image detail view
        imageDVC.indexPath = indexPath
        imageDVC.imageData = imageData
        return imageDVC
    }
    
    // Create view controller for presenting the video at the provided index
    func videoDetailViewController(ofImage imageData: Image, atIndexPath indexPath: IndexPath) -> VideoDetailViewController? {
//        debugPrint("••> Create page view controller for video #\(imageData.pwgID) at index \(indexPath)")
        guard let videoDVC = storyboard?.instantiateViewController(withIdentifier: "VideoDetailViewController") as? VideoDetailViewController
        else { return nil }

        // Create video detail view
        videoDVC.user = user
        videoDVC.indexPath = indexPath
        videoDVC.imageData = imageData
        return videoDVC
    }
    
    // Returns the view controller after the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        // Did we reach the last image?
        guard let nextIndexPath = getIndexPath(after: indexPath)
        else {
            // Reached the end of the album
            return nil
        }
        
        // Create view controller for presenting next image
        let imageData = getImageData(atIndexPath: nextIndexPath)
        if imageData.isVideo {
            return videoDetailViewController(ofImage: imageData, atIndexPath: nextIndexPath)
        } else {
            return imageDetailViewController(ofImage: imageData, atIndexPath: nextIndexPath)
        }
    }

    // Returns the view controller before the given view controller
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        // Did we reach the first image?
        guard let previousIndexPath = getIndexPath(before: indexPath)
        else {
            // Reached the beginning of the album
            return nil
        }
        
        // Create view controller
        let imageData = getImageData(atIndexPath: previousIndexPath)
        if imageData.isVideo {
            return videoDetailViewController(ofImage: imageData, atIndexPath: previousIndexPath)
        } else {
            return imageDetailViewController(ofImage: imageData, atIndexPath: previousIndexPath)
        }
    }
}


// MARK: - SelectCategoryDelegate Methods
extension ImageViewController: SelectCategoryDelegate
{
    func didSelectCategory(withId category: Int32) {
        setEnableStateOfButtons(true)
    }
}
