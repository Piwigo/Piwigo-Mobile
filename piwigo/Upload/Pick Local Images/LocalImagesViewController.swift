//
//  LocalImagesViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 25 March 2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 18/04/2020
//

import Photos
import UIKit

@objc
class LocalImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, PHPhotoLibraryChangeObserver, LocalImagesHeaderDelegate, ImageUploadProgressDelegate {
    
    @objc func setCategoryId(_ categoryId: Int) {
        _categoryId = categoryId
    }
    private var _categoryId: Int?
    private var categoryId: Int {
        get {
            return _categoryId ?? Model.sharedInstance().defaultCategory
        }
        set(categoryId) {
            _categoryId = categoryId
        }
    }

    @objc func setImageCollectionId(_ imageCollectionId: String) {
        _imageCollectionId = imageCollectionId
    }
    private var _imageCollectionId: String?
    private var imageCollectionId: String {
        get {
            return _imageCollectionId ?? String()
        }
        set(imageCollectionId) {
            _imageCollectionId = imageCollectionId
        }
    }

    @IBOutlet weak var localImagesCollection: UICollectionView!
    @IBOutlet weak var collectionFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private var assetCollections: PHFetchResult<PHAssetCollection>!         // Path to selected non-empty local album
    private var imageCollection: PHFetchResult<PHAsset>!                    // Collection of images in selected non-empty local album
    private var sortedImages: [[PHAsset]] = []                              // Array of images in selected non-empty local album
    private let kPiwigoNberImagesShowHUDWhenSorting = 2500                  // Show HUD when sorting more than this number of images
    private var imagesSortedByDays: [[PHAsset]] = []
    private var imagesSortedByWeeks: [[PHAsset]] = []
    private var imagesSortedByMonths: [[PHAsset]] = []

    private var nberOfImagesPerRow = 0                                      // Number of images displayed per row in collection view
    private var selectedImages = [String]()                                 // Array of identifiers
    private var selectedSections = [NSNumber]()                             // Boolean values corresponding to Select/Deselect status
    private var touchedImages = [String]()                                  // Array of identifiers
    
    private var actionBarButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    
//    private var removedUploadedImages = false
    private var hudViewController: UIViewController?

    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Check collection Id
        if imageCollectionId.count == 0 {
            PhotosFetch.sharedInstance().showPhotosLibraryAccessRestricted(in: self)
        }

        // Fetch non-empty input collection and prepare data source in background
        fetchAndSortImages()

        // Arrays for managing selections
//        removedUploadedImages = false

        // Collection flow layout of images
        collectionFlowLayout.scrollDirection = .vertical
        collectionFlowLayout.sectionHeadersPinToVisibleBounds = true

        // Collection view identifier
        localImagesCollection.accessibilityIdentifier = "CameraRoll"
        
        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "LocalImagesNav"

        // Bar buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "list"), landscapeImagePhone: UIImage(named: "listCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        actionBarButton?.accessibilityIdentifier = "Sort"
        cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelSelect))
        cancelBarButton?.accessibilityIdentifier = "Cancel"
        uploadBarButton = UIBarButtonItem(image: UIImage(named: "upload"), style: .plain, target: self, action: #selector(presentImageUploadView))
        
        // Segmented control (choice for presenting images by date, week or month)
        var attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        segmentedControl.setTitleTextAttributes(attributes, for: .normal)
        attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.piwigoFontSemiBold()
        ]
        segmentedControl.setTitleTextAttributes(attributes, for: .selected)
        segmentedControl.selectedSegmentIndex = Int(Model.sharedInstance().localImagesSectionType.rawValue)
        segmentedControl.setTitle(NSLocalizedString("Months", comment: "Months"), forSegmentAt: 0)
        segmentedControl.setTitle(NSLocalizedString("Weeks", comment: "Weeks"), forSegmentAt: 1)
        segmentedControl.setTitle(NSLocalizedString("Days", comment: "Days"), forSegmentAt: 2)
        segmentedControl.isHidden = true
    }

    @objc func applyColorPalette() {
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

        // Segmented control
        if !segmentedControl.isHidden {
            segmentedControl.backgroundColor = Model.sharedInstance().isDarkPaletteActive ? UIColor.piwigoColorGray().withAlphaComponent(0.8) : UIColor.piwigoColorGray().withAlphaComponent(0.4)
        }

        // Collection view
        localImagesCollection.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        localImagesCollection.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Update navigation bar and title
        updateNavBar()

        // Scale width of images on iPad so that they seem to adopt a similar size
        if UIDevice.current.userInterfaceIdiom == .pad {
            let mainScreenWidth = fminf(Float(UIScreen.main.bounds.size.width), Float(UIScreen.main.bounds.size.height))
            let currentViewWidth = fminf(Float(view.bounds.size.width), Float(view.bounds.size.height))
            nberOfImagesPerRow = Int(roundf(currentViewWidth / mainScreenWidth * Float(Model.sharedInstance().thumbnailsPerRowInPortrait)))
        } else {
            nberOfImagesPerRow = Model.sharedInstance().thumbnailsPerRowInPortrait
        }

        // Progress bar
        ImageUploadProgressView.sharedInstance().delegate = self
        ImageUploadProgressView.sharedInstance().changePaletteMode()
        if ImageUploadManager.sharedInstance().imageUploadQueue.count > 0 {
            ImageUploadProgressView.sharedInstance().addView(to: view, forBottomLayout: bottomLayoutGuide)
        }

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = localImagesCollection.visibleCells.first as? LocalImageCollectionViewCell {
            if let indexPath = localImagesCollection.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { context in
                    self.updateNavBar()
                    self.localImagesCollection.reloadData()

                    // Scroll to previous position
                    self.localImagesCollection.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
                })
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    func updateNavBar() {
        switch selectedImages.count {
            case 0:
                navigationItem.leftBarButtonItems = []
                // Do not show two buttons to provide enough space for title
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width <= 414 {
                    // i.e. smaller than iPhones 6,7 Plus screen width
                    navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
                } else {
                    navigationItem.rightBarButtonItems = [actionBarButton, uploadBarButton].compactMap { $0 }
                    uploadBarButton?.isEnabled = false
                }
                title = NSLocalizedString("selectImages", comment: "Select Photos")
            case 1:
                navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
                // Do not show two buttons to provide enough space for title
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width <= 414 {
                    // i.e. smaller than iPhones 6,7 Plus screen width
                    navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                } else {
                    navigationItem.rightBarButtonItems = [actionBarButton, uploadBarButton].compactMap { $0 }
                }
                uploadBarButton?.isEnabled = true
                title = NSLocalizedString("selectImageSelected", comment: "1 Photo Selected")
            default:
                navigationItem.leftBarButtonItems = [cancelBarButton].compactMap { $0 }
                // Do not show two buttons to provide enough space for title
                // See https://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
                if view.bounds.size.width <= 414 {
                    // i.e. smaller than iPhones 6,7 Plus screen width
                    navigationItem.rightBarButtonItems = [uploadBarButton].compactMap { $0 }
                } else {
                    navigationItem.rightBarButtonItems = [actionBarButton, uploadBarButton].compactMap { $0 }
                }
                uploadBarButton?.isEnabled = true
                title = String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: selectedImages.count))
        }
    }

    
    // MARK: - Fetch and Sort Images
    
    @IBAction func didChangeSortOption(_ sender: UISegmentedControl) {
        // Did select new sort option [Months, Weeks, Days]
        Model.sharedInstance().localImagesSectionType.rawValue = UInt32(sender.selectedSegmentIndex)
        Model.sharedInstance().saveToDisk()
        
        // Sort images as requested
        switch Model.sharedInstance()?.localImagesSectionType {
        case kPiwigoSortImagesByMonths:
            self.sortedImages = self.imagesSortedByMonths
        case kPiwigoSortImagesByWeeks:
            self.sortedImages = self.imagesSortedByWeeks
        default:
            self.sortedImages = self.imagesSortedByDays
        }

        // Update buttons of sections
        self.finishTheJob()
    }
    
    func fetchAndSortImages() -> Void {
        // Fetch non-empty collection previously selected by user
        // We fetch a specific path of the Photos Library to reduce the workload
        DispatchQueue.global(qos: .userInitiated).async {
            var start = CFAbsoluteTimeGetCurrent()
            self.assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil)
            var diff = (CFAbsoluteTimeGetCurrent() - start)*1000
            print("=> Fetching collections took \(diff) ms")

            start = CFAbsoluteTimeGetCurrent()
            let fetchOptions = PHFetchOptions()
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedDescending:
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            case kPiwigoSortDateCreatedAscending:
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            default:
                break
            }
//            fetchOptions.predicate = NSPredicate(format: "isHidden == false")     // Much too slow!
//            fetchOptions.fetchLimit = 100000
            self.imageCollection = PHAsset.fetchAssets(in: self.assetCollections.firstObject!, options: fetchOptions)
            diff = (CFAbsoluteTimeGetCurrent() - start)*1000
            print("=> Fetching assets took \(diff) ms")
            
            // Sort collected images
            self.sortCollectionOfImages()
        }
    }
    
    // Launches 3 sortings in parallel, by months, weeks and days
    private func sortCollectionOfImages() -> Void {
        // Show HUD during job if huge collection
        if imageCollection.count > kPiwigoNberImagesShowHUDWhenSorting {
            DispatchQueue.main.async {
                // Show HUD
                self.showHUDwithTitle(NSLocalizedString("imageSortingHUD", comment: "Sorting Images"))
            }
        }

        // Sort images by months on one queue
        DispatchQueue.global(qos: .userInitiated).async {
            let start = CFAbsoluteTimeGetCurrent()
            self.imagesSortedByMonths = self.split(images: self.imageCollection, with: kPiwigoSortImagesByMonths)
            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
            print("=> Splitting by months took \(diff) ms")

            if Model.sharedInstance().localImagesSectionType == kPiwigoSortImagesByMonths {
                self.sortedImages = self.imagesSortedByMonths
                self.finishTheJob()
            }
        }

        // Sort images by weeks on one queue
        DispatchQueue.global(qos: .userInitiated).async {
            let start = CFAbsoluteTimeGetCurrent()
            self.imagesSortedByWeeks = self.split(images: self.imageCollection, with: kPiwigoSortImagesByWeeks)
            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
            print("=> Splitting by weeks took \(diff) ms")

            if Model.sharedInstance().localImagesSectionType == kPiwigoSortImagesByWeeks {
                self.sortedImages = self.imagesSortedByWeeks
                self.finishTheJob()
            }
        }

        // Sort images by days on one queue
        DispatchQueue.global(qos: .userInitiated).async {
            let start = CFAbsoluteTimeGetCurrent()
            self.imagesSortedByDays = self.split(images: self.imageCollection, with: kPiwigoSortImagesByDays)
            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
            print("=> Splitting by days took \(diff) ms")

            if Model.sharedInstance().localImagesSectionType == kPiwigoSortImagesByDays {
                self.sortedImages = self.imagesSortedByDays
                self.finishTheJob()
            }
        }
    }

    private func split(images: PHFetchResult<PHAsset>?, with option: kPiwigoSortImages) -> [[PHAsset]] {

        // NOP if no image
        guard let images = images else {
            return [[]]
        }

        // Initialisation
        let components: Set<Calendar.Component>
        switch option {
        case kPiwigoSortImagesByMonths:
            components = [.year, .month]
        case kPiwigoSortImagesByWeeks:
            components = [.year, .weekOfYear]
        default:
            components = [.year, .month, .day]
        }
        var imagesByPeriod: [[PHAsset]] = []
        let calendar = Calendar.current
        var periodComponents = calendar.dateComponents(components, from: images.firstObject?.creationDate ?? Date())
        var imagesOfSamePeriod: [PHAsset] = []

        // Sort imageAssets
        images.enumerateObjects({ obj, idx, stop in

            // Get current image creation date
            let dateComponents = calendar.dateComponents(components, from: obj.creationDate ?? Date())

            // Image taken on the same day?
            if dateComponents == periodComponents {
                // Same date -> Append object to section
                imagesOfSamePeriod.append(obj)
            } else {
                // Append section to collection
                imagesByPeriod.append(imagesOfSamePeriod)

                // Initialise for next items
                imagesOfSamePeriod.removeAll()
                periodComponents = calendar.dateComponents(components, from: obj.creationDate ?? Date())

                // Add current item
                imagesOfSamePeriod.append(obj)
            }
        })

        // Append last section to collection
        imagesByPeriod.append(imagesOfSamePeriod)

        return imagesByPeriod
    }

    private func finishTheJob() {

        // Initialise buttons of sections
        selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count))

        // Loop over all sections to reselect cells
        for section in 0..<sortedImages.count {

            // Number of images in section
            let nberOfImages = sortedImages[section].count

            // Count selected images in section
            var nberOfSelectedImages = 0
            for item in 0..<nberOfImages {
                // Retrieve image asset
                let imageId = sortedImages[section][item].localIdentifier
                // Is this image selected?
                if selectedImages.contains(imageId) {
                    nberOfSelectedImages += 1
                }
            }

            // Update state of Select button
            selectedSections[section] = nberOfImages == nberOfSelectedImages ? NSNumber(value: true) : NSNumber(value: false)
        }

        // Hide HUD
        if self.imageCollection.count > kPiwigoNberImagesShowHUDWhenSorting {
            self.hideHUDwithSuccess(true) {
                DispatchQueue.main.async {
                    // Refresh collection view
                    self.localImagesCollection.reloadData()

                    // Update Select buttons status
                    self.updateSelectButtons()
                    
                    // Show segmented control if needed
                    if self.segmentedControl.isHidden {
                        self.showSegmentedControl()
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()

                // Update Select buttons status
                self.updateSelectButtons()
                
                // Show segmented control if needed
                if self.segmentedControl.isHidden {
                    self.showSegmentedControl()
                }
            }
        }
    }
    

    // MARK: - Action Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })

        // Change sort option
        let sortAction = UIAlertAction(title: CategorySortViewController.getNameForCategorySortType(Model.sharedInstance().localImagesSort), style: .default, handler: { action in
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedDescending:
                Model.sharedInstance().localImagesSort = kPiwigoSortDateCreatedAscending
            case kPiwigoSortDateCreatedAscending:
                Model.sharedInstance().localImagesSort = kPiwigoSortDateCreatedDescending
            default:
                break
            }
            Model.sharedInstance()?.saveToDisk()

            // Sort images
            self.fetchAndSortImages()
        })

//        let uploadedAction = UIAlertAction(title: removedUploadedImages ? "✓ \(NSLocalizedString("localImageSort_notUploaded", comment: "Not Uploaded"))" : NSLocalizedString("localImageSort_notUploaded", comment: "Not Uploaded"), style: .default, handler: { action in
//            // Remove uploaded images?
//            if self.removedUploadedImages {
//                // Store choice
//                self.removedUploadedImages = false
//
//                // Sort images
//                self.performSelector(inBackground: #selector(self.sortImages), with: nil)
//            } else {
//                // Store choice
//                self.removedUploadedImages = true
//
//                // Remove uploaded images from collection
//                self.performSelector(inBackground: #selector(self.removeUploadedImagesFromCollection), with: nil)
//            }
//        })

        // Add actions
        alert.addAction(cancelAction)
        alert.addAction(sortAction)

        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = UIColor.piwigoColorOrange()
        }
    }

    @objc func removeUploadedImagesFromCollection() {
        // Show HUD during download
        DispatchQueue.main.async(execute: {
            self.showHUDwithTitle(NSLocalizedString("imageUploadRemove", comment: "Removing Uploaded Images"))
        })

        // Remove uploaded images from the collection
//        NotUploadedYet.getListOfImageNamesThatArentUploaded(forCategory: categoryId, withImages: imagesInSections, andSelections: selectedSections, onCompletion: { imagesNotUploaded, sectionsToDelete in
//            DispatchQueue.main.async(execute: {
//                // Check returned data
//                if let imagesNotUploaded = imagesNotUploaded {
//                    // Update image list
//                    self.imagesInSections = imagesNotUploaded
//
//                    // Hide HUD
//                    self.hideHUDwithSuccess(true) {
//                        self.hudViewController = nil
//
//                        // Refresh collection view
//                        if let sectionsToDelete = sectionsToDelete {
//                            self.localImagesCollection.deleteSections(sectionsToDelete as IndexSet)
//                        }
//
//                        // Update selections
//                        self.updateSelectButtons()
//                    }
//                } else {
//                    self.hideHUDwithSuccess(false) {
//                        self.hudViewController = nil
//                    }
//                }
//            })
//        })
    }


    // MARK: - Select Images
    
    func updateSelectButtons() {
        // Update status of Select buttons
        // The number of sections may have changed
        let start = CFAbsoluteTimeGetCurrent()
        for section in 0..<localImagesCollection.numberOfSections {
            updateSelectButton(forSection: section)
        }
        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
        print("=> Took \(diff) ms to set up sortedSections")
    }

    @objc func cancelSelect() {
        // Loop over all sections to deselect cells
        for section in 0..<localImagesCollection.numberOfSections {
            // Loop over images in section
            for row in 0..<localImagesCollection.numberOfItems(inSection: section) {
                // Deselect image
                let cell = localImagesCollection.cellForItem(at: IndexPath(row: row, section: (section + 1))) as? LocalImageCollectionViewCell
                cell?.cellSelected = false
            }
        }
        
        // Clear list of selected sections
        selectedSections = [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count)

        // Clear list of selected images
        selectedImages = []

        // Update navigation bar
        updateNavBar()

        // Update collection
        localImagesCollection.reloadData()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Will interpret touches only in horizontal direction
        if (gestureRecognizer is UIPanGestureRecognizer) {
            let gPR = gestureRecognizer as? UIPanGestureRecognizer
            let translation = gPR?.translation(in: localImagesCollection)
            if abs(Float(translation?.x ?? 0.0)) > abs(Float(translation?.y ?? 0.0)) {
                return true
            }
        }
        return false
    }

    @objc func touchedImages(_ gestureRecognizer: UIPanGestureRecognizer?) {
        // To prevent a crash
        if gestureRecognizer?.view == nil {
            return
        }

        // Select/deselect the cell or scroll the view
        if (gestureRecognizer?.state == .began) || (gestureRecognizer?.state == .changed) {

            // Point and direction
            let point = gestureRecognizer?.location(in: localImagesCollection)

            // Get image asset at touch position
            guard let indexPath = localImagesCollection.indexPathForItem(at: point ?? CGPoint.zero) else {
                return
            }

            // Get image asset and cell at touch position
            let imageId = sortedImages[indexPath.section][indexPath.row].localIdentifier
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
                return
            }

            // Update the selection if not already done
            if !touchedImages.contains(imageId) {

                // Store that the user touched this cell during this gesture
                touchedImages.append(imageId)

                // Update the selection state
                if let index = selectedImages.firstIndex(of: imageId) {
                    selectedImages.remove(at: index)
                    cell.cellSelected = false
                } else {
                    // Select the cell
                    selectedImages.append(imageId)
                    cell.cellSelected = true
                }

                // Update navigation bar
                updateNavBar()

                // Refresh cell
                cell.reloadInputViews()

                // Update state of Select button if needed
                updateSelectButton(forSection: indexPath.section)
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizer?.state == .ended {
            touchedImages = []
        }
    }

    func updateSelectButton(forSection section: Int) {
        // Number of images in section
        let nberOfImages = sortedImages[section].count

        // Count selected images in section
        var nberOfSelectedImages = 0
        for item in 0..<nberOfImages {
            // Retrieve image asset
            let imageId = sortedImages[section][item].localIdentifier
            // Is this image selected?
            if selectedImages.contains(imageId) {
                nberOfSelectedImages += 1
            }
        }

        // Update state of Select button only if needed
        if nberOfImages == nberOfSelectedImages {
            if selectedSections[section].boolValue == false {
                selectedSections[section] = NSNumber(value: true)
                localImagesCollection.reloadSections(NSIndexSet(index: section) as IndexSet)
            }
        } else {
            if selectedSections[section].boolValue == true {
                selectedSections[section] = NSNumber(value: false)
                localImagesCollection.reloadSections(NSIndexSet(index: section) as IndexSet)
            }
        }
    }

    @objc func presentImageUploadView() {
        // Reset Select buttons
        selectedSections = [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count)

        // Present Image Upload View
        let imageUploadVC = ImageUploadViewController()
        imageUploadVC.selectedCategory = categoryId
        imageUploadVC.imagesSelected = selectedImages
        navigationController?.pushViewController(imageUploadVC, animated: true)

        // Clear list of selected images
        selectedImages = []
    }

    
    // MARK: - UICollectionView - Headers & Footers
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            if sortedImages.count > 0 {
                guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "LocalImagesHeaderReusableView", for: indexPath) as? LocalImagesHeaderReusableView else {
                    let view = UICollectionReusableView(frame: CGRect.zero)
                    return view
                }
                
                // Set up header
                header.configure(with: sortedImages[indexPath.section], section: indexPath.section,
                                 selectionMode: selectedSections[indexPath.section].boolValue)
                header.headerDelegate = self
                return header
            }
        } else if kind == UICollectionView.elementKindSectionFooter {
            // Footer with number of images
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "LocalImagesFooterReusableView", for: indexPath) as? LocalImagesFooterReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            footer.configure(with: sortedImages[indexPath.section].count)
            return footer
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
            view.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }

    
    // MARK: - UICollectionView - Sections
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sortedImages.count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: kImageMarginsSpacing, bottom: 10, right: kImageMarginsSpacing)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(ImagesCollection.imageCellVerticalSpacing(for: kImageCollectionPopup))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(ImagesCollection.imageCellHorizontalSpacing(for: kImageCollectionPopup))
    }

    
    // MARK: - UICollectionView - Rows
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sortedImages[section].count
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: nberOfImagesPerRow, collectionType: kImageCollectionPopup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        let imageAsset = sortedImages[indexPath.section][indexPath.row]
        cell.configure(with: imageAsset, thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: nberOfImagesPerRow, collectionType: kImageCollectionPopup)))

        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        // Cell state
        cell.cellSelected = selectedImages.contains(imageAsset.localIdentifier)
        let originalFilename = PhotosFetch.sharedInstance().getFileNameFomImageAsset(imageAsset)!
        cell.cellUploading = ImageUploadManager.sharedInstance().imageNamesUploadQueue.contains(URL(fileURLWithPath: originalFilename).deletingPathExtension().absoluteString)
        return cell
    }


    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Image asset
        let imageId = sortedImages[indexPath.section][indexPath.row].localIdentifier

        // Update cell and selection
        if let index = selectedImages.firstIndex(of: imageId) {
            selectedImages.remove(at: index)
            cell.cellSelected = false
        } else {
            // Select the cell
            selectedImages.append(imageId)
            cell.cellSelected = true
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton(forSection: indexPath.section)
    }


    // MARK: - UIScrollViewDelegate Methods
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hideSegmentedControl()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            showSegmentedControl()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        showSegmentedControl()
    }
    
    private func showSegmentedControl() {
        self.segmentedControl.isHidden = false
        UIView.animate(withDuration: 0.3, animations: {
            self.segmentedControl.backgroundColor = Model.sharedInstance().isDarkPaletteActive ? UIColor.piwigoColorGray().withAlphaComponent(0.8) : UIColor.piwigoColorGray().withAlphaComponent(0.4)
            if #available(iOS 13.0, *) {
                self.segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange().withAlphaComponent(1.0)
            } else {
                // Fallback on earlier versions
                self.segmentedControl.tintColor = UIColor.piwigoColorOrange().withAlphaComponent(1.0)
            }
        }) { (done) in
        }
    }
    
    private func hideSegmentedControl() {
        UIView.animate(withDuration: 0.3, animations: {
            self.segmentedControl.backgroundColor = UIColor.piwigoColorGray().withAlphaComponent(0.0)
            if #available(iOS 13.0, *) {
                self.segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange().withAlphaComponent(0.0)
            } else {
                // Fallback on earlier versions
                self.segmentedControl.tintColor = UIColor.piwigoColorOrange().withAlphaComponent(0.0)
            }
        }) { (done) in
            self.segmentedControl.isHidden = true
        }
    }
    
    
    // MARK: - HUD methods
    
    func showHUDwithTitle(_ title: String?) {
        // Determine the present view controller if needed (not necessarily self.view)
        if hudViewController == nil {
            hudViewController = UIApplication.shared.keyWindow?.rootViewController
            while ((hudViewController?.presentedViewController) != nil) {
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
        hud?.mode = MBProgressHUDMode.indeterminate
        let numberFormatter = NumberFormatter()
        numberFormatter.positiveFormat = "#,##0"
        let nberPhotos = numberFormatter.string(from: NSNumber(value: imageCollection.count))!
        hud?.detailsLabel.text = String(format: "%@ %@", nberPhotos, NSLocalizedString("severalImages", comment: "Photos"))
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
                    hud?.hide(animated: true, afterDelay: 1.0)
                } else {
                    hud?.hide(animated: true)
                }
            }
            completion()
        })
    }


    // MARK: - ImageUploadProgress Delegate Methods

    func imageProgress(_ image: ImageUpload?, onCurrent current: Int, forTotal total: Int, onChunk currentChunk: Int, forChunks totalChunks: Int, iCloudProgress: CGFloat) {
        print("AlbumUploadViewController[imageProgress:]")
        guard let indexPath = indexPathOfImageAsset(image?.imageAsset) else {
            return
        }
        guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        let chunkPercent: CGFloat = CGFloat(100.0 / Float(totalChunks) / 100.0)
        let onChunkPercent = chunkPercent * CGFloat((currentChunk - 1))
        let pieceProgress = CGFloat(current) / CGFloat(total)
        var uploadProgress = onChunkPercent + (chunkPercent * pieceProgress)
        if uploadProgress > 1 {
            uploadProgress = 1
        }

        cell.cellUploading = true
        if iCloudProgress < 0 {
            cell.progress = uploadProgress
        print(String(format: "AlbumUploadViewController[ImageProgress]: %.2f", uploadProgress))
        } else {
            cell.progress = (iCloudProgress + uploadProgress) / 2.0
        print(String(format: "AlbumUploadViewController[ImageProgress]: %.2f", (iCloudProgress + uploadProgress) / 2.0))
        }
    }

    func imageUploaded(_ image: ImageUpload?, placeInQueue rank: Int, outOf totalInQueue: Int, withResponse response: [AnyHashable : Any]?) {
        print("AlbumUploadViewController[imageUploaded:]")
        guard let indexPath = indexPathOfImageAsset(image?.imageAsset) else {
            return
        }
        guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Image upload ended, deselect cell
        cell.cellUploading = false
        cell.cellSelected = false
        if let imageAsset = image?.imageAsset {
            if selectedImages.contains(imageAsset.localIdentifier) {
                selectedImages.removeAll { $0 as AnyObject === image?.imageAsset.localIdentifier as AnyObject }
            }
        }

        // Update list of "Not Uploaded" images
//        if removedUploadedImages {
//            var newList = imagesInSections
//            newList?.removeAll { $0 as AnyObject === image?.imageAsset as AnyObject }
//            imagesInSections = newList
//
//            // Update image cell
//            localImagesCollection.reloadItems(at: [indexPath].compactMap { $0 })
//        }
    }

    private func indexPathOfImageAsset(_ imageAsset: PHAsset?) -> IndexPath? {
        var indexPath = IndexPath(item: 0, section: 0)

        // Loop over all sections
        for section in 0..<localImagesCollection.numberOfSections {
            // Index of image in section?
            var item: Int? = nil
            if let imageAsset = imageAsset {
                item = sortedImages[section].firstIndex(of: imageAsset) ?? NSNotFound
            }
            if item != NSNotFound {
                indexPath = IndexPath(item: item ?? 0, section: section)
                break
            }
        }
        return indexPath
    }

    
    // MARK: - Changes occured in the Photo library

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes,
        // and update the cached fetch results, and reload the table sections to match.
        DispatchQueue.main.async(execute: {
            if let changeDetails = changeInstance.changeDetails(for: self.assetCollections) {
                // Update fetched asset collection
                self.assetCollections = changeDetails.fetchResultAfterChanges

                // Fetch images in selected collection
                self.fetchAndSortImages()
            }
        })
    }

    
    // MARK: - LocalImagesHeaderReusableView Delegate Methods
    
    func didSelectImagesOfSection(_ section: Int) {
        // Loop over all images in section
        for item in 0..<sortedImages[section].count {

            // Corresponding image asset
            let imageId = sortedImages[section][item].localIdentifier

            // Corresponding collection view cell
            let indexPath = IndexPath(item: item, section: section)
            let selectedCell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell

            // Select or deselect cell
            if selectedSections[section].boolValue == true {
                // Deselect the cell
                if let index = selectedImages.firstIndex(of: imageId) {
                    selectedImages.remove(at: index)
                    selectedCell?.cellSelected = false
                }
            } else {
                // Select the cell
                if !selectedImages.contains(imageId) {
                    selectedImages.append(imageId)
                    selectedCell?.cellSelected = true
                }
            }
        }

        // Update navigation bar
        updateNavBar()

        // Update section
        updateSelectButton(forSection: section)
    }

    
    // MARK: - NotUploadedYet Delegate Methods
    
    func showProgress(withSubTitle title: String?) {
        MBProgressHUD(for: (hudViewController?.view)!)?.detailsLabel.text = title
    }
}
