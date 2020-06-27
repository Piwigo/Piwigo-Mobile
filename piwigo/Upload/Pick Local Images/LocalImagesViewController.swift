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

enum SectionType: Int {
    case month
    case week
    case day
    case all
}

@objc
class LocalImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, UIScrollViewDelegate, PHPhotoLibraryChangeObserver, LocalImagesHeaderDelegate /*, ImageUploadProgressDelegate */ {
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    

    // MARK: - View
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
    
    @IBOutlet weak var sortOptionsView: UIView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private var imageCollection: PHFetchResult<PHAsset>!                    // Collection of images in selected non-empty local album
    private var sortType: SectionType = .all                                // [Months, Weeks, Days, All images in one section]
    private var indexOfImageSortedByMonth: [IndexSet] = []                  // Indices of images sorted by month, week and day
    private var indexOfImageSortedByWeek: [IndexSet] = []
    private var indexOfImageSortedByDay: [IndexSet] = []

    private var uploadsInQueue = [(String?,kPiwigoUploadState?)?]()                     // Array of uploads in queue at start
    private var indexedUploadsInQueue = [(String?,kPiwigoUploadState?)?]()              // Arrays of uploads at indices of corresponding image
    private var selectedImages = [UploadProperties?]()                                  // Array of images to upload
    private var selectedSections = [LocalImagesHeaderReusableView.SelectButtonState]()  // State of Select buttons
    private var imagesBeingTouched = [IndexPath]()                                      // Array of indexPaths of touched images
    
    private var actionBarButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    
    private var removeUploadedImages = false
    private var hudViewController: UIViewController?


    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Check collection Id
        if imageCollectionId.count == 0 {
            PhotosFetch.sharedInstance().showPhotosLibraryAccessRestricted(in: self)
        }

        // Fetch a specific path of the Photos Library to reduce the workload and store the fetched assets for future use
        fetchImagesByCreationDate(assetCollections: PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil))
        
        // Initialise arrays
        selectedImages = .init(repeating: nil, count: imageCollection.count)            // At start, there is no image selected
        selectedSections = .init(repeating: .none, count: imageCollection.count)        // User cannot select sections of images until data is ready
        if let uploads = uploadsProvider.fetchedResultsController.fetchedObjects {       // We provide a non-indexed list of images in the upload queue
            uploadsInQueue = uploads.map {($0.localIdentifier, $0.state)}
        }                                                                               // so that we can at least show images in upload queue at start
                                                                                        // and prevent their selection
        // Sort images in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.sortImagesAndIndexUploads()
        }
        
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
        uploadBarButton = UIBarButtonItem(image: UIImage(named: "upload"), style: .plain, target: self, action: #selector(didTapUploadButton))
        
        // Segmented control (choice for presenting images by month, week, day or in a single collection)
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange()
        } else {
            segmentedControl.tintColor = UIColor.piwigoColorOrange()
        }
        segmentedControl.selectedSegmentIndex = Int(sortType.rawValue)
        segmentedControl.setEnabled(false, forSegmentAt: SectionType.month.rawValue)
        segmentedControl.setEnabled(false, forSegmentAt: SectionType.week.rawValue)
        segmentedControl.setEnabled(false, forSegmentAt: SectionType.day.rawValue)
        segmentedControl.superview?.layer.cornerRadius = segmentedControl.layer.cornerRadius
        
        // Show images in upload queue by default
        removeUploadedImages = false
    }


    @objc func applyColorPalette() {
        // Background color of the views
        view.backgroundColor = UIColor.piwigoColorBackground()
        sortOptionsView.backgroundColor = UIColor.piwigoColorBackground()

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
        segmentedControl.superview?.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.8)
        if #available(iOS 13.0, *) {
            // Keep standard background color
            segmentedControl.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
        } else {
            segmentedControl.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.08, alpha: 0.06666)
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

        // Register Photo Library changes
        PHPhotoLibrary.shared().register(self)

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
        
        // Register upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress), name: name2, object: nil)
        
        // Prevent device from sleeping if uploads are in progress
        let uploadsToPerform = uploadsProvider.fetchedResultsController.fetchedObjects?.map({
            ($0.state == .waiting) || ($0.state == .preparing) || ($0.state == .prepared) ||
            ($0.state == .uploading) || ($0.state == .finishing) ? 1 : 0}).reduce(0, +) ?? 0
        if uploadsToPerform > 0 {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = localImagesCollection.visibleCells.first {
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
        
        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false

        // Register Photo Library changes
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
        
        // Unregister palette changes
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name2, object: nil)
    }

    func updateNavBar() {
        let nberOfSelectedImages = selectedImages.compactMap{ $0 }.count
        switch nberOfSelectedImages {
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
                title = String(format:NSLocalizedString("selectImagesSelected", comment: "%@ Photos Selected"), NSNumber(value: nberOfSelectedImages))
        }
    }

    
    // MARK: - Fetch and Sort Images
    
    func fetchImagesByCreationDate(assetCollections: PHFetchResult<PHAssetCollection>) -> Void {
        /**
         Fetch non-empty collection previously selected by user.
         We fetch a specific path of the Photos Library to reduce the workload and store the fetched collection for future use.
         The fetch is performed with ascending creation date.
         */
//        let start = CFAbsoluteTimeGetCurrent()
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//        fetchOptions.predicate = NSPredicate(format: "isHidden == false")     // From 0.2 to 2.2s for 70k images when activated
        imageCollection = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Fetched \(imageCollection.count) assets in \(diff) ms")
    }
    
    // Sorts images by months, weeks and days in the background,
    // initialise the array of selected sections and enable the choices
    private func sortImagesAndIndexUploads() -> Void {
       
        // Sort all images in one loop i.e. O(n)
        let queue = OperationQueue()
//        queue.maxConcurrentOperationCount = 1   // Make it a serial queue for debugging
        let operation1 = BlockOperation.init(block: {
            // Sort images by months, weeks and days in the background
            (self.indexOfImageSortedByDay, self.indexOfImageSortedByWeek, self.indexOfImageSortedByMonth) = self.sortByMonthWeekDay(images: self.imageCollection)

            // Update interface
            DispatchQueue.main.async {
                // Enable segments
                self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.month.rawValue)
                self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.week.rawValue)
                self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.day.rawValue)
            }
        })
        let operation2 = BlockOperation.init(block: {
            // Index the images in the upload queue
            self.indexUploads(images: self.imageCollection)
        })
        queue.addOperations([operation1, operation2], waitUntilFinished: true)

        // Initialise buttons of sections for the max number of sections
        self.selectedSections = .init(repeating: .select, count: self.indexOfImageSortedByDay.count)
        
        // Update interface
        DispatchQueue.main.async {
            // Hide HUD (displayed when Photo Library motifies changes)
            self.hideHUDwithSuccess(true) {
                // Enable Select buttons
                self.localImagesCollection.reloadData()
            }
            
            // Below code is slower… Bizarre
//            let indexPaths = self.localImagesCollection.indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader)
//            for indexPath in indexPaths {
//                self.localImagesCollection.reloadSections(IndexSet.init(integer: indexPath.section))
//            }
        }
    }

    private func sortByMonthWeekDay(images: PHFetchResult<PHAsset>) -> (imagesByDay: [IndexSet], imagesByWeek: [IndexSet], imagesByMonth: [IndexSet])  {

        // Initialisation
//        let start = CFAbsoluteTimeGetCurrent()
//        print("=> Start sorting images…")
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images[0].creationDate ?? Date())
        var firstIndexOfSameDay = 0
        var imagesByDay: [IndexSet] = []

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images[0].creationDate ?? Date())
        var firstIndexOfSameWeek = 0
        var imagesByWeek: [IndexSet] = []

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images[0].creationDate ?? Date())
        var firstIndexOfSameMonth = 0
        var imagesByMonth: [IndexSet] = []
        
        // Sort imageAssets
        for index in 0..<images.count {
            // Get day of current image
            let creationDate = images[index].creationDate ?? Date()
            let newDayComponents = calendar.dateComponents(byDays, from: creationDate)

            // Image taken the same day?
            if newDayComponents == dayComponents {
                // Same date -> Next image
                continue
            } else {
                // Append section to collection by days
                imagesByDay.append(IndexSet.init(integersIn: firstIndexOfSameDay..<index))
                                
                // Initialise for next day
                firstIndexOfSameDay = index
                dayComponents = calendar.dateComponents(byDays, from: creationDate)
                
                // Get week of year of new image
                let newWeekComponents = calendar.dateComponents(byWeeks, from: creationDate)
                
                // What should we do with this new image?
                if newWeekComponents != weekComponents {
                    // Append section to collection by weeks
                    imagesByWeek.append(IndexSet.init(integersIn: firstIndexOfSameWeek..<index))
                    
                    // Initialise for next week
                    firstIndexOfSameWeek = index
                    weekComponents = newWeekComponents
                }

                // Get month of new image
                let newMonthComponents = calendar.dateComponents(byMonths, from: creationDate)
                
                // What should we do with this new image?
                if newMonthComponents != monthComponents {
                    // Append section to collection by months
                    imagesByMonth.append(IndexSet.init(integersIn: firstIndexOfSameMonth..<index))
                    
                    // Initialise for next month
                    firstIndexOfSameMonth = index
                    monthComponents = newMonthComponents
                }
            }
        }
        
        // Append last section to collection
        imagesByDay.append(IndexSet.init(integersIn: firstIndexOfSameDay..<images.count))
        imagesByWeek.append(IndexSet.init(integersIn: firstIndexOfSameWeek..<images.count))
        imagesByMonth.append(IndexSet.init(integersIn: firstIndexOfSameMonth..<images.count))
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   Sorted \(imageCollection.count) images by days, weeks and months in \(diff) ms")
        return (imagesByDay, imagesByWeek, imagesByMonth)
    }
    
    private func indexUploads(images: PHFetchResult<PHAsset>) -> (Void) {
        // Loop over all images
//        let start = CFAbsoluteTimeGetCurrent()
//        print("=> Start indexing uploads…")
        indexedUploadsInQueue = []
        for index in 0..<images.count {
            // Get image identifier
            let imageId = images[index].localIdentifier
            if let upload = uploadsInQueue.first(where: { $0?.0 == imageId }) {
                indexedUploadsInQueue.append(upload)
            } else {
                indexedUploadsInQueue.append(nil)
            }
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   indexed \(imageCollection.count) uploads in \(diff) ms")
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
            self.localImagesCollection.reloadData()
        })

//        let uploadedAction = UIAlertAction(title: removeUploadedImages ? NSLocalizedString("localImageSort_notUploaded", comment: "Not Uploaded") : "✓ \(NSLocalizedString("localImageSort_notUploaded", comment: "Not Uploaded"))", style: .default, handler: { action in
//            // Remove uploaded images?
//            if self.removeUploadedImages {
//                // Store choice
//                self.removeUploadedImages = false
//
//                // Sort images
//                self.localImagesCollection.reloadData()
//            } else {
//                // Store choice
//                self.removeUploadedImages = true
//
//                // Remove uploaded images from collection
//                self.localImagesCollection.reloadData()
//            }
//        })

        // Add actions
        alert.addAction(cancelAction)
//        alert.addAction(uploadedAction)
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

    @IBAction func didChangeSortOption(_ sender: UISegmentedControl) {
        // Did select new sort option [Months, Weeks, Days, All in one section]
        sortType = SectionType(rawValue: sender.selectedSegmentIndex) ?? .all
                
//        // Sort images as requested using cached arrays
//        switch sortType {
//        case .month:
//            self.sortedImages = self.imagesSortedByMonth
//            // Refresh collection (may be called from background queue)
//            DispatchQueue.main.async {
//                // Refresh collection view
//                self.localImagesCollection.reloadData()
//            }
//        case .week:
//            self.sortedImages = self.imagesSortedByWeek
//            // Refresh collection (may be called from background queue)
//            DispatchQueue.main.async {
//                // Refresh collection view
//                self.localImagesCollection.reloadData()
//            }
//        case .day:
//            self.sortedImages = self.imagesSortedByDay
//            // Refresh collection (may be called from background queue)
//            DispatchQueue.main.async {
//                // Refresh collection view
//                self.localImagesCollection.reloadData()
//            }
//        case .all:
            // Refresh collection (may be called from background queue)
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()
            }
//        }
    }
        
    @objc func didTapUploadButton() {
        // Add selected images to upload queue
        uploadsProvider.importUploads(from: selectedImages.compactMap{ $0 }) { error in
            
              DispatchQueue.main.async {
                // Show an alert if there was an error.
                guard let error = error else {
                    // Launch upload tasks
                    UploadManager.sharedInstance()?.findNextImageToUpload(endPrepare: false, endUpload: false, endFinish: false)
                    return
                }
                let alert = UIAlertController(title: NSLocalizedString("CoreDataFetch_UploadCreateFailed", comment: "Failed to create a new Upload object."),
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"),
                                              style: .default, handler: nil))
                alert.view.tintColor = UIColor.piwigoColorOrange()
                if #available(iOS 13.0, *) {
                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                } else {
                    // Fallback on earlier versions
                }
                self.present(alert, animated: true, completion: {
                    // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                    alert.view.tintColor = UIColor.piwigoColorOrange()
                })
            }
        }
    }
    

    // MARK: - Select Images
    
    @objc func cancelSelect() {
        // Clear list of selected sections
        selectedSections = .init(repeating: .select, count: indexOfImageSortedByDay.count)

        // Clear list of selected images
        selectedImages = Array(repeating: nil, count: imageCollection.count)

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

        // Point and direction
        let point = gestureRecognizer?.location(in: localImagesCollection)

        // Get index path at touch position
        guard let indexPath = localImagesCollection.indexPathForItem(at: point ?? CGPoint.zero) else {
            return
        }

        // Select/deselect the cell or scroll the view
        if (gestureRecognizer?.state == .began) || (gestureRecognizer?.state == .changed) {

            // Get cell at touch position
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
                return
            }

            // Images in the upload queue cannot be selected
            let index = getImageIndex(for: indexPath)
            
            // Update the selection if not already done
            if !imagesBeingTouched.contains(indexPath) {

                // Store that the user touched this cell during this gesture
                imagesBeingTouched.append(indexPath)

                // Update the selection state
                if let _ = selectedImages[index] {
                    selectedImages[index] = nil
                    cell.cellSelected = false
                } else {
                    // Can we select this image?
                    if indexedUploadsInQueue.count < index {
                        // Use non-indexed data (might be quite slow)
                        if let _ = uploadsInQueue.firstIndex(where: { $0?.0 == cell.localIdentifier }) { return }
                    } else {
                        // Indexed uploads available
                        if indexedUploadsInQueue[index] != nil { return }
                    }

                    // Select the cell
                    selectedImages[index] = UploadProperties.init(localIdentifier: cell.localIdentifier, category: categoryId)
                    cell.cellSelected = true
                }

                // Update navigation bar
                updateNavBar()

                // Refresh cell
                cell.reloadInputViews()
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizer?.state == .ended {
            // Clear list of touched images
            imagesBeingTouched = []

            // Update state of Select button if needed
            updateSelectButton(ofSection: indexPath.section, completion: {
                self.localImagesCollection.reloadSections(NSIndexSet(index: indexPath.section) as IndexSet)
            })
        }
    }

    func updateSelectButton(ofSection section: Int, completion: @escaping () -> Void) {
        
        // Number of images in section
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)

        // Get start and last indices of section
        let firstIndex: Int, lastIndex: Int
        if Model.sharedInstance().localImagesSort == kPiwigoSortDateCreatedAscending {
            firstIndex = getImageIndex(for: IndexPath.init(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath.init(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath.init(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath.init(item: 0, section: section))
        }

        // Number of selected images
        let nberOfSelectedImagesInSection = selectedImages[firstIndex...lastIndex].compactMap{ $0 }.count
        if nberOfImagesInSection == nberOfSelectedImagesInSection {
            // All images are selected
            if selectedSections[section] != .deselect {
                selectedSections[section] = .deselect
                completion()
            }
            return
        }

        // Can we calculate the number of images already in the upload queue?
        if indexedUploadsInQueue.count < lastIndex + 1 {
            // Keep Select button disabled
            if selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
            return
        }

        // Number of images already in the upload queue
        let nberOfImagesOfSectionInUploadQueue = indexedUploadsInQueue[firstIndex...lastIndex].compactMap{ $0 }.count

        // Update state of Select button only if needed
        if nberOfImagesInSection == nberOfImagesOfSectionInUploadQueue {
            // All images are in the upload queue or already downloaded
            if selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
        } else if nberOfImagesInSection == nberOfSelectedImagesInSection + nberOfImagesOfSectionInUploadQueue {
            // All images are either selected or in the upload queue
            if selectedSections[section] != .deselect {
                selectedSections[section] = .deselect
                completion()
            }
        } else {
            // Not all images are either selected or in the upload queue
            if selectedSections[section] != .select {
                selectedSections[section] = .select
                completion()
            }
        }
    }
    
    
    // MARK: - UICollectionView - Headers & Footers
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // Header with place name
        if kind == UICollectionView.elementKindSectionHeader {
            // Images sorted by month, week or day
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "LocalImagesHeaderReusableView", for: indexPath) as? LocalImagesHeaderReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
                
            // Update section if available data
            updateSelectButton(ofSection: indexPath.section, completion: {})
            
            // Determine place names from first images
            var imageAssets: [PHAsset] = []
            for row in 0..<min(localImagesCollection.numberOfItems(inSection: indexPath.section), 20) {
                let index = getImageIndex(for: IndexPath.init(item: row, section: indexPath.section))
                imageAssets.append(imageCollection[index])
            }
            
            // Configure the header
            header.configure(with: imageAssets, section: indexPath.section, selectState: selectedSections[indexPath.section])
            header.headerDelegate = self
            return header
        }
        else if kind == UICollectionView.elementKindSectionFooter {
            // Footer with number of images
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "LocalImagesFooterReusableView", for: indexPath) as? LocalImagesFooterReusableView else {
                let view = UICollectionReusableView(frame: CGRect.zero)
                return view
            }
            footer.configure(with: localImagesCollection.numberOfItems(inSection: indexPath.section))
            return footer
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if (elementKind == UICollectionView.elementKindSectionHeader) || (elementKind == UICollectionView.elementKindSectionFooter) {
            view.layer.zPosition = 0 // Below scroll indicator
        }
    }

    
    // MARK: - UICollectionView - Sections
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // Number of sections depends on image sort type
        switch sortType {
        case .month:
            return indexOfImageSortedByMonth.count
        case .week:
            return indexOfImageSortedByWeek.count
        case .day:
            return indexOfImageSortedByDay.count
        case .all:
            return 1
        }
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
        // Number of items depends on image sort type and date order
        switch sortType {
        case .month:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByMonth[section].count
            case kPiwigoSortDateCreatedDescending:
                return indexOfImageSortedByMonth[indexOfImageSortedByMonth.count - 1 - section].count
            default:
                return 0
            }
        case .week:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByWeek[section].count
            case kPiwigoSortDateCreatedDescending:
                return indexOfImageSortedByWeek[indexOfImageSortedByWeek.count - 1 - section].count
            default:
                return 0
            }
        case .day:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByDay[section].count
            case kPiwigoSortDateCreatedDescending:
                return indexOfImageSortedByDay[indexOfImageSortedByDay.count - 1 - section].count
            default:
                return 0
            }
        case .all:
            return imageCollection.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Calculate the optimum image size
        let size = CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        
        // Get image asset, index depends on image sort type and date order
        let index = getImageIndex(for: indexPath)
        let imageAsset = imageCollection[index]

        // Configure cell with image asset
        cell.configure(with: imageAsset, thumbnailSize: CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup)))

        // Add pan gesture recognition
        let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
        imageSeriesRocognizer.minimumNumberOfTouches = 1
        imageSeriesRocognizer.maximumNumberOfTouches = 1
        imageSeriesRocognizer.cancelsTouchesInView = false
        imageSeriesRocognizer.delegate = self
        cell.addGestureRecognizer(imageSeriesRocognizer)
        cell.isUserInteractionEnabled = true

        // Cell state
        if indexedUploadsInQueue.count == imageCollection.count {
            // Use indexed data
            if let state = indexedUploadsInQueue[index]?.1 {
                switch state {
                case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                    cell.cellWaiting = true
                case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                    cell.cellUploading = true
                case .finished:
                    cell.cellUploaded = true
                }
            } else {
                cell.cellSelected = selectedImages[index] != nil
            }
        } else {
            // Use non-indexed data
            if let upload = uploadsInQueue.first(where: { $0?.0 == imageAsset.localIdentifier }) {
                switch upload?.1 {
                case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                    cell.cellWaiting = true
                case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                    cell.cellUploading = true
                case .finished:
                    cell.cellUploaded = true
                case .none:
                    cell.cellSelected = false
                }
            } else {
                cell.cellSelected = selectedImages[index] != nil
            }
        }
        return cell
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        let localIdentifier =  (notification.userInfo?["localIndentifier"] ?? "") as! String
        let progressFraction = (notification.userInfo?["progressFraction"] ?? 0.0) as! Float
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        for indexPath in indexPathsForVisibleItems {
            let index = getImageIndex(for: indexPath)
            let imageAsset = imageCollection[index]
            if imageAsset.localIdentifier == localIdentifier {
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                    cell.setProgress(progressFraction, withAnimation: true)
                }
            }
        }
    }

    
    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Images in the upload queue cannot be selected
        let index = getImageIndex(for: indexPath)
        if indexedUploadsInQueue.count < index {
            // Use non-indexed data (might be quite slow)
            if let _ = uploadsInQueue.first(where: { $0?.0 == cell.localIdentifier }) { return }
        } else {
            // Indexed uploads available
            if indexedUploadsInQueue[index] != nil { return }
        }

        // Update cell and selection
        if let _ = selectedImages[index] {
            // Deselect the cell
            selectedImages[index] = nil
            cell.cellSelected = false
        } else {
            // Select the cell
            selectedImages[index] = UploadProperties.init(localIdentifier: cell.localIdentifier, category: categoryId)
            cell.cellSelected = true
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton(ofSection: indexPath.section, completion: {
            self.localImagesCollection.reloadSections(IndexSet(integer: indexPath.section))
        })
    }


    // MARK: - HUD methods
    
    func showHUD(with title: String?, detail: String?) {
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
        hud?.detailsLabel.text = detail
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
                    hud?.hide(animated: true, afterDelay: 0.3)
                } else {
                    hud?.hide(animated: true)
                }
            }
            completion()
        })
    }


    // MARK: - Changes occured in the Photo library

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check each of the fetches for changes,
        // and update the cached fetch results, and reload the table sections to match.
        DispatchQueue.main.async(execute: {
            if let changeDetails = changeInstance.changeDetails(for: self.imageCollection) {
                // Show HUD during update, preventing touches
                self.showHUD(with: NSLocalizedString("editImageDetailsHUD_updatingPlural", comment: "Updating Photos…"), detail: nil)
                // Update fetched asset collection
                self.imageCollection = changeDetails.fetchResultAfterChanges
                // Sort images in foreground
                self.sortImagesAndIndexUploads()
            }
        })
    }

    
    // MARK: - LocalImagesHeaderReusableView Delegate Methods
    
    func didSelectImagesOfSection(_ section: Int) {
        let nberOfImagesInSection = localImagesCollection.numberOfItems(inSection: section)
        let firstIndex: Int, lastIndex: Int
        if Model.sharedInstance().localImagesSort == kPiwigoSortDateCreatedAscending {
            firstIndex = getImageIndex(for: IndexPath.init(item: 0, section: section))
            lastIndex = getImageIndex(for: IndexPath.init(item: nberOfImagesInSection - 1, section: section))
        } else {
            firstIndex = getImageIndex(for: IndexPath.init(item: nberOfImagesInSection - 1, section: section))
            lastIndex = getImageIndex(for: IndexPath.init(item: 0, section: section))
        }
//        let start = CFAbsoluteTimeGetCurrent()
        if selectedSections[section] == .select {
            if nberOfImagesInSection < 1_000 {
                // Select all images in one go
                var batch = selectedImages[firstIndex...lastIndex]
                selectImagesInSection(from: firstIndex, in: &batch)
                selectedImages[firstIndex...lastIndex] = batch
            } else {
                // Show HUD during job
                DispatchQueue.main.async {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = .decimal
                    let nberStr = numberFormatter.string(from: NSNumber(value: nberOfImagesInSection))!
                    self.showHUD(with: NSLocalizedString("imageSelectingHUD", comment: "Selecting…"),
                                 detail: String(format: "%@ %@", nberStr, NSLocalizedString("severalImages", comment: "Photos")))
                }
                // Select images in parallel tasks
                let queue = OperationQueue()
    //            queue.maxConcurrentOperationCount = 1   // Make it a serial queue for debugging
                let (nberOfImagesInJob, leftImages) = nberOfImagesInSection.quotientAndRemainder(dividingBy: 3)
                var operations = [BlockOperation]()
                var batch1 = selectedImages[firstIndex..<firstIndex + nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.selectImagesInSection(from: firstIndex, in: &batch1)}))
                var batch2 = selectedImages[firstIndex + nberOfImagesInJob..<firstIndex + 2*nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.selectImagesInSection(from: firstIndex + nberOfImagesInJob, in: &batch2)}))
                var batch3 = selectedImages[firstIndex + 2*nberOfImagesInJob..<firstIndex + 3*nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.selectImagesInSection(from: firstIndex + 2*nberOfImagesInJob, in: &batch3)}))
                var batch4: ArraySlice<UploadProperties?>?
                if leftImages > 0 {
                    batch4 = selectedImages[firstIndex + 3*nberOfImagesInJob...lastIndex]
                    operations.append(BlockOperation.init(block: {self.selectImagesInSection(from: firstIndex + 3*nberOfImagesInJob, in: &(batch4!))}))
                }
                queue.addOperations(operations, waitUntilFinished: true)
                selectedImages[firstIndex..<firstIndex + nberOfImagesInJob] = batch1
                selectedImages[firstIndex + nberOfImagesInJob..<firstIndex + 2*nberOfImagesInJob] = batch2
                selectedImages[firstIndex + 2*nberOfImagesInJob..<firstIndex + 3*nberOfImagesInJob] = batch3
                if let batch = batch4 { selectedImages[firstIndex + 3*nberOfImagesInJob..<lastIndex] = batch }
            }
            // Change section button state
            selectedSections[section] = .deselect
        } else {
            if nberOfImagesInSection < 1_000 {
                // Deselect all images in one go
                var batch = selectedImages[firstIndex...lastIndex]
                deselectImagesInSection(from: firstIndex, in: &batch)
                selectedImages[firstIndex...lastIndex] = batch
            } else {
                // Show HUD during job
                DispatchQueue.main.async {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.numberStyle = .decimal
                    let nberStr = numberFormatter.string(from: NSNumber(value: nberOfImagesInSection))!
                    self.showHUD(with: NSLocalizedString("imageDeselectingHUD", comment: "Deselecting…"),
                                 detail: String(format: "%@ %@", nberStr, NSLocalizedString("severalImages", comment: "Photos")))
                }
                // Select images in parallel tasks
                let queue = OperationQueue()
//                queue.maxConcurrentOperationCount = 1   // Make it a serial queue for debugging
                let (nberOfImagesInJob, leftImages) = nberOfImagesInSection.quotientAndRemainder(dividingBy: 3)
                var operations = [BlockOperation]()
                var batch1 = selectedImages[firstIndex..<firstIndex + nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.deselectImagesInSection(from: firstIndex, in: &batch1)}))
                var batch2 = selectedImages[firstIndex + nberOfImagesInJob..<firstIndex + 2*nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.deselectImagesInSection(from: firstIndex + nberOfImagesInJob, in: &batch2)}))
                var batch3 = selectedImages[firstIndex + 2*nberOfImagesInJob..<firstIndex + 3*nberOfImagesInJob]
                operations.append(BlockOperation.init(block: {self.deselectImagesInSection(from: firstIndex + 2*nberOfImagesInJob, in: &batch3)}))
                var batch4: ArraySlice<UploadProperties?>?
                if leftImages > 0 {
                    batch4 = selectedImages[firstIndex + 3*nberOfImagesInJob...lastIndex]
                    operations.append(BlockOperation.init(block: {self.deselectImagesInSection(from: firstIndex + 3*nberOfImagesInJob, in: &(batch4!))}))
                }
                queue.addOperations(operations, waitUntilFinished: true)
                selectedImages[firstIndex..<firstIndex + nberOfImagesInJob] = batch1
                selectedImages[firstIndex + nberOfImagesInJob..<firstIndex + 2*nberOfImagesInJob] = batch2
                selectedImages[firstIndex + 2*nberOfImagesInJob..<firstIndex + 3*nberOfImagesInJob] = batch3
                if let batch = batch4 { selectedImages[firstIndex + 3*nberOfImagesInJob..<lastIndex] = batch }
            }
            // Change section button state
            selectedSections[section] = .select
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Select/Deselect \(localImagesCollection.numberOfItems(inSection: section)) images of section \(section) took \(diff) ms")

        // Hide HUD at end of job
        DispatchQueue.main.async {
            self.hideHUDwithSuccess(true) {
                // Update navigation bar
                self.updateNavBar()

                // Update collection
                self.localImagesCollection.reloadData()
            }
        }
    }

    private func selectImagesInSection(from firstIndex: Int, in batch: inout ArraySlice<UploadProperties?>) -> (Void) {
        // Loop over all images in section to select them
        for index in firstIndex..<firstIndex + batch.count {
            // Images in the upload queue cannot be selected
            if indexedUploadsInQueue[index] == nil {
                // Select image if not already selected
                if batch[index] == nil {
                    let imageId = imageCollection[index].localIdentifier
                    batch[index] = UploadProperties.init(localIdentifier: imageId, category: self.categoryId)
                }
            }
        }
    }

    private func deselectImagesInSection(from firstIndex: Int, in batch: inout ArraySlice<UploadProperties?>) -> (Void) {
        // Loop over all images in section to select them
        for index in firstIndex..<firstIndex + batch.count {
            // Deselect any image
            batch[index] = nil
        }
    }

    // MARK: - utilities
    
    private func getImageIndex(for indexPath:IndexPath) -> Int {
        switch sortType {
        case .month:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByMonth[indexPath.section].first! + indexPath.row
            case kPiwigoSortDateCreatedDescending:
                let lastSection = indexOfImageSortedByMonth.endIndex - 1
                return indexOfImageSortedByMonth[lastSection - indexPath.section].last! - indexPath.row
            default:
                return 0
            }
        case .week:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByWeek[indexPath.section].first! + indexPath.row
            case kPiwigoSortDateCreatedDescending:
                let lastSection = indexOfImageSortedByWeek.endIndex - 1
                return indexOfImageSortedByWeek[lastSection - indexPath.section].last! - indexPath.row
            default:
                return 0
            }
        case .day:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexOfImageSortedByDay[indexPath.section].first! + indexPath.row
            case kPiwigoSortDateCreatedDescending:
                let lastSection = indexOfImageSortedByDay.endIndex - 1
                return indexOfImageSortedByDay[lastSection - indexPath.section].last! - indexPath.row
            default:
                return 0
            }
        case .all:
            switch Model.sharedInstance().localImagesSort {
            case kPiwigoSortDateCreatedAscending:
                return indexPath.row
            case kPiwigoSortDateCreatedDescending:
                return imageCollection.count - 1 - indexPath.row
            default:
                return 0
            }
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

extension LocalImagesViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
//            print("••• LocalImagesViewController controller:insert...")
            // Image added to upload queue
            if let upload:Upload = anObject as? Upload {
                // Append upload to non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[index] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                } else {
                    uploadsInQueue.append((upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState)))
                }
                // Get index of uploaded image
                if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                    // Deselect image
                    selectedImages[indexOfUploadedImage] = nil
                    // Add image to indexed upload queue
                    indexedUploadsInQueue[indexOfUploadedImage] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        case .delete:
//            print("••• LocalImagesViewController controller:delete...")
            // Image removed from upload queue
            if let upload:Upload = anObject as? Upload {
                // Remove upload from non-indexed upload queue
                if let index = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue.remove(at: index)
                }
                // Get index of uploaded image
                if let indexOfUploadedImage = selectedImages.firstIndex(where: { $0?.localIdentifier == upload.localIdentifier }) {
                    // Deselect image
                    selectedImages[indexOfUploadedImage] = nil
                    // Remove image from indexed upload queue
                    indexedUploadsInQueue[indexOfUploadedImage] = nil
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        case .move:
//            print("••• LocalImagesViewController controller:move...")
            break
        case .update:
//            print("••• LocalImagesViewController controller:update...")
            // Image removed from upload queue
            if let upload:Upload = anObject as? Upload {
                // Update upload in non-indexed upload queue
                if let indexInQueue = uploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    uploadsInQueue[indexInQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update image in indexed upload queue
                if let indexInIndexedQueue = indexedUploadsInQueue.firstIndex(where: { $0?.0 == upload.localIdentifier }) {
                    indexedUploadsInQueue[indexInIndexedQueue] = (upload.localIdentifier, kPiwigoUploadState(rawValue: upload.requestState))
                }
                // Update corresponding cell
                updateCell(for: upload)
            }
        @unknown default:
            fatalError("LocalImagesViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        print("••• LocalImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateNavBar()
    }

    func updateCell(for upload: Upload) {
        // Get indices of visible items
        let indexPathsForVisibleItems = localImagesCollection.indexPathsForVisibleItems
        
        // Loop over the visible items
        for indexPath in indexPathsForVisibleItems {
            
            // Get the corresponding index and local identifier
            let indexOfUploadedImage = getImageIndex(for: indexPath)
            let imageAsset = imageCollection[indexOfUploadedImage]
            
            // Identify cell to be updated (if presented)
            if imageAsset.localIdentifier == upload.localIdentifier {
                // Update visible cell
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                    cell.selectedImage.isHidden = true
                    switch upload.state {
                    case .waiting, .preparing, .preparingError, .preparingFail, .prepared, .formatError:
                        cell.cellWaiting = true
                    case .uploading, .uploadingError, .uploaded, .finishing, .finishingError:
                        cell.cellUploading = true
                    case .finished:
                        cell.cellUploaded = true
                    }
                    cell.reloadInputViews()
                    return
                }
            }
        }
    }
}

extension UIImage {
    func imageWithColor(_ color: UIColor) -> UIImage? {
        var image = withRenderingMode(.alwaysTemplate)
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        color.set()
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
