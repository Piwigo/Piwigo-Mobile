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
class LocalImagesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, PHPhotoLibraryChangeObserver, LocalImagesHeaderDelegate {
    
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
    
    private var assetCollections: PHFetchResult<PHAssetCollection>!         // Path to selected non-empty local album
    private var imageCollection: PHFetchResult<PHAsset>!                    // Collection of images in selected non-empty local album
    private var sortedImages: [[PHAsset]] = []                              // Array of images in selected non-empty local album
    private var nberOfImagesPerRow = 0                                      // Number of images displayed per row in collection view

    // Sort method #3 & 4
//    private var nberOfImagesInSection: [Int] = []                         // For determining quickly if more images must be sorted
    // Sort method #4
//    private var indexOfNextImageToSort: Int = 0                           // Index of the next image of the collection to sort
//    private var canAddSection = false                                     // For preventing concurrent section insertions

    private var actionBarButton: UIBarButtonItem?
    private var cancelBarButton: UIBarButtonItem?
    private var uploadBarButton: UIBarButtonItem?
    
    private var touchedImages = [String]()                                  // Array of identifiers
    private var selectedImages = [String]()                                 // Array of identifiers
    private var selectedSections = [NSNumber]()                             // Boolean values corresponding to Select/Deselect status
    
//    private var removedUploadedImages = false
    private var hudViewController: UIViewController?

    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Check collection Id
        if imageCollectionId.count == 0 {
            PhotosFetch.sharedInstance().showPhotosLibraryAccessRestricted(in: self)
        }

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

        // Collection view
        localImagesCollection.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        localImagesCollection.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fetch non-empty input collection and prepare data source
        fetchAndSortImages()

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
//        ImageUploadProgressView.sharedInstance().delegate = self
//        ImageUploadProgressView.sharedInstance().changePaletteMode()

//        if ImageUploadManager.sharedInstance().imageUploadQueue.count > 0 {
//            ImageUploadProgressView.sharedInstance().addView(to: view, forBottomLayout: bottomLayoutGuide)
//        }

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

    
    // MARK: - Images Management
    
    func fetchAndSortImages() {
        // Fetch non-empty collection previously selected by user
        // We fetch a specific path of the Photos Library to reduce the workload
        assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [imageCollectionId], options: nil)

        let fetchOptions = PHFetchOptions()
        switch Model.sharedInstance().localImagesSort {
        case kPiwigoSortDateCreatedDescending:
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        case kPiwigoSortDateCreatedAscending:
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        default:
            break
        }
        fetchOptions.predicate = NSPredicate(format: "isHidden == false")
        imageCollection = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)
        
        // Show HUD during job if huge collection
        if imageCollection.count > 10000 {
            DispatchQueue.main.async {
                // Show HUD
                self.showHUDwithTitle(NSLocalizedString("imageSortingHUD", comment: "Sorting Images"))
            }
            DispatchQueue.global(qos: .userInitiated).async {
                // Sort image collection
                self.sortedImages = self.splitImages(byDate: self.imageCollection)
                self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: self.sortedImages.count))

                // Hide HUD
                DispatchQueue.main.async {
                    self.hideHUDwithSuccess(true) {
                        self.hudViewController = nil

                        // Refresh collection view
                        self.localImagesCollection.reloadData()

                        // Update Select buttons status
                        self.updateSelectButtons()
                    }
                }
            }
        } else {
        
            // Method #1 — Fetch all images in selected collection and sort them
            // iPod - iOS 9.3.5: 219 ms for 669 photos
            // iPhone 11 Pro - iOS 13.5ß: 2.974 ms for 100.347 photos photos
//            let start = CFAbsoluteTimeGetCurrent()
            sortedImages = splitImages(byDate: imageCollection)
            self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count))
//            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//            print("Took \(diff) ms")

            // Method #2 — Fetch all images in selected collection and sort them
            // iPod - iOS 9.3.5: 446 ms for 669 photos
            // iPhone 11 Pro - iOS 13.5ß: 27.775 ms for 100.347 photos photos
//            let start = CFAbsoluteTimeGetCurrent()
//            sortedImages = splitImages2(byDate: imageCollection)
//            self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count))
//            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//            print("Took \(diff) ms")

            // Method #3 — Fetch all images in selected collection and sort them
            // iPod - iOS 9.3.5: 239 ms for 669 photos
            // iPhone 11 Pro - iOS 13.5ß: 17.924 ms for 100.347 photos photos
//            let start = CFAbsoluteTimeGetCurrent()
//            nberOfImagesInSection = splitImages3(byDate: imageCollection)
//            self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count))
//            let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//            print("Took \(diff) ms")

            // Method #4 — Start filling data source, i.e. an array of images sorted by day
            // This method is super-fast but adding sections to collection view is not very smooth
            // iPod - iOS 9.3.5: 81 ms for 669 photos
            // iPhone 11 Pro - iOS 13.5ß: 12 ms for 100.347 photos photos
//            indexOfNextImageToSort = 0
//            addImagesOfDay(onlyOnce: false)
        
            // Hide HUD
            DispatchQueue.main.async {
                // Refresh collection view
                self.localImagesCollection.reloadData()

                // Update Select buttons status
                self.updateSelectButtons()
            }
        }
    }

    func splitImages(byDate images: PHFetchResult<PHAsset>?) -> [[PHAsset]] {

        // NOP if no image
        guard let images = images else {
            return [[]]
        }

        // Initialisation
        var imagesByDate: [[PHAsset]] = []
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: images.firstObject?.creationDate ?? Date())
        var sectionDay = calendar.date(from: dateComponents)!
        var imagesOfSameDate: [PHAsset] = []

        // Sort imageAssets
        images.enumerateObjects({ obj, idx, stop in

            // Get current image creation date
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: obj.creationDate ?? Date())
            let date = calendar.date(from: dateComponents)!

            // Image taken at same date?
            if date.compare(sectionDay) == .orderedSame {
                // Same date -> Append object to section
                imagesOfSameDate.append(obj)
            } else {
                // Append section to collection
                imagesByDate.append(imagesOfSameDate)

                // Initialise for next items
                imagesOfSameDate.removeAll()
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: obj.creationDate ?? Date())
                sectionDay = calendar.date(from: dateComponents)!

                // Add current item
                imagesOfSameDate.append(obj)
            }
        })

        // Append last section to collection
        imagesByDate.append(imagesOfSameDate)

        return imagesByDate
    }

//    func splitImages2(byDate images: PHFetchResult<PHAsset>?) -> [[PHAsset]] {
//
//        // NOP if no image
//        guard let images = images else {
//            return [[]]
//        }
//
//        // Initialisation
//        var imagesByDate: [[PHAsset]] = []
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
//
//        // Sort imageAssets
//        var index = 0
//        while index < imageCollection.count {
//            let startOfday = Calendar.current.startOfDay(for: images.object(at: index).creationDate!)
//            let endOfDay = startOfday + 3600*24
//            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", startOfday as NSDate, endOfDay as NSDate)
//            let imagesOfDay = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)
//
//            // Append section to collection
//            imagesByDate.append(imagesOfDay.objects(at: IndexSet.init(integersIn: 0..<imagesOfDay.count)))
//
//            // Next day?
//            index += imagesOfDay.count
//        }
//
//        return imagesByDate
//    }

//    func splitImages3(byDate images: PHFetchResult<PHAsset>?) -> [Int] {
//
//        // NOP if no image
//        guard let images = images else {
//            return []
//        }
//
//        // Initialisation
//        var imagesBySection: [Int] = []
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
//
//        // Sort imageAssets
//        var index = 0
//        while index < imageCollection.count {
//            let startOfday = Calendar.current.startOfDay(for: images.object(at: index).creationDate!)
//            let endOfDay = startOfday + 3600*24
//            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ && creationDate < %@", startOfday as NSDate, endOfDay as NSDate)
//            let imagesOfDay = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)
//
//            // Append section to collection
//            imagesBySection.append(imagesOfDay.count)
//
//            // Next day?
//            index += imagesOfDay.count
//        }
//
//        return imagesBySection
//    }

//    func addImagesOfDay(onlyOnce: Bool) -> Void {
//
//        // Check starting index
//        if indexOfNextImageToSort > imageCollection.count - 1 {
//            return
//        }
//
//        // Initialisation
//        let start = CFAbsoluteTimeGetCurrent()
//        canAddSection = false
//        var imagesOfDay: [PHAsset] = []
//        let calendar = Calendar.current
//        let dayComponents = calendar.dateComponents([.year, .month, .day], from: imageCollection.object(at: indexOfNextImageToSort).creationDate ?? Date())
//
//        // Collect images of same day
//        let indexSet = IndexSet.init(integersIn: indexOfNextImageToSort..<imageCollection.count)
//        imageCollection.enumerateObjects(at: indexSet, options: []) { (image, idx, stop) in
//            let dateComponents = calendar.dateComponents([.year, .month, .day], from: image.creationDate ?? Date())
//            if dateComponents == dayComponents {
//                // Image of same day
////                print("==> Add image of same day at index:", idx)
//                imagesOfDay.append(image)
//                self.indexOfNextImageToSort = idx + 1
//            } else {
//                // Reached end of day
////                print("==> Reached end of day at index:", idx - 1)
//                self.indexOfNextImageToSort = idx
//                stop.pointee = true
//            }
//        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("Took \(diff) ms")
//
//        // Should we continue with next day?
//        if onlyOnce {
//            print("==> Reload collection")
//            // Add section of images to collection view
//            localImagesCollection.performBatchUpdates({
//                self.nberOfImagesInSection.append(indexOfNextImageToSort)
//                self.sortedImages.append(imagesOfDay)
//                self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: imagesOfDay.count))
//                print("    Add", imagesOfDay.count, "images in section:", nberOfImagesInSection.count-1)
//                self.localImagesCollection.insertSections(IndexSet.init(integer: nberOfImagesInSection.count - 1))
//            }) { (success) in
//                if success {
//                    print("    Did add new section ;-)")
//                    self.canAddSection = true
//                } else {
//                    print("    Did NOT add new section :-(")
//                    self.canAddSection = false
//                }
//            }
//            return
//        }
//
//        // Update data source before loading collection view
//        self.nberOfImagesInSection.append(indexOfNextImageToSort)
//        self.sortedImages.append(imagesOfDay)
//        self.selectedSections.append(contentsOf: [NSNumber](repeating: NSNumber(value: false), count: imagesOfDay.count))
//
//        // Calculate the number of images displayed per page
//        let imagesPerPage = Float(ImagesCollection.numberOfImagesPerPage(for: localImagesCollection, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait))
//
//        // Continue with next day until we have enough images to present
//        if (Float(indexOfNextImageToSort) < (imagesPerPage * 5).rounded()) &&
//            (indexOfNextImageToSort < imageCollection.count) {
//            addImagesOfDay(onlyOnce:false)
//        } else {
//            canAddSection = true
//        }
//    }

//    func getLocationOfImages(in section: Int) -> CLLocation {
//        // Initialise location of section with invalid location
//        var locationForSection = CLLocation.init(coordinate: kCLLocationCoordinate2DInvalid,
//                                                 altitude: CLLocationDistance(0.0),
//                                                 horizontalAccuracy: CLLocationAccuracy(0.0),
//                                                 verticalAccuracy: CLLocationAccuracy(0.0),
//                                                 timestamp: Date())
//
//        // Loop over images in section
//        for imageAsset in sortedImages[section] {
//
//            // Any location data ?
//            guard let assetLocation = imageAsset.location else {
//                // Image has no valid location data => Next image
//                continue
//            }
//
//            // Location found => Store if first found and move to next section
//            if !CLLocationCoordinate2DIsValid(locationForSection.coordinate) {
//                // First valid location => Store it
//                locationForSection = assetLocation
//            } else {
//                // Another valid location => Compare to first one
//                let distance = locationForSection.distance(from: assetLocation)
//                if distance <= locationForSection.horizontalAccuracy {
//                    // Same location within horizontal accuracy
//                    continue
//                }
//                // Still a similar location?
//                let meanLatitude: CLLocationDegrees = (locationForSection.coordinate.latitude + assetLocation.coordinate.latitude)/2
//                let meanLongitude: CLLocationDegrees = (locationForSection.coordinate.longitude + assetLocation.coordinate.longitude)/2
//                let newCoordinate = CLLocationCoordinate2DMake(meanLatitude,meanLongitude)
//                var newHorizontalAccuracy = kCLLocationAccuracyBestForNavigation
//                let newVerticalAccuracy = max(locationForSection.verticalAccuracy, assetLocation.verticalAccuracy)
//                if distance < kCLLocationAccuracyBest {
//                    newHorizontalAccuracy = max(kCLLocationAccuracyBest, locationForSection.horizontalAccuracy)
//                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
//                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
//                                                    timestamp: locationForSection.timestamp)
//                    return locationForSection
//                } else if distance < kCLLocationAccuracyNearestTenMeters {
//                    newHorizontalAccuracy = max(kCLLocationAccuracyNearestTenMeters, locationForSection.horizontalAccuracy)
//                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
//                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
//                                                    timestamp: locationForSection.timestamp)
//                    return locationForSection
//                } else if distance < kCLLocationAccuracyHundredMeters {
//                    newHorizontalAccuracy = max(kCLLocationAccuracyHundredMeters, locationForSection.horizontalAccuracy)
//                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
//                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
//                                                    timestamp: locationForSection.timestamp)
//                    return locationForSection
//                } else if distance < kCLLocationAccuracyKilometer {
//                    newHorizontalAccuracy = max(kCLLocationAccuracyKilometer, locationForSection.horizontalAccuracy)
//                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
//                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
//                                                    timestamp: locationForSection.timestamp)
//                    return locationForSection
//                } else if distance < kCLLocationAccuracyThreeKilometers {
//                    newHorizontalAccuracy = max(kCLLocationAccuracyThreeKilometers, locationForSection.horizontalAccuracy)
//                    locationForSection = CLLocation(coordinate: newCoordinate, altitude: locationForSection.altitude,
//                                                    horizontalAccuracy: newHorizontalAccuracy, verticalAccuracy: newVerticalAccuracy,
//                                                    timestamp: locationForSection.timestamp)
//                    return locationForSection
//                } else {
//                    // Above 3 km, we estimate that it is a different location
//                    return locationForSection
//                }
//             }
//        }
//
//        return locationForSection
//    }
    
//    func indexPathOfImageAsset(_ imageAsset: PHAsset?) -> IndexPath? {
//        var indexPath = IndexPath(item: 0, section: 0)
//
//        // Loop over all sections
//        for section in 0..<localImagesCollection.numberOfSections {
//            // Index of image in section?
//            var item: Int? = nil
//            if let imageAsset = imageAsset {
//                item = imagesInSections[section].firstIndex(of: imageAsset) ?? NSNotFound
//            }
//            if item != NSNotFound {
//                indexPath = IndexPath(item: item ?? 0, section: section)
//                break
//            }
//        }
//        return indexPath
//    }


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
//            self.removedUploadedImages = false

            // Show HUD during job if huge collection
//            if self.imageCollection.count > 10000 {
//                DispatchQueue.main.async {
//                    self.showHUDwithTitle(NSLocalizedString("imageSortingHUD", comment: "Sorting Images"))
//                }
//            }

            // Sort images
//            DispatchQueue.global(qos: .userInitiated).async {
                self.fetchAndSortImages()
//            }
            }
        )

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
    
//    func initSelectButtons() {
//        selectedSections = [NSNumber](repeating: NSNumber(value: false), count: sortedImages.count)
//    }

    func updateSelectButtons() {
        // Update status of Select buttons
        // Same number of sections, or fewer if uploaded images removed
        for section in 0..<sortedImages.count {
            updateSelectButton(forSection: section)
        }
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
//        selectedSections = [AnyHashable](repeating: NSNumber(value: false), count: sortedImages.count)
//
//        // Present Image Upload View
//        let imageUploadVC = ImageUploadViewController()
//        imageUploadVC.selectedCategory = categoryId
//        imageUploadVC.imagesSelected = selectedImages
//        navigationController?.pushViewController(imageUploadVC, animated: true)

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
//        let originalFilename = PhotosFetch.sharedInstance().getFileNameFomImageAsset(imageAsset)
//        cell.cellUploading = ImageUploadManager.sharedInstance().imageNamesUploadQueue.contains(URL(fileURLWithPath: originalFilename).deletingPathExtension().absoluteString)

        // Sort images in advance if needed (method #4)
//        if indexOfNextImageToSort == imageCollection.count || !canAddSection {
//            return cell
//        }
//        if Float(indexOfNextImageToSort) < (Float(nberOfImagesInSection[indexPath.section])*5).rounded() {
//            addImagesOfDay(onlyOnce: true)
//        }
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

//    func imageProgress(_ image: ImageUpload?, onCurrent current: Int, forTotal total: Int, onChunk currentChunk: Int, forChunks totalChunks: Int, iCloudProgress: CGFloat) {
//        //    NSLog(@"AlbumUploadViewController[imageProgress:]");
//        let indexPath = indexPathOfImageAsset(image?.imageAsset)
//        let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell
//
//        let chunkPercent: CGFloat = 100.0 / Double(totalChunks) / 100.0
//        let onChunkPercent = chunkPercent * CGFloat((currentChunk - 1))
//        let pieceProgress = CGFloat(current) / CGFloat(total)
//        var uploadProgress = onChunkPercent + (chunkPercent * pieceProgress)
//        if uploadProgress > 1 {
//            uploadProgress = 1
//        }
//
//        cell?.cellUploading = true
//        if iCloudProgress < 0 {
//            cell?.progress = uploadProgress
//            //        NSLog(@"AlbumUploadViewController[ImageProgress]: %.2f", uploadProgress);
//        } else {
//            cell?.progress = (iCloudProgress + uploadProgress) / 2.0
//            //        NSLog(@"AlbumUploadViewController[ImageProgress]: %.2f", ((iCloudProgress + uploadProgress) / 2.0));
//        }
//    }

//    func imageUploaded(_ image: ImageUpload?, placeInQueue rank: Int, outOf totalInQueue: Int, withResponse response: [AnyHashable : Any]?) {
//        //    NSLog(@"AlbumUploadViewController[imageUploaded:]");
//        let indexPath = indexPathOfImageAsset(image?.imageAsset)
//        let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell
//
//        // Image upload ended, deselect cell
//        cell?.cellUploading = false
//        cell?.cellSelected = false
//        if let imageAsset = image?.imageAsset {
//            if selectedImages?.contains(imageAsset.localIdentifier) ?? false {
//                selectedImages?.removeAll { $0 as AnyObject === image?.imageAsset.localIdentifier as AnyObject }
//            }
//        }
//
//        // Update list of "Not Uploaded" images
//        if removedUploadedImages {
//            var newList = imagesInSections
//            newList?.removeAll { $0 as AnyObject === image?.imageAsset as AnyObject }
//            imagesInSections = newList
//
//            // Update image cell
//            localImagesCollection.reloadItems(at: [indexPath].compactMap { $0 })
//        }
//    }

    
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
