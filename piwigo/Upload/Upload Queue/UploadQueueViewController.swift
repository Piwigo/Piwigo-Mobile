//
//  UploadQueueViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit

@available(iOS 13.0, *)
@objc
class UploadQueueViewController: UIViewController, UITableViewDelegate {

    // MARK: - Core Data
    /**
     The managedObjectContext that manages Core Data objects in the main queue.
     The UploadsProvider that collects upload data, saves it to Core Data, and serves it to the uploader.
     */
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return context
    }()

    private lazy var uploadsProvider: UploadsProvider = {
        let provider : UploadsProvider = UploadsProvider()
        provider.fetchedNonCompletedResultsControllerDelegate = self
        return provider
    }()
    
    
    // MARK: - View
    @IBOutlet weak var queueTableView: UITableView!
    private var actionBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?

    typealias DataSource = UITableViewDiffableDataSource<String,NSManagedObjectID>
    private lazy var diffableDataSource: DataSource = configDataSource()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "action"), landscapeImagePhone: UIImage(named: "actionCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitUpload))
        doneBarButton?.accessibilityIdentifier = "Done"

        // Register section header view
        queueTableView.register(UploadImageHeaderView.self, forHeaderFooterViewReuseIdentifier:"UploadImageHeaderView")

        // Initialise dataSource and tableView
        applyInitialSnapshots()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPaletteToInitialViews()

        // Navigation bar button and identifier
        navigationItem.setLeftBarButtonItems([doneBarButton].compactMap { $0 }, animated: false)
        navigationController?.navigationBar.accessibilityIdentifier = "UploadQueueNav"
        updateNavBar()
        
        // Header informing user on network status
        mainHeader()
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
        navigationController?.navigationBar.prefersLargeTitles = false
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
        let visibleCells = queueTableView.visibleCells as? [UploadImageTableViewCell] ?? []
        visibleCells.forEach { (cell) in
            cell.backgroundColor = UIColor.piwigoColorCellBackground()
            cell.uploadInfoLabel.textColor = UIColor.piwigoColorLeftLabel()
            cell.swipeBackgroundColor = UIColor.piwigoColorCellBackground()
            cell.imageInfoLabel.textColor = UIColor.piwigoColorRightLabel()
        }
        for section in 0..<queueTableView.numberOfSections {
            let header = queueTableView.headerView(forSection: section) as? UploadImageHeaderView
            header?.headerLabel.textColor = UIColor.piwigoColorHeader()
            header?.headerBckg.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
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

        // Unregister upload progress
        let name2: NSNotification.Name = NSNotification.Name(kPiwigoNotificationUploadProgress)
        NotificationCenter.default.removeObserver(self, name: name2, object: nil)
    }

    
    // MARK: - Action Menu
    
    func updateNavBar() {
        // Title
        let nberOfImagesInQueue = diffableDataSource.snapshot().numberOfItems
        title = nberOfImagesInQueue > 1 ?
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("severalImages", comment: "Photos")) :
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("singleImage", comment: "Photo"))
        
        // Action menu
        var hasImpossibleUploadsSection = false
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
            hasImpossibleUploadsSection = true
        }
        var hasFailedUploadsSection = false
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section2.rawValue) {
            hasFailedUploadsSection = true
        }
        if hasImpossibleUploadsSection || hasFailedUploadsSection {
            navigationItem.rightBarButtonItems = [actionBarButton].compactMap { $0 }
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }
    
    @objc func didTapActionButton() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Cancel action
        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in })
        alert.addAction(cancelAction)

        // Resume upload requests in section 2 (preparingError, uploadingError, finishingError)
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section2.rawValue) {
            let failedUploads = diffableDataSource.snapshot().numberOfItems(inSection: SectionKeys.Section2.rawValue)
            if failedUploads > 0 {
                let titleResume = failedUploads > 1 ? String(format: NSLocalizedString("imageUploadResumeSeveral", comment: "Resume %@ Failed Uploads"), NumberFormatter.localizedString(from: NSNumber.init(value: failedUploads), number: .decimal)) : NSLocalizedString("imageUploadResumeSingle", comment: "Resume Failed Upload")
                let resumeAction = UIAlertAction(title: titleResume, style: .default, handler: { action in
                    if let _ = self.diffableDataSource.snapshot().indexOfSection(SectionKeys.Section2.rawValue) {
                        // Get IDs of upload requests which can be resumed
                        let uploadIds = self.diffableDataSource.snapshot().itemIdentifiers(inSection: SectionKeys.Section2.rawValue)
                        // Resume failed uploads
                        UploadManager.shared.backgroundQueue.async {
                            UploadManager.shared.resume(failedUploads: uploadIds, completionHandler: { (error) in
                                if let error = error {
                                    // Inform user
                                    let alert = UIAlertController(title: NSLocalizedString("errorHUD_label", comment: "Error"), message: error.localizedDescription, preferredStyle: .alert)
                                    let cancelAction = UIAlertAction(title: NSLocalizedString("alertDismissButton", comment: "Dismiss"), style: .destructive, handler: { action in
                                        })
                                    alert.addAction(cancelAction)
                                    alert.view.tintColor = UIColor.piwigoColorOrange()
                                    alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
                                    self.present(alert, animated: true, completion: {
                                        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                                        alert.view.tintColor = UIColor.piwigoColorOrange()
                                    })
                                } else {
                                    // Relaunch uploads
                                    UploadManager.shared.findNextImageToUpload()
                                }
                            })
                        }
                    }
                })
                alert.addAction(resumeAction)
            }
        }

        // Clear impossible upload requests in section 1 (preparingFail, formatError)
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
            let impossibleUploads = diffableDataSource.snapshot().numberOfItems(inSection: SectionKeys.Section1.rawValue)
            if impossibleUploads > 0 {
                let titleClear = impossibleUploads > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber.init(value: impossibleUploads), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
                let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
                    if let _ = self.diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
                        // Get IDs of upload requests which won't be possible to perform
                        let uploadIds = self.diffableDataSource.snapshot().itemIdentifiers(inSection: SectionKeys.Section1.rawValue)
                        // Delete failed uploads in a private queue
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.uploadsProvider.delete(uploadRequests: uploadIds)
                        }
                    }
                })
                alert.addAction(clearAction)
            }
        }

        // Don't present the alert if there is only "Cancel"
        if alert.actions.count == 1 {
            updateNavBar()
            return
        }
        
        // Present list of actions
        alert.view.tintColor = UIColor.piwigoColorOrange()
        alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
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

        
    // MARK: - UITableView - DataSource
    
    private func configDataSource() -> DataSource {
        let dataSource = UITableViewDiffableDataSource<String, NSManagedObjectID>(tableView: queueTableView) { (tableView, indexPath, objectID) -> UITableViewCell? in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!")
                return UploadImageTableViewCell()
            }
            let upload = self.managedObjectContext.object(with: objectID) as! Upload
            cell.configure(with: upload, availableWidth: Int(tableView.bounds.size.width))
            return cell
        }
        return dataSource
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>()
        
        // Sections
        let sectionInfos = uploadsProvider.fetchedNonCompletedResultsController.sections
        let sections = sectionInfos?.map({$0.name}) ?? Array(repeating: "—?—", count: sectionInfos?.count ?? 0)
        snapshot.appendSections(sections)
        diffableDataSource.apply(snapshot, animatingDifferences: false)
        
        // Items
        let items = uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects ?? []
        snapshot.appendItems(items.map({$0.objectID}))
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }
    

    // MARK: - UITableView - Headers
    
    @objc func mainHeader() {
        DispatchQueue.main.async {
            if AFNetworkReachabilityManager.shared().isReachableViaWWAN && Model.sharedInstance().wifiOnlyUploading {
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
                if let _ = self.diffableDataSource.snapshot().indexOfSection(SectionKeys.Section3.rawValue) {
                    if self.diffableDataSource.snapshot().numberOfItems(inSection: SectionKeys.Section3.rawValue) > 0 {
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                }
            }
            self.viewWillLayoutSubviews()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
        let sectionName = sectionKey.name
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
        let sectionKey = SectionKeys.init(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
        header.config(with: sectionKey)
        return header
    }
    

    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        let localIdentifier =  (notification.userInfo?["localIdentifier"] ?? "") as! String
        let visibleCells = queueTableView.visibleCells as! [UploadImageTableViewCell]
        for cell in visibleCells {
            if cell.localIdentifier == localIdentifier {
                cell.update(with: notification.userInfo!)
            }
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

@available(iOS 13.0, *)
extension UploadQueueViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        // Update UI
        let snapshot = snapshot as NSDiffableDataSourceSnapshot<String,NSManagedObjectID>
        DispatchQueue.main.async {
            self.diffableDataSource.apply(snapshot, animatingDifferences: self.queueTableView.window != nil)
            self.updateNavBar()
        }
        
        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
        if snapshot.numberOfItems == 0 {
            // Delete remaining files from Upload directory (if any)
            UploadManager.shared.deleteFilesInUploadsDirectory(with: nil)
            // Close the view when there is no more upload request to display
            self.dismiss(animated: true, completion: nil)
        }
    }
}
