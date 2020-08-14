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

    var diffableDataSource: UITableViewDiffableDataSource<String,NSManagedObjectID>?
    var diffableDataSourceSnapshot = NSDiffableDataSourceSnapshot<String,NSManagedObjectID>()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Buttons
        actionBarButton = UIBarButtonItem(image: UIImage(named: "list"), landscapeImagePhone: UIImage(named: "listCompact"), style: .plain, target: self, action: #selector(didTapActionButton))
        doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(quitUpload))
        doneBarButton?.accessibilityIdentifier = "Done"
        
        // Header informing user on network status
        mainHeader()

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

    @objc func applyColorPalette() {
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
        configureDataSource()
        applyInitialSnapshots()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

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
                        alert.overrideUserInterfaceStyle = Model.sharedInstance().isDarkPaletteActive ? .dark : .light
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
    
    func sectionNameFor(_ section: Int) -> String {
        var sectionName = "Unknown section"
        guard let sectionInfo = uploadsProvider.fetchedNonCompletedResultsController.sections?[section] else {
            return sectionName
        }
        switch sectionInfo.name {
        case "Section1":
            sectionName = "Impossible Uploads"
        case "Section2":
            sectionName = "Resumable Uploads"
        case "Section3":
            sectionName = "Uploads Queue"
        case "Section4":
            fallthrough
        default:
            sectionName = "Unknown section name"
        }
        
        return sectionName
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleAttributes = [NSAttributedString.Key.font: UIFont.piwigoFontBold()]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = sectionNameFor(section).boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let sectionName = sectionNameFor(section)
        let titleAttributedString = NSMutableAttributedString(string: sectionName)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: sectionName.count))
        headerAttributedString.append(titleAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoColorHeader()

        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.addSubview(headerLabel)
        header.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
        header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))

        return header
    }
    

    // MARK: - UITableView - Rows
    private func configureDataSource() {
        diffableDataSource = UITableViewDiffableDataSource<String, NSManagedObjectID>(tableView: queueTableView) { (tableView, indexPath, id) -> UITableViewCell? in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadImageTableViewCell", for: indexPath) as? UploadImageTableViewCell else {
                print("Error: tableView.dequeueReusableCell does not return a UploadImageTableViewCell!")
                return UploadImageTableViewCell()
            }
            let upload = self.uploadsProvider.fetchedNonCompletedResultsController.object(at: indexPath)
            cell.configure(with: upload, width: Int(tableView.bounds.size.width))
            return cell
        }
    }
    
    private func applyInitialSnapshots() {
        var snapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>()
        
        // Sections
        let sectionInfos = uploadsProvider.fetchedNonCompletedResultsController.sections
        let sections = sectionInfos?.map({$0.name}) ?? Array(repeating: "—?—", count: sectionInfos?.count ?? 0)
        snapshot.appendSections(sections)
        diffableDataSource?.apply(snapshot, animatingDifferences: false)
        
        // Items
        let items = uploadsProvider.fetchedNonCompletedResultsController.fetchedObjects ?? []
        snapshot.appendItems(items.map({$0.objectID}))
        diffableDataSource?.apply(snapshot)
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

@available(iOS 13.0, *)
extension UploadQueueViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        print("••>> didChangeContentWith…")
        let snapshot = snapshot as NSDiffableDataSourceSnapshot<String,NSManagedObjectID>
        DispatchQueue.main.async {
            self.diffableDataSource?.apply(snapshot, animatingDifferences: self.queueTableView.window != nil)
        }
    }
}
