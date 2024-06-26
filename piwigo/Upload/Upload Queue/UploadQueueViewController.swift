//
//  UploadQueueViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import UIKit
import piwigoKit
import uploadKit

@available(iOS 13.0, *)
class UploadQueueViewController: UIViewController, UITableViewDelegate {

    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()


    // MARK: - Core Data Source
    lazy var fetchPendingRequest: NSFetchRequest = {
        let fetchRequest = Upload.fetchRequest()
        // Sort upload requests by state and date
        // Priority to uploads requested manually, oldest ones first
        var sortDescriptors = [NSSortDescriptor(key: #keyPath(Upload.requestSectionKey), ascending: true)]
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.markedForAutoUpload), ascending: true))
        sortDescriptors.append(NSSortDescriptor(key: #keyPath(Upload.requestDate), ascending: true))
        fetchRequest.sortDescriptors = sortDescriptors

        // Retrieves non-completed upload requests:
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        var unwantedStates: [pwgUploadState] = [.finished, .moderated]
        andPredicates.append(NSPredicate(format: "NOT (requestState IN %@)", unwantedStates.map({$0.rawValue})))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var uploads: NSFetchedResultsController<Upload> = {
        let uploads = NSFetchedResultsController(fetchRequest: fetchPendingRequest,
                                                 managedObjectContext: self.mainContext,
                                                 sectionNameKeyPath: "requestSectionKey",
                                                 cacheName: "org.piwigo.frgd.pendingUploads")
        uploads.delegate = self
        return uploads
    }()


    // MARK: - View
    @IBOutlet weak var queueTableView: UITableView!
    private var actionBarButton: UIBarButtonItem?
    private var doneBarButton: UIBarButtonItem?

    typealias DataSource = UITableViewDiffableDataSource<String,NSManagedObjectID>
    private var diffableDataSource: DataSource!
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Buttons
        if #available(iOS 14.0, *) {
            // Menu
            actionBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), landscapeImagePhone: UIImage(systemName: "ellipsis.circle"), style: .plain, target: self, action: #selector(didTapActionButton))
        } else {
            // Fallback on earlier versions
            actionBarButton = UIBarButtonItem(image: UIImage(named: "action"), landscapeImagePhone: UIImage(named: "actionCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        }
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitUpload))
        doneBarButton?.accessibilityIdentifier = "Done"

        // Register section header view
        queueTableView.register(UploadImageHeaderView.self, forHeaderFooterViewReuseIdentifier:"UploadImageHeaderView")

        // Initialise dataSource and tableView
        diffableDataSource = configDataSource()
        do {
            try uploads.performFetch()
        }
        catch {
            print("••> Could not fetch uploads: \(error)")
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
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        
        // Register Low Power Mode status
        NotificationCenter.default.addObserver(self, selector: #selector(setTableViewMainHeader),
                                               name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Register upload progress
        NotificationCenter.default.addObserver(self, selector: #selector(applyUploadProgress),
                                               name: Notification.Name.pwgUploadProgress, object: nil)
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
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
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

        // Header informing user on network status
        setTableViewMainHeader()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Allow device to sleep
        UIApplication.shared.isIdleTimerDisabled = false
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
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

        // Resume upload requests in section 2
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section2.rawValue) {
            let failedUploads = diffableDataSource.snapshot().numberOfItems(inSection: SectionKeys.Section2.rawValue)
            if failedUploads > 0 {
                let titleResume = failedUploads > 1 ? String(format: NSLocalizedString("imageUploadResumeSeveral", comment: "Resume %@ Failed Uploads"), NumberFormatter.localizedString(from: NSNumber(value: failedUploads), number: .decimal)) : NSLocalizedString("imageUploadResumeSingle", comment: "Resume Failed Upload")
                let resumeAction = UIAlertAction(title: titleResume, style: .default, handler: { action in
                    UploadManager.shared.backgroundQueue.async {
                        // Resume all failed uploads
                        UploadManager.shared.resumeAllFailedUploads()
                        // Relaunch uploads
                        UploadManager.shared.findNextImageToUpload()
                    }
                })
                alert.addAction(resumeAction)
            }
        }

        // Clear impossible upload requests in section 1
        if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
            let impossibleUploads = diffableDataSource.snapshot().numberOfItems(inSection: SectionKeys.Section1.rawValue)
            if impossibleUploads > 0 {
                let titleClear = impossibleUploads > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber(value: impossibleUploads), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
                let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
                    UploadManager.shared.backgroundQueue.async {
                        // Delete all impossible upload requests
                        UploadManager.shared.deleteImpossibleUploads()
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
        let dataSource = DataSource(tableView: queueTableView) { [self] (tableView, indexPath, objectID) -> UITableViewCell? in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!")
                return UploadImageTableViewCell()
            }
            guard let upload = try? self.mainContext.existingObject(with: objectID) as? Upload else {
                fatalError("Managed object should be available")
            }
            cell.configure(with: upload, availableWidth: Int(tableView.bounds.size.width))
            return cell
        }
        return dataSource
    }
    

    // MARK: - UITableView - Headers
    @objc func setTableViewMainHeader() {
        if queueTableView?.window == nil { return }
        DispatchQueue.main.async { [self] in
            // No upload request in the queue?
            if UploadManager.shared.nberOfUploadsToComplete == 0 {
                queueTableView.tableHeaderView = nil
                UIApplication.shared.isIdleTimerDisabled = false
            }
            else if !NetworkVars.isConnectedToWiFi() && UploadVars.wifiOnlyUploading {
                // No Wi-Fi and user wishes to upload only on Wi-Fi
                let headerView = TableHeaderView(frame: .zero)
                headerView.configure(width: self.queueTableView.frame.size.width,
                                     text: NSLocalizedString("uploadNoWiFiNetwork", comment: "No Wi-Fi Connection"))
                self.queueTableView.tableHeaderView = headerView
                UIApplication.shared.isIdleTimerDisabled = false
            }
            else if ProcessInfo.processInfo.isLowPowerModeEnabled {
                // Low Power mode enabled
                let headerView = TableHeaderView(frame: .zero)
                headerView.configure(width: self.queueTableView.frame.size.width,
                                     text: NSLocalizedString("uploadLowPowerMode", comment: "Low Power Mode enabled"))
                self.queueTableView.tableHeaderView = headerView
                UIApplication.shared.isIdleTimerDisabled = false
            }
            else {
                // Uploads in progress
                queueTableView.tableHeaderView = nil
                UIApplication.shared.isIdleTimerDisabled = true
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
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // Retreive upload object
        guard let cell = tableView.cellForRow(at: indexPath) as? UploadImageTableViewCell,
              let objectID = cell.objectID,
              let upload = try? self.mainContext.existingObject(with: objectID) as? Upload else {
            fatalError("Managed object should be available")
        }
        
        // Create retry upload action
        let retry = UIContextualAction(style: .normal, title: nil,
                                       handler: { action, view, completionHandler in
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
                UploadManager.shared.findNextImageToUpload()
            }
            completionHandler(true)
        })
        retry.backgroundColor = .piwigoColorBrown()
        retry.image = UIImage(named: "swipeRetry.png")

        // Create trash/cancel upload action
        let cancel = UIContextualAction(style: .normal, title: nil,
                                        handler: { action, view, completionHandler in
            let savingContext = upload.managedObjectContext
            savingContext?.delete(upload)
            try? savingContext?.save()
            UploadManager.shared.backgroundQueue.async {
                UploadManager.shared.resumeFailedUpload(withID: upload.localIdentifier)
                UploadManager.shared.findNextImageToUpload()
            }
            completionHandler(true)
        })
        cancel.backgroundColor = .red
        cancel.image = UIImage(named: "swipeCancel.png")

        // Associate actions
        switch upload.state {
        case .preparing, .prepared, .uploading, .uploaded, .finishing:
            return UISwipeActionsConfiguration(actions: [retry])
        case .preparingError, .uploadingError, .finishingError:
            return UISwipeActionsConfiguration(actions: [retry, cancel])
        case .waiting, .preparingFail, .formatError, .uploadingFail, .finishingFail, .finished, .moderated:
            return UISwipeActionsConfiguration(actions: [cancel])
        }
    }

    @objc func applyUploadProgress(_ notification: Notification) {
        if let localIdentifier =  notification.userInfo?["localIdentifier"] as? String, !localIdentifier.isEmpty ,
           let progressFraction = notification.userInfo?["progressFraction"] as? Float,
           let visibleCells = queueTableView.visibleCells as? [UploadImageTableViewCell],
           let cell = visibleCells.first(where: {$0.localIdentifier == localIdentifier}) {
            print("••> progressFraction = \(progressFraction) in applyUploadProgress()")
            cell.uploadingProgress?.setProgress(progressFraction, animated: true)
        }
    }
}


// MARK: - Uploads Provider NSFetchedResultsControllerDelegate

@available(iOS 13.0, *)
extension UploadQueueViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        // Update UI
        guard let dataSource = queueTableView.dataSource as? UITableViewDiffableDataSource<String, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }
        var snapshot = snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
        let currentSnapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>

        let reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers.compactMap { itemIdentifier in
            guard let currentIndex = currentSnapshot.indexOfItem(itemIdentifier),
                  let index = snapshot.indexOfItem(itemIdentifier), index == currentIndex else {
                return nil
            }
            guard let existingObject = try? controller.managedObjectContext.existingObject(with: itemIdentifier),
                  existingObject.isUpdated else { return nil }
            return itemIdentifier
        }
        snapshot.reloadItems(reloadIdentifiers)

        let shouldAnimate = queueTableView.numberOfSections != 0
        dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>,
                         animatingDifferences: shouldAnimate)
            
        // Update the navigation bar
        self.updateNavBar()
        
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
