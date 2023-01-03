//
//  TagsViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.1 by Eddy Lelièvre-Berna on 17/07/2020.
//

import UIKit
import CoreData
import piwigoKit

protocol TagsViewControllerDelegate: NSObjectProtocol {
    func didSelectTags(_ selectedTags: Set<Tag>)
}

class TagsViewController: UITableViewController {

    weak var delegate: TagsViewControllerDelegate?

    // Called before uploading images (Tag class)
    private var selectedTagIds = [Int32]()
    func setPreselectedTagIds(_ preselectedTagIds: [Int32]?) {
        selectedTagIds = preselectedTagIds ?? [Int32]()
    }
    
    private var hasTagCreationRights:Bool = false
    func setTagCreationRights(_ tagCreationRights:Bool) {
        hasTagCreationRights = tagCreationRights
    }
    

    // MARK: - Core Data Providers
    lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()


    // MARK: - View Lifecycle
    @IBOutlet var tagsTableView: UITableView!
    private var letterIndex: [String] = []
    private var selectedTagIdsBeforeUpdate = [Int32]()
    private var nonSelectedTagIdsBeforeUpdate = [Int32]()

    let searchController = UISearchController(searchResultsController: nil)
    var searchQuery = ""
    private var selectedTags: [Tag] {
        let allTags = tagProvider.fetchedResultsController.fetchedObjects ?? []
        let selectedTags = allTags.filter({selectedTagIds.contains($0.tagId)})
        return selectedTags
    }
    private var nonSelectedTags: [Tag] {
        let allTags = tagProvider.fetchedResultsController.fetchedObjects ?? []
        let nonSelectedTags = allTags.filter({!selectedTagIds.contains($0.tagId)})
        return nonSelectedTags.filterTags(for: searchQuery)
    }

    var addAction: UIAlertAction?
    private var addBarButton: UIBarButtonItem?
    private var hudViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add search bar and prepare data source
        initSearchBar()
        
        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        tagProvider.fetchTags(asAdmin: hasTagCreationRights) { error in
            guard let error = error else { return }     // Done if no error

            // Show an alert if there was an error.
            DispatchQueue.main.async {
                self.dismissPiwigoError(withTitle: TagError.fetchFailed.localizedDescription,
                                        message: error.localizedDescription) { }
            }
        }
        
        // Title
        title = NSLocalizedString("tags", comment: "Tags")
        
        // Add button for Admins and some Community users
        if hasTagCreationRights {
            addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(requestNewTagName))
            navigationItem.setRightBarButton(addBarButton, animated: false)
        }
    }
    
    @objc func applyColorPalette() {
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

        // Table view
        tagsTableView?.separatorColor = .piwigoColorSeparator()
        tagsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tagsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Refresh table
        tagsTableView.reloadData()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)

        // Return list of selected tags
        delegate?.didSelectTags(Set(selectedTags))
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    
    // MARK: - UITableView - Header
    private func getContentOfHeader(inSection section: Int) -> String {
        if section == 0 {
            return NSLocalizedString("tagsHeader_selected", comment: "Selected")
        } else {
            return NSLocalizedString("tagsHeader_notSelected", comment: "Not Selected")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title,
                                                        width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title)
    }


    // MARK: - UITableView Rows & Cells
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return selectedTags.count
        case 1:
            return nonSelectedTags.count
        default:
            fatalError("Unknown tableView section!")
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath) as? TagTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a TagTableViewCell!")
            return TagTableViewCell()
        }
        switch indexPath.section {
        case 0 /* Selected tags */:
            cell.configure(with: selectedTags[indexPath.row], andEditOption: .remove)
        case 1 /* Non-selected tags */:
            cell.configure(with: nonSelectedTags[indexPath.row], andEditOption: .add)
        default:
            fatalError("Unknown tableView section!")
        }
        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0 /* Selected tags */:
            // Tapped selected tag
            let currentTag = selectedTags[indexPath.row]

            // Remove tag from list of selected tags
            selectedTagIds.removeAll(where: {$0 == currentTag.tagId})
            
            // Determine new indexPath of deselected tag
            if let indexOfTag = nonSelectedTags.firstIndex(where: {$0.tagId == currentTag.tagId}) {
                let insertPath = IndexPath(row: indexOfTag, section: 1)
                // Move cell from top to bottom section
                tableView.moveRow(at: indexPath, to: insertPath)
                // Update icon of cell
                tableView.reloadRows(at: [insertPath], with: .automatic)
            }
        case 1 /* Non-selected tags */:
            // Tapped non selected tag
            let currentTag = nonSelectedTags[indexPath.row]

            // Add tag to list of selected tags
            selectedTagIds.append(currentTag.tagId)

            // Determine new indexPath of selected tag
            if let indexOfTag = selectedTags.firstIndex(where: {$0.tagId == currentTag.tagId}) {
                let insertPath = IndexPath(row: indexOfTag, section: 0)
                // Move cell from bottom to top section
                tableView.moveRow(at: indexPath, to: insertPath)
                // Update icon of cell
                if let indexPaths = tableView.indexPathsForVisibleRows,
                   indexPaths.contains(insertPath) {
                    tableView.reloadRows(at: [insertPath], with: .automatic)
                }
            }
        default:
            fatalError("Unknown tableView section!")
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension TagsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Stores tag IDs before the update
        selectedTagIdsBeforeUpdate = selectedTags.map({$0.tagId})
        nonSelectedTagIdsBeforeUpdate = nonSelectedTags.map({$0.tagId})
        
        // Begin the update
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .delete:   // Action performed in priority
            // Remove tag from the right list of tags
            guard let tag: Tag = anObject as? Tag else { return }
            // List of selected tags
            if let index = selectedTagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId}) {
                // Remove selected tag from data source
                selectedTagIds.removeAll(where: {$0 == tag.tagId})
                // Remove selected tag from table view
                let deleteAtIndexPath = IndexPath(row: index, section: 0)
                print(".delete =>", deleteAtIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [deleteAtIndexPath], with: .automatic)
            }
            // List of non-selected tags
            else if let index = nonSelectedTagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId}) {
                // Remove non-selected tag from table view
                let deleteAtIndexPath = IndexPath(row: index, section: 1)
                print(".delete =>", deleteAtIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [deleteAtIndexPath], with: .automatic)
            }

        case .insert:
            // Insert tag into the right list of tags
            guard let tag: Tag = anObject as? Tag else { return }
            // Append tag to appropriate list
            if let index = selectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let addAtIndexPath = IndexPath(row: index, section: 0)
                print(".insert =>", addAtIndexPath.debugDescription)
                tagsTableView.insertRows(at: [addAtIndexPath], with: .automatic)
            }
            else if let index = nonSelectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let addAtIndexPath = IndexPath(row: index, section: 1)
                print(".insert =>", addAtIndexPath.debugDescription)
                tagsTableView.insertRows(at: [addAtIndexPath], with: .automatic)
            }

        case .move:        // Should never "move"
            // Update tag belonging to the right list
            print("TagsViewController / NSFetchedResultsControllerDelegate: \"move\" should never happen!")

        case .update:      // Will never "move"
            // Update tag belonging to the right list
            guard let tag: Tag = anObject as? Tag else { return }
            // List of selected tags
            if let index = selectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let updateAtIndexPath = IndexPath(row: index, section: 0)
                print(".update =>", updateAtIndexPath.debugDescription)
                if let cell = tableView.cellForRow(at: updateAtIndexPath) as? TagTableViewCell {
                    cell.configure(with: tag, andEditOption: .remove)
                }
            }
            // List of non-selected tags
            else if let index = nonSelectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let updateAtIndexPath = IndexPath(row: index, section: 1)
                print(".update =>", updateAtIndexPath.debugDescription)
                if let cell = tableView.cellForRow(at: updateAtIndexPath) as? TagTableViewCell {
                    cell.configure(with: tag, andEditOption: .add)
                }
            }

        @unknown default:
            fatalError("TagsViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
