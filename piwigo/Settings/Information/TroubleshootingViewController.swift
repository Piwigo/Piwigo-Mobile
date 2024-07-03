//
//  TroubleshootingViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import OSLog
import UIKit
import piwigoKit

@available(iOS 15, *)
class TroubleshootingViewController: UIViewController {
    
    @IBOutlet private weak var piwigoLogo: UIImageView!
    @IBOutlet private weak var authorsLabel: UILabel!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    
    private var clearBarButton: UIBarButtonItem?
    
    
    // MARK: - TableView Data
    private var queue: OperationQueue = OperationQueue()
    private lazy var fm: FileManager = FileManager.default
    private lazy var JSONprefixCount: Int = JSONprefix.count
    private lazy var JSONextensionCount: Int = JSONextension.count
    private var JSONfiles = [URL]()
    private var pwgLogs = [[OSLogEntryLog]]()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("settings_logs", comment: "Logs")
        
        // Button for returning to albums/images
        clearBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteJSONfiles))
        clearBarButton?.isEnabled = false
        clearBarButton?.accessibilityIdentifier = "trash"
        
        // Fetch data
        getLogsAndJSONData()
    }
    
    @objc func applyColorPalette() {
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
        
        /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
        /// which by default produces a transparent background, to all navigation bars.
        let barAppearance = UINavigationBarAppearance()
        barAppearance.configureWithOpaqueBackground()
        barAppearance.backgroundColor = .piwigoColorBackground()
        navigationController?.navigationBar.standardAppearance = barAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        
        // Text color depdending on background color
        authorsLabel?.textColor = .piwigoColorText()
        versionLabel?.textColor = .piwigoColorText()
        
        // Table view
        tableView?.separatorColor = .piwigoColorSeparator()
        tableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Piwigo authors and app version
        authorsLabel?.text = SettingsUtilities.getAuthors(forView: view)
        versionLabel?.text = SettingsUtilities.getAppVersion()
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Set navigation buttons
        navigationItem.setRightBarButtonItems([clearBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Display HUD while retrieving logs and invalid JSON data
        if queue.operations.count != 0 {
            navigationController?.showHUD(
                withTitle: NSLocalizedString("loadingHUD_label", comment: "Loading…"),
                detail: NSLocalizedString("settings_logs", comment: "Logs"), minWidth: 200)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update Piwigo authors label
        coordinator.animate(alongsideTransition: { (context) in
            // Piwigo authors
            self.authorsLabel?.text = SettingsUtilities.getAuthors(forView: self.view)
        }, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cancel operations (with HUD shown, should never be needed)
        queue.cancelAllOperations()
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Fetch & Delete Data
    private func getLogsAndJSONData() {
        // Operation for retrieving logs
        let getLogs = BlockOperation {
            do {
                let timeCounter = CFAbsoluteTimeGetCurrent()
                let logStore = try OSLogStore(scope: .currentProcessIdentifier)
                let oneHourAgo = logStore.position(date: Date().addingTimeInterval(-3600))
                let predicate = NSPredicate(format: "subsystem IN %@", ["org.piwigo", "org.piwigoKit", "org.uploadKit"])
                let allEntries = try logStore.getEntries(at: oneHourAgo, matching: predicate)
                let duration = (CFAbsoluteTimeGetCurrent() - timeCounter)*1000
                print("••> completed in \(duration.rounded()) ms")
                let entries = allEntries.compactMap({$0 as? OSLogEntryLog})
                // Core Data
                var someLogs = entries.filter({$0.category == "TagToTagMigrationPolicy_09_to_0C"})
                if someLogs.isEmpty == false { self.pwgLogs.append(someLogs) }
                someLogs = entries.filter({$0.category == "UploadToUploadMigrationPolicy_09_to_0C"})
                if someLogs.isEmpty ==  false { self.pwgLogs.append(someLogs)}
                someLogs = entries.filter({$0.category == "Image"})
                if someLogs.isEmpty ==  false { self.pwgLogs.append(someLogs)}
                // Networking
                someLogs = entries.filter({$0.category == "PwgSession"})
                if someLogs.isEmpty == false { self.pwgLogs.append(someLogs) }
            } catch {
                debugPrint("••> Could not retrieve logs.")
                self.pwgLogs = []
            }
        }
        getLogs.completionBlock = {
            DispatchQueue.main.async {
                self.navigationController?.hideHUD {
                    self.tableView?.reloadSections(IndexSet(integer: 0), with: .automatic)
                }
            }
        }

        // Operation for retrieving invalid JSON data
        let getJSONfiles = BlockOperation {
            let tmpURL = self.fm.temporaryDirectory
            do {
                let allFiles = try self.fm.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: [.fileSizeKey],
                                                               options: .skipsHiddenFiles)
                self.JSONfiles = allFiles.filter({$0.lastPathComponent.hasPrefix(JSONprefix)})
                    .sorted(by: {$0.lastPathComponent < $1.lastPathComponent})
            }
            catch {
                debugPrint("!!! Could not retrieve content of temporary directory. !!!")
                self.JSONfiles =  []
            }
        }
        getJSONfiles.completionBlock = {
            DispatchQueue.main.async {
                self.tableView?.reloadSections(IndexSet(integer: 1), with: .automatic)
                self.clearBarButton?.isEnabled = !self.JSONfiles.isEmpty
            }
        }
        
        // Perform both operations in background and in parallel
        queue.maxConcurrentOperationCount = .max   // Make it a serial queue for debugging with 1
        queue.qualityOfService = .userInteractive
        queue.addOperations([getLogs, getJSONfiles], waitUntilFinished: false)
    }
    
    @objc func deleteJSONfiles() {
        // Delete JSON data files
        if JSONfiles.count > 100 {
            // Show progress view
            showHUD(withTitle: "")
            // Remove files
            JSONfiles.forEach { fileURL in
                try? fm.removeItem(at: fileURL)
            }
            // Hide progress view and reload section
            hideHUD {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                self.clearBarButton?.isEnabled = !self.JSONfiles.isEmpty
            }
        } else {
            // Remove files
            JSONfiles.forEach { fileURL in
                try? fm.removeItem(at: fileURL)
            }
            // Reload section
            self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            self.clearBarButton?.isEnabled = !self.JSONfiles.isEmpty
        }
    }
}


// MARK: - UITableViewDataSource Methods
@available(iOS 15, *)
extension TroubleshootingViewController: UITableViewDataSource
{
    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0 /* Logs */:
            return max(1, pwgLogs.count)
        case 1 /* Invalid JSON data */:
            return max(1, JSONfiles.count)
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "subtitle")
        
        switch indexPath.section {
        case 0 /* Logs */:
            if pwgLogs.isEmpty {
                cell.textLabel?.text = "None"
                cell.accessoryType = UITableViewCell.AccessoryType.none
            } else if let entry = pwgLogs[indexPath.row].first {
                cell.textLabel?.text = entry.category
                cell.detailTextLabel?.text = DateUtilities.dateFormatter.string(from: entry.date)
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            } else {
                cell.textLabel?.text = "None"
                cell.accessoryType = UITableViewCell.AccessoryType.none
            }
        case 1 /* Invalid JSON data */:
            if JSONfiles.isEmpty {
                cell.textLabel?.text = "None"
                cell.accessoryType = UITableViewCell.AccessoryType.none
            } else {
                let fileURL = JSONfiles[indexPath.row]
                let fileName = String(fileURL.lastPathComponent.dropFirst(JSONprefixCount).dropLast(JSONextensionCount))
                if let pos = fileName.lastIndex(of: " ") {
                    cell.textLabel?.text = String(fileName[pos...].dropFirst())
                    cell.detailTextLabel?.text = String(fileName[...pos]) + " | " + fileURL.fileSizeString
                } else {
                    cell.textLabel?.text = fileName
                    cell.detailTextLabel?.text = fileURL.fileSizeString
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            }
        default:
            break
        }
        return cell
    }
}


// MARK: - UITableViewDelegate Methods
@available(iOS 15, *)
extension TroubleshootingViewController: UITableViewDelegate
{
    // MARK: - Headers
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        // Header strings
        var title = "", text = ""
        switch section {
        case 0 /* Logs */:
            title = NSLocalizedString("settings_logs", comment: "Logs")
        case 1 /* Invalid JSON data */:
            title = NSLocalizedString("settings_JSONinvalid", comment: "Invalid JSON data")
        default:
            title = ""
        }
        return (title, text)
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        if title.isEmpty, text.isEmpty {
            return CGFloat(1)
        } else {
            return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                            width: tableView.frame.size.width)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }
    
    
    // MARK: - Cell Management
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch indexPath.section {
        case 0 /* Logs */:
            return !pwgLogs.isEmpty
        case 1 /* Invalid JSON data */:
            return !JSONfiles.isEmpty
        default:
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0 /* Logs */:
            guard let LogsVC = storyboard?.instantiateViewController(withIdentifier: "LogsViewController") as? LogsViewController
            else { preconditionFailure("Could not load LogsViewController") }
            LogsVC.logEntries = pwgLogs[indexPath.row]
            navigationController?.pushViewController(LogsVC, animated: true)
        
        case 1 /* Invalid JSON data */:
            guard let JsonVC = storyboard?.instantiateViewController(withIdentifier: "JsonViewController") as? JsonViewController
            else { preconditionFailure("Could not load JsonViewController") }
            if indexPath.row >= JSONfiles.count { break }
            JsonVC.fileURL = JSONfiles[indexPath.row]
            navigationController?.pushViewController(JsonVC, animated: true)
        
        default:
            break
        }
    }
}
