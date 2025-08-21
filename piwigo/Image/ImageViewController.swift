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
    lazy var setThumbnailBarButton: UIBarButtonItem = getSetThumbnailBarButton()
    lazy var moveBarButton: UIBarButtonItem = getMoveBarButton()
    lazy var deleteBarButton: UIBarButtonItem = getDeleteBarButton()
    var shareBarButton: UIBarButtonItem?
    var favoriteBarButton: UIBarButtonItem?
    var playBarButton: UIBarButtonItem?
    var muteBarButton: UIBarButtonItem?
    var goToPageButton: UIBarButtonItem?
    
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
        let fileType = pwgImageFileType(rawValue: imageData.fileType) ?? .image
        switch fileType {
        case .image:
            if let imageDVC = imageDetailViewController(ofImage: imageData, atIndexPath: indexPath) {
                pageViewController?.setViewControllers([imageDVC], direction: .forward, animated: false)
            }
        case .video:
            if let videoDVC = videoDetailViewController(ofImage: imageData, atIndexPath: indexPath) {
                pageViewController?.setViewControllers([videoDVC], direction: .forward, animated: false)
            }
        case .pdf:
            if let pdfDVC = pdfDetailViewController(ofImage: imageData, atIndexPath: indexPath) {
                pageViewController?.setViewControllers([pdfDVC], direction: .forward, animated: false)
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
    
    @MainActor
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
        }, completion: { [self] _ in
            // Force reload flexible spaces (known iOS bug)
            guard let toolbar = self.navigationController?.toolbar else { return }
            debugPrint("••> toolbar width: \(toolbar.bounds.width), screen width: \(UIScreen.main.bounds.width)")
            
            // Store current items
            let currentItems = toolbar.items
            
            // Temporarily clear and reset items to force recalculation
            toolbar.setItems(nil, animated: false)
            toolbar.setItems(currentItems, animated: false)
            
            // Force layout update
            toolbar.setNeedsLayout()
            toolbar.layoutIfNeeded()
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
                            } else if let pvc = vc as? PdfDetailViewController, pvc.imageData.pwgID == imageID,
                                      let updatedImage = self.images.fetchedObjects?.first(where: { $0.pwgID == imageID }){
                                // Update image data
                                if updatedImage.isFault {
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
                        DispatchQueue.main.async { [self] in
                            self.retrieveImageDataError(error)
                        }
                    }
                }
            } failure: { [self] error in
                // Don't display an error if there is no Internet connection
                if [NSURLErrorDataNotAllowed,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorInternationalRoamingOff].contains((error as NSError).code) {
                    return
                }
                // Display error only once and when image data is incomplete
                if isIncomplete  {
                    DispatchQueue.main.async { [self] in
                        self.retrieveImageDataError(error)
                    }
                }
            }
        }
    }

    @MainActor
    private func retrieveImageDataError(_ error: Error) {
        // Session logout required?
        if let pwgError = error as? PwgSessionError,
           [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
            return
        }

        // Report error
        let title = NSLocalizedString("imageDetailsFetchError_title", comment: "Image Details Fetch Failed")
        let message = NSLocalizedString("imageDetailsFetchError_message", comment: "Fetching the image data failed.")
        dismissPiwigoError(withTitle: title, message: message, errorMessage: error.localizedDescription) { }
    }

    func logImageVisitIfNeeded(_ imageID: Int64, asDownload: Bool = false) {
        PwgSession.checkSession(ofUser: user) { [self] in
            if NetworkVars.shared.saveVisits {
                PwgSession.shared.logVisitOfImage(withID: imageID, asDownload: asDownload) {
                    // Statistics updated
                } failure: { [self] error in
                    // Session logout required?
                    DispatchQueue.main.async { [self] in
                        if let pwgError = error as? PwgSessionError,
                           [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed]
                            .contains(pwgError) {
                            ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                            return
                        }
                    }
                    // Statistics not updated ► No error reported
                }
            }
        } failure: { [self] error in
            // Session logout required?
            DispatchQueue.main.async { [self] in
                if let pwgError = error as? PwgSessionError,
                   [.invalidCredentials, .incompatiblePwgVersion, .invalidURL, .authenticationFailed].contains(pwgError) {
                    ClearCache.closeSessionWithPwgError(from: self, error: pwgError)
                    return
                }
            }
            // Statistics not updated ► No error reported
        }
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
            (imagePVC as? PdfDetailViewController)?.updateDescriptionVisibility()
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
        else if let pdfDVC = pageViewController.viewControllers?.first as? PdfDetailViewController,
                let imageURL = pdfDVC.imageURL {
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
            
            // Reset video player and PDF goToPage buttons
            playBarButton = nil
            muteBarButton = nil
            goToPageButton = nil
        }
        else if let videoDVC = pageViewController.viewControllers?.first as? VideoDetailViewController {
            // Store index and image data of presented page
            indexPath = videoDVC.indexPath
            imageData = videoDVC.imageData
            
            // Reset PDF goToPage buttons
            goToPageButton = nil
            
            // Set video player buttons
            playBarButton = UIBarButtonItem.playImageButton(self, action: #selector(playVideo))
            muteBarButton = UIBarButtonItem.muteAudioButton(VideoVars.shared.isMuted, target: self, action: #selector(muteUnmuteAudio))
        }
        else if let pdfDVC = pageViewController.viewControllers?.first as? PdfDetailViewController {
            // Store index and image data of presented page
            indexPath = pdfDVC.indexPath
            imageData = pdfDVC.imageData
            
            // Reset video player and PDF reader buttons
            playBarButton = nil
            muteBarButton = nil
            
            // Set PDF goToPage button
            goToPageButton = UIBarButtonItem.goToPageButton(self, action: #selector(goToPage))
        }
        else {
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
        else if let pdfDVC = previousViewControllers.first as? PdfDetailViewController {
            didPresentNextPage = indexPath > pdfDVC.indexPath
        }

        // Scroll album collection view to keep the selected image/video centered on the screen
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
    
    // Create view controller for presenting the PDF at the provided index
    func pdfDetailViewController(ofImage imageData: Image, atIndexPath indexPath: IndexPath) -> PdfDetailViewController? {
//        debugPrint("••> Create page view controller for PDF #\(imageData.pwgID) at index \(indexPath)")
        guard let pdfDVC = storyboard?.instantiateViewController(withIdentifier: "PdfDetailViewController") as? PdfDetailViewController
        else { return nil }

        // Create PDF detail view
        pdfDVC.indexPath = indexPath
        pdfDVC.imageData = imageData
        return pdfDVC
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
        let fileType = pwgImageFileType(rawValue: imageData.fileType) ?? .image
        switch fileType {
        case .image:
            return imageDetailViewController(ofImage: imageData, atIndexPath: nextIndexPath)
        case .video:
            return videoDetailViewController(ofImage: imageData, atIndexPath: nextIndexPath)
        case .pdf:
            return pdfDetailViewController(ofImage: imageData, atIndexPath: nextIndexPath)
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
        let fileType = pwgImageFileType(rawValue: imageData.fileType) ?? .image
        switch fileType {
        case .image:
            return imageDetailViewController(ofImage: imageData, atIndexPath: previousIndexPath)
        case .video:
            return videoDetailViewController(ofImage: imageData, atIndexPath: previousIndexPath)
        case .pdf:
            return pdfDetailViewController(ofImage: imageData, atIndexPath: previousIndexPath)
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
