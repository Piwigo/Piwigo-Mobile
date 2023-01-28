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

@objc
protocol TagSelectorViewDelegate {
    func pushTaggedImagesView(_ viewController: UIViewController)
}

class TagSelectorViewController: UITableViewController {
    
    weak var tagSelectedDelegate: TagSelectorViewDelegate?

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()

    
    // MARK: - Core Data Providers
    private lazy var tagProvider: TagProvider = {
        let provider : TagProvider = TagProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    
    private lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider()
        return provider
    }()


    // MARK: - View Lifecycle
    @IBOutlet var tagsTableView: UITableView!
    private var tagIdsBeforeUpdate = [Int32]()
    private var letterIndex: [String] = []

    let searchController = UISearchController(searchResultsController: nil)
    var searchQuery = ""
    lazy var predicates: [NSPredicate] = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", 0))
        andPredicates.append(NSPredicate(format: "numberOfImagesUnderTag != %ld", Int64.max))
        return andPredicates
    }()
    lazy var fetchRequest: NSFetchRequest = {
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Tag.tagName), ascending: true,
                                         selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialise search bar
        initSearchBar()
        
        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        tagProvider.fetchTags(asAdmin: false) { error in
            DispatchQueue.main.async { [self] in
                guard let error = error else { return }

                // Show an alert if there was an error.
                self.dismissPiwigoError(withTitle: TagError.fetchFailed.localizedDescription,
                                        message: error.localizedDescription) { }
            }
        }
        
        // Add button for returning to albums/images
        let cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitTagSelect))
        navigationItem.setLeftBarButtonItems([cancelBarButton], animated: true)
    }
    
    @objc private func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = .piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.barStyle = AppVars.shared.isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = .piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = .piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = .piwigoColorBackground()

        // Table view
        tagsTableView.separatorColor = .piwigoColorSeparator()
        tagsTableView.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        tagsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Initialise data source
        do {
            try tags.performFetch()
        } catch {
            fatalError("Failed to fetch tags: \(error)")
        }

        // Reload data
        tagsTableView.reloadData()
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    @objc private func quitTagSelect() {
        dismiss(animated: true, completion: nil)
    }


    // MARK: - UITableView Rows
    // Return the number of sections for the table.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return the number of rows for the table.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let objects = tags.fetchedObjects
        return objects?.count ?? 0
    }

    // Return cell configured with tag
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TagSelectorCell", for: indexPath) as? TagSelectorCell else {
            print("Error: tableView.dequeueReusableCell does not return a TagSelectorCell!")
            return TagSelectorCell()
        }
        cell.configure(with: tags.object(at: indexPath))
        return cell
    }

    
    // MARK: - UITableView Footers
    private func getContentOfFooter() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let nberOfTags = tags.fetchedObjects?.count ?? 0
        let nberAsStr = numberFormatter.string(from: NSNumber(value: nberOfTags)) ?? "0"
        let footer = nberOfTags > 1 ?
            String(format: NSLocalizedString("severalTagsCount", comment: "%@ tags"), nberAsStr) :
            String(format: NSLocalizedString("singleTagCount", comment: "%@ tag"), nberAsStr)
        return footer
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let footer = getContentOfFooter()
        let height = TableViewUtilities.shared.heightOfFooter(withText: footer)
        return CGFloat(fmax(44.0, height))
    }
    
    // Return the footer view
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let text = getContentOfFooter()
        return TableViewUtilities.shared.viewOfFooter(withText: text, alignment: .center)
    }
    

    // MARK: - UITableViewDelegate Methods
    // Display images tagged with the tag selected a row of the table
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect row
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Determine selected tag before deactivating search bar
        let tag = tags.object(at: indexPath)
        let catID = pwgSmartAlbum.tagged.rawValue - Int32(tag.tagId)
        
        // Check that an album of tagged images exists in cache (create it if necessary)
        guard let _ = albumProvider.getAlbum(inContext: mainContext, withId: catID) else {
            return
        }
        
        // Deactivate search bar
        searchController.isActive = false

        // Dismiss tag select
        dismiss(animated: true) { [self] in
            // Push tagged images view with AlbumViewController
            let taggedImagesVC = AlbumViewController(albumId: catID)
            self.tagSelectedDelegate?.pushTaggedImagesView(taggedImagesVC)
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate

extension TagSelectorViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Begin the update
        tagsTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .delete:   // Action performed in priority
            guard let indexPath = indexPath else { return }
            tagsTableView.deleteRows(at: [indexPath], with: .automatic)
            
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            tagsTableView.insertRows(at: [newIndexPath], with: .automatic)
            
        case .move:
            guard let indexPath = indexPath,  let newIndexPath = newIndexPath else { return }
            tagsTableView.moveRow(at: indexPath, to: newIndexPath)
            
        case .update:
            guard let indexPath = indexPath else { return }
            tagsTableView.reloadRows(at: [indexPath], with: .automatic)
            
        @unknown default:
            fatalError("TagSelectorViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tagsTableView.endUpdates()
    }
}
