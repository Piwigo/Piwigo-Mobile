//
//  UploadQueueViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@objc
class UploadQueueViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

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
    @IBOutlet var queueTableView: UITableView!
    private var actionBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?

//    private var allUploads: [Upload] = []
//    private var imagesSortedByCategory: [[Upload]] = []
//    private let kPiwigoNberImagesShowHUDWhenSorting = 2_500                 // Show HUD when sorting more than this number of images
//    private var hudViewController: UIViewController?


    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title
        let nberOfImagesInQueue = uploadsProvider.fetchedResultsController.fetchedObjects?.count ?? 0
        title = nberOfImagesInQueue > 1 ?
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("severalImages", comment: "Photos")) :
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("singleImage", comment: "Photo"))
        
        // Get all uploads
//        allUploads = uploadsProvider.fetchedResultsController.fetchedObjects ?? []

        // Fetch uploads and prepare data source in background
//        fetchAndSortImages()

        // Buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "list"), landscapeImagePhone: UIImage(named: "listCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitUpload))
        doneBarButton?.accessibilityIdentifier = "Done"

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)

        // Register upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress), name: name2, object: nil)
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

        // Table view
        queueTableView.separatorColor = UIColor.piwigoColorSeparator()
        queueTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        queueTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Navigation bar button and identifier
        navigationItem.setLeftBarButtonItems([doneBarButton].compactMap { $0 }, animated: true)
        navigationItem.setRightBarButtonItems([actionBarButton].compactMap { $0 }, animated: true)
        navigationController?.navigationBar.accessibilityIdentifier = "UploadQueueNav"

        // Prevent device from sleeping if uploads are in progress
        let uploadsToPerform = uploadsProvider.fetchedResultsController.fetchedObjects?.map({
            ($0.state == .waiting) || ($0.state == .preparing) ||  ($0.state == .prepared) ||
            ($0.state == .uploading) || ($0.state == .finishing) ? 1 : 0}).reduce(0, +) ?? 0
        if uploadsToPerform > 0 {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if let cell = self.queueTableView.visibleCells.first {
            if let indexPath = self.queueTableView.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { context in
                    self.queueTableView.reloadData()

                    // Scroll to previous position
                    self.queueTableView.scrollToRow(at: indexPath, at: .middle, animated: true)
                })
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)

        // Unregister palette changes
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name2, object: nil)
    }

    
    // MARK: - Action Menu
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in })

        // Clear completed uploads
        let completedUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.map({ ($0.state == .finished) ? 1 : 0}).reduce(0, +) ?? 0
        let titleClear = completedUploads > 1 ? String(format: NSLocalizedString("imageUploadClearCompletedSeveral", comment: "Clear %@ Completed"), NumberFormatter.localizedString(from: NSNumber.init(value: completedUploads), number: .decimal)) : NSLocalizedString("imageUploadClearCompletedSingle", comment: "Clear 1 Completed")
        let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
            // Get completed uploads
            guard let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects else {
                return
            }
            // Get uploads to delete
            let uploadsToDelete = allUploads.filter({ $0.state == .finished})
            // Delete completed uploads in background
            self.uploadsProvider.delete(uploadRequests: uploadsToDelete)
        })
        
        // Delete uploaded photos
        let titleDelete = completedUploads > 1 ? String(format: NSLocalizedString("deleteCategory_allImages", comment: "Delete %@ Photos"), NumberFormatter.localizedString(from: NSNumber.init(value: completedUploads), number: .decimal)) : NSLocalizedString("deleteSingleImage_title", comment: "Delete Photo")
        let deleteAction = UIAlertAction(title: titleDelete, style: .destructive, handler: { action in
            // Delete uploaded images (fetch on the main queue)
            if let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects {
                let uploadsToDelete = allUploads.filter({ $0.state == .finished })
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.uploadManager?.delete(uploadedImages: uploadsToDelete)
            }
        })
        
        // Clear impossible uploads
        let impossibleUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.map({ ($0.state == .preparingFail) ? 1 : 0}).reduce(0, +) ?? 0
        let titleClear2 = impossibleUploads > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber.init(value: impossibleUploads), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
        let clearAction2 = UIAlertAction(title: titleClear2, style: .default, handler: { action in
            // Get completed uploads
            guard let allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects else {
                return
            }
            // Get uploads to delete
            let uploadsToDelete = allUploads.filter({ $0.state == .preparingFail})
            // Delete failed uploads in background
            self.uploadsProvider.delete(uploadRequests: uploadsToDelete)
        })
        
        // Retry failed uploads
        let failedUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.map({ ($0.state == .preparingError) || ($0.state == .uploadingError) || ($0.state == .finishingError) ? 1 : 0}).reduce(0, +) ?? 0
        let titleResume = failedUploads > 1 ? String(format: NSLocalizedString("imageUploadResumeSeveral", comment: "Resume %@ Failed Uploads"), NumberFormatter.localizedString(from: NSNumber.init(value: failedUploads), number: .decimal)) : NSLocalizedString("imageUploadResumeSingle", comment: "Resume Failed Upload")
        let resumeAction = UIAlertAction(title: titleResume, style: .default, handler: { action in
            // Collect list of failed uploads
            if let failedUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects?.filter({$0.state == .preparingError || $0.state == .uploadingError || $0.state == .finishingError }) {
                // Resume failed uploads
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.uploadManager?.resume(failedUploads: failedUploads, completionHandler: { (error) in
                    if let error = error {
                        // Inform user
                        let alert = UIAlertController(title: NSLocalizedString("errorHUD_label", comment: "Error"), message: error.localizedDescription, preferredStyle: .alert)
                        let cancelAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .destructive, handler: { action in
                            })
                        alert.addAction(cancelAction)
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
                })
            }
        })

        // Add actions
        alert.addAction(cancelAction)
        if failedUploads > 0 {
            alert.addAction(resumeAction)
        }
        if impossibleUploads > 0 {
            alert.addAction(clearAction2)
        }
        if completedUploads > 0 {
            alert.addAction(clearAction)
            alert.addAction(deleteAction)
        }

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
    
    @objc func quitUpload() {
        // Leave Upload action and return to Albums and Images
        dismiss(animated: true)
    }


    // MARK: - Fetch and Sort Images
//    func fetchAndSortImages() -> Void {
//        // Get all uploads
//        DispatchQueue.global(qos: .userInitiated).async {
//            // Get all uploads
//            self.allUploads = self.uploadsProvider.fetchedResultsController.fetchedObjects ?? []
//
//            // Sort collected images
//            self.sortCollectionOfImages()
//        }
//    }
    
    // Sorts images by Piwigo album
    // A first batch is sorted and displayed
    // A second batch follows in the background and finally upadtes the table
//    private func sortCollectionOfImages() {
//
//        // Sort first limited batch of images
//        let start = CFAbsoluteTimeGetCurrent()
//        let nberOfImages = min(allUploads.count, kPiwigoNberImagesShowHUDWhenSorting)
//        imagesSortedByCategory = split(inRange: 0..<nberOfImages)
//        let diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("=> Splitted", nberOfImages, "images by days, weeks and months took \(diff) ms")
//
//        // Display first limited batch of images
//        DispatchQueue.main.async {
//            // Refresh collection view
//            self.queueTableView.reloadData()
//        }
//
//        // Sort remaining images
//        if allUploads.count > kPiwigoNberImagesShowHUDWhenSorting {
//
//            // Show HUD during job
//            DispatchQueue.main.async {
//                self.showHUDwithTitle(NSLocalizedString("imageSortingHUD", comment: "Sorting Images"))
//            }
//
//            // Initialisation
//            var remainingImagesSortedByCategory: [[Upload]] = []
//
//            // Sort remaining images
//            remainingImagesSortedByCategory = split(inRange: kPiwigoNberImagesShowHUDWhenSorting..<allUploads.count)
//
//            // Images sorted by category
//            if remainingImagesSortedByCategory.count > 0 {
//                let lastCategory = imagesSortedByCategory.last?.last?.category
//                let firstCategory = remainingImagesSortedByCategory.first?.first?.category
//                if lastCategory == firstCategory {
//                    // Append images to last section
//                    imagesSortedByCategory[imagesSortedByCategory.count - 1].append(contentsOf: (remainingImagesSortedByCategory.first)!)
//
//                    // Update collection view if needed
//                    updateSection(with: remainingImagesSortedByCategory.first!)
//
//                    // Append new sections
//                    if remainingImagesSortedByCategory.count > 1 {
//                        // Append sections
//                        imagesSortedByCategory.append(contentsOf: remainingImagesSortedByCategory[1...remainingImagesSortedByCategory.count-1])
//
//                        // Update collection view if needed
//                        addSections(of: Array(remainingImagesSortedByCategory.dropFirst()))
//
//                        // Hide HUD at end of job
//                        DispatchQueue.main.async {
//                            self.hideHUDwithSuccess(true) {
//                            }
//                        }
//                    }
//                } else {
//                    // Append new section
//                    remainingImagesSortedByCategory.append(contentsOf: remainingImagesSortedByCategory[0...remainingImagesSortedByCategory.count-1])
//
//                    // Update collection view if needed
//                    addSections(of: remainingImagesSortedByCategory)
//
//                    // Hide HUD at end of job
//                    DispatchQueue.main.async {
//                        self.hideHUDwithSuccess(true) {
//                        }
//                    }
//                }
//            }
//        }
//    }
    
//    private func updateSection(with images:[Upload]!) {
//        // Append images of the day, week or month to last section
//        DispatchQueue.main.async {
//            // Update data source
//            let indexOfLastItem = self.imagesSortedByCategory.last!.count
//            let nberOfAddedItems = images.count
//            let indexesOfNewItems = Array(indexOfLastItem..<indexOfLastItem + nberOfAddedItems).map { IndexPath(item: $0, section: self.imagesSortedByCategory.count-1) }
//            self.imagesSortedByCategory[self.imagesSortedByCategory.count-1].append(contentsOf: images)
//
//            // Update section
//            self.queueTableView.insertRows(at: indexesOfNewItems, with: .automatic)
//        }
//    }
    
//    private func addSections(of images: [[Upload]]) {
//        // Append sections of images to current data source
//        DispatchQueue.main.async {
//            // Update data source
//            let nberOfAddedSections = images.count
//            let indexesOfNewSections = IndexSet.init(integersIn: self.imagesSortedByCategory.count..<self.imagesSortedByCategory.count + nberOfAddedSections)
//            self.imagesSortedByCategory.append(contentsOf: images)
//            // Update section
//            self.queueTableView.insertSections(indexesOfNewSections, with: .automatic)
//        }
//
//    }
    
//    private func split(inRange range: Range<Int>) -> [[Upload]]  {
//
//        // Get collection of images sorted by ascending request date
//        var start = CFAbsoluteTimeGetCurrent()
//        let uploads = Array(allUploads[range.startIndex ..< range.endIndex])
//        var diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("           uploads.objects took \(diff) ms")
//
//         Initialisation
//        start = CFAbsoluteTimeGetCurrent()
//        var imagesByCatId: [[Upload]] = []
//
//        // Sort imageAssets
//        for index in 0..<range.endIndex-range.startIndex {
//            // Get object
//            let obj = uploads[index]
//
//            // Index of a known category?
//            let index = imagesByCatId.firstIndex(where: { $0.first?.category == obj.category})
//
//            // Add object to array of known category?
//            if let index = index {
//                // Same category -> Append object to section
//                imagesByCatId[index].append(obj)
//            } else {
//                // Append section to collection by category
//                imagesByCatId.append([obj])
//            }
//        }
//
//        diff = (CFAbsoluteTimeGetCurrent() - start)*1000
//        print("           sorting objects took \(diff) ms")
//        return imagesByCatId
//    }

        
    // MARK: - UITableView - Header
    
//    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        // Title
//        var titleString = ""
//        if let category = CategoriesData.sharedInstance()?.getCategoryById(Int(imagesSortedByCategory[section].first!.category)) {
//            titleString = category.name
//        }
//        let titleAttributes = [
//            NSAttributedString.Key.font: UIFont.piwigoFontBold()
//        ]
//        let context = NSStringDrawingContext()
//        context.minimumScaleFactor = 1.0
//        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
//        return CGFloat(fmax(44.0, ceil(titleRect.size.height)))
//    }

//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let headerAttributedString = NSMutableAttributedString(string: "")
//
//        // Title
//        var titleString = ""
//        if let category = CategoriesData.sharedInstance()?.getCategoryById(Int(imagesSortedByCategory[section].first!.category)) {
//            titleString = category.name
//        }
//        let titleAttributedString = NSMutableAttributedString(string: titleString)
//        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
//        headerAttributedString.append(titleAttributedString)
//
//        // Header label
//        let headerLabel = UILabel()
//        headerLabel.translatesAutoresizingMaskIntoConstraints = false
//        headerLabel.textColor = UIColor.piwigoColorHeader()
//
//        headerLabel.numberOfLines = 0
//        headerLabel.adjustsFontSizeToFitWidth = false
//        headerLabel.lineBreakMode = .byWordWrapping
//        headerLabel.attributedText = headerAttributedString
//
//        // Header view
//        let header = UIView()
//        header.addSubview(headerLabel)
//        header.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
//        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
//        if #available(iOS 11, *) {
//            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
//            "header": headerLabel
//            ]))
//        } else {
//            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
//            "header": headerLabel
//            ]))
//        }
//
//        return header
//    }


    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploadsProvider.fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!")
            return UploadImageTableViewCell()
        }
        guard let upload = uploadsProvider.fetchedResultsController.fetchedObjects?[indexPath.row] else { return cell }
        cell.configure(with: upload, width: Int(tableView.bounds.size.width))
        return cell
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        let localIdentifier =  (notification.userInfo?["localIndentifier"] ?? "") as! String
        let visibleCells = queueTableView.visibleCells as! [UploadImageTableViewCell]
        for cell in visibleCells {
            if cell.localIdentifier == localIdentifier {
                cell.update(with: notification.userInfo!)
            }
        }
    }
    
    // MARK: - HUD methods
    
//    func showHUDwithTitle(_ title: String?) {
//        // Determine the present view controller if needed (not necessarily self.view)
//        if hudViewController == nil {
//            hudViewController = UIApplication.shared.keyWindow?.rootViewController
//            while ((hudViewController?.presentedViewController) != nil) {
//                hudViewController = hudViewController?.presentedViewController
//            }
//        }
//
//        // Create the login HUD if needed
//        var hud = hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
//        if hud == nil {
//            // Create the HUD
//            hud = MBProgressHUD.showAdded(to: (hudViewController?.view)!, animated: true)
//            hud?.tag = loadingViewTag
//
//            // Change the background view shape, style and color.
//            hud?.isSquare = false
//            hud?.animationType = MBProgressHUDAnimation.fade
//            hud?.backgroundView.style = MBProgressHUDBackgroundStyle.solidColor
//            hud?.backgroundView.color = UIColor(white: 0.0, alpha: 0.5)
//            hud?.contentColor = UIColor.piwigoColorHudContent()
//            hud?.bezelView.color = UIColor.piwigoColorHudBezelView()
//
//            // Will look best, if we set a minimum size.
//            hud?.minSize = CGSize(width: 200.0, height: 100.0)
//        }
//
//        // Set title
//        hud?.label.text = title
//        hud?.label.font = UIFont.piwigoFontNormal()
//        hud?.mode = MBProgressHUDMode.indeterminate
//        let numberFormatter = NumberFormatter()
//        numberFormatter.numberStyle = .decimal
//        let nberPhotos = numberFormatter.string(from: NSNumber(value: allUploads.count))!
//        hud?.detailsLabel.text = String(format: "%@ %@", nberPhotos, NSLocalizedString("severalImages", comment: "Photos"))
//    }

//    func hideHUDwithSuccess(_ success: Bool, completion: @escaping () -> Void) {
//        DispatchQueue.main.async(execute: {
//            // Hide and remove the HUD
//            let hud = self.hudViewController?.view.viewWithTag(loadingViewTag) as? MBProgressHUD
//            if hud != nil {
//                if success {
//                    let image = UIImage(named: "completed")?.withRenderingMode(.alwaysTemplate)
//                    let imageView = UIImageView(image: image)
//                    hud?.customView = imageView
//                    hud?.mode = MBProgressHUDMode.customView
//                    hud?.label.text = NSLocalizedString("completeHUD_label", comment: "Complete")
//                    hud?.hide(animated: true, afterDelay: 0.3)
//                } else {
//                    hud?.hide(animated: true)
//                }
//            }
//            completion()
//        })
//    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

extension UploadQueueViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        queueTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        let oldIndexPath = indexPath ?? IndexPath.init(row: 0, section: 0)
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            queueTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            queueTableView.deleteRows(at: [oldIndexPath], with: .automatic)
            if uploadsProvider.fetchedResultsController.fetchedObjects?.count == 0 {
                // Delete remaining files from Upload directory (if any)
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.uploadManager?.emptyUploadsDirectory()
                // Close the view when there is no more upload to display
                self.dismiss(animated: true, completion: nil)
            }
        case .move:
            guard let newIndexPath = newIndexPath else { return }
            queueTableView.deleteRows(at: [oldIndexPath], with: .automatic)
            queueTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .update:
            // Upload in progress
            guard let upload:Upload = anObject as? Upload else { return }
            guard let cell = queueTableView.cellForRow(at: oldIndexPath) as? UploadImageTableViewCell else { return }
            var uploadInfo: [String : Any]
            switch upload.state {
            case .waiting, .preparing, .prepared, .formatError, .uploadingError:
                uploadInfo = ["localIndentifier" : upload.localIdentifier,
                              "photoResize" : upload.photoResize,
                              "stateLabel" : upload.stateLabel,
                              "Error" : upload.requestError ?? "",
                              "progressFraction" : Float(0.0)]
            case .uploaded, .finishing, .finishingError, .finished:
                uploadInfo = ["localIndentifier" : upload.localIdentifier,
                              "photoResize" : upload.photoResize,
                              "stateLabel" : upload.stateLabel,
                              "Error" : upload.requestError ?? "",
                              "progressFraction" : Float(1.0)]
            default:
                uploadInfo = ["localIndentifier" : upload.localIdentifier,
                              "photoResize" : upload.photoResize,
                              "stateLabel" : upload.stateLabel,
                              "Error" : upload.requestError ?? ""]
            }
            cell.update(with: uploadInfo)
        @unknown default:
            fatalError("UploadQueueViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Update table view
        queueTableView.endUpdates()
    }
}
