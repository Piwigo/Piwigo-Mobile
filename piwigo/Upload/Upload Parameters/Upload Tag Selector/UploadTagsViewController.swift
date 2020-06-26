//
//  UploadTagsViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 19/01/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A UIViewController subclass to manage a table view that displays a collection of tags.

import UIKit
import CoreData

class UploadTagsViewController: UITableViewController {

    @objc var selectedTags:Array<Tag> = []

    
    // MARK: - Core Data
    
    /**
     The TagsProvider that fetches tag data, saves it to Core Data,
     and serves it to this table view.
     */
    private lazy var dataProvider: TagsProvider = {
        
        let provider = TagsProvider(completionClosure: {})
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    
    // MARK: View
    @IBOutlet var tagsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        dataProvider.fetchTags { error in
            DispatchQueue.main.async {

                // Show an alert if there was an error.
                guard let error = error else { return }
                let alert = UIAlertController(title: NSLocalizedString("CoreDataFetch_TagError", comment: "Fetch tags error!"),
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("alertOkButton", comment: "OK"),
                                              style: .default, handler: nil))
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
        }
    }
}


// MARK: - UITableViewDataSource

extension UploadTagsViewController {
    
    // Return the number of sections for the table.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return the number of rows for the table.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataProvider.fetchedResultsController.fetchedObjects?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "UploadTagCell", for: indexPath) as? UploadTagCell else {
            print("Error: tableView.dequeueReusableCell doesn'return a UploadTagCell!")
            return UploadTagCell()
        }
        guard let tag = dataProvider.fetchedResultsController.fetchedObjects?[indexPath.row] else { return cell }
        cell.configureCell(with: tag.tagName, action: UploadTagCell.tagCellOptions.actions.none)
        return cell
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension UploadTagsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        guard let indexPath = indexPath else { return }
        guard let newIndexPath = newIndexPath else { return }
        
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            tableView.deleteRows(at: [indexPath], with: .automatic)
        case .move:
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .update:
            guard let tag: Tag = anObject as? Tag else { return }
            guard let cell = tableView.cellForRow(at: oldIndexPath) as? UploadTagCell else { return }
            cell.configureCell(with: tag.tagName, action: UploadTagCell.tagCellOptions.actions.unknown)
        @unknown default:
            fatalError("UploadTagsViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
