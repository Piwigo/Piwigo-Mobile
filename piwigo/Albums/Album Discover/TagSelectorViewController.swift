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

@objc
protocol TagSelectorViewDelegate {
    func pushTaggedImagesView(_ viewController: UIViewController?)
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
        
        let provider = TagsProvider(completionClosure: {})
        provider.fetchedResultsControllerDelegate = self
        return provider
    }()
        
    // MARK: View
    @IBOutlet var tagsTableView: UITableView!
    var letterIndex: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Use the TagsProvider to fetch tag data. On completion,
        // handle general UI updates and error alerts on the main queue.
        dataProvider.fetchTags(asAdmin: false) { error in
            DispatchQueue.main.async {

                // Show an alert if there was an error.
                guard let error = error else {
                    
                    // Build ABC index
                    let firstCharacters = NSMutableSet.init(capacity: 0)
                    for tag in self.dataProvider.fetchedResultsController.fetchedObjects! {
                        firstCharacters.add((tag.tagName as String).prefix(1).uppercased())
                    }
                    self.letterIndex = (firstCharacters.allObjects as! [String]).sorted()
                    self.tableView.reloadData()
                    return
                }
                let alert = UIAlertController(title: "Fetch tags error!",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        // Add button for returning to albums/images
        let cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(quitTagSelect))
        navigationItem.setLeftBarButtonItems([cancelBarButton], animated: true)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes as [NSAttributedString.Key : Any]
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoBackground()

        // Table view
        tagsTableView.separatorColor = UIColor.piwigoSeparator()
        tagsTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        tagsTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set colors, fonts, etc.
        applyColorPalette()

        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    @objc func quitTagSelect()
    {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
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

        var newRow = 0
        for tag in dataProvider.fetchedResultsController.fetchedObjects! {
            if  tag.tagName.hasPrefix(title) {
                break
            }
            newRow += 1
        }
        let newIndexPath = IndexPath(row: newRow, section: 0)
        tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
        return index
    }

    // MARK: - Headers
    // Return the height and width of the header
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString = "\(NSLocalizedString("tags", comment: "Tags"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold() as Any
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("tagsTitle_selectOne", comment: "Select a Tag")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall() as Any
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    // Return the header view
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("tags", comment: "Tags"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold() as Any, range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("tagsTitle_selectOne", comment: "Select a Tag")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall() as Any, range: NSRange(location: 0, length: textString.count))
        headerAttributedString.append(textAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = UIColor.piwigoHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint(item: headerLabel, attribute: .bottom, relatedBy: .equal, toItem: headerLabel.superview, attribute: .bottom, multiplier: 1.0, constant: -4))
        if #available(iOS 11, *) {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[header]-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        } else {
            header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[header]-15-|", options: [], metrics: nil, views: [
            "header": headerLabel
            ]))
        }

        return header
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
    // Return the height and width of the footer
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // Footer height?
        let numberFormatter = NumberFormatter()
        numberFormatter.positiveFormat = "#,##0"
        let numberOfTags = dataProvider.fetchedResultsController.fetchedObjects?.count ?? 0
        let footer = "\(numberFormatter.string(from: NSNumber(value: numberOfTags)) ?? "") \(numberOfTags > 1 ? NSLocalizedString("tags", comment: "Tags").lowercased() : NSLocalizedString("tag", comment: "Tag").lowercased())"
        let attributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontLight()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: attributes as [NSAttributedString.Key : Any], context: context)

        return CGFloat(fmax(44.0, ceil(footerRect.size.height)))
    }
    
    // Return the footer view
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        // Footer label
        let footerLabel = UILabel()
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = UIFont.piwigoFontLight()
        footerLabel.textColor = UIColor.piwigoHeader()
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 1

        let numberFormatter = NumberFormatter()
        numberFormatter.positiveFormat = "#,##0"
        let numberOfTags = dataProvider.fetchedResultsController.fetchedObjects?.count ?? 0
        footerLabel.text = "\(numberFormatter.string(from: NSNumber(value: numberOfTags)) ?? "") \(numberOfTags > 1 ? NSLocalizedString("tags", comment: "Tags").lowercased() : NSLocalizedString("tag", comment: "Tag").lowercased())"
        footerLabel.adjustsFontSizeToFitWidth = false

        // Footer view
        let footer = UIView()
        footer.backgroundColor = UIColor.clear
        footer.addSubview(footerLabel)
        footer.addConstraint(NSLayoutConstraint(item: footerLabel, attribute: .top, relatedBy: .equal, toItem: footerLabel.superview, attribute: .top, multiplier: 1.0, constant: 4))
        if #available(iOS 11, *) {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-[footer]-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        } else {
            footer.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|-15-[footer]-15-|", options: [], metrics: nil, views: [
            "footer": footerLabel
            ]))
        }

        return footer
    }


    // MARK: - UITableViewDelegate Methods
    // Display images tagged with the tag selected a row of the table
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Deselect row
        tableView.deselectRow(at: indexPath, animated: true)

        // Dismiss tag select
        dismiss(animated: true) {
            // Push tagged images view with AlbumImagesViewController
            if let tag = self.dataProvider.fetchedResultsController.fetchedObjects?[indexPath.row] {
                let taggedImagesVC = TaggedImagesViewController(tagId: tag.tagId, andTagName: tag.tagName)
                self.tagSelectedDelegate?.pushTaggedImagesView(taggedImagesVC)
            }
        }
    }
}


// MARK: - NSFetchedResultsControllerDelegate

extension TagSelectorViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tagsTableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {

        let oldIndexPath = indexPath ?? IndexPath.init(row: 0, section: 0)
        guard let newIndexPath = newIndexPath else { return }
        guard let tag: Tag = anObject as? Tag else { return }
        guard let cell: TagSelectorCell = tableView(tagsTableView, cellForRowAt: oldIndexPath) as? TagSelectorCell else { return }

        switch type {
        case .insert:
            print("tagsTableView.insertRows: \(newIndexPath.row)")
            tagsTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            tagsTableView.deleteRows(at: [oldIndexPath], with: .automatic)
        case .move:
            tagsTableView.deleteRows(at: [oldIndexPath], with: .automatic)
            tagsTableView.insertRows(at: [newIndexPath], with: .automatic)
        case .update:
            print("cell.configure(with: \(tag.tagName)")
            cell.configure(with: tag)
        @unknown default:
            fatalError("TagSelectorViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tagsTableView.endUpdates()
    }
}

// k7ji}wx[bCcsihd@fg23
