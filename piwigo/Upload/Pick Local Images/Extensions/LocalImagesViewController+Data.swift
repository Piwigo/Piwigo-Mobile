//
//  LocalImagesViewController+Data.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 16/03/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit

extension LocalImagesViewController
{
    // MARK: - Fetch and Sort Images
    func fetchImagesByCreationDate() -> Void {
        /**
         Fetch non-empty collection previously selected by user.
         We fetch a specific path of the Photo Library to reduce the workload and store the fetched collection for future use.
         The fetch is performed with ascending creation date.
         */
        // Next line for testing
//        let start = CFAbsoluteTimeGetCurrent()

        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: #keyPath(PHAsset.creationDate), ascending: false)]

        // Fetch image collection
        let assetCollections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.imageCollectionId], options: nil)
        
        // Display album name on iPhone as from iOS 14
        if #available(iOS 14.0, *), UIDevice.current.userInterfaceIdiom == .phone {
            title = assetCollections.firstObject!.localizedTitle
        }
        
        // Fetch images in album
        fetchedImages = PHAsset.fetchAssets(in: assetCollections.firstObject!, options: fetchOptions)

        // Next 2 lines for testing
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Fetched \(fetchedImages.count) assets in \(diff) ms")
        // => Fetched 70331 assets in 205.949068069458 ms with hidden assets
        // => Fetched 70331 assets in 216.99798107147217 ms with option "includeHiddenAssets = false"
    }
    
    // Sorts images by months, weeks and days in the background,
    // initialise the array of selected sections and enable the choices
    func sortImagesAndIndexUploads() -> Void {

        // Operations are organised to reduce time
        // Sort 70588 images by days, weeks and months in 5.2 to 6.7 s with iPhone 11 Pro
        // The above duration is multiplied by 4 when the iPhone is not powered.
        // and index 70588 uploads in about the same if there is no upload request already stored.
        // but index 70588 uploads in 69.1 s if there are already 520 stored upload requests

        // Stop sort already running if any
        queue.cancelAllOperations()
        
        // Pause UploadManager while sorting images
        UploadManager.shared.isPaused = true

        // Sort all images in one loop i.e. O(n)
        let sortOperation = BlockOperation {
            self.indexOfImageSortedByDay = []
            self.indexOfImageSortedByWeek = []
            self.indexOfImageSortedByMonth = []
            if self.fetchedImages.count > 0 {
                // Sort images by months, weeks and days in the background
                if self.selectedImages.compactMap({$0}).isEmpty {
                    self.sortByMonthWeekDay(images: self.fetchedImages)
                } else {
                    self.sortByMonthWeekDayAndUpdateSelection(images: self.fetchedImages)
                }
            } else {
                self.selectedImages = []
                self.selectedSections = [.none]
            }
        }
        sortOperation.completionBlock = {
            // Allow sort options and refresh section headers
            DispatchQueue.main.async {
                if #available(iOS 14, *) {
                    // NOP
                } else {
                    // Enable segments
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.month.rawValue)
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.week.rawValue)
                    self.segmentedControl.setEnabled(true, forSegmentAt: SectionType.day.rawValue)
                    self.segmentedControl.selectedSegmentIndex = Int(self.sortType.rawValue)
                }
            }
        }
        
        // Caching upload request indices
        let cacheOperation = BlockOperation {
            // Initialise cached indexed uploads
            self.indexedUploadsInQueue = .init(repeating: nil, count: self.fetchedImages.count)
            if self.fetchedImages.count > 10 * (self.uploads.fetchedObjects ?? []).count {
                // By iterating uploads in queue
                self.cachingUploadIndicesIteratingUploadsInQueue()
            } else {
                // By iterating fetched images
                self.cachingUploadIndicesIteratingFetchedImages()
            }
        }
        
        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = .max   // Make it a serial queue for debugging with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([sortOperation, cacheOperation], waitUntilFinished: true)

        // Hide HUD when Photo Library notifies changes
        DispatchQueue.main.async {
            if self.isShowingHUD() {
                self.updateHUDwithSuccess {
                    self.hideHUD(afterDelay: pwgDelayHUD) {
                        self.didFinishSorting()
                        self.localImagesCollection.reloadData()
                    }
                }
            } else {
                self.didFinishSorting()
            }
        }
    }
    
    private func didFinishSorting() {
        // Enable Select buttons
        self.updateActionButton()
        self.updateNavBar()

        // Restart UplaodManager activity
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.isPaused = false
            UploadManager.shared.findNextImageToUpload()
        }
        
//        uploadsInQueue.forEach({
//            print("••> uploadsInQueue: \($0?.0 ?? "")")
//        })
//        indexedUploadsInQueue.forEach({
//            print("••> indexedUploadsInQueue: \($0?.0 ?? "")")
//        })
    }

    private func sortByMonthWeekDay(images: PHFetchResult<PHAsset>) -> (Void)  {

        // Empty selection, re-initialise cache for managing selected images
        selectedImages = .init(repeating: nil, count: images.count)

        // Initialisation
//        let start = CFAbsoluteTimeGetCurrent()
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images[0].creationDate ?? Date())
        var firstIndexOfSameDay = 0

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images[0].creationDate ?? Date())
        var firstIndexOfSameWeek = 0

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images[0].creationDate ?? Date())
        var firstIndexOfSameMonth = 0
        
        // Sort imageAssets
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = images.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop first operation in iteration \(i) ;-)")
                indexOfImageSortedByDay = [IndexSet]()
                indexOfImageSortedByWeek = [IndexSet]()
                indexOfImageSortedByMonth = [IndexSet]()
                return
            }

            for index in i*step..<min((i+1)*step,images.count) {
                // Get day of current image
                let creationDate = images[index].creationDate ?? Date()
                let newDayComponents = calendar.dateComponents(byDays, from: creationDate)

                // Image taken the same day?
                if newDayComponents == dayComponents {
                    // Same date -> Next image
                    continue
                } else {
                    // Append section to collection by days
                    indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<index))

                    // Initialise for next day
                    firstIndexOfSameDay = index
                    dayComponents = calendar.dateComponents(byDays, from: creationDate)

                    // Get week of year of new image
                    let newWeekComponents = calendar.dateComponents(byWeeks, from: creationDate)

                    // What should we do with this new image?
                    if newWeekComponents != weekComponents {
                        // Append section to collection by weeks
                        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<index))

                        // Initialise for next week
                        firstIndexOfSameWeek = index
                        weekComponents = newWeekComponents
                    }

                    // Get month of new image
                    let newMonthComponents = calendar.dateComponents(byMonths, from: creationDate)

                    // What should we do with this new image?
                    if newMonthComponents != monthComponents {
                        // Append section to collection by months
                        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<index))

                        // Initialise for next month
                        firstIndexOfSameMonth = index
                        monthComponents = newMonthComponents
                    }
                }
            }
        }

        // Append last section to collection
        indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<images.count))
        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<images.count))
        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<images.count))
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   sorted \(fetchedImages.count) images by days, weeks and months in \(diff) ms")
    }
    
    private func sortByMonthWeekDayAndUpdateSelection(images: PHFetchResult<PHAsset>) -> (Void)  {

        // Store current selection and re-select images after data source change
        let oldSelection = selectedImages
        selectedImages = .init(repeating: nil, count: fetchedImages.count)

        // Initialisation
//        let start = CFAbsoluteTimeGetCurrent()
        let calendar = Calendar.current
        let byDays: Set<Calendar.Component> = [.year, .month, .day]
        var dayComponents = calendar.dateComponents(byDays, from: images[0].creationDate ?? Date())
        var firstIndexOfSameDay = 0

        let byWeeks: Set<Calendar.Component> = [.year, .weekOfYear]
        var weekComponents = calendar.dateComponents(byWeeks, from: images[0].creationDate ?? Date())
        var firstIndexOfSameWeek = 0

        let byMonths: Set<Calendar.Component> = [.year, .month]
        var monthComponents = calendar.dateComponents(byMonths, from: images[0].creationDate ?? Date())
        var firstIndexOfSameMonth = 0
        
        // Sort imageAssets
        let step = 1_000    // Check if this operation was cancelled every 1000 iterations
        let iterations = images.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                print("Stop first operation in iteration \(i) ;-)")
                indexOfImageSortedByDay = [IndexSet]()
                indexOfImageSortedByWeek = [IndexSet]()
                indexOfImageSortedByMonth = [IndexSet]()
                return
            }

            for index in i*step..<min((i+1)*step,images.count) {
                // Get localIdentifier of current image
                let imageID = images[index].localIdentifier
                if let indexOfSelection = oldSelection.firstIndex(where: {$0?.localIdentifier == imageID}) {
                    selectedImages[index] = oldSelection[indexOfSelection]
                }
                
                // Get day of current image
                let creationDate = images[index].creationDate ?? Date()
                let newDayComponents = calendar.dateComponents(byDays, from: creationDate)

                // Image taken the same day?
                if newDayComponents == dayComponents {
                    // Same date -> Next image
                    continue
                } else {
                    // Append section to collection by days
                    indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<index))

                    // Initialise for next day
                    firstIndexOfSameDay = index
                    dayComponents = calendar.dateComponents(byDays, from: creationDate)

                    // Get week of year of new image
                    let newWeekComponents = calendar.dateComponents(byWeeks, from: creationDate)

                    // What should we do with this new image?
                    if newWeekComponents != weekComponents {
                        // Append section to collection by weeks
                        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<index))

                        // Initialise for next week
                        firstIndexOfSameWeek = index
                        weekComponents = newWeekComponents
                    }

                    // Get month of new image
                    let newMonthComponents = calendar.dateComponents(byMonths, from: creationDate)

                    // What should we do with this new image?
                    if newMonthComponents != monthComponents {
                        // Append section to collection by months
                        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<index))

                        // Initialise for next month
                        firstIndexOfSameMonth = index
                        monthComponents = newMonthComponents
                    }
                }
            }
        }

        // Append last section to collection
        indexOfImageSortedByDay.append(IndexSet(integersIn: firstIndexOfSameDay..<images.count))
        indexOfImageSortedByWeek.append(IndexSet(integersIn: firstIndexOfSameWeek..<images.count))
        indexOfImageSortedByMonth.append(IndexSet(integersIn: firstIndexOfSameMonth..<images.count))
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   sorted \(fetchedImages.count) images by days, weeks and months and updated selection in \(diff) ms")
    }
    
    // Return image index from indexPath
    func getImageIndex(for indexPath:IndexPath) -> Int {
        switch sortType {
        case .month:
            switch UploadVars.localImagesSort {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByMonth[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByMonth.endIndex - 1
                if let index = indexOfImageSortedByMonth[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .week:
            switch UploadVars.localImagesSort {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByWeek[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByWeek.endIndex - 1
                if let index = indexOfImageSortedByWeek[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .day:
            switch UploadVars.localImagesSort {
            case .dateCreatedDescending:
                if let index = indexOfImageSortedByDay[indexPath.section].first {
                    return index + indexPath.row
                } else {
                    return 0
                }
            case .dateCreatedAscending:
                let lastSection = indexOfImageSortedByDay.endIndex - 1
                if let index = indexOfImageSortedByDay[lastSection - indexPath.section].last {
                    return index - indexPath.row
                } else {
                    return 0
                }
            default:
                return 0
            }
        case .none:
            switch UploadVars.localImagesSort {
            case .dateCreatedDescending:
                return indexPath.row
            case .dateCreatedAscending:
                return max(0, fetchedImages.count - 1 - indexPath.row)
            default:
                return 0
            }
        }
    }

    private func cachingUploadIndicesIteratingFetchedImages() -> (Void) {
        // For debugging purposes
//        let start = CFAbsoluteTimeGetCurrent()
        
        // Check if this operation was cancelled every 1000 iterations
        let step = 1_000
        let iterations = fetchedImages.count / step
        for i in 0...iterations {
            // Continue with this operation?
            if queue.operations.first!.isCancelled {
                indexedUploadsInQueue = []
                print("Stop second operation in iteration \(i) ;-)")
                return
            }
            
            // Caching indexed uploads and resetting image selection
            for index in i*step..<min((i+1)*step,fetchedImages.count) {
                // Get image identifier
                let imageId = fetchedImages[index].localIdentifier
                if uploads.fetchedObjects == nil {
                    assertionFailure("!!! uploads is nil !!!")
                }
                if let upload = (uploads.fetchedObjects ?? []).first(where: {$0.localIdentifier == imageId}) {
                    let cachedObject = (upload.localIdentifier, upload.state, fetchedImages[index].canPerform(.delete))
                    indexedUploadsInQueue[index] = cachedObject
                }
            }
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   indexed \(fetchedImages.count) images by iterating fetched images in \(diff) ms")
    }

    private func cachingUploadIndicesIteratingUploadsInQueue() -> (Void) {
        // For debugging purposes
//        let start = CFAbsoluteTimeGetCurrent()
        
        // Determine fetched images already in upload queue
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false

        // Operation done if no stored upload requests
        let count = (uploads.fetchedObjects ?? []).count
        if count > 0 {
            // Check if this operation was cancelled every 100 iterations
            let step = 1_00
            let iterations = count / step
            for i in 0...iterations {
                // Continue with this operation?
                if queue.operations.first!.isCancelled {
                    indexedUploadsInQueue = []
                    print("Stop second operation in iteration \(i) ;-)")
                    return
                }

                // Caching fetched images already in upload queue
                if i*step >= min((i+1)*step,count) { break }
                for index in i*step..<min((i+1)*step,count) {
                    // Get image identifier
                    let upload = uploads.object(at: IndexPath(row: index, section: 0))
                    fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", upload.localIdentifier)
                    fetchOptions.fetchLimit = 1
                    if let asset = PHAsset.fetchAssets(with: fetchOptions).firstObject {
                        let idx = fetchedImages.index(of: asset)
                        if idx != NSNotFound {
                            let cachedObject = (upload.localIdentifier, upload.state, asset.canPerform(.delete))
                            if idx >= indexedUploadsInQueue.count {
                                let newElements:[(String,pwgUploadState,Bool)?] = .init(repeating: nil, count: idx - (indexedUploadsInQueue.count - 1))
                                indexedUploadsInQueue.append(contentsOf: newElements)
                            }
                            indexedUploadsInQueue[idx] = cachedObject
                        }
                    }
                }
            }
        }
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("   cached \(count) images by iterating uploads in queue in \(diff) ms")
    }
    
    func getUploadStateOfImage(at index: Int,
                               for cell: LocalImageCollectionViewCell) -> pwgUploadState? {
        var state: pwgUploadState? = nil
        if queue.operationCount == 0, index < indexedUploadsInQueue.count {
            // Indexed uploads available
            state = indexedUploadsInQueue[index]?.1
        } else {
            // Use non-indexed data (might be quite slow)
            state = (uploads.fetchedObjects ?? []).first(where: {
                let upload = $0
                if upload.isFault {
                    // The upload request is not fired yet.
                    upload.willAccessValue(forKey: nil)
                    upload.didAccessValue(forKey: nil)
                }
                return upload.localIdentifier == cell.localIdentifier })?.state
        }
        return state
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate
extension LocalImagesViewController: NSFetchedResultsControllerDelegate
{
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            print("••> LocalImagesViewController: insert pending upload request…")
            // Add upload request to cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Get index of selected image if any and deselect it
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
            }

            // Get index of image and update request in cache
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeHiddenAssets = false
            fetchOptions.predicate = NSPredicate(format: "localIdentifier == %@", upload.localIdentifier)
            fetchOptions.fetchLimit = 1
            if let asset = PHAsset.fetchAssets(with: fetchOptions).firstObject {
                let index = fetchedImages.index(of: asset)
                if index != NSNotFound {
                    let cachedObject = (upload.localIdentifier, upload.state, asset.canPerform(.delete))
                    if index >= indexedUploadsInQueue.count {
                        let newElements:[(String,pwgUploadState,Bool)?] = .init(repeating: nil,
                                count: index - indexedUploadsInQueue.count + 1)
                        indexedUploadsInQueue.append(contentsOf: newElements)
                    }
                    indexedUploadsInQueue[index] = cachedObject
                }
            }

            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .delete:
            print("••> LocalImagesViewController: delete pending upload request…")
            // Delete upload request from cache and update cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Remove image from indexed upload queue
            if let index = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[index] = nil
            }
            // Remove image from selection if needed
            if let index = selectedImages.firstIndex(where: {$0?.localIdentifier == upload.localIdentifier}) {
                // Deselect image
                selectedImages[index] = nil
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        case .move:
            assertionFailure("••> LocalImagesViewController: Unexpected move!")
        case .update:
            print("••• LocalImagesViewController controller:update...")
            // Update upload request and cell
            guard let upload:Upload = anObject as? Upload else { return }

            // Update upload in indexed upload queue
            if let indexOfUploadedImage = indexedUploadsInQueue.firstIndex(where: {$0?.0 == upload.localIdentifier}) {
                indexedUploadsInQueue[indexOfUploadedImage]?.1 = upload.state
            }
            // Update corresponding cell
            updateCellAndSectionHeader(for: upload)
        @unknown default:
            assertionFailure("••> LocalImagesViewController: unknown NSFetchedResultsChangeType!")
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("••• LocalImagesViewController controller:didChangeContent...")
        // Update navigation bar
        updateActionButton()
        updateNavBar()
    }

    func updateCellAndSectionHeader(for upload: Upload) {
        DispatchQueue.main.async {
            if let visibleCells = self.localImagesCollection.visibleCells as? [LocalImageCollectionViewCell],
               let cell = visibleCells.first(where: {$0.localIdentifier == upload.localIdentifier}) {
                // Update cell
                cell.update(selected: false, state: upload.state)
                cell.reloadInputViews()

                // The section will be refreshed only if the button content needs to be changed
                if let indexPath = self.localImagesCollection.indexPath(for: cell) {
                    let selectState = self.updateSelectButton(ofSection:  indexPath.section)
                    let indexPathOfHeader = IndexPath(item: 0, section: indexPath.section)
                    if let header = self.localImagesCollection.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: indexPathOfHeader) as? LocalImagesHeaderReusableView {
                        header.selectButton.setTitle(forState: selectState)
                    }
                }
            }
        }
    }
}
