//
//  ImageCollectionViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import UIKit
import piwigoKit

enum pwgImageAction {
    case edit, delete, share
    case copyImages, moveImages
    case addToFavorites, removeFromFavorites
    case rotateImagesLeft, rotateImagesRight
}

protocol ImageCollectionViewDelegate: NSObjectProtocol {
    func updateImageSortMenu()
}

protocol ImageSelectionCollectionViewDelegate: NSObjectProtocol {
    func updatePreviewMode(withInit: Bool)
    func updateSelectMode(withInit: Bool)
    func setButtonsState(_ enabled: Bool)
    func pushSelectionToView(_ viewController: UIViewController?)
    func deselectImages()
}

class ImageCollectionViewController: UICollectionViewController
{
    weak var imageCollectionDelegate: ImageCollectionViewDelegate?
    weak var imageSelectionDelegate: ImageSelectionCollectionViewDelegate?
    
    var imageOfInterest = IndexPath(item: 0, section: 0)
    var indexOfImageToRestore = Int.min
    var isSelect = false
    var touchedImageIds = [Int64]()
    var selectedImageIds = Set<Int64>()
    var selectedImageIdsLoop = Set<Int64>()
    var selectedFavoriteIds = Set<Int64>()
    var selectedVideosIds = Set<Int64>()
    var totalNumberOfImages = 0
    
    private var updateOperations = [BlockOperation]()
    private var didUpdateCellHeight = false             // Workaround for iOS 12 - 15.x

    // Cached parameters
    private var timeCounter = CFAbsoluteTime(0)
    private let imagePlaceHolder = UIImage(named: "unknownImage")!
    private let imageSize = pwgImageSize(rawValue: AlbumVars.shared.defaultThumbnailSize) ?? .thumb
    lazy var hasFavorites: Bool = {
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending,
           NetworkVars.userStatus != .guest { return true }
        return false
    }()
    

    // MARK: - Core Data Source
    var user: User!
    var albumData: Album!
    var albumProvider: AlbumProvider!
    var imageProvider: ImageProvider!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext
        else { fatalError("!!! Missing Managed Object Context !!!") }
        return context
    }()
        
    lazy var imagePredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY albums.pwgID == $catId"))
        andPredicates.append(NSPredicate(format: "ANY albums.user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    func sortDescriptors(for sortKeys: String) -> [NSSortDescriptor] {
        var descriptors = [NSSortDescriptor]()
        let items = sortKeys.components(separatedBy: ",")
        for item in items {
            var fixedItem = item
            // Remove extra space at the begining and end
            while fixedItem.hasPrefix(" ") {
                fixedItem.removeFirst()
            }
            while fixedItem.hasSuffix(" ") {
                fixedItem.removeLast()
            }
            // Convert to sort descriptors
            let sortDesc = fixedItem.components(separatedBy: " ")
            if sortDesc[0].contains(pwgImageOrder.random.rawValue) {
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.rankRandom), ascending: true))
                continue
            }
            if sortDesc.count != 2 { continue }
            let isAscending = sortDesc[1].lowercased() == pwgImageOrder.ascending.rawValue ? true : false
            switch sortDesc[0] {
            case pwgImageAttr.title.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.titleStr), ascending: isAscending, selector: #selector(NSString.localizedCaseInsensitiveCompare)))
            case pwgImageAttr.dateCreated.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.dateCreated), ascending: isAscending))
            case pwgImageAttr.datePosted.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: isAscending))
            case pwgImageAttr.fileName.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.fileName), ascending: isAscending, selector: #selector(NSString.localizedCompare)))
            case pwgImageAttr.rating.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.ratingScore), ascending: isAscending))
            case pwgImageAttr.visits.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.visits), ascending: isAscending))
            case pwgImageAttr.identifier.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: isAscending))
            case pwgImageAttr.rank.rawValue, "`\(pwgImageAttr.rank.rawValue)`":
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.rankManual), ascending: isAscending))
            default:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: isAscending))
            }
        }
        if descriptors.isEmpty {
            let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: false)
            let sortByFile = NSSortDescriptor(key: #keyPath(Image.fileName), ascending: true)
            let sortById = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)
            return [sortByPosted, sortByFile, sortById]
        } else {
            return descriptors
        }
    }
    
    lazy var fetchImagesRequest: NSFetchRequest = {
        // Sort images according to default settings
        // PS: Comparator blocks are not supported with Core Data
        let fetchRequest = Image.fetchRequest()
        let sortByIdDesc = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: false)
        let sortByIdAsc = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)
        switch albumData.pwgID {
        case pwgSmartAlbum.search.rawValue:
            // 'datePosted' is always accessible (returned by pwg.images.search)
            fetchRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.datePostedAscending.param)
            
        case pwgSmartAlbum.visits.rawValue:
            // 'visits' is always accessible (returned by pwg.category.getImages)
            fetchRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.visitsDescending.param)
            
        case pwgSmartAlbum.best.rawValue:
            // 'ratingScore' is not always accessible (returned by pwg.images.getInfo)
            // so the image list might not be identical to the one returned by the web UI.
            fetchRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.ratingScoreDescending.param)
            
        case pwgSmartAlbum.recent.rawValue:
            // 'datePosted' can be unknown and defaults to 01/01/1900 in such situation
            fetchRequest.sortDescriptors = sortDescriptors(for: pwgImageSort.datePostedDescending.param)
            
        default:    // Sorting option chosen by user
            if albumData.imageSort.isEmpty {
                // Piwigo version < 14
                if AlbumVars.shared.defaultSort.rawValue > pwgImageSort.random.rawValue {
                    AlbumVars.shared.defaultSort = .dateCreatedAscending
                }
                fetchRequest.sortDescriptors = sortDescriptors(for: AlbumVars.shared.defaultSort.param)
            }
            else if AlbumVars.shared.defaultSort == pwgImageSort.albumDefault {
                fetchRequest.sortDescriptors = sortDescriptors(for: albumData.imageSort)
            }
            else {
                fetchRequest.sortDescriptors = sortDescriptors(for: AlbumVars.shared.defaultSort.param)
            }
        }
        fetchRequest.predicate = imagePredicate.withSubstitutionVariables(["catId" : albumData.pwgID])
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()
    
    lazy var images: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        images.delegate = self
        return images
    }()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("••> viewDidLoad images…")

        // Set collection view layout and enable prefetching
        collectionView?.collectionViewLayout = ImageCollectionViewFlowLayout()
        collectionView?.isPrefetchingEnabled = true
        
        // Register ImageCollectionViewCell and ImagesFooterReusableView classes
        collectionView?.register(UINib(nibName: "ImageCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ImageCollectionViewCell")
        collectionView?.register(ImageFooterReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooter")

        // Register palette changes
        NotificationCenter.default.addObserver(self,selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Collection view
        collectionView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        (collectionView?.visibleCells ?? []).forEach { cell in
            if let imageCell = cell as? ImageCollectionViewCell {
                imageCell.applyColorPalette()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("••> viewWillAppear images…")

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Initialise data source
        do {
            try images.performFetch()
        } catch {
            print("Error: \(error)")
        }
        
        // Restore image view if necessary
        if indexOfImageToRestore != Int.min,
           let allImages = images.fetchedObjects, allImages.count > indexOfImageToRestore
        {
            let indexPath = IndexPath(item: indexOfImageToRestore, section: 0)
            presentImage(ofCell: ImageCollectionViewCell(), at: indexPath, animated: false)

            // Image restored ► Reset index
            indexOfImageToRestore = Int.min

            // Scroll collection view to cell position
            imageOfInterest = indexPath
            collectionView?.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        } else {
//            collectionView?.reloadData()
        }
        
        // For bebugging…
        timeCounter = CFAbsoluteTimeGetCurrent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("••> viewDidLayoutSubviews imageCollectionView: ", collectionView?.collectionViewLayout.collectionViewContentSize as Any)

        // Update table row height after collection view layouting
        if let albumImageVC = parent as? AlbumImageTableViewController {
            albumImageVC.imageCollectionCell?.invalidateIntrinsicContentSize()
            if #available(iOS 16, *) {
                // NOP — ImageCollectionTableViewCell height updated automatically
            } else if didUpdateCellHeight == false {
                // Update ImageCollectionTableViewCell updated manually once
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        albumImageVC.albumImageTableView?.beginUpdates()
                        albumImageVC.albumImageTableView?.endUpdates()
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Speed and memory measurements with iPad Pro 11" in debug mode
        /// Old method —> 0 photo: 527 ms, 24 photos: 583 ms, 3020 photos: 15 226 ms (memory crash after repeating tests)
        /// hasFavorites  cached —> a very little quicker but less memory impacting (-195 MB transcient allocations for 3020 photos)
        /// placeHolder & size cached —> 0 photo: 526 ms, 24 photos: 585 ms, 3020 photos: 14 586 ms i.e. -6% (memory crash after repeating tests)
        let diff = (CFAbsoluteTimeGetCurrent() - timeCounter)*1000
        print("••> viewDidAppear imageCollectionView in \(diff.rounded()) ms")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Reload collection
            collectionView?.reloadData()
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        didUpdateCellHeight = true
    }
    
    deinit {
        // Cancel all block operations
        for operation in updateOperations {
            operation.cancel()
        }
        updateOperations.removeAll(keepingCapacity: false)
        
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    

    // MARK: - Image Data
    func revealImageOfInteret() {
        if imageOfInterest.item != 0 {
            // Highlight the cell of interest
            let indexPathsForVisibleItems = collectionView?.indexPathsForVisibleItems
            if indexPathsForVisibleItems?.contains(imageOfInterest) ?? false {
                // Thumbnail is already visible and is highlighted
                if let cell = collectionView?.cellForItem(at: imageOfInterest),
                   let imageCell = cell as? ImageCollectionViewCell {
                    imageCell.highlight() {
                        self.imageOfInterest = IndexPath(item: 0, section: 0)
                    }
                } else {
                    self.imageOfInterest = IndexPath(item: 0, section: 0)
                }
            }
        }
    }
    
    private func getImageCount() -> String {
        // Build footer content
        var legend = ""
        if albumData.nbImages == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if albumData.nbImages == Int64.zero {
            // Not loading and no images
            if albumData.pwgID == Int64.zero {
                legend = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
            } else {
                legend = NSLocalizedString("noImages", comment:"No Images")
            }
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: albumData.nbImages)) {
                let format:String = albumData.nbImages > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
    
    func updateNberOfImagesInFooter() {
        // Update number of images in footer
        DispatchQueue.main.async { [self] in
            let indexPath = IndexPath(item: 0, section: 0)
            if let footer = collectionView?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? ImageFooterReusableView {
                footer.nberImagesLabel?.text = getImageCount()
            }
        }
    }
    
    func resetPredicateAndPerformFetch() {
        // Update images
        fetchImagesRequest.predicate = imagePredicate.withSubstitutionVariables(["catId" : albumData.pwgID])
        try? images.performFetch()
    }
}


// MARK: - UICollectionViewDataSourcePrefetching
extension ImageCollectionViewController: UICollectionViewDataSourcePrefetching
{
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        print("••> prefetchItemsAt \(indexPaths.debugDescription)")
        for indexPath in indexPaths {
            // Retrieve image data
            let imageData = images.object(at: indexPath)
            
            // Retrieve image from cache or download it
            let nbImages = AlbumVars.shared.thumbnailsPerRowInPortrait  // from Settings
            let size = AlbumUtilities.imageSize(forView: collectionView, imagesPerRowInPortrait: nbImages)
            let cellSize = CGSize(width: size, height: size)
            let scale = self.traitCollection.displayScale
            ImageSession.shared.getImage(withID: imageData.pwgID, ofSize: imageSize,
                                         atURL: ImageUtilities.getURL(imageData, ofMinSize: imageSize),
                                         fromServer: imageData.server?.uuid, fileSize: imageData.fileSize,
                                         placeHolder: imagePlaceHolder) { cachedImageURL in
                let _ = ImageUtilities.downsample(imageAt: cachedImageURL, to: cellSize, scale: scale)
            } failure: { _ in
                // No image available
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        print("••> cancelPrefetchingForItemsAt \(indexPaths.debugDescription)")
        for indexPath in indexPaths {
            // Retrieve image data
            let imageData = images.object(at: indexPath)
            
            // Cancel download if needed
            guard let imageURL = ImageUtilities.getURL(imageData, ofMinSize: imageSize)
            else { return }
            ImageSession.shared.cancelDownload(atURL: imageURL)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ImageCollectionViewController
{
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        if albumData.pwgID != 0, kind == UICollectionView.elementKindSectionFooter {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooter", for: indexPath) as? ImageFooterReusableView else { fatalError("!!! NO ImageFooterReusableView class !!!")}
            footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
            footer.nberImagesLabel?.text = getImageCount()
            return footer
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let objects = images.fetchedObjects
        return objects?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Create cell from Piwigo data
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCollectionViewCell", for: indexPath) as? ImageCollectionViewCell else { fatalError("No ImageCollectionViewCell!") }

        // Add pan gesture recognition if needed
        if cell.gestureRecognizers == nil {
            let imageSeriesRocognizer = UIPanGestureRecognizer(target: self, action: #selector(touchedImages(_:)))
            imageSeriesRocognizer.minimumNumberOfTouches = 1
            imageSeriesRocognizer.maximumNumberOfTouches = 1
            imageSeriesRocognizer.cancelsTouchesInView = false
            imageSeriesRocognizer.delegate = self
            cell.addGestureRecognizer(imageSeriesRocognizer)
            cell.isUserInteractionEnabled = true
        }

        // Retrieve image data
        let image = images.object(at: indexPath)
        
        // Is this cell selected?
        cell.isSelection = selectedImageIds.contains(image.pwgID)
        
        // pwg.users.favorites… methods available from Piwigo version 2.10
        if hasFavorites {
            cell.isFavorite = (image.albums ?? Set<Album>())
                .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
        }
        
        // The image being retrieved in a background task,
        // config() must be called after setting all other parameters
        cell.config(with: image, placeHolder: imagePlaceHolder, size: imageSize)
        debugPrint("••> Adds image cell at \(indexPath.item): \(cell.bounds.size)")
        return cell
    }
}


// MARK: - UICollectionViewDelegateFlowLayout
extension ImageCollectionViewController: UICollectionViewDelegateFlowLayout
{
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if elementKind == UICollectionView.elementKindSectionHeader {
            view.layer.zPosition = 0 // Below scroll indicator
            view.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        if albumData.pwgID == 0 { return CGSize.zero}
        
        // Get number of images and status
        let footer = getImageCount()
        if footer.isEmpty { return CGSize.zero }
        
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light)]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(
            with: CGSize(width: collectionView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes, context: context)
        return CGSize(width: collectionView.frame.size.width - 30.0,
                      height: ceil(footerRect.size.height + 8.0))
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        if collectionView.numberOfItems(inSection: section) == 0 {
            return UIEdgeInsets.zero
        } else if albumData.comment.string.isEmpty {
            return UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        } else {
            return UIEdgeInsets(top: 10, left: 0, bottom: 4, right: 0)
        }
    }
}


// MARK: - UICollectionViewDelegate
extension ImageCollectionViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Check data
        guard let selectedCell = collectionView.cellForItem(at: indexPath) as? ImageCollectionViewCell,
              indexPath.item >= 0, indexPath.item < (images.fetchedObjects ?? []).count else {
            return
        }

        // Action depends on mode
        if isSelect {
            // Check image ID
            guard let imageId = selectedCell.imageData?.pwgID, imageId != 0 else {
                return
            }
            
            // Selection mode active => add/remove image from selection
            if !selectedImageIds.contains(imageId) {
                selectedImageIds.insert(imageId)
                selectedCell.isSelection = true
                if selectedCell.isFavorite {
                    selectedFavoriteIds.insert(imageId)
                }
                if selectedCell.imageData.isVideo {
                    selectedVideosIds.insert(imageId)
                }
            } else {
                selectedCell.isSelection = false
                selectedImageIds.remove(imageId)
                selectedFavoriteIds.remove(imageId)
                selectedVideosIds.remove(imageId)
            }
            
            // Update nav buttons
            imageSelectionDelegate?.updateSelectMode(withInit: false)
            return
        }
        
        // Add category to list of recent albums
        let userInfo = ["categoryId": NSNumber(value: albumData.pwgID)]
        NotificationCenter.default.post(name: .pwgAddRecentAlbum, object: nil, userInfo: userInfo)

        // Selection mode not active => display full screen image
        presentImage(ofCell: selectedCell, at: indexPath, animated: true)
    }
    
    func presentImage(ofCell selectedCell: ImageCollectionViewCell, at indexPath: IndexPath, animated: Bool) {
        // Create ImageViewController
        let imageDetailSB = UIStoryboard(name: "ImageViewController", bundle: nil)
        guard let imageDetailView = imageDetailSB.instantiateViewController(withIdentifier: "ImageViewController") as? ImageViewController else { fatalError("!!! NO ImageViewController !!!") }
        imageDetailView.imageIndex = indexPath.item
        imageDetailView.categoryId = albumData.pwgID
        imageDetailView.images = images
        imageDetailView.user = user
        imageDetailView.imgDetailDelegate = self
        
        // Prepare image animated transitioning
        guard let albumImageVC = parent as? AlbumImageTableViewController else { return }
        albumImageVC.animatedCell = selectedCell
        albumImageVC.albumViewSnapshot = albumImageVC.view.snapshotView(afterScreenUpdates: false)
        albumImageVC.cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: false)
        albumImageVC.navBarSnapshot = navigationController?.navigationBar.snapshotView(afterScreenUpdates: false)

        // Push ImageDetailView embedded in navigation controller
        let navController = UINavigationController(rootViewController: imageDetailView)
        navController.hidesBottomBarWhenPushed = true
        navController.transitioningDelegate = albumImageVC
        navController.modalPresentationStyle = .custom
        navController.modalPresentationCapturesStatusBarAppearance = true
        navigationController?.present(navController, animated: animated)
        
        // Remember that user did tap this image
        imageOfInterest = indexPath
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension ImageCollectionViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if collectionView?.window == nil || controller != images { return }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Check that this update should be managed by this view controller
        guard let fetchDelegate = controller.delegate as? ImageCollectionViewController else { return }
        if collectionView?.window == nil || controller != images { return }

        // Collect operation changes
        switch type.rawValue {
        case NSFetchedResultsChangeType.delete.rawValue:
            guard let indexPath = indexPath else { return }
            guard let image = anObject as? Image else { return }
            selectedImageIds.remove(image.pwgID)
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Delete image of album #\(fetchDelegate.albumData.pwgID) at \(indexPath)")
                self?.collectionView?.deleteItems(at: [indexPath])
            })
            // Disable menu if this is the last deleted image
            if albumData.nbImages == 0 {
                updateOperations.append( BlockOperation { [weak self] in
                    debugPrint("••> Last removed image ► disable menu")
                    self?.isSelect = false
                    self?.imageSelectionDelegate?.updatePreviewMode(withInit: true)
                })
            }
        case NSFetchedResultsChangeType.update.rawValue:
            guard let indexPath = indexPath else { return }
            guard let image = anObject as? Image else { return }
            updateOperations.append( BlockOperation {  [self] in
                debugPrint("••> Update image at \(indexPath) of album #\(fetchDelegate.albumData.pwgID)")
                if let cell = self.collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell {
                    // Re-configure image cell
                    cell.config(with: image, placeHolder: self.imagePlaceHolder, size: self.imageSize)
                    // pwg.users.favorites… methods available from Piwigo version 2.10
                    if "2.10.0".compare(NetworkVars.pwgVersion, options: .numeric) != .orderedDescending {
                        cell.isFavorite = (image.albums ?? Set<Album>())
                            .contains(where: {$0.pwgID == pwgSmartAlbum.favorites.rawValue})
                    }
                }
            })
        case NSFetchedResultsChangeType.insert.rawValue:
            guard let newIndexPath = newIndexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Insert image of album #\(fetchDelegate.albumData.pwgID) at \(newIndexPath)")
                self?.collectionView?.insertItems(at: [newIndexPath])
            })
            // Enable menu if this is the first added image
            if albumData.nbImages == 1 {
                updateOperations.append( BlockOperation { [weak self] in
                    debugPrint("••> First added image ► enable menu")
                    self?.imageSelectionDelegate?.updatePreviewMode(withInit: true)
                })
            }
        case NSFetchedResultsChangeType.move.rawValue:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath,
                  indexPath != newIndexPath else { return }
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Move image of album #\(fetchDelegate.albumData.pwgID) from \(indexPath) to \(newIndexPath)")
                self?.collectionView?.moveItem(at: indexPath, to: newIndexPath)
            })
        default:
            fatalError("AlbumViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if collectionView?.window == nil || controller != images || updateOperations.isEmpty { return }

        // Update objects
        collectionView?.performBatchUpdates { [weak self] in
            self?.updateOperations.forEach({ $0.start()})
        } completion: { [weak self] _ in
            // Update footer
            self?.updateNberOfImagesInFooter()
        }
    }
}


// MARK: - ImageDetailDelegate Methods
extension ImageCollectionViewController: ImageDetailDelegate {
    func didSelectImage(atIndex imageIndex: Int) {
        // Scroll view to center image
        if (collectionView?.numberOfItems(inSection: 0) ?? 0) > imageIndex {
            let indexPath = IndexPath(item: imageIndex, section: 0)
            imageOfInterest = indexPath
            collectionView?.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
            
            // Prepare variables for transitioning delegate
            if let selectedCell = collectionView?.cellForItem(at: indexPath) as? ImageCollectionViewCell,
               let albumImageVC = parent as? AlbumImageTableViewController {
                albumImageVC.animatedCell = selectedCell
                albumImageVC.albumViewSnapshot = albumImageVC.view.snapshotView(afterScreenUpdates: false)
                albumImageVC.cellImageViewSnapshot = selectedCell.snapshotView(afterScreenUpdates: false)
                albumImageVC.navBarSnapshot = navigationController?.navigationBar.snapshotView(afterScreenUpdates: false)
            }
        }
    }
}
