//
//  ErrorLogsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 30/06/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

class ErrorLogsViewController: UIViewController {
    
    @IBOutlet private weak var piwigoLogo: UIImageView!
    @IBOutlet private weak var authorsLabel: UILabel!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    
    private var clearBarButton: UIBarButtonItem?
    
    // JSON Data
    private lazy var fm: FileManager = {
        return FileManager.default
    }()
    private lazy var JSONfiles: [URL] = {
        let tmpURL = self.fm.temporaryDirectory
        do {
            let fileList = try self.fm.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: [.fileSizeKey],
                                                           options: .skipsHiddenFiles)
            let JSONfiles = fileList.filter({$0.lastPathComponent.hasPrefix(JSONprefix)})
            clearBarButton?.isEnabled = !JSONfiles.isEmpty
            return JSONfiles.sorted(by: {$0.lastPathComponent < $1.lastPathComponent})
        }
        catch {
            debugPrint("!!! Could not retrieve content of temporary directory. !!!")
            return []
        }
    }()
    private lazy var JSONprefixCount: Int = {
        return JSONprefix.count
    }()
    private lazy var JSONextensionCount: Int = {
        return JSONextension.count
    }()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = NSLocalizedString("error_logs", comment: "Error Logs")
        
        // Button for returning to albums/images
        clearBarButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(clearLogs))
        clearBarButton?.isEnabled = false
        clearBarButton?.accessibilityIdentifier = "trash"
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
        
        if #available(iOS 15.0, *) {
            /// In iOS 15, UIKit has extended the usage of the scrollEdgeAppearance,
            /// which by default produces a transparent background, to all navigation bars.
            let barAppearance = UINavigationBarAppearance()
            barAppearance.configureWithOpaqueBackground()
            barAppearance.backgroundColor = .piwigoColorBackground()
            navigationController?.navigationBar.standardAppearance = barAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }
        
        // Text color depdending on background color
        authorsLabel.textColor = .piwigoColorText()
        versionLabel.textColor = .piwigoColorText()

        // Table view
        tableView.separatorColor = .piwigoColorSeparator()
        tableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Piwigo authors and app version
        authorsLabel.text = SettingsUtilities.getAuthors(forView: view)
        versionLabel.text = SettingsUtilities.getAppVersion()

        // Set colors, fonts, etc.
        applyColorPalette()

        // Set navigation buttons
        navigationItem.setRightBarButtonItems([clearBarButton].compactMap { $0 }, animated: true)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update Piwigo authors label
        coordinator.animate(alongsideTransition: { (context) in
            // Piwigo authors
            self.authorsLabel.text = SettingsUtilities.getAuthors(forView: self.view)
        }, completion: nil)
    }

    @objc func clearLogs() {
        // Delete JSON data files
        if JSONfiles.count > 100 {
            // Show progress view
            showHUD(withTitle: "")
            // Remove files
            JSONfiles.forEach { fileURL in
                try? fm.removeItem(at: fileURL)
            }
            hideHUD {
                // Close Settings view
                self.dismiss(animated: true)
            }
        } else {
            // Remove files
            JSONfiles.forEach { fileURL in
                try? fm.removeItem(at: fileURL)
            }
            // Close Settings view
            dismiss(animated: true)
        }
    }

    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: UITableViewDataSource Methods
extension ErrorLogsViewController: UITableViewDataSource
{
    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // MARK: - Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return JSONfiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "subtitle")
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
        return cell
    }
}


extension ErrorLogsViewController: UITableViewDelegate
{
    // MARK: - Headers
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        // Header strings
        var title = "", text = ""
        switch section {
        case 0:
            title = NSLocalizedString("error_JSONheader", comment: "JSON data")
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            guard let JsonVC = storyboard?.instantiateViewController(withIdentifier: "JsonViewController") as? JsonViewController,
               indexPath.row < JSONfiles.count
            else { preconditionFailure("Could not load JsonViewController") }
            JsonVC.fileURL = JSONfiles[indexPath.row]
            navigationController?.pushViewController(JsonVC, animated: true)

        default:
            break
        }
    }
}
