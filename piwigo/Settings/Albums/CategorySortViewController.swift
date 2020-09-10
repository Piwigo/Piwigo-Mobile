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

@objc
protocol CategorySortDelegate: NSObjectProtocol {
    func didSelectCategorySortType(_ sortType: kPiwigoSort)
}

@objc
class CategorySortViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @objc weak var sortDelegate: CategorySortDelegate?
    @objc var currentCategorySortType: kPiwigoSort = Model.sharedInstance().defaultSort 

    @objc
    class func getNameForCategorySortType(_ sortType: kPiwigoSort) -> String {
        var name = ""
        switch sortType {
        case kPiwigoSortNameAscending:
            name = NSLocalizedString("categorySort_nameAscending", comment: "Photo Title, A → Z")
        case kPiwigoSortNameDescending:
            name = NSLocalizedString("categorySort_nameDescending", comment: "Photo Title, Z → A")
        case kPiwigoSortFileNameAscending:
            name = NSLocalizedString("categorySort_fileNameAscending", comment: "File Name, A → Z")
        case kPiwigoSortFileNameDescending:
            name = NSLocalizedString("categorySort_fileNameDescending", comment: "File Name, Z → A")
        case kPiwigoSortDateCreatedDescending:
            name = NSLocalizedString("categorySort_dateCreatedDescending", comment: "Date Created, new → old")
        case kPiwigoSortDateCreatedAscending:
            name = NSLocalizedString("categorySort_dateCreatedAscending", comment: "Date Created, old → new")
        case kPiwigoSortDatePostedDescending:
            name = NSLocalizedString("categorySort_datePostedDescending", comment: "Date Posted, new → old")
        case kPiwigoSortDatePostedAscending:
            name = NSLocalizedString("categorySort_datePostedAscending", comment: "Date Posted, old → new")
        case kPiwigoSortRatingScoreDescending:
            name = NSLocalizedString("categorySort_ratingScoreDescending", comment: "Rating Score, high → low")
        case kPiwigoSortRatingScoreAscending:
            name = NSLocalizedString("categorySort_ratingScoreAscending", comment: "Rating Score, low → high")
        case kPiwigoSortVisitsDescending:
            name = NSLocalizedString("categorySort_visitsDescending", comment: "Visits, high → low")
        case kPiwigoSortVisitsAscending:
            name = NSLocalizedString("categorySort_visitsAscending", comment: "Visits, low → high")
        case kPiwigoSortManual:
            name = NSLocalizedString("categorySort_manual", comment: "Manual Order")
        case kPiwigoSortRandom:
            name = NSLocalizedString("categorySort_random", comment: "Random Order")
//		case kPiwigoSortVideoOnly:
//			name = NSLocalizedString(@"categorySort_videosOnly", @"Videos Only");
//			break;
//		case kPiwigoSortImageOnly:
//			name = NSLocalizedString(@"categorySort_imagesOnly", @"Images Only");
//			break;

        case kPiwigoSortCount:
            name = ""
        default:
            name = ""
            break
        }
        return name
    }

    @IBOutlet var sortSelectTableView: UITableView!


// MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("tabBar_albums", comment: "Albums")
        sortSelectTableView.accessibilityIdentifier = "sortSelect"
    }

    @objc
    func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()

        // Navigation bar
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorWhiteCream(),
            NSAttributedString.Key.font: UIFont.piwigoFontNormal()
        ]
        navigationController?.navigationBar.titleTextAttributes = attributes
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
        navigationController?.navigationBar.barStyle = Model.sharedInstance().isDarkPaletteActive ? .black : .default
        navigationController?.navigationBar.tintColor = UIColor.piwigoColorOrange()
        navigationController?.navigationBar.barTintColor = UIColor.piwigoColorBackground()
        navigationController?.navigationBar.backgroundColor = UIColor.piwigoColorBackground()

        // Table view
        sortSelectTableView.separatorColor = UIColor.piwigoColorSeparator()
        sortSelectTableView.indicatorStyle = Model.sharedInstance().isDarkPaletteActive ? .white : .black
        sortSelectTableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Register palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette), name: name, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Return selected album
        sortDelegate?.didSelectCategorySortType(currentCategorySortType)

        // Unregister palette changes
        let name: NSNotification.Name = NSNotification.Name(kPiwigoNotificationPaletteChanged)
        NotificationCenter.default.removeObserver(self, name: name, object: nil)
    }

    
// MARK: - UITableView - Header
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Title
        let titleString = "\(NSLocalizedString("defaultImageSort>414px", comment: "Default Sort of Images"))\n"
        let titleAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontBold()
        ]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let titleRect = titleString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: titleAttributes, context: context)

        // Text
        let textString = NSLocalizedString("imageSortMessage", comment: "Please select how you wish to sort images")
        let textAttributes = [
            NSAttributedString.Key.font: UIFont.piwigoFontSmall()
        ]
        let textRect = textString.boundingRect(with: CGSize(width: tableView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: textAttributes, context: context)
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
        headerLabel.textColor = UIColor.piwigoColorHeader()
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
        return Int(kPiwigoSortCount.rawValue)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let sortChoice = kPiwigoSort(rawValue: UInt32(indexPath.row))

        cell.backgroundColor = UIColor.piwigoColorCellBackground()
        cell.tintColor = UIColor.piwigoColorOrange()
        cell.textLabel?.font = UIFont.piwigoFontNormal()
        cell.textLabel?.textColor = UIColor.piwigoColorLeftLabel()
        cell.textLabel?.text = CategorySortViewController.getNameForCategorySortType(sortChoice)
        cell.textLabel?.minimumScaleFactor = 0.5
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.lineBreakMode = .byTruncatingMiddle
        if indexPath.row == 0 {
            cell.accessibilityIdentifier = "sortAZ"
        }

        if indexPath.row == currentCategorySortType.rawValue {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    
// MARK: - UITableViewDelegate Methods
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        currentCategorySortType = kPiwigoSort(rawValue: UInt32(indexPath.row))
        tableView.reloadData()
        navigationController?.popViewController(animated: true)
    }
}
