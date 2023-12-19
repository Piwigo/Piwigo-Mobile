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
    private var updateOperations: [BlockOperation] = [BlockOperation]()

    // Called before uploading images (Tag class)
    private var selectedTagIds = Set<Int32>()
    func setPreselectedTagIds(_ preselectedTagIds: Set<Int32>?) {
        selectedTagIds = preselectedTagIds ?? Set<Int32>()
    }
    

    // MARK: - Core Data Objects
    var user: User!
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()


    // MARK: - Core Data Providers
    lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider.shared
        return provider
    }()


    // MARK: - Core Data Source
    lazy var tagPredicates: [NSPredicate] = {
        let andPredicates = [NSPredicate(format: "server.path == %@", NetworkVars.serverPath)]
        return andPredicates
    }()
    
    lazy var selectedTagsPredicate: NSPredicate = {
        var andPredicates = tagPredicates
        andPredicates.append(NSPredicate(format: "tagId IN $tagIds"))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    func getSelectedVars() -> [String : Any] {
        return ["tagIds" : selectedTagIds]
    }

    lazy var fetchSelectedTagsRequest: NSFetchRequest = {
        // Sort tags by name i.e. the order in which they are presented in the web UI
        let fetchRequest = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fetchRequest.predicate = selectedTagsPredicate.withSubstitutionVariables(getSelectedVars())
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var selectedTags: NSFetchedResultsController<Tag> = {
        let tags = NSFetchedResultsController(fetchRequest: fetchSelectedTagsRequest,
                                              managedObjectContext: mainContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
        tags.delegate = self
        return tags
    }()

    var searchQuery = ""
    lazy var nonSelectedTagsPredicate: NSPredicate = {
        var andPredicates = tagPredicates
        andPredicates.append(NSPredicate(format: "NOT (tagId IN $tagIds)"))
        andPredicates.append(NSPredicate(format: "tagName LIKE[c] $query"))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    func getNonSelectedVars() -> [String : Any] {
        return ["tagIds" : selectedTagIds,
                "query"  : "*" + searchQuery + "*"]
    }
    
    lazy var fetchNonSelectedTagsRequest: NSFetchRequest = {
        // Sort tags by name i.e. the order in which they are presented in the web UI
        let fetchRequest = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fetchRequest.predicate = nonSelectedTagsPredicate.withSubstitutionVariables(getNonSelectedVars())
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    lazy var nonSelectedTags: NSFetchedResultsController<Tag> = {
        let tags = NSFetchedResultsController(fetchRequest: fetchNonSelectedTagsRequest,
                                              managedObjectContext: mainContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
        tags.delegate = self
        return tags
    }()


    // MARK: - View Lifecycle
    @IBOutlet var tagsTableView: UITableView!
    private var letterIndex: [String] = []
    var allTagNames = Set<String>()
    let searchController = UISearchController(searchResultsController: nil)

    var addAction: UIAlertAction?
    private var addBarButton: UIBarButtonItem?
    private var hudViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add search bar
        initSearchBar()
        
        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        NetworkUtilities.checkSession(ofUser: user) {
            self.tagProvider.fetchTags(asAdmin: self.user.hasAdminRights) { [self] error in
                guard let error = error else { return }     // Done if no error
                didFetchTagsWithError(error as Error)
            }
        } failure: { [self] error in
            didFetchTagsWithError(error as Error)
        }
        
        // Title
        title = NSLocalizedString("tags", comment: "Tags")
        
        // Add button for Admins and some Community users
        if user.hasAdminRights {
            addBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(requestNewTagName))
            navigationItem.setRightBarButton(addBarButton, animated: false)
        }
    }
    
    private func didFetchTagsWithError(_ error: Error) {
        let title = TagError.fetchFailed.localizedDescription
        if let pwgError = error as? PwgSessionErrors,
           pwgError == PwgSessionErrors.incompatiblePwgVersion {
            ClearCache.closeSessionWithIncompatibleServer(from: self, title: title)
        } else {
            DispatchQueue.main.async {
                self.dismissPiwigoError(withTitle: title,
                                        message: error.localizedDescription) { }
            }
        }
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

        // Table view
        tagsTableView?.separatorColor = .piwigoColorSeparator()
        tagsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tagsTableView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()

        // Initialise data source
        do {
            try selectedTags.performFetch()
            try nonSelectedTags.performFetch()
        } catch {
            debugPrint("Error: \(error)")
        }

        // Refresh table
        tagsTableView.reloadData()

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Dismiss search bar
        searchController.dismiss(animated: false)
        
        // Return list of selected tags
        delegate?.didSelectTags(Set(selectedTags.fetchedObjects ?? []))
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
            let objects = selectedTags.fetchedObjects
            return objects?.count ?? 0
        case 1:
            let objects = nonSelectedTags.fetchedObjects
            return objects?.count ?? 0
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
            cell.configure(with: selectedTags.object(at: indexPath), andEditOption: .remove)
        case 1 /* Non-selected tags */:
            let indexPath1 = IndexPath(row: indexPath.row, section: 0)
            cell.configure(with: nonSelectedTags.object(at: indexPath1), andEditOption: .add)
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
            let currentTag = selectedTags.object(at: indexPath)

            // Remove tag from list of selected tags
            selectedTagIds.remove(currentTag.tagId)
            
            // Update fetch requests and perform fetches
            do {
                fetchSelectedTagsRequest.predicate = selectedTagsPredicate.withSubstitutionVariables(getSelectedVars())
                try selectedTags.performFetch()
                fetchNonSelectedTagsRequest.predicate = nonSelectedTagsPredicate.withSubstitutionVariables(getNonSelectedVars())
                try nonSelectedTags.performFetch()

                // Determine new indexPath of deselected tag
                if let indexOfTag = nonSelectedTags.fetchedObjects?.firstIndex(where: {$0.tagId == currentTag.tagId}) {
                    let insertPath = IndexPath(row: indexOfTag, section: 1)
                    // Move cell from top to bottom section
                    tableView.moveRow(at: indexPath, to: insertPath)
                    // Update icon of cell
                    if let indexPaths = tableView.indexPathsForVisibleRows,
                       indexPaths.contains(insertPath) {
                        tableView.reloadRows(at: [insertPath], with: .automatic)
                    }
                }
            }
            catch {
                debugPrint("••> Could not perform fetch!!!")
            }
        case 1 /* Non-selected tags */:
            // Tapped non selected tag
            let indexPath1 = IndexPath(row: indexPath.row, section: 0)
            let currentTag = nonSelectedTags.object(at: indexPath1)

            // Add tag to list of selected tags
            selectedTagIds.insert(currentTag.tagId)

            // Update fetch requests and perform fetches
            do {
                fetchSelectedTagsRequest.predicate = selectedTagsPredicate.withSubstitutionVariables(getSelectedVars())
                try selectedTags.performFetch()
                fetchNonSelectedTagsRequest.predicate = nonSelectedTagsPredicate.withSubstitutionVariables(getNonSelectedVars())
                try nonSelectedTags.performFetch()

                // Determine new indexPath of selected tag
                if let indexOfTag = selectedTags.fetchedObjects?.firstIndex(where: {$0.tagId == currentTag.tagId}) {
                    let insertPath = IndexPath(row: indexOfTag, section: 0)
                    // Move cell from bottom to top section
                    tableView.moveRow(at: indexPath, to: insertPath)
                    // Update icon of cell
                    if let indexPaths = tableView.indexPathsForVisibleRows,
                       indexPaths.contains(insertPath) {
                        tableView.reloadRows(at: [insertPath], with: .automatic)
                    }
                }
            }
            catch {
                debugPrint("••> Could not perform fetch!!!")
            }
        default:
            fatalError("Unknown tableView section!")
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension TagsViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Initialise update operations
        updateOperations.removeAll(keepingCapacity: false)
        // Begin the update
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        // Initialisation
        var hasTagsInSection1 = false
        if controller == nonSelectedTags  {
            hasTagsInSection1 = true
        }

        // Collect operation changes
        switch type {
        case .insert:
            // Insert tag into the right list of tags
            guard var newIndexPath = newIndexPath else { return }
            if hasTagsInSection1 { newIndexPath.section = 1 }
            updateOperations.append( BlockOperation { [weak self] in
                print("••> Insert tag item at \(newIndexPath)")
                self?.tagsTableView?.insertRows(at: [newIndexPath], with: .automatic)
            })
        case .update:
            guard var indexPath = indexPath else { return }
            if hasTagsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Update tag item at \(indexPath)")
                self?.tableView?.reloadRows(at: [indexPath], with: .automatic)
            })
        case .move:
            guard var indexPath = indexPath,  var newIndexPath = newIndexPath else { return }
            if hasTagsInSection1 {
                indexPath.section = 1
                newIndexPath.section = 1
            }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Move tag item from \(indexPath) to \(newIndexPath)")
                self?.tableView?.moveRow(at: indexPath, to: newIndexPath)
            })
        case .delete:
            guard var indexPath = indexPath else { return }
            if hasTagsInSection1 { indexPath.section = 1 }
            updateOperations.append( BlockOperation {  [weak self] in
                print("••> Delete tag item at \(indexPath)")
                self?.tableView?.deleteRows(at: [indexPath], with: .automatic)
            })
        @unknown default:
            fatalError("TagsViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Do not update items if the album is not presented.
        if view.window == nil { return }
        
        // Any update to perform?
        if updateOperations.isEmpty || view.window == nil { return }

        // Perform all updates
        tableView?.performBatchUpdates({ () -> Void  in
            for operation: BlockOperation in self.updateOperations {
                operation.start()
            }
        })
        
        // End updates
        tableView.endUpdates()
    }
}
