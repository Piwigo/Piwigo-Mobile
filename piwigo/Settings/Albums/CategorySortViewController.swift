//
//  CategorySortViewController.swift
//  piwigo
//
//  Created by Spencer Baker on 3/1/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5 by Eddy Lelièvre-Berna on 07/04/2020.
//

import UIKit
import piwigoKit

protocol CategorySortDelegate: NSObjectProtocol {
    func didSelectCategorySortType(_ sortType: kPiwigoSort)
}

class CategorySortViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    weak var sortDelegate: CategorySortDelegate?
    private var currentCategorySortType = kPiwigoSort(rawValue: AlbumVars.defaultSort)

    class func getNameForCategorySortType(_ sortType: kPiwigoSort) -> String {
        var name = ""
        switch sortType {
        case .nameAscending:
            name = NSLocalizedString("categorySort_nameAscending", comment: "Photo Title, A → Z")
        case .nameDescending:
            name = NSLocalizedString("categorySort_nameDescending", comment: "Photo Title, Z → A")
        case .fileNameAscending:
            name = NSLocalizedString("categorySort_fileNameAscending", comment: "File Name, A → Z")
        case .fileNameDescending:
            name = NSLocalizedString("categorySort_fileNameDescending", comment: "File Name, Z → A")
        case .dateCreatedDescending:
            name = NSLocalizedString("categorySort_dateCreatedDescending", comment: "Date Created, new → old")
        case .dateCreatedAscending:
            name = NSLocalizedString("categorySort_dateCreatedAscending", comment: "Date Created, old → new")
        case .datePostedDescending:
            name = NSLocalizedString("categorySort_datePostedDescending", comment: "Date Posted, new → old")
        case .datePostedAscending:
            name = NSLocalizedString("categorySort_datePostedAscending", comment: "Date Posted, old → new")
        case .ratingScoreDescending:
            name = NSLocalizedString("categorySort_ratingScoreDescending", comment: "Rating Score, high → low")
        case .ratingScoreAscending:
            name = NSLocalizedString("categorySort_ratingScoreAscending", comment: "Rating Score, low → high")
        case .visitsDescending:
            name = NSLocalizedString("categorySort_visitsDescending", comment: "Visits, high → low")
        case .visitsAscending:
            name = NSLocalizedString("categorySort_visitsAscending", comment: "Visits, low → high")
        case .manual:
            name = NSLocalizedString("categorySort_manual", comment: "Manual Order")
        case .random:
            name = NSLocalizedString("categorySort_random", comment: "Random Order")
//		case .videoOnly:
//			name = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case .imageOnly:
//			name = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;

        case .count:
            name = ""
        }
        return name
    }

    @IBOutlet var sortSelectTableView: UITableView!


// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_albums", comment: "Albums")
        sortSelectTableView.accessibilityIdentifier = "sortSelect"
        navigationController?.navigationBar.accessibilityIdentifier = "CategorySortBar"

        // Set colors, fonts, etc.
        applyColorPalette()
    }

    @objc
    func applyColorPalette() {
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
        navigationController?.navigationBar.barStyle = AppVars.isDarkPaletteActive ? .black : .default
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

        // Table view
        sortSelectTableView.separatorColor = .piwigoColorSeparator()
        sortSelectTableView.indicatorStyle = AppVars.isDarkPaletteActive ? .white : .black
        sortSelectTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: PwgNotifications.paletteChanged, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Return selected album
        sortDelegate?.didSelectCategorySortType(currentCategorySortType ?? .dateCreatedAscending)
    }

    deinit {
        // Unregister palette changes
        NotificationCenter.default.removeObserver(self, name: PwgNotifications.paletteChanged, object: nil)
    }
    
    
    // MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let maxWidth = CGSize(width: tableView.frame.size.width - 30.0,
                              height: CGFloat.greatestFiniteMagnitude)
        // Title
        let titleString = "\(NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let titleRect = titleString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("imageSortMessage", comment: "Please select how you wish to sort images")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: maxWidth, options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
        return CGFloat(fmax(44.0, ceil(titleRect.size.height + textRect.size.height)))
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerAttributedString = NSMutableAttributedString(string: "")

        // Title
        let titleString = "\(NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images"))\n"
        let titleAttributedString = NSMutableAttributedString(string: titleString)
        titleAttributedString.addAttribute(.font, value: UIFont.piwigoFontBold(), range: NSRange(location: 0, length: titleString.count))
        headerAttributedString.append(titleAttributedString)

        // Text
        let textString = NSLocalizedString("imageSortMessage", comment: "Please select how you wish to sort images")
        let textAttributedString = NSMutableAttributedString(string: textString)
        textAttributedString.addAttribute(.font, value: UIFont.piwigoFontSmall(), range: NSRange(location: 0, length: textString.count))
        headerAttributedString.append(textAttributedString)

        // Header label
        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.textColor = .piwigoColorHeader()
        headerLabel.numberOfLines = 0
        headerLabel.adjustsFontSizeToFitWidth = false
        headerLabel.lineBreakMode = .byWordWrapping
        headerLabel.attributedText = headerAttributedString

        // Header view
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.addSubview(headerLabel)
        header.addConstraint(NSLayoutConstraint.constraintView(fromBottom: headerLabel, amount: 4)!)
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

    
    // MARK: - UITableView - Rows
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(kPiwigoSort.count.rawValue)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let sortChoice = kPiwigoSort(rawValue: Int16(indexPath.row))

        cell.backgroundColor = .piwigoColorCellBackground()
        cell.tintColor = .piwigoColorOrange()
        cell.textLabel?.font = .piwigoFontNormal()
        cell.textLabel?.textColor = .piwigoColorLeftLabel()
        cell.textLabel?.text = CategorySortViewController.getNameForCategorySortType(sortChoice!)
        cell.textLabel?.minimumScaleFactor = 0.5
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
        if indexPath.row == 0 {
            cell.accessibilityIdentifier = "sortAZ"
        }

        if indexPath.row == currentCategorySortType!.rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    
    // MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Did the user change the sort option
        if kPiwigoSort(rawValue: Int16(indexPath.row)) == currentCategorySortType { return }

        // Update choice
        tableView.cellForRow(at: IndexPath(row: Int(currentCategorySortType!.rawValue), section: 0))?.accessoryType = .none
        currentCategorySortType = kPiwigoSort(rawValue: Int16(indexPath.row))
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
}
