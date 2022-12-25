//
//  AlbumCollectionViewCell.swift
//  piwigo
//
//  Created by Spencer Baker on 3/9/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//
//  Converted to Swift 5.4 by Eddy Lelièvre-Berna on 23/01/2022
//

import CoreData
import UIKit
import piwigoKit

protocol AlbumCollectionViewCellDelegate: NSObjectProtocol {
    func pushCategoryView(_ viewController: UIViewController?)
    func didMoveCategory(_ albumCell: AlbumCollectionViewCell?)
    func deleteCategory(_ albumId: Int32, inParent parentID: Int32,
                        inMode mode: pwgAlbumDeletionMode)
}

class AlbumCollectionViewCell: UICollectionViewCell
{
    weak var categoryDelegate: AlbumCollectionViewCellDelegate?
    var albumData: Album? {
        didSet {
            tableView?.reloadData()
        }
    }
    var albumProvider: AlbumProvider!
    var savingContext: NSManagedObjectContext?
    
    var tableView: UITableView?
    var renameAlert: UIAlertController?
    var renameAction: UIAlertAction?
    var deleteAction: UIAlertAction?
    var nbOrphans = Int64.min
    enum textFieldTag: Int {
        case albumName = 1000, albumDescription, nberOfImages
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView = UITableView()
        tableView?.translatesAutoresizingMaskIntoConstraints = false
        tableView?.backgroundColor = UIColor.clear
        tableView?.separatorStyle = .none
        tableView?.register(UINib(nibName: "AlbumTableViewCell", bundle: nil),
                            forCellReuseIdentifier: "AlbumTableViewCell")
        tableView?.delegate = self
        tableView?.dataSource = self
        if let tableView = tableView {
            contentView.addSubview(tableView)
        }
        contentView.addConstraints(NSLayoutConstraint.constraintFillSize(tableView)!)

        NotificationCenter.default.addObserver(self, selector: #selector(autoUploadUpdated(_:)),
                                               name: .pwgAutoUploadEnabled, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(autoUploadUpdated(_:)),
                                               name: .pwgAutoUploadDisabled, object: nil)
    }

    @objc
    func applyColorPalette() {
        tableView?.reloadData()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        albumData = nil
    }

    @objc
    func autoUploadUpdated(_ notification: Notification?) {
        // Is this cell concerned?
        if UploadVars.autoUploadCategoryId != Int(albumData?.pwgID ?? 0)  { return }

        // Disallow user to delete the active auto-upload destination album
        let cell = tableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? AlbumTableViewCell
        cell?.refreshButtons(true)
    }

    deinit {
        renameAction = nil
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadEnabled, object: nil)
        NotificationCenter.default.removeObserver(self, name: .pwgAutoUploadDisabled, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - UITableViewDataSource Methods
extension AlbumCollectionViewCell: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumTableViewCell", for: indexPath) as? AlbumTableViewCell else {
            print("Error: tableView.dequeueReusableCell does not return a AlbumTableViewCell!")
            return AlbumTableViewCell()
        }
        
        // Configure cell
        cell.config(withAlbumData: albumData)
        
        // Album modifications are possible only if data are known
        if albumData != nil {
            cell.delegate = self
            cell.isAccessibilityElement = true
        }
        return cell
    }
}


// MARK: - UITableViewDelegate
extension AlbumCollectionViewCell: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 148.5 // see XIB file
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Push new album view
        if let albumData = albumData {
            let albumView = AlbumViewController(albumId: albumData.pwgID)
            categoryDelegate?.pushCategoryView(albumView)
        }
    }
}


// MARK: - MGSwipeTableCellDelegate Methods
extension AlbumCollectionViewCell: MGSwipeTableCellDelegate
{
    func swipeTableCell(_ cell: MGSwipeTableCell, canSwipe direction: MGSwipeDirection,
                        from point: CGPoint) -> Bool {
        return true
    }
    
    func swipeTableCellWillBeginSwiping(_ cell: MGSwipeTableCell) {
        // Determine number of orphans if album deleted
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            self.nbOrphans = Int64.min
            guard let catId = albumData?.pwgID else { return }
            AlbumUtilities.calcOrphans(catId) { nbOrphans in
                self.nbOrphans = nbOrphans
            } failure: { _ in }
        }
    }

    func swipeTableCell(_ cell: MGSwipeTableCell, swipeButtonsFor direction: MGSwipeDirection, swipeSettings: MGSwipeSettings, expansionSettings: MGSwipeExpansionSettings) -> [UIView]?
    {
        guard let albumData = albumData else { return nil }

        // Only admins can rename, move and delete albums
        if !NetworkVars.hasAdminRights { return nil }

        // Settings
        cell.swipeBackgroundColor = UIColor.piwigoColorOrange()
        swipeSettings.transition = .border

        // Right => Left swipe
        if direction == .rightToLeft {
            let trash = MGSwipeButton(title: "", icon: UIImage(named: "swipeTrash.png"),
                backgroundColor: UIColor.red, callback: { [self] sender in
                    deleteCategory()
                    return false
                })
            let move = MGSwipeButton(title: "", icon: UIImage(named: "swipeMove.png"),
                backgroundColor: UIColor.piwigoColorBrown(), callback: { [self] sender in
                    moveCategory()
                    return false
                })
            let rename = MGSwipeButton(title: "", icon: UIImage(named: "swipeRename.png"),
                backgroundColor: UIColor.piwigoColorOrange(), callback: { [self] sender in
                    renameCategory()
                    return false
                })

            // Disallow user to delete the active auto-upload destination album
            if (UploadVars.autoUploadCategoryId == Int(albumData.pwgID)),
                UploadVars.isAutoUploadActive {
                return [move, rename]
            } else {
                expansionSettings.buttonIndex = 0
                return [trash, move, rename]
            }
        }
        return nil
    }
}


// MARK: - UITextField Delegate Methods
extension AlbumCollectionViewCell: UITextFieldDelegate
{
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName, .albumDescription:
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            let newDescription = renameAlert?.textFields?.last?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            if let _ = Int(textField.text ?? "") {
                deleteAction?.isEnabled = true
            } else {
                deleteAction?.isEnabled = false
            }
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName:
            // Check both text fields
            let newName = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            let newDescription = renameAlert?.textFields?.last?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .albumDescription:
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            let newDescription = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: newDescription)
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            if let nberAsText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string),
               let _ = Int(nberAsText) {
                deleteAction?.isEnabled = true
            } else {
                deleteAction?.isEnabled = false
            }
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
        }
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        switch textFieldTag(rawValue: textField.tag) {
        case .albumName:
            // The album cannot be renamed with an empty string.
            renameAction?.isEnabled = false
        case .albumDescription:
            // The album cannot be renamed with an empty string or the same name.
            // Check both text fields
            let newName = renameAlert?.textFields?.first?.text
            renameAction?.isEnabled = shouldEnableActionWith(newName: newName,
                                                             newDescription: "")
        case .nberOfImages:
            // The album deletion cannot be requested if a number of images is not provided.
            deleteAction?.isEnabled = false
        case .none:
            renameAction?.isEnabled = false
            deleteAction?.isEnabled = false
        }
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
