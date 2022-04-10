//
//  UploadQueueViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Photos
import UIKit
import piwigoKit

@available(iOS 13.0, *)
@objc
class UploadQueueViewController: UIViewController, UITableViewDelegate {

    // MARK: - Core Data
    /**
     The managedObjectContext that manages Core Data objects in the main queue.
     The UploadsProvider that collects upload data, saves it to Core Data, and serves it to the uploader.
     */
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.managedObjectContext
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
        setTableViewMainHeader()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
        
        // Register network reachability
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.AFNetworkingReachabilityDidChange, object: nil)

        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: .pwgUploadProgress, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Save position of collection view
        if queueTableView.visibleCells.count > 0,
           let cell = queueTableView.visibleCells.first {
            if let indexPath = queueTableView.indexPath(for: cell) {
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
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        // Table view
        queueTableView.separatorColor = .piwigoColorSeparator()
        queueTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
    }
    
    @objc func applyColorPalette() {
        // Set colors, fonts, etc.
        applyColorPaletteToInitialViews()

        // Table view items
        let visibleCells = queueTableView.visibleCells as? [UploadImageTableViewCell] ?? []
        visibleCells.forEach { (cell) in
            cell.backgroundColor = .piwigoColorCellBackground()
            cell.uploadInfoLabel.textColor = .piwigoColorLeftLabel()
            cell.swipeBackgroundColor = .piwigoColorCellBackground()
            cell.imageInfoLabel.textColor = .piwigoColorRightLabel()
        }
        for section in 0..<queueTableView.numberOfSections {
            let header = queueTableView.headerView(forSection: section) as? UploadImageHeaderView
            header?.headerLabel.textColor = .piwigoColorHeader()
            header?.headerBckg.backgroundColor = .piwigoColorBackground().withAlphaComponent(0.75)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Update title of current scene (iPad only)
        view.window?.windowScene?.title = title
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)

        // Unregister network reachability
        NotificationCenter.default.removeObserver(self, name: Notification.Name.AFNetworkingReachabilityDidChange, object: nil)

        // Unregister Low Power Mode status
        NotificationCenter.default.removeObserver(self, name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Unregister upload progress
        NotificationCenter.default.removeObserver(self, name: .pwgUploadProgress, object: nil)
    }
    
    // MARK: - Action Menu
    
    func updateNavBar() {
        // Title
        let nberOfImagesInQueue = diffableDataSource.snapshot().numberOfItems
        title = nberOfImagesInQueue > 1 ?
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("severalImages", comment: "Photos")) :
            String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("singleImage", comment: "Photo"))
        
        // Set title of current scene (iPad only)
        view.window?.windowScene?.title = title

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
                let titleResume = failedUploads > 1 ? String(format: NSLocalizedString("imageUploadResumeSeveral", comment: "Resume %@ Failed Uploads"), NumberFormatter.localizedString(from: NSNumber(value: failedUploads), number: .decimal)) : NSLocalizedString("imageUploadResumeSingle", comment: "Resume Failed Upload")
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
                                    alert.view.tintColor = .piwigoColorOrange()
                                    alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
                                    self.present(alert, animated: true, completion: {
                                        // Bugfix: iOS9 - Tint not fully Applied without Reapplying
                                        alert.view.tintColor = .piwigoColorOrange()
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
                let titleClear = impossibleUploads > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber(value: impossibleUploads), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
                let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
                    if let _ = self.diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
                        // Get IDs of upload requests which won't be possible to perform
                        let uploadIds = self.diffableDataSource.snapshot().itemIdentifiers(inSection: SectionKeys.Section1.rawValue)
                        // Delete failed uploads in the main thread
                        self.uploadsProvider.delete(uploadRequests: uploadIds) { error in
                            // Error encountered?
                            if let error = error {
                                DispatchQueue.main.async {
                                    self.dismissPiwigoError(withTitle: titleClear,
                                                            message: error.localizedDescription) { }
                                }
                            }
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
        alert.view.tintColor = .piwigoColorOrange()
        alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        alert.popoverPresentationController?.barButtonItem = actionBarButton
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
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
        snapshot.appendItems(items.compactMap({$0.objectID}))
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }
    

    // MARK: - UITableView - Headers
    
    @objc func setTableViewMainHeader() {
        DispatchQueue.main.async {
            if AFNetworkReachabilityManager.shared().isReachableViaWWAN && UploadVars.wifiOnlyUploading {
                // No Wi-Fi and user wishes to upload only on Wi-Fi
                let headerView = UploadQueueHeaderView(frame: .zero)
                headerView.configure(width: self.queueTableView.frame.size.width,
                                     text: NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection"))
                self.queueTableView.tableHeaderView = headerView
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Low Power mode enabled
                let headerView = UploadQueueHeaderView(frame: .zero)
                headerView.configure(width: self.queueTableView.frame.size.width,
                                     text: NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled"))
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
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot()
                                        .sectionIdentifiers[section]) ?? SectionKeys.Section4
        return TableViewUtilities.shared.heightOfHeader(withTitle: sectionKey.name,
                                                        width: tableView.frame.size.width)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "UploadImageHeaderView") as? UploadImageHeaderView else {
            print("Error: tableView.dequeueReusableHeaderFooterView does not return a UploadImageHeaderView!")
            return UploadImageHeaderView()
        }
        let sectionKey = SectionKeys(rawValue: diffableDataSource.snapshot().sectionIdentifiers[section]) ?? SectionKeys.Section4
        header.config(with: sectionKey)
        return header
    }
    

    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let localIdentifier =  notification.userInfo?["localIdentifier"] as? String,
           localIdentifier.count > 0 {
            let visibleCells = queueTableView.visibleCells as! [UploadImageTableViewCell]
            for cell in visibleCells {
                if cell.localIdentifier == localIdentifier {
                    cell.update(with: notification.userInfo!)
                    break
                }
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
            // Apply modifications
            self.diffableDataSource.apply(snapshot, animatingDifferences: self.queueTableView.window != nil)
            
            // Update the navigation bar
            self.updateNavBar()
            
            // Refresh header informing user on network status when UploadManager restarted running
            self.setTableViewMainHeader()
        }
        
        // If all upload requests are done, delete all temporary files (in case some would not be deleted)
        if snapshot.numberOfItems == 0 {
            // Delete remaining files from Upload directory (if any)
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.deleteFilesInUploadsDirectory()
            }
            // Close the view when there is no more upload request to display
            self.dismiss(animated: true, completion: nil)
        }
    }
}
