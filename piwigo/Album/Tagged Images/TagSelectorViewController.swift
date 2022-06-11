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
    private lazy var dataProvider: TagsProvider = {
        let provider : TagsProvider = TagsProvider()
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
        
    
    // MARK: View
    @IBOutlet private var tagsTableView: UITableView!
    private var letterIndex: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        dataProvider.fetchTags(asAdmin: false) { error in
            DispatchQueue.main.async {
                guard let error = error else {
                    // Rebuild ABC index
                    let firstCharacters = NSMutableSet(capacity: 0)
                    for tag in self.dataProvider.fetchedResultsController.fetchedObjects! {
                        firstCharacters.add((tag.tagName as String).prefix(1).uppercased())
                    }
                    self.letterIndex = (firstCharacters.allObjects as! [String]).sorted()
                    self.tableView.reloadData()
                    return
                }

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

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: .pwgPaletteChanged, object: nil)
    }

    @objc private func quitTagSelect()
    {
        dismiss(animated: true, completion: nil)
    }
}


// MARK: - UITableViewDataSource

extension TagSelectorViewController {
    
    // MARK: - ABC Index
    // Returns the titles for the sections
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return letterIndex
    }

    // Returns the section that the table view should scroll to
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {

        var newRow: Int = 0
        for tag in dataProvider.fetchedResultsController.fetchedObjects! {
            if tag.tagName.hasPrefix(title) { break }
            newRow += 1
        }
        let newIndexPath = IndexPath(row: newRow, section: 0)
        tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
        return index
    }

    
    // MARK: - Headers
    private func getContentOfHeader(inSection section: Int) -> (String, String) {
        let title = String(format: "%@\n", NSLocalizedString("tags", comment: "Tags"))
        let text = NSLocalizedString("tagsTitle_selectOne", comment: "Select a Tag")
        return (title, text)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.heightOfHeader(withTitle: title, text: text,
                                                        width: tableView.frame.size.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let (title, text) = getContentOfHeader(inSection: section)
        return TableViewUtilities.shared.viewOfHeader(withTitle: title, text: text)
    }

    
    // MARK: - Rows & Cells
    // Return the number of sections for the table.
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    // Return the number of rows for the table.
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataProvider.fetchedResultsController.fetchedObjects?.count ?? 0
    }

    // Return cell configured with tag
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TagSelectorCell", for: indexPath) as? TagSelectorCell else {
            print("Error: tableView.dequeueReusableCell does not return a TagSelectorCell!")
            return TagSelectorCell()
        }
        guard let tag = dataProvider.fetchedResultsController.fetchedObjects?[indexPath.row] else { return cell }
        cell.configure(with: tag)
        return cell
    }

    // MARK: - Footers
    private func getContentOfFooter() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let nberOfTags = dataProvider.fetchedResultsController.fetchedObjects?.count ?? 0
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

        // Dismiss tag select
        dismiss(animated: true) {
            // Push tagged images view with AlbumImagesViewController
            if let tag = self.dataProvider.fetchedResultsController.fetchedObjects?[indexPath.row],
               let taggedImagesVC = TaggedImagesViewController(tagId: Int(tag.tagId), andTagName: tag.tagName) {
                self.tagSelectedDelegate?.pushTaggedImagesView(taggedImagesVC)
            }
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate

extension TagSelectorViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
//                print(".insert =>", newIndexPath.debugDescription)
                tagsTableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
        case .delete:
            if let indexPath = indexPath {
//                print(".delete =>", indexPath.debugDescription)
                tagsTableView.deleteRows(at: [indexPath], with: .automatic)
            }
            
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
//                print(".move =>", indexPath.debugDescription, "=>", newIndexPath.debugDescription)
                tagsTableView.deleteRows(at: [indexPath], with: .automatic)
                tagsTableView.insertRows(at: [newIndexPath], with: .automatic)
            }
            
        case .update:
            guard let tag: Tag = anObject as? Tag else { return }
            if let indexPath = indexPath {
//                print(".update =>", indexPath.debugDescription)
                if let cell = tableView.cellForRow(at: indexPath) as? TagSelectorCell {
                    cell.configure(with: tag)
                }
            }
            
        @unknown default:
            fatalError("TagSelectorViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
