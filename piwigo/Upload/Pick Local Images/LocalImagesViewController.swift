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
    
    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    
    
    // MARK: View
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
    @IBOutlet weak var sortButton: UIButton!
    
    
    private var assetCollections: PHFetchResult<PHAssetCollection>!         // Path to selected non-empty local album
    private var imageCollection: PHFetchResult<PHAsset>!                    // Collection of images in selected non-empty local album
    private var sortedImages: [[PHAsset]] = []                              // Array of images in selected non-empty local album
    private let kPiwigoNberImagesShowHUDWhenSorting = 2_500                 // Show HUD when sorting more than this number of images
    private var imagesSortedByDays: [[PHAsset]] = []
    private var imagesSortedByWeeks: [[PHAsset]] = []
    private var imagesSortedByMonths: [[PHAsset]] = []

    private var selectedImages = [UploadProperties]()                       // Array of images to upload
    private var selectedSections = [LocalImagesHeaderReusableView.SelectButtonState]()  // State of Select buttons
    private var touchedImages = [String]()                                  // Array of identifiers
    
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

        // Fetch non-empty input collection and prepare data source in background
        fetchAndSortImages()

        // Show images in upload queue by default
        removeUploadedImages = false

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
        
        // Segmented control (choice for presenting images by date, week or month)
        segmentedControl.selectedSegmentIndex = Int(Model.sharedInstance().localImagesSectionType.rawValue)
        segmentedControl.isHidden = true
//        segmentedControl.backgroundColor = UIColor.init(red: 148.0/256.0, green: 148.0/256.0, blue: 152.0/256.0, alpha: 1.0)
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange()
        } else {
            // Fallback on earlier versions
            segmentedControl.tintColor = UIColor.piwigoColorOrange()
        }

        // Sort button
        sortButton.isHidden = true
        sortButton.layer.cornerRadius = segmentedControl.layer.cornerRadius
        sortButton.layer.masksToBounds = false
        switch Model.sharedInstance().localImagesSort {
        case kPiwigoSortDateCreatedDescending:
            sortButton.setImage(UIImage(named: "imageDateBackward"), for: .normal)
        case kPiwigoSortDateCreatedAscending:
            sortButton.setImage(UIImage(named: "imageDateForward"), for: .normal)
        default:
            break
        }
        sortButton.tintColor = UIColor.white
//        sortButton.backgroundColor = UIColor.init(red: 148.0/256.0, green: 148.0/256.0, blue: 152.0/256.0, alpha: 1.0)
        sortButton.showsTouchWhenHighlighted = true
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
            sortButton.backgroundColor = Model.sharedInstance().isDarkPaletteActive ? UIColor.piwigoColorGray().withAlphaComponent(0.8) : UIColor.piwigoColorGray().withAlphaComponent(0.4)
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

    
    // MARK: - Fetch and Sort Images
    
    func fetchAndSortImages() -> Void {
        // Fetch non-empty collection previously selected by user
        // We fetch a specific path of the Photos Library to reduce the workload
        // and store the fetched collection for future use
        DispatchQueue.global(qos: .userInitiated).async {
//            var start = CFAbsoluteTimeGetCurrent()
            self.assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil)
//            var diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//            print("=> Fetching collections took \(diff) ms")

//            start = CFAbsoluteTimeGetCurrent()
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
            self.imageCollection = PHAsset.fetchAssets(in: self.assetCollections.firstObject!, options: fetchOptions)
//            diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//            print("=> Fetching assets took \(diff) ms")
            
            // Sort collected images
            self.sortCollectionOfImages()
        }
    }
    
    // Sorts images by months, weeks and days
    // A first batch is sorted and displayed
    // A second batch follows in the background and finally upadtes the collection
    private func sortCollectionOfImages() -> Void {
       
        // Sort first limited batch of images
//        let start = CFAbsoluteTimeGetCurrent()
        let nberOfImages = min(imageCollection.count, kPiwigoNberImagesShowHUDWhenSorting)
        (imagesSortedByDays, imagesSortedByWeeks, imagesSortedByMonths) = split(inRange: 0..<nberOfImages)
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Splitted", nberOfImages, "images by days, weeks and months took \(diff) ms")

        // Adopt the last chosen sort type
        switch Model.sharedInstance().localImagesSectionType {
        case kPiwigoSortImagesByMonths:
            sortedImages = imagesSortedByMonths
        case kPiwigoSortImagesByWeeks:
            sortedImages = imagesSortedByWeeks
        default:
            sortedImages = imagesSortedByDays
        }
        
        // Initialise buttons of sections for the max number of sections)
        selectedSections = .init(repeating: .select, count: imagesSortedByDays.count)

        // Display first limited batch of images
        DispatchQueue.main.async {
            // Refresh collection view
            self.localImagesCollection.reloadData()
        }

        // Sort remaining images
        if imageCollection.count > kPiwigoNberImagesShowHUDWhenSorting {

            // Show HUD during job
            DispatchQueue.main.async {
                self.showHUDwithTitle(NSLocalizedString("imageSortingHUD", comment: "Sorting Images"))
            }

            // Initialisation
            var remainingImagesSortedByDays: [[PHAsset]] = []
            var remainingImagesSortedByWeeks: [[PHAsset]] = []
            var remainingImagesSortedByMonths: [[PHAsset]] = []
            
            // Sort remaining images
            (remainingImagesSortedByDays, remainingImagesSortedByWeeks, remainingImagesSortedByMonths) = split(inRange: kPiwigoNberImagesShowHUDWhenSorting..<imageCollection.count)
            
            // Images sorted by days
            let calendar = Calendar.current
            if remainingImagesSortedByDays.count > 0 {
                let byDays: Set<Calendar.Component> = [.year, .month, .day]
                let lastDayComponents = calendar.dateComponents(byDays, from: (imagesSortedByDays.last?.last?.creationDate)!)
                let firstDayComponents = calendar.dateComponents(byDays, from: (remainingImagesSortedByDays.first?.first?.creationDate)!)
                if lastDayComponents == firstDayComponents {
                    // Append images to last section
                    imagesSortedByDays[imagesSortedByDays.count - 1].append(contentsOf: (remainingImagesSortedByDays.first)!)

                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByDays {
                        updateSection(with: remainingImagesSortedByDays.first!)
                    }
                    
                    // Append new sections
                    if remainingImagesSortedByDays.count > 1 {
                        // Append sections
                        imagesSortedByDays.append(contentsOf: remainingImagesSortedByDays[1...remainingImagesSortedByDays.count-1])

                        // Update collection view if needed
                        if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByDays {
                            addSections(of: Array(remainingImagesSortedByDays.dropFirst()))
                        }
                        
                        // Hide HUD at end of job
                        DispatchQueue.main.async {
                            self.hideHUDwithSuccess(true) {
                                // Show segmented control if needed
                                if self.segmentedControl.isHidden {
                                    self.showSegmentedControlAndSortButton()
                                }
                            }
                        }
                    }
                } else {
                    // Append new section
                    imagesSortedByDays.append(contentsOf: remainingImagesSortedByDays[0...remainingImagesSortedByDays.count-1])

                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByDays {
                        addSections(of: remainingImagesSortedByDays)
                    }
                    
                    // Hide HUD at end of job
                    DispatchQueue.main.async {
                        self.hideHUDwithSuccess(true) {
                            // Show segmented control if needed
                            if self.segmentedControl.isHidden {
                                self.showSegmentedControlAndSortButton()
                            }
                        }
                    }
                }
            }

            // Images sorted by weeks
            if remainingImagesSortedByWeeks.count > 0 {
                let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
                let lastWeekComponents = calendar.dateComponents(byWeeks, from: (imagesSortedByWeeks.last?.last?.creationDate)!)
                let firstWeekComponents = calendar.dateComponents(byWeeks, from: (remainingImagesSortedByWeeks.first?.first?.creationDate)!)
                if lastWeekComponents == firstWeekComponents {
                    // Append images to last section
                    imagesSortedByWeeks[imagesSortedByWeeks.count - 1].append(contentsOf: (remainingImagesSortedByWeeks.first)!)
                    
                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByWeeks {
                        updateSection(with: remainingImagesSortedByWeeks.first!)
                    }

                    // Append new sections
                    if remainingImagesSortedByWeeks.count > 1 {
                        // Append sections
                        imagesSortedByWeeks.append(contentsOf: remainingImagesSortedByWeeks[1...remainingImagesSortedByWeeks.count-1])
                        
                        // Update collection view if needed
                        if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByWeeks {
                            addSections(of: Array(remainingImagesSortedByWeeks.dropFirst()))
                        }
                        
                        // Hide HUD at end of job
                        DispatchQueue.main.async {
                            self.hideHUDwithSuccess(true) {
                                // Show segmented control if needed
                                if self.segmentedControl.isHidden {
                                    self.showSegmentedControlAndSortButton()
                                }
                            }
                        }
                    }
                } else {
                    // Append new section
                    imagesSortedByWeeks.append(contentsOf: remainingImagesSortedByWeeks[0...remainingImagesSortedByWeeks.count-1])
                    
                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByWeeks {
                        addSections(of: remainingImagesSortedByWeeks)
                    }
                    
                    // Hide HUD at end of job
                    DispatchQueue.main.async {
                        self.hideHUDwithSuccess(true) {
                            // Show segmented control if needed
                            if self.segmentedControl.isHidden {
                                self.showSegmentedControlAndSortButton()
                            }
                        }
                    }
                }
            }

            // Images sorted by months
            if remainingImagesSortedByMonths.count > 0 {
                let byMonths: Set<Calendar.Component> = [.year, .month]
                let lastMonthComponents = calendar.dateComponents(byMonths, from: (imagesSortedByMonths.last?.last?.creationDate)!)
                let firstMonthComponents = calendar.dateComponents(byMonths, from: (remainingImagesSortedByMonths.first?.first?.creationDate)!)
                if lastMonthComponents == firstMonthComponents {
                    // Append images to last section
                    imagesSortedByMonths[imagesSortedByMonths.count - 1].append(contentsOf: (remainingImagesSortedByMonths.first)!)
                    
                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByMonths {
                        updateSection(with: remainingImagesSortedByMonths.first!)
                    }

                    // Append new sections
                    if remainingImagesSortedByMonths.count > 1 {
                        imagesSortedByMonths.append(contentsOf: remainingImagesSortedByMonths[1...remainingImagesSortedByMonths.count-1])
                        
                        // Update collection view if needed
                        if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByMonths {
                            addSections(of: Array(remainingImagesSortedByMonths.dropFirst()))
                        }
                        
                        // Hide HUD at end of job
                        DispatchQueue.main.async {
                            self.hideHUDwithSuccess(true) {
                                // Show segmented control if needed
                                if self.segmentedControl.isHidden {
                                    self.showSegmentedControlAndSortButton()
                                }
                            }
                        }
                    }
                } else {
                    // Append new section
                    imagesSortedByMonths.append(contentsOf: remainingImagesSortedByMonths[0...remainingImagesSortedByMonths.count-1])
                    
                    // Update collection view if needed
                    if Model.sharedInstance()?.localImagesSectionType == kPiwigoSortImagesByMonths {
                        addSections(of: remainingImagesSortedByMonths)
                    }
                    
                    // Hide HUD at end of job
                    DispatchQueue.main.async {
                        self.hideHUDwithSuccess(true) {
                            // Show segmented control if needed
                            if self.segmentedControl.isHidden {
                                self.showSegmentedControlAndSortButton()
                            }
                        }
                    }
                }
            }
        } else {
            // Show segmented control if needed
            DispatchQueue.main.async {
                if self.segmentedControl.isHidden {
                    self.showSegmentedControlAndSortButton()
                }
            }
        }
    }

    private func updateSection(with images:[PHAsset]!) {
        // Append images of the day, week or month to last section
        DispatchQueue.main.async {
            // Update data source
            let indexOfLastItem = self.sortedImages.last!.count
            let nberOfAddedItems = images.count
            let indexesOfNewItems = Array(indexOfLastItem..<indexOfLastItem + nberOfAddedItems).map { IndexPath(item: $0, section: self.sortedImages.count-1) }
            self.sortedImages[self.sortedImages.count-1].append(contentsOf: images)
            
            // Update section
            self.localImagesCollection.insertItems(at: indexesOfNewItems)
        }
    }
    
    private func addSections(of images: [[PHAsset]]) {
        // Append sections of images to current data source
        DispatchQueue.main.async {
            // Update data source
            let nberOfAddedSections = images.count
            self.selectedSections.append(contentsOf: [LocalImagesHeaderReusableView.SelectButtonState](repeating: .select, count: nberOfAddedSections))
            let indexesOfNewSections = IndexSet.init(integersIn: self.sortedImages.count..<self.selectedSections.count)
            self.sortedImages.append(contentsOf: images)
            // Update section
            self.localImagesCollection.insertSections(indexesOfNewSections)
        }
    }
    
    private func split(inRange range: Range<Int>) -> (imagesByDays: [[PHAsset]], imagesByWeeks: [[PHAsset]], imagesByMonths: [[PHAsset]])  {

        // Get collection of images
//        var start = CFAbsoluteTimeGetCurrent()
        let images = imageCollection.objects(at: IndexSet.init(integersIn: range))
//        var diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("           imageCollection.objects took \(diff) ms")

        // Initialisation
//        start = CFAbsoluteTimeGetCurrent()
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images.first?.creationDate ?? Date())
        var imagesOfSameDay: [PHAsset] = []
        var imagesByDays: [[PHAsset]] = []

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images.first?.creationDate ?? Date())
        var imagesOfSameWeek: [PHAsset] = []
        var imagesByWeeks: [[PHAsset]] = []

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images.first?.creationDate ?? Date())
        var imagesOfSameMonth: [PHAsset] = []
        var imagesByMonths: [[PHAsset]] = []

        // Sort imageAssets
        for index in 0..<range.endIndex-range.startIndex {
            // Get object
            let obj = images[index]

            // Get day of current image
            let newDayComponents = calendar.dateComponents(byDays, from: obj.creationDate ?? Date())

            // Image taken the same day?
            if newDayComponents == dayComponents {
                // Same date -> Append object to section
                imagesOfSameDay.append(obj)
            } else {
                // Append section to collection by days
                imagesByDays.append(imagesOfSameDay)

                // Append images of same day to collection by weeks
                imagesOfSameWeek.append(contentsOf: imagesOfSameDay)
                                
                // Append images of same day to collection by months
                imagesOfSameMonth.append(contentsOf: imagesOfSameDay)
                                
                // Initialise for next day
                imagesOfSameDay.removeAll()
                dayComponents = calendar.dateComponents(byDays, from: obj.creationDate ?? Date())

                // Add current item to new list of images by days
                imagesOfSameDay.append(obj)
                
                // Get week of year of new image
                let newWeekComponents = calendar.dateComponents(byWeeks, from: obj.creationDate ?? Date())
                
                // What should we do with this new image?
                if newWeekComponents != weekComponents {
                    // Append section to collection by weeks
                    imagesByWeeks.append(imagesOfSameWeek)
                    
                    // Initialise for next week
                    imagesOfSameWeek.removeAll()
                    weekComponents = newWeekComponents
                }

                // Get month of new image
                let newMonthComponents = calendar.dateComponents(byMonths, from: obj.creationDate ?? Date())
                
                // What should we do with this new image?
                if newMonthComponents != monthComponents {
                    // Append section to collection by months
                    imagesByMonths.append(imagesOfSameMonth)
                    
                    // Initialise for next month
                    imagesOfSameMonth.removeAll()
                    monthComponents = newMonthComponents
                }
            }
        }
        
        // Append last section to collection
        imagesByDays.append(imagesOfSameDay)
        imagesOfSameWeek.append(contentsOf: imagesOfSameDay)
        imagesByWeeks.append(imagesOfSameWeek)
        imagesOfSameMonth.append(contentsOf: imagesOfSameDay)
        imagesByMonths.append(imagesOfSameMonth)
        
//        diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("           sorting objects took \(diff) ms")
        return (imagesByDays, imagesByWeeks, imagesByMonths)
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
        // Did select new sort option [Months, Weeks, Days]
        Model.sharedInstance().localImagesSectionType.rawValue = UInt32(sender.selectedSegmentIndex)
        Model.sharedInstance().saveToDisk()
                
        // Sort images as requested using cached arrays
        switch Model.sharedInstance()?.localImagesSectionType {
        case kPiwigoSortImagesByMonths:
            self.sortedImages = self.imagesSortedByMonths
        case kPiwigoSortImagesByWeeks:
            self.sortedImages = self.imagesSortedByWeeks
        default:
            self.sortedImages = self.imagesSortedByDays
        }

        // Load changed collection
        DispatchQueue.main.async {
            // Refresh collection view
            self.localImagesCollection.reloadData()

            // Show segmented control if needed
            if self.segmentedControl.isHidden {
                self.showSegmentedControlAndSortButton()
            }
        }
    }
    
    @IBAction func didTapSortButton(_ sender: Any) {
        // Did change date sort order
        switch Model.sharedInstance().localImagesSort {
        case kPiwigoSortDateCreatedDescending:
            Model.sharedInstance().localImagesSort = kPiwigoSortDateCreatedAscending
            self.sortButton.setImage(UIImage(named: "imageDateForward"), for: .normal)
        case kPiwigoSortDateCreatedAscending:
            Model.sharedInstance().localImagesSort = kPiwigoSortDateCreatedDescending
            self.sortButton.setImage(UIImage(named: "imageDateBackward"), for: .normal)
        default:
            break
        }
        Model.sharedInstance()?.saveToDisk()

        // Sort images
        self.fetchAndSortImages()
    }
    
    @objc func didTapUploadButton() {
        // Add selected images to upload queue
        uploadProvider.importUploads(from: selectedImages) { error in
            
              DispatchQueue.main.async {
                // Show an alert if there was an error.
                guard let error = error else {
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
        selectedSections = .init(repeating: .select, count: sortedImages.count)

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
            guard let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
                return
            }

            // Images in the upload queue cannot be selected
            if let uploads = uploadProvider.fetchedResultsController.fetchedObjects {
                if uploads.contains(where: { $0.localIdentifier == cell.localIdentifier }) {
                    return
                }
            }
            
            // Update the selection if not already done
            if !touchedImages.contains(cell.localIdentifier) {

                // Store that the user touched this cell during this gesture
                touchedImages.append(cell.localIdentifier)

                // Update the selection state
                if let index = selectedImages.firstIndex(where: { (item) -> Bool in item.localIdentifier == cell.localIdentifier }) {
                    selectedImages.remove(at: index)
                    cell.cellSelected = false
                } else {
                    // Select the cell
                    selectedImages.append(UploadProperties.init(localIdentifier: cell.localIdentifier, category: categoryId))
                    cell.cellSelected = true
                }

                // Update navigation bar
                updateNavBar()

                // Refresh cell
                cell.reloadInputViews()

                // Update state of Select button if needed
                updateSelectButton(ofSection: indexPath.section, completion: {
                    self.localImagesCollection.reloadSections(NSIndexSet(index: indexPath.section) as IndexSet)
                })
            }
        }

        // Is this the end of the gesture?
        if gestureRecognizer?.state == .ended {
            touchedImages = []
        }
    }

    func updateSelectButton(ofSection section: Int, completion: @escaping () -> Void) {
        // Number of images in section
        let nberOfImages = sortedImages[section].count
        
        // Count images selected and in upload queue
        var nberOfSelectedImages = 0
        var nberOfNonSelectableImages = 0
        DispatchQueue.concurrentPerform(iterations: nberOfImages) { item in
            // Retrieve image local identifier
            let imageId = sortedImages[section][item].localIdentifier
            // Is this image selected or in upload queue?
            if selectedImages.contains(where: { (item) -> Bool in item.localIdentifier == imageId }) {
                nberOfSelectedImages +=  1
            }
            // Images in the upload queue cannot be selected
            else if let uploads = uploadProvider.fetchedResultsController.fetchedObjects {
                if uploads.contains(where: { $0.localIdentifier == imageId }) {
                    nberOfNonSelectableImages +=  1
                }
            }
        }

        // Update state of Select button only if needed
        if nberOfImages == nberOfNonSelectableImages {
            // All images are in the upload queue
            if selectedSections[section] != .none {
                selectedSections[section] = .none
                completion()
            }
        } else if nberOfImages == nberOfSelectedImages + nberOfNonSelectableImages {
            // All images are either selected or in the upload queue
            if selectedSections[section] == .select {
                selectedSections[section] = .deselect
                completion()
            }
        } else {
            // Not all images are either selected or in the upload queue
            if selectedSections[section] == .deselect {
                selectedSections[section] = .select
                completion()
            }
        }
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
                updateSelectButton(ofSection: indexPath.section, completion: {})
                header.configure(with: sortedImages[indexPath.section], section: indexPath.section,
                                 selectState: selectedSections[indexPath.section])
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
        let size = CGFloat(ImagesCollection.imageSize(for: collectionView, imagesPerRowInPortrait: Model.sharedInstance().thumbnailsPerRowInPortrait, collectionType: kImageCollectionPopup))

        return CGSize(width: size, height: size)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LocalImageCollectionViewCell", for: indexPath) as? LocalImageCollectionViewCell else {
            print("Error: collectionView.dequeueReusableCell does not return a LocalImageCollectionViewCell!")
            return LocalImageCollectionViewCell()
        }
        let imageAsset = sortedImages[indexPath.section][indexPath.row]
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
        cell.cellSelected = selectedImages.contains(where: { (item) -> Bool in item.localIdentifier == imageAsset.localIdentifier })
        if let uploads = uploadProvider.fetchedResultsController.fetchedObjects {
            cell.cellUploading = uploads.contains(where: { $0.localIdentifier == cell.localIdentifier })
        }
        return cell
    }


    // MARK: - UICollectionView Delegate Methods
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? LocalImageCollectionViewCell else {
            return
        }

        // Images in the upload queue cannot be selected
        if let uploads = uploadProvider.fetchedResultsController.fetchedObjects {
            if uploads.contains(where: { $0.localIdentifier == cell.localIdentifier }) {
                return
            }
        }

        // Update cell and selection
        if let index = selectedImages.firstIndex(where: { (item) -> Bool in item.localIdentifier == cell.localIdentifier }) {
            selectedImages.remove(at: index)
            cell.cellSelected = false
        } else {
            // Select the cell
            selectedImages.append(UploadProperties.init(localIdentifier: cell.localIdentifier, category: categoryId))
            cell.cellSelected = true
        }

        // Update navigation bar
        updateNavBar()

        // Refresh cell
        cell.reloadInputViews()

        // Update state of Select button if needed
        updateSelectButton(ofSection: indexPath.section, completion: {
            self.localImagesCollection.reloadSections(NSIndexSet(index: indexPath.section) as IndexSet)
        })
    }


    // MARK: - UIScrollViewDelegate Methods
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hideSegmentedControlAndSortButton()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            showSegmentedControlAndSortButton()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        showSegmentedControlAndSortButton()
    }
    
    private func showSegmentedControlAndSortButton() {
        segmentedControl.isHidden = false
        sortButton.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.segmentedControl.backgroundColor = Model.sharedInstance().isDarkPaletteActive ? UIColor.piwigoColorGray().withAlphaComponent(0.8) : UIColor.piwigoColorGray().withAlphaComponent(0.4)
            self.sortButton.backgroundColor = Model.sharedInstance().isDarkPaletteActive ? UIColor.piwigoColorGray().withAlphaComponent(0.8) : UIColor.piwigoColorGray().withAlphaComponent(0.4)
            if #available(iOS 13.0, *) {
                self.segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange().withAlphaComponent(1.0)
            } else {
                // Fallback on earlier versions
                self.segmentedControl.tintColor = UIColor.piwigoColorOrange().withAlphaComponent(1.0)
            }
        }
    }
    
    private func hideSegmentedControlAndSortButton() {
        UIView.animate(withDuration: 0.3) {
            if #available(iOS 13.0, *) {
                self.segmentedControl.backgroundColor = UIColor.piwigoColorGray().withAlphaComponent(0.0)
                self.sortButton.backgroundColor = UIColor.piwigoColorGray().withAlphaComponent(0.08)
                self.segmentedControl.selectedSegmentTintColor = UIColor.piwigoColorOrange().withAlphaComponent(0.0)
            } else {
                // Fallback on earlier versions
                self.segmentedControl.backgroundColor = UIColor.piwigoColorGray().withAlphaComponent(0.08)
                self.sortButton.backgroundColor = UIColor.piwigoColorGray().withAlphaComponent(0.08)
                self.segmentedControl.tintColor = UIColor.piwigoColorOrange().withAlphaComponent(0.0)
            }
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
                    hud?.hide(animated: true, afterDelay: 0.3)
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
            if selectedImages.contains(where: { (item) -> Bool in item.localIdentifier == imageAsset.localIdentifier }) {
                selectedImages.removeAll { $0 as AnyObject === image?.imageAsset.localIdentifier as AnyObject }
            }
        }

        // Update list of "Not Uploaded" images
//        if removeUploadedImages {
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
        for row in 0..<sortedImages[section].count {

            // Images in the upload queue cannot be selected
            let imageId = sortedImages[section][row].localIdentifier
            if let uploads = uploadProvider.fetchedResultsController.fetchedObjects {
                if uploads.contains(where: { $0.localIdentifier == imageId }) {
                    continue
                }
            }

            // Select or deselect cell
            let indexPath = IndexPath(item: row, section: section)
            if selectedSections[section] == .deselect {
                // Deselect image
                if let index = selectedImages.firstIndex(where: { (item) -> Bool in item.localIdentifier == imageId }) {
                    selectedImages.remove(at: index)
                }
                // Update cell in section
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                    cell.cellSelected = false
                }
            } else {
                // Select image if not already selected
                if !selectedImages.contains(where: { (item) -> Bool in item.localIdentifier == imageId }) {
                    selectedImages.append(UploadProperties.init(localIdentifier: imageId, category: categoryId))
                }
                // Update cell in section
                if let cell = localImagesCollection.cellForItem(at: indexPath) as? LocalImageCollectionViewCell {
                    cell.cellSelected = true
                }
            }
        }

        // Update navigation bar
        updateNavBar()

        // Update section
        updateSelectButton(ofSection: section, completion: {
            self.localImagesCollection.reloadSections(NSIndexSet(index: section) as IndexSet)
        })
    }
}


// MARK: - NSFetchedResultsControllerDelegate

extension LocalImagesViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            print("••• controller:insert...")
            // Deselect image added to upload queue
            if let upload:Upload = anObject as? Upload {
                selectedImages.removeAll(where: { $0.localIdentifier == upload.localIdentifier })
            }
        case .delete:
            print("••• controller:delete...")
        case .move:
            print("••• controller:move...")
        case .update:
            print("••• controller:update...")
        @unknown default:
            fatalError("LocalImagesViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        print("••• controller:didChangeContent...")

        // Update navigation bar
        updateNavBar()

        // Update collection
        localImagesCollection.reloadData()
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
