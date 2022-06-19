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

@objc
class TagSelectorViewController: UITableViewController {
    
    @objc weak var tagSelectedDelegate: TagSelectorViewDelegate?

    // MARK: - Core Data
    /**
     The TagsProvider that fetches tag data, saves it to Core Data,
     and serves it to this table view.
     */
    private lazy var tagsProvider: TagsProvider = {
        let provider : TagsProvider = TagsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
    
    
    // MARK: - View Lifecycle
    @IBOutlet var tagsTableView: UITableView!
    private var tagIdsBeforeUpdate = [Int32]()
    private var letterIndex: [String] = []

    let searchController = UISearchController(searchResultsController: nil)
    var searchQuery = ""
    private var filteredTags: [Tag] {
        let allTags = tagsProvider.fetchedResultsController.fetchedObjects ?? []
        if #available(iOS 11.0, *) {
            return allTags.filterTags(for: searchQuery)
        } else {
            return allTags
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add search bar and prepare data source
        if #available(iOS 11.0, *) {
            // Initialise search bar
            initSearchBar()
        } else {
            // Rebuild ABC index
            rebuildABCindex()
        }
        
        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        tagsProvider.fetchTags(asAdmin: false) { error in
            DispatchQueue.main.async { [self] in
                guard let error = error else { return }

                // Show an alert if there was an error.
                self.dismissPiwigoError(withTitle: NSLocalizedString("CoreDataFetch_TagError", comment: "Fetch tags error!"), message: error.localizedDescription) { }
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
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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


    // MARK: - UITableView ABC Index (before iOS 11)
    func rebuildABCindex() {
        // Rebuild ABC index
        let firstCharacters = NSMutableSet(capacity: 0)
        for tag in filteredTags {
            firstCharacters.add((tag.tagName as String).prefix(1).uppercased())
        }
        letterIndex = (firstCharacters.allObjects as! [String]).sorted()
    }
    
    // Returns the titles for the sections
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if #available(iOS 11.0, *) {
            return nil
        } else {
            return letterIndex
        }
    }

    // Returns the section that the table view should scroll to
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {

        var newRow: Int = 0
        for tag in filteredTags {
            if tag.tagName.hasPrefix(title) { break }
            newRow += 1
        }
        let newIndexPath = IndexPath(row: newRow, section: 0)
        tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
        return index
    }

    
    // MARK: - UITableView Rows & Cells
    // Return the number of sections for the table.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return the number of rows for the table.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredTags.count
    }

    // Return cell configured with tag
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TagSelectorCell", for: indexPath) as? TagSelectorCell else {
            print("Error: tableView.dequeueReusableCell does not return a TagSelectorCell!")
            return TagSelectorCell()
        }
        cell.configure(with: filteredTags[indexPath.row])
        return cell
    }

    
    // MARK: - UITableView Footers
    private func getContentOfFooter() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let nberOfTags = filteredTags.count
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
        var catID = NSNotFound
        if filteredTags.count > indexPath.row {
            let tag = filteredTags[indexPath.row]
            catID = getCategory(withTagId: tag.tagId, tagName: tag.tagName)
        }
        if catID == NSNotFound { return }
        
        // Deactivate search bar
        searchController.isActive = false

        // Dismiss tag select
        dismiss(animated: true) { [self] in
            // Push tagged images view with AlbumImagesViewController
            let taggedImagesVC = AlbumImagesViewController(albumId: catID)
            self.tagSelectedDelegate?.pushTaggedImagesView(taggedImagesVC)
        }
    }
    
    private func getCategory(withTagId tagId:Int32, tagName:String) -> Int {
        // Calc category ID
        let categoryId = kPiwigoTagsCategoryId - Int(tagId)
        
        // Create category in cache if necessary
        if CategoriesData.sharedInstance().getCategoryById(categoryId) == nil,
           let album = PiwigoAlbumData(id: categoryId, andQuery: tagName) {
            CategoriesData.sharedInstance().updateCategories([album])
        }
        return categoryId
    }
}


// MARK: - NSFetchedResultsControllerDelegate

extension TagSelectorViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Stores tag IDs before the update
        tagIdsBeforeUpdate = filteredTags.map({$0.tagId})
        
        // Begin the update
        tagsTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .delete:   // Action performed in priority
            // Should we remove this tag from the filtered list?
            guard let tag: Tag = anObject as? Tag else { return }
            if let index = tagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId}) {
                // Delete tag from table view
                let deleteAtIndexPath = IndexPath(row: index, section: 0)
                print(".delete =>", deleteAtIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [deleteAtIndexPath], with: .automatic)
            }
            
        case .insert:
            // Should we add this tag to the filtered list?
            guard let tag: Tag = anObject as? Tag else { return }
            if let index = filteredTags.firstIndex(where: {$0.tagId == tag.tagId}) {
                let addAtIndexPath = IndexPath(row: index, section: 0)
                print(".insert =>", addAtIndexPath.debugDescription)
                tagsTableView.insertRows(at: [addAtIndexPath], with: .automatic)
            }
            
        case .move:
            // Should never happen…
            print("TagsSelectorViewController / NSFetchedResultsControllerDelegate: \"move\" should never happen!")
            
        case .update:
            guard let tag: Tag = anObject as? Tag else { return }
            // Get index of tag to update
            if let index = tagIdsBeforeUpdate.firstIndex(where: {$0 == tag.tagId}) {
                let indexPath = IndexPath(row: index, section: 0)
                if let cell = tableView.cellForRow(at: indexPath) as? TagSelectorCell {
                    cell.configure(with: tag)
                }
            }
            
        @unknown default:
            fatalError("TagSelectorViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tagsTableView.endUpdates()
        
        if #available(iOS 11, *) {
            // Use search bar
        } else {
            // Rebuild ABC index
            rebuildABCindex()
            tagsTableView.reloadSectionIndexTitles()
        }
    }
}
