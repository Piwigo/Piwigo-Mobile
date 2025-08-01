//
//  UploadQueueViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import UIKit
import piwigoKit
import uploadKit

class UploadQueueViewController: UIViewController {
    
    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()
    
    
    // MARK: - Core Data Source
    @available(iOS 13.0, *)
    typealias DataSource = UITableViewDiffableDataSource<String, NSManagedObjectID>
    @available(iOS 13.0, *)
    typealias Snaphot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>
    /// Stored properties cannot be marked potentially unavailable with '@available'.
    // "private var diffableDataSource: DataSource!" replaced by below lines
    private var _diffableDataSource: NSObject? = nil
    @available(iOS 13.0, *)
    var diffableDataSource: DataSource {
        if _diffableDataSource == nil {
            _diffableDataSource = configDataSource()
        }
        return _diffableDataSource as! DataSource
    }
    
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
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.shared.username))
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
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register section header view before using it
        queueTableView?.register(UploadImageHeaderView.self, forHeaderFooterViewReuseIdentifier:"UploadImageHeaderView")
        
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
        
        // No extra space above tableView
        if #available(iOS 13.0, *) {
            // NOP
        } else {
            // Fallback on earlier versions
            queueTableView.contentInsetAdjustmentBehavior = .never
        }
        
        // Initialise dataSource
        if #available(iOS 13.0, *) {
            _diffableDataSource = configDataSource()
        } else {
            // Fallback on earlier versions
        }
        
        // Fetch data (setting up the initial snapshot on iOS 13+)
        do {
            try uploads.performFetch()
        }
        catch {
            debugPrint("••> Could not fetch uploads: \(error)")
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
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if #available(iOS 13.0, *) {
            // NOP
        } else {
            // Fallback on earlier versions
            guard let header = queueTableView.tableHeaderView else { return }
            header.frame.size.height = header.systemLayoutSizeFitting(CGSize(width: view.bounds.width - 32.0, height: 0)).height
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Save position of collection view
        if queueTableView.visibleCells.count > 0,
           let cell = queueTableView.visibleCells.first {
            if let indexPath = queueTableView.indexPath(for: cell) {
                // Reload the tableview on orientation change, to match the new width of the table.
                coordinator.animate(alongsideTransition: { [self] _ in
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
    
    @MainActor
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
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = title
        }
        
        // Header informing user on network status
        setTableViewMainHeader()
    }
    
    @MainActor
    @objc func setTableViewMainHeader() {
        // Anything to do?
        if queueTableView?.window == nil { return }
        // No upload request in the queue?
        if UploadVars.shared.nberOfUploadsToComplete == 0 {
            queueTableView.tableHeaderView = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
        else if !NetworkVars.shared.isConnectedToWiFi() && UploadVars.shared.wifiOnlyUploading {
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
        self.viewWillLayoutSubviews()
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
        var nberOfImagesInQueue = 0
        if #available(iOS 13.0, *) {
            nberOfImagesInQueue = diffableDataSource.snapshot().numberOfItems
        } else {
            // Fallback on earlier versions
            nberOfImagesInQueue = (uploads.fetchedObjects ?? []).count
        }
        title = nberOfImagesInQueue > 1 ?
        String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("severalImages", comment: "Photos")) :
        String(format: "%ld %@", nberOfImagesInQueue, NSLocalizedString("singleImage", comment: "Photo"))
        
        // Set title of current scene (iPad only)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.title = title
        }
        
        // Action menu
        var hasImpossibleUploadsSection = false
        var hasFailedUploadsSection = false
        if #available(iOS 13.0, *) {
            if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section1.rawValue) {
                hasImpossibleUploadsSection = true
            }
            if let _ = diffableDataSource.snapshot().indexOfSection(SectionKeys.Section2.rawValue) {
                hasFailedUploadsSection = true
            }
        } else {
            // Fallback on earlier versions
            let impossible: [pwgUploadState] = [.preparingFail, .formatError, .uploadingFail, .finishingFail]
            let impossibleUploads: Int = (uploads.fetchedObjects ?? []).map({ impossible.contains($0.state) ? 1 : 0}).reduce(0, +)
            hasImpossibleUploadsSection = impossibleUploads != 0
            let resumable: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
            let failedUploads: Int = (uploads.fetchedObjects ?? []).map({ resumable.contains($0.state) ? 1 : 0}).reduce(0, +)
            hasFailedUploadsSection = failedUploads > 0
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
        if #available(iOS 13.0, *) {
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
        } else {
            // Fallback on earlier versions
            let resumable: [pwgUploadState] = [.preparingError, .uploadingError, .finishingError]
            let failedUploads = (uploads.fetchedObjects ?? []).filter({ resumable.contains($0.state) == true })
            if failedUploads.isEmpty == false {
                let failedCount = failedUploads.count
                let titleResume = failedCount > 1 ? String(format: NSLocalizedString("imageUploadResumeSeveral", comment: "Resume %@ Failed Uploads"), NumberFormatter.localizedString(from: NSNumber(value: failedCount), number: .decimal)) : NSLocalizedString("imageUploadResumeSingle", comment: "Resume Failed Upload")
                let resumeAction = UIAlertAction(title: titleResume, style: .default, handler: { action in
                    // Resume failed uploads
                    UploadManager.shared.backgroundQueue.async {
                        UploadManager.shared.resumeAllFailedUploads()
                        UploadManager.shared.findNextImageToUpload()
                    }
                })
                alert.addAction(resumeAction)
            }
        }
        
        // Clear impossible upload requests in section 1
        if #available(iOS 13.0, *) {
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
        } else {
            // Fallback on earlier versions
            let impossible: [pwgUploadState] = [.preparingFail, .formatError, .uploadingFail, .finishingFail]
            let impossibleUploads = (uploads.fetchedObjects ?? []).filter({ impossible.contains($0.state) == true})
            if impossibleUploads.isEmpty == false {
                let impossibleCount = impossibleUploads.count
                let titleClear = impossibleCount > 1 ? String(format: NSLocalizedString("imageUploadClearFailedSeveral", comment: "Clear %@ Failed"), NumberFormatter.localizedString(from: NSNumber(value: impossibleCount), number: .decimal)) : NSLocalizedString("imageUploadClearFailedSingle", comment: "Clear 1 Failed")
                let clearAction = UIAlertAction(title: titleClear, style: .default, handler: { action in
                    // Delete failed uploads
                    impossibleUploads.forEach({ self.mainContext.delete($0) })
                    self.mainContext.saveIfNeeded()
                    // Resume failed uploads
                    UploadManager.shared.backgroundQueue.async {
                        // Update number of uploads
                        UploadManager.shared.updateNberOfUploadsToComplete()
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
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
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
}
