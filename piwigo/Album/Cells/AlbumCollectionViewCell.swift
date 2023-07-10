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
    func pushCategoryView(_ viewController: UIViewController?,
                          completion: @escaping (Bool) -> Void)
    func didDeleteCategory(withError error: NSError?,
                           viewController topViewController: UIViewController?)
}

class AlbumCollectionViewCell: UICollectionViewCell
{
    weak var categoryDelegate: AlbumCollectionViewCellDelegate?
    var albumData: Album? {
        didSet {
            tableView?.reloadData()
        }
    }

    var tableView: UITableView?
    var renameAlert: UIAlertController?
    var renameAction: UIAlertAction?
    var deleteAction: UIAlertAction?
    var nbOrphans = Int64.min
    enum textFieldTag: Int {
        case albumName = 1000, albumDescription, nberOfImages
    }


    // MARK: - Core Data Object Contexts
    lazy var user: User? = albumData?.user
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    
    // MARK: - Core Data Providers
    private lazy var albumProvider: AlbumProvider = {
        let provider : AlbumProvider = AlbumProvider.shared
        return provider
    }()

    
    // MARK: - Initialisation
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
    }

    @objc
    func applyColorPalette() {
        tableView?.reloadData()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        albumData = nil
    }

    deinit {
        renameAction = nil
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - UITableViewDataSource Methods
extension AlbumCollectionViewCell: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albumData?.isFault ?? true ? 0 : 1
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
            categoryDelegate?.pushCategoryView(albumView, completion: {_ in })
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        // Only admins can rename, move and delete albums
        if !(user?.hasAdminRights ?? false) { return nil }

        // Determine number of orphans if album deleted
        DispatchQueue.global(qos: .userInteractive).async { [unowned self] in
            self.nbOrphans = Int64.min
            guard let catId = albumData?.pwgID else { return }
            AlbumUtilities.calcOrphans(catId) { nbOrphans in
                self.nbOrphans = nbOrphans
            } failure: { _ in }
        }

        // Album deletion
        let trash = UIContextualAction(style: .normal, title: nil,
                                       handler: { _, _, completionHandler in
            self.deleteCategory(completion: completionHandler)
        })
        trash.backgroundColor = .red
        trash.image = UIImage(named: "swipeTrash.png")
        
        // Album move
        let move = UIContextualAction(style: .normal, title: nil,
                                      handler: { action, view, completionHandler in
            self.moveCategory(completion: completionHandler)
        })
        move.backgroundColor = .piwigoColorBrown()
        move.image = UIImage(named: "swipeMove.png")
        
        // Album renaming
        let rename = UIContextualAction(style: .normal, title: nil,
                                        handler: { action, view, completionHandler in
            self.renameCategory(completion: completionHandler)
        })
        rename.backgroundColor = .piwigoColorOrange()
        rename.image = UIImage(named: "swipeRename.png")

        // Disallow user to delete the active auto-upload destination album
        guard let albumData = albumData else { return nil }
        if (UploadVars.autoUploadCategoryId == Int(albumData.pwgID)),
            UploadVars.isAutoUploadActive {
            return UISwipeActionsConfiguration(actions: [move, rename])
        } else {
            return UISwipeActionsConfiguration(actions: [trash, move, rename])
        }
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
