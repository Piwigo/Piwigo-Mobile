//
//  TagSelectorViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A UIViewController subclass to manage a table view
//  that displays the collection of tags.

import UIKit
import CoreData
import piwigoKit

protocol TagSelectorViewDelegate: NSObjectProtocol {
    func pushTaggedImagesView(_ viewController: UIViewController)
}

class TagSelectorViewController: UIViewController {
    
    weak var tagSelectedDelegate: (any TagSelectorViewDelegate)?
    
    @IBOutlet var tagsTableView: UITableView!
    
    private var tagIdsBeforeUpdate = [Int32]()
    private var letterIndex: [String] = []
    private var updateOperations = [BlockOperation]()
    
    
    // MARK: - Core Data Objects
    var user: User!
    private lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()
    
    
    // MARK: - Fetched Results Controller
    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()
    var searchQuery = ""
    lazy var predicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.shared.serverPath))
        andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", 0))
        andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", Int64.max))
        andPredicates.append(NSPredicate(format: "tagName LIKE[c] $query"))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    func getQueryVar() -> [String : Any] {
        return ["query"  : "*" + searchQuery + "*"]
    }
    
    lazy var fetchRequest: NSFetchRequest = {
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fetchRequest.predicate = predicate.withSubstitutionVariables(getQueryVar())
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()
    
    lazy var tags: NSFetchedResultsController<Tag> = {
        // Create a fetched results controller and set its fetch request, context, and delegate.
        let tags = NSFetchedResultsController(fetchRequest: fetchRequest,
                                              managedObjectContext: mainContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
        tags.delegate = self
        return tags
    }()
    
    
    // MARK: - View Lifecycle
    @MainActor
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title
        title = NSLocalizedString("tagsTitle_selectOne", comment: "Select a Tag")
        
        // Initialise search bar
        let searchBar = searchController.searchBar
        initSearchBar(searchBar)

        // Add search bar to navigation bar or toolbar
        navigationItem.searchController = searchController
        if #available(iOS 26.0, *) {
            navigationItem.preferredSearchBarPlacement = .integrated
            let searchBarButton = navigationItem.searchBarPlacementBarButtonItem
            setToolbarItems([searchBarButton], animated: false)
            navigationController?.setToolbarHidden(false, animated: false)
        }
        navigationItem.hidesSearchBarWhenScrolling = false

        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        JSONManager.shared.checkSession(ofUser: user) { [self] in
            TagProvider().fetchTags(asAdmin: false) { [self] error in
                DispatchQueue.main.async { [self] in
                    guard let error = error else { return }
                    didFetchTagsWithError(error)
                }
            }
        } failure: { [self] error in
            DispatchQueue.main.async { [self] in
                didFetchTagsWithError(error)
            }
        }
        
        // Add button for returning to albums/images
        let cancelBarButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(quitTagSelect))
        cancelBarButton.accessibilityIdentifier = "cancelTagSelectionButton"
        navigationItem.setLeftBarButtonItems([cancelBarButton], animated: true)
        
        // Table view identifier
        tagsTableView?.accessibilityIdentifier = "tag selector"
        tagsTableView?.rowHeight = UITableView.automaticDimension
        tagsTableView?.estimatedRowHeight = TableViewUtilities.rowHeight
    }
    
    @MainActor
    private func didFetchTagsWithError(_ error: PwgKitError) {
        // Session logout required?
        if error.requiresLogout {
            ClearCache.closeSessionWithPwgError(from: self, error: error)
            return
        }
        
        // Report error
        let title = PwgKitError.tagCreationError.localizedDescription
        self.dismissPiwigoError(withTitle: title, message: error.localizedDescription) { }
    }
    
    @MainActor
    @objc private func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = PwgColor.background
        
        // Navigation bar
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        
        // Search bar
        searchController.searchBar.configAppearance()
        
        // Table view
        tagsTableView?.separatorColor = PwgColor.separator
        tagsTableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tagsTableView?.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Initialise data source
        do {
            try tags.performFetch()
        } catch {
            debugPrint("Failed to fetch tags: \(error)")
        }
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func quitTagSelect() {
        dismiss(animated: true, completion: nil)
    }
    

    // MARK: - Content Sizes
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Search bar
            self.searchController.searchBar.searchTextField.font = UIFont.preferredFont(forTextStyle: .body)
            self.searchController.searchBar.invalidateIntrinsicContentSize()
            self.searchController.searchBar.layer.setNeedsLayout()
            self.searchController.searchBar.layoutIfNeeded()
            
            // Animated update for smoother experience
            self.tagsTableView?.beginUpdates()
            self.tagsTableView?.endUpdates()
        }
    }
}
    

// MARK: - UITableViewDataSource Methods
extension TagSelectorViewController: UITableViewDataSource
{
    // Return the number of sections for the table.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // Return the number of rows for the table.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let objects = tags.fetchedObjects
        return objects?.count ?? 0
    }
    
    // Return cell configured with tag
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "LabelTableViewCell", for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load LabelTableViewCell") }
        
        // => pwg.tags.getList returns in addition: counter, url
        let tag = tags.object(at: indexPath)
        let nber: Int64 = tag.numberOfImagesUnderTag
        if (nber == Int64.zero) || (nber == Int64.max) {
            // Unknown number of images
            cell.configure(with: tag.tagName, detail: "")
        } else {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            let nberPhotos = (numberFormatter.string(from: NSNumber(value: nber)) ?? "0") as String
            cell.configure(with: tag.tagName, detail: nberPhotos)
        }
        
        return cell
    }
}


// MARK: - UITableViewDelegate Methods
extension TagSelectorViewController: UITableViewDelegate
{
    // MARK: - UITableView Footers
    private func getContentOfFooter() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let nberOfTags = (tags.fetchedObjects ?? []).count
        let nberAsStr = numberFormatter.string(from: NSNumber(value: nberOfTags)) ?? "0"
        let footer = nberOfTags > 1 ?
        String(format: String(localized: "severalTagsCount", bundle: piwigoKit, comment: "%@ tags"), nberAsStr) :
        String(format: String(localized: "singleTagCount", bundle: piwigoKit, comment: "%@ tag"), nberAsStr)
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter()
        let height = TableViewUtilities.shared.heightOfFooter(withText: footer)
        return CGFloat(fmax(44.0, height))
    }
    
    // Return the footer view
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter()
        return TableViewUtilities.shared.viewOfFooter(withText: text, alignment: .center)
    }
    
    // Display images tagged with the tag selected a row of the table
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Determine selected tag before deactivating search bar
        let tag = tags.object(at: indexPath)
        let catID = pwgSmartAlbum.tagged.rawValue - Int32(tag.tagId)
        
        // Check that an album of tagged images exists in cache (create it if necessary)
        guard let _ = try? AlbumProvider().getAlbum(ofUser: user, withId: catID, name: tag.tagName) else {
            return
        }
        
        // Deactivate search bar
        searchController.isActive = false
        
        // Dismiss tag select
        dismiss(animated: true) { [self] in
            // Push tagged images view with AlbumViewController
            let taggedImagesSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let taggedImagesVC = taggedImagesSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            taggedImagesVC.categoryId = catID
            self.tagSelectedDelegate?.pushTaggedImagesView(taggedImagesVC)
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension TagSelectorViewController: NSFetchedResultsControllerDelegate
{    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // Initialise update operations
        updateOperations = []
        // Begin the update
        tagsTableView?.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<any NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .delete:   // Action performed in priority
            guard let indexPath = indexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Delete tag item at \(indexPath)")
                self?.tagsTableView?.deleteRows(at: [indexPath], with: .automatic)
            })
            
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Insert tag item at \(newIndexPath)")
                self?.tagsTableView?.insertRows(at: [newIndexPath], with: .automatic)
            })
            
        case .move:
            guard let indexPath = indexPath,  let newIndexPath = newIndexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Move tag item from \(indexPath) to \(newIndexPath)")
                self?.tagsTableView?.moveRow(at: indexPath, to: newIndexPath)
            })
            
        case .update:
            guard let indexPath = indexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Update tag item at \(indexPath)")
                self?.tagsTableView?.reloadRows(at: [indexPath], with: .automatic)
            })
            
        @unknown default:
            fatalError("TagSelectorViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<any NSFetchRequestResult>) {
        // Perform all updates
        tagsTableView?.performBatchUpdates { [weak self] in
            self?.updateOperations.forEach { $0.start() }
        }
        
        tagsTableView?.endUpdates()
    }
}
