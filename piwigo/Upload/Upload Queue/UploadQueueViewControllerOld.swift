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
class UploadQueueViewControllerOld: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Core Data
    /**
     The UploadsProvider that collects upload data, saves it to Core Data,
     and serves it to the uploader.
     */
    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedNonCompletedResultsControllerDelegate = self
        return provider
    }()

    
    // MARK: - View
    @IBOutlet var queueTableView: UITableView!
    private var actionBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "list"), landscapeImagePhone: UIImage(named: "listCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitUpload))
        doneBarButton?.accessibilityIdentifier = "Done"
        
        // Header informing user on network status
        mainHeader()

        // Register section header view
        queueTableView.register(UploadImageHeaderView.self, forHeaderFooterViewReuseIdentifier:"UploadImageHeaderView")

        // No extra space above tableView
        if #available(iOS 11.0, *) {
            queueTableView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            automaticallyAdjustsScrollViewInsets = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPaletteToInitialViews()

        // Navigation bar button and identifier
        navigationItem.setLeftBarButtonItems([doneBarButton].compactMap { $0 }, animated: false)
        navigationController?.navigationBar.accessibilityIdentifier = "UploadQueueNav"
        updateNavBar()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        guard let header = queueTableView.tableHeaderView else { return }
        header.frame.size.height = header.systemLayoutSizeFitting(CGSize(width: view.bounds.width - 32.0, height: 0)).height
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
    
    private func applyColorPaletteToInitialViews() {
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
    }
    
    @objc func applyColorPalette() {
        // Set colors, fonts, etc.
        applyColorPaletteToInitialViews()

        // Table view items
        queueTableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applyColorPalette), name: name, object: nil)
        
        // Register network reachability
        NotificationCenter.default.addObserver(self, selector: #selector(self.mainHeader), name: NSNotification.Name.AFNetworkingReachabilityDidChange, object: nil)

        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(self.mainHeader), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Register upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applyUploadProgress), name: name2, object: nil)
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
    
    func updateNavBar() {
        // Title
        let nberOfImagesInQueue = uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects?.count ?? 0
        title = nberOfImagesInQueue > 1 ?
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("severalImages", comment: "Photos")) :
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("singleImage", comment: "Photo"))
        
        // Action menu
        let impossibleUploads = uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects?.map({ ($0.state == .preparingFail) ? 1 : 0}).reduce(0, +) ?? 0
        let failedUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.map({ ($0.state == .preparingError) || ($0.state == .uploadingError) || ($0.state == .finishingError) ? 1 : 0}).reduce(0, +) ?? 0

        if impossibleUploads + failedUploads > 0 {
            navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in })
        
        // Clear impossible uploads
        let impossibleUploads = uploadsProvider.fetchedResultsController.fetchedObjects?.map({ ($0.state == .preparingFail) ? 1 : 0}).reduce(0, +) ?? 0
        let titleClear = impossibleUploads > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber.init(value: impossibleUploads), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
        let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
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
                UploadManager.shared.resume(failedUploads: failedUploads, completionHandler: { (error) in
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
            alert.addAction(clearAction)
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

        
    // MARK: - UITableView - Header
    
    @objc func mainHeader() {
        DispatchQueue.main.async {
            if !AFNetworkReachabilityManager.shared().isReachable {
                // No network access
                let headerView = UploadQueueHeaderView(frame: .zero)
                headerView.configure(text: NSLocalizedString("uploadNoInternetNetwork", comment: "No Internet Connection"))
                self.queueTableView.tableHeaderView = headerView
            }
            else if AFNetworkReachabilityManager.shared().isReachableViaWWAN && Model.sharedInstance().wifiOnlyUploading {
                // No Wi-Fi and user wishes to upload only on Wi-Fi
                let headerView = UploadQueueHeaderView(frame: .zero)
                headerView.configure(text: NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection"))
                self.queueTableView.tableHeaderView = headerView
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Low Power mode enabled
                let headerView = UploadQueueHeaderView(frame: .zero)
                headerView.configure(text: NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled"))
                self.queueTableView.tableHeaderView = headerView
            }
            else {
                // Prevent device from sleeping if uploads are in progress
                self.queueTableView.tableHeaderView = nil
                let uploadsToPerform = self.uploadsProvider.fetchedResultsController.fetchedObjects?.map({
                    ($0.state == .waiting) || ($0.state == .preparing) ||  ($0.state == .prepared) ||
                    ($0.state == .uploading) || ($0.state == .finishing) ? 1 : 0}).reduce(0, +) ?? 0
                if uploadsToPerform > 0 {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        var sectionName = SectionKeys.Section4.name
        if let sectionInfo = uploadsProvider.fetchedNonCompletedResultsController.sections?[section] {
            let sectionKey = SectionKeys.init(rawValue: sectionInfo.name) ?? SectionKeys.Section4
            sectionName = sectionKey.name
        }
        let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = sectionName.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "UploadImageHeaderView") as? UploadImageHeaderView else {
            print("Error: tableView.dequeueReusableHeaderFooterView does not return a UploadImageHeaderView!")
            return UploadImageHeaderView()
        }
        if let sectionInfo = uploadsProvider.fetchedNonCompletedResultsController.sections?[section] {
            let sectionKey = SectionKeys.init(rawValue: sectionInfo.name) ?? SectionKeys.Section4
            header.config(with: sectionKey)
        } else {
            header.config(with: SectionKeys.Section4)
        }
        return header
    }
    

    // MARK: - UITableView - Rows
    func numberOfSections(in tableView: UITableView) -> Int {
        if let sections = uploadsProvider.fetchedNonCompletedResultsController.sections {
            return sections.count
        }
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = uploadsProvider.fetchedNonCompletedResultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!")
            return UploadImageTableViewCell()
        }
        let upload = uploadsProvider.fetchedNonCompletedResultsController.object(at: indexPath)
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
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

extension UploadQueueViewControllerOld: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        queueTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        print("    > sectionInfo:", sectionInfo)
        
        switch type {
        case .insert:
            print("insert section… at", sectionIndex)
            queueTableView.insertSections(IndexSet.init(integer: sectionIndex), with: .automatic)
        case .delete:
            print("delete section… at", sectionIndex)
            queueTableView.deleteSections(IndexSet.init(integer: sectionIndex), with: .automatic)
        case .move, .update:
            fallthrough
        @unknown default:
                fatalError("UploadQueueViewController: unknown NSFetchedResultsChangeType")
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        let oldIndexPath = indexPath ?? IndexPath.init(row: 0, section: 0)
        switch type {
        case .insert:
            print("insert…")
            guard let newIndexPath = newIndexPath else { return }
            queueTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            print("delete… at", oldIndexPath)
            // Delete row
            queueTableView.deleteRows(at: [oldIndexPath], with: .automatic)
            // If all upload requests are done, delete all temporary files (in case some would not be deleted)
            if uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects?.count == 0 {
                // Delete remaining files from Upload directory (if any)
                UploadManager.shared.deleteFilesInUploadsDirectory(with: nil)
                // Close the view when there is no more upload request to display
                self.dismiss(animated: true, completion: nil)
            }
        case .move:
            guard let newIndexPath = newIndexPath else { return }
            print("move… from", oldIndexPath, "to", newIndexPath)
            queueTableView.deleteRows(at: [oldIndexPath], with: .fade)
            queueTableView.insertRows(at: [newIndexPath], with: .fade)
            guard let upload:Upload = anObject as? Upload else { return }
            updateCell(at: newIndexPath, with: upload)
        case .update:
            print("update… at", oldIndexPath)
            if newIndexPath == nil {        // Regular update
                guard let upload:Upload = anObject as? Upload else { break }
                updateCell(at: oldIndexPath, with: upload)
            } else {                        // Moving update when using iOS 10
                queueTableView.deleteRows(at: [oldIndexPath], with: .fade)
                queueTableView.insertRows(at: [newIndexPath!], with: .fade)
            }
        @unknown default:
            fatalError("UploadQueueViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    private func updateCell(at indexPath: IndexPath, with upload: Upload) -> Void {
        guard let cell = queueTableView.cellForRow(at: indexPath) as? UploadImageTableViewCell else { return }
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
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // To prevent crash occurring when the last row of a section is removed
        var willDeleteSection = false
        for section in 1..<queueTableView.numberOfSections {
            if queueTableView.numberOfRows(inSection: section) == 1 {
                willDeleteSection = true
            }
        }
        
        if willDeleteSection {
            let dispatchTime = DispatchTime.now() + 0.5
            DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
                self.queueTableView.reloadData()
            }
            return
        }
        
        queueTableView.endUpdates()
        queueTableView.layoutIfNeeded()
        updateNavBar()
    }
}
