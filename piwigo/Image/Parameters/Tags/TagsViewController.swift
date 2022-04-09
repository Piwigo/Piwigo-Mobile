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
    func didSelectTags(_ selectedTags: [Tag])
}

class TagsViewController: UITableViewController, UITextFieldDelegate {

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
    

    // MARK: - Core Data
    /**
     The TagsProvider that fetches tag data, saves it to Core Data,
     and serves it to this table view.
     */
    private lazy var dataProvider: TagsProvider = {
        let provider : TagsProvider = TagsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()


    // MARK: - View Lifecycle
    @IBOutlet var tagsTableView: UITableView!
    private var letterIndex: [String] = []
    private var selectedTags = [Tag]()
    private var nonSelectedTags = [Tag]()
    private var selectedTagIdsBeforeUpdate = [Int32]()
    private var nonSelectedTagIdsBeforeUpdate = [Int32]()

    private var addBarButton: UIBarButtonItem?
    private var addAction: UIAlertAction?
    private var hudViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        dataProvider.fetchTags(asAdmin: hasTagCreationRights) { error in
            guard let error = error else { return }     // Done if no error

            // Show an alert if there was an error.
            DispatchQueue.main.async {
                self.dismissPiwigoError(withTitle: "", message: NSLocalizedString("CoreDataFetch_TagError", comment: "Fetch tags error!"), errorMessage: error.localizedDescription) { }
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
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
        
        // Prepare data source
        self.selectedTags = dataProvider.fetchedResultsController.fetchedObjects?
                                .filter({selectedTagIds.contains($0.tagId)}) ?? [Tag]()
        self.nonSelectedTags = dataProvider.fetchedResultsController.fetchedObjects?
                                .filter({!selectedTagIds.contains($0.tagId)}) ?? [Tag]()
        // Build ABC index
        self.updateSectionIndex()
        
        // Refresh table
        self.tagsTableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super .viewWillDisappear(animated)

        // Return list of selected tags
        delegate?.didSelectTags(selectedTags)
    }
    
    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
}

    
// MARK: - UITableViewDataSource

extension TagsViewController {

    // MARK: - ABC Index
    // Compile index
    private func updateSectionIndex() {
        // Build section index
        let firstCharacters = NSMutableSet(capacity: 0)
        for tag in nonSelectedTags {
            firstCharacters.add(tag.tagName.prefix(1).uppercased())
        }
        self.letterIndex = (firstCharacters.allObjects as! [String]).sorted()
    }
    
    // Returns the titles for the sections
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return letterIndex
    }

    // Returns the section that the table view should scroll to
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {

        if let row = nonSelectedTags.firstIndex(where: {$0.tagName.hasPrefix(title)}) {
            let newIndexPath = IndexPath(row: row, section: 1)
            tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
        }
        return index
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


    // MARK: - UITableView - Rows
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return selectedTags.count
        } else {
            return nonSelectedTags.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath) as? TagTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a TagTableViewCell!")
            return TagTableViewCell()
        }

        if indexPath.section == 0 {
            // Selected tags
            cell.configure(with: selectedTags[indexPath.row], andEditOption: .remove)
        } else {
            // Not selected tags
            cell.configure(with: nonSelectedTags[indexPath.row], andEditOption: .add)
        }
        
        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            // Tapped selected tag
            let currentTag = selectedTags[indexPath.row]

            // Remove tag from list of selected tags
            selectedTags.remove(at: indexPath.row)
            selectedTagIds.removeAll(where: {$0 == currentTag.tagId})

            // Add tag to list of non selected tags
            nonSelectedTags.append(currentTag)
            
            // Sort tags using a case-insensitive, localized, comparison
            nonSelectedTags.sort { (tag1,tag2) in
                tag1.tagName.localizedCaseInsensitiveCompare(tag2.tagName) == .orderedAscending
            }
            
            // Determine new indexPath of deselected tag
            let indexOfTag = nonSelectedTags.firstIndex(where: {$0.tagId == currentTag.tagId})
            let insertPath = IndexPath(row: indexOfTag!, section: 1)

            // Move cell from top to bottom section
            tableView.moveRow(at: indexPath, to: insertPath)

            // Update icon of cell
            tableView.reloadRows(at: [insertPath], with: .automatic)
        }
        else {
            // Tapped non selected tag
            let currentTag = nonSelectedTags[indexPath.row]

            // Remove tag from list of non-selected tags
            nonSelectedTags.remove(at: indexPath.row)
            
            // Add tag to list of selected tags
            selectedTags.append(currentTag)
            selectedTagIds.append(currentTag.tagId)
            
            // Sort tags using a case-insensitive, localized, comparison
            selectedTags.sort { (tag1,tag2) in
                (tag1.tagName as String).localizedCaseInsensitiveCompare(tag2.tagName as String) == .orderedAscending
            }

            // Determine new indexPath of selected tag
            let indexOfTag = selectedTags.firstIndex(where: {$0.tagId == currentTag.tagId})
            let insertPath = IndexPath(row: indexOfTag!, section: 0)

            // Move cell from bottom to top section
            tableView.moveRow(at: indexPath, to: insertPath)

            // Update icon of cell
            tableView.reloadRows(at: [insertPath], with: .automatic)
        }
        
        // Update section index
        updateSectionIndex()
        self.tableView.reloadSectionIndexTitles()
    }


    // MARK: - Add tag (for admins only)
    @objc func requestNewTagName() {
        let alert = UIAlertController(title: NSLocalizedString("tagsAdd_title", comment: "Add Tag"), message: NSLocalizedString("tagsAdd_message", comment: "Enter a name for this new tag"), preferredStyle: .alert)

        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = NSLocalizedString("tagsAdd_placeholder", comment: "New tag")
            textField.clearButtonMode = .always
            textField.keyboardType = .default
            textField.keyboardAppearance = AppVars.shared.isDarkPaletteActive ? .dark : .default
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.returnKeyType = .continue
            textField.delegate = self
        })

        let cancelAction = UIAlertAction(title: NSLocalizedString("alertCancelButton", comment: "Cancel"), style: .cancel, handler: { action in
            })

        addAction = UIAlertAction(title: NSLocalizedString("alertAddButton", comment: "Add"), style: .default, handler: { action in
            // Rename album if possible
            if (alert.textFields?.first?.text?.count ?? 0) > 0 {
                self.addTag(withName: alert.textFields?.first?.text)
            }
        })

        alert.addAction(cancelAction)
        if let addAction = addAction {
            alert.addAction(addAction)
        }
        alert.view.tintColor = .piwigoColorOrange()
        if #available(iOS 13.0, *) {
            alert.overrideUserInterfaceStyle = AppVars.shared.isDarkPaletteActive ? .dark : .light
        } else {
            // Fallback on earlier versions
        }
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = .piwigoColorOrange()
        }
    }

    func addTag(withName tagName: String?) {
        // Check tag name
        guard let tagName = tagName, tagName.count != 0 else {
            return
        }
        
        // Display HUD during the update
        showPiwigoHUD(withTitle: NSLocalizedString("tagsAddHUD_label", comment: "Creating Tag…"))

        // Add new tag
        DispatchQueue.global(qos: .userInteractive).async {
            self.dataProvider.addTag(with: tagName, completionHandler: { error in
                guard let error = error else {
                    self.updatePiwigoHUDwithSuccess {
                        self.hidePiwigoHUD(afterDelay: kDelayPiwigoHUD, completion: {})
                    }
                    return
                }
                self.hidePiwigoHUD {
                    self.dismissPiwigoError(withTitle: NSLocalizedString("tagsAddError_title", comment: "Create Fail"),
                                            message: NSLocalizedString("tagsAddError_message", comment: "Failed to…"),
                                            errorMessage: error.localizedDescription, completion: { })
                }
            })
        }
    }


    // MARK: - UITextField Delegate Methods
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Disable Add/Delete Category action
        addAction?.isEnabled = false
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Enable Add/Delete Tag action if text field not empty
        let finalString = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        var existTagWithName = false
        if let _ = selectedTags.firstIndex(where: {$0.tagName == finalString}),
            let _ = nonSelectedTags.firstIndex(where: {$0.tagName == finalString}) {
            existTagWithName = true
        }
        addAction?.isEnabled = (((finalString?.count ?? 0) >= 1) && !existTagWithName)
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        // Disable Add/Delete Category action
        addAction?.isEnabled = false
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension TagsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Stores tags index paths before the update
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
            if let index = selectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                // Remove selected tag from data source
                selectedTags.remove(at: index)
                selectedTagIds.removeAll(where: {$0 == tag.tagId})
                // Delete tag from table view
                let deleteAtIndexPath = IndexPath(row: selectedTagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId})!, section: 0)
//                print(".delete =>", deleteAtIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [deleteAtIndexPath], with: .automatic)
            }
            // List of not selected tags
            else if let index = nonSelectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                // Remove non-selected tag from data source
                nonSelectedTags.remove(at: index)
                // Delete tag from table view
                let deleteAtIndexPath = IndexPath(row: nonSelectedTagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId})!, section: 1)
//                print(".delete =>", deleteAtIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [deleteAtIndexPath], with: .automatic)
            }

        case .insert:
            // Add tag to appropriate list of tags
            /// We cannot sort the list now to avoid the case where we insert several rows at the same index path.
            /// The sort is performed after having changed the data source.
            guard let tag: Tag = anObject as? Tag else { return }
            // Append tag to appropriate list
            if selectedTagIds.contains(tag.tagId) {
                // Append tag to list of selected tags
                selectedTags.append(tag)
                // Determine index of added tag
                if let index = selectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                    let addAtIndexPath = IndexPath(row: index, section: 0)
//                    print(".insert =>", addAtIndexPath.debugDescription)
                    tagsTableView.insertRows(at: [addAtIndexPath], with: .automatic)
                }
            } else {
                // Append tag to list of non-selected tags
                nonSelectedTags.append(tag)
                // Determine index of added tag
                if let index = nonSelectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                    let addAtIndexPath = IndexPath(row: index, section: 1)
//                    print(".insert =>", addAtIndexPath.debugDescription)
                    tagsTableView.insertRows(at: [addAtIndexPath], with: .automatic)
                }
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
//                print(".update =>", updateAtIndexPath.debugDescription)
                if let cell = tableView.cellForRow(at: updateAtIndexPath) as? TagTableViewCell {
                    cell.configure(with: tag, andEditOption: .remove)
                }
            }
            // List of not selected tags
            else if let index = nonSelectedTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let updateAtIndexPath = IndexPath(row: index, section: 1)
//                print(".update =>", updateAtIndexPath.debugDescription)
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

        // Update section index
        self.updateSectionIndex()
        self.tableView.reloadSectionIndexTitles()
        
        // Sort tags using a case-insensitive, localized, comparison
        nonSelectedTags.sort { (tag1,tag2) in
            tag1.tagName.localizedCaseInsensitiveCompare(tag2.tagName) == .orderedAscending
        }
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }
}
