//
//  AlbumCollectionViewCellOld.swift
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

protocol PushAlbumCollectionViewCellDelegate: NSObjectProtocol {
    func pushAlbumView(_ viewController: UIViewController?,
                       completion: @escaping (Bool) -> Void)
}

class AlbumCollectionViewCellOld: UICollectionViewCell
{
    weak var pushAlbumDelegate: (any PushAlbumCollectionViewCellDelegate)?
    
    var albumData: Album? {
        didSet {
            tableView?.reloadData()
        }
    }

    var tableView: UITableView?
    var nbOrphans = Int64.min


    // MARK: - Core Data Object Contexts
    lazy var user: User? = albumData?.user
    lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
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
        tableView?.isScrollEnabled = false
        if let tableView = tableView {
            contentView.addSubview(tableView)
        }
        contentView.addConstraints(NSLayoutConstraint.constraintFillSize(tableView)!)
    }

    @MainActor
    @objc func applyColorPalette() {
        tableView?.reloadData()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        albumData = nil
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}


// MARK: - UITableViewDataSource Methods
extension AlbumCollectionViewCellOld: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albumData?.isFault ?? true ? 0 : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumTableViewCell", for: indexPath) as? AlbumTableViewCell 
        else { preconditionFailure("Could not load a AlbumTableViewCell") }
        
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
extension AlbumCollectionViewCellOld: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return contentView.bounds.height   // see XIB file
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Push new album view
        if let albumData = albumData {
            let albumSB = UIStoryboard(name: "AlbumViewController", bundle: nil)
            guard let subAlbumVC = albumSB.instantiateViewController(withIdentifier: "AlbumViewController") as? AlbumViewController
            else { preconditionFailure("Could not load AlbumViewController") }
            subAlbumVC.categoryId = albumData.pwgID
            pushAlbumDelegate?.pushAlbumView(subAlbumVC, completion: { _ in })
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        // Only admins can rename, move and delete albums
        guard user?.hasAdminRights ?? false,
              let albumData = self.albumData, let user = self.user,
              let topViewController = self.window?.topMostViewController()
        else { return nil }

        // Determine number of orphans if album deleted
        DispatchQueue.global(qos: .userInteractive).async { [self] in
            self.nbOrphans = Int64.min
            AlbumUtilities.calcOrphans(albumData.pwgID) { [self] nbOrphans in
                self.nbOrphans = nbOrphans
            } failure: { _ in }
        }

        // Symbol configuration
        var symbolConfig: UIImage.SymbolConfiguration
        if #available(iOS 26.0, *) {
            symbolConfig = UIImage.SymbolConfiguration(pointSize: 21.0, weight: .medium)
        } else {
            // Fallback on previous version
            symbolConfig = UIImage.SymbolConfiguration(pointSize: 24.0, weight: .regular)
        }
        let colorConfig = UIImage.SymbolConfiguration(paletteColors: [.white])
        let combinedConfig = symbolConfig.applying(colorConfig)
        
        // Album deletion
        let trash = UIContextualAction(style: .normal, title: nil,
                                       handler: { _, _, completionHandler in
            let delete = AlbumDeletion(albumData: albumData, user: user,
                                       topViewController: topViewController)
            delete.displayAlert(completion: completionHandler)
        })
        trash.backgroundColor = .red
        trash.image = UIImage(systemName: "trash", withConfiguration: combinedConfig)
        
        // Album move
        let move = UIContextualAction(style: .normal, title: nil,
                                      handler: { action, view, completionHandler in
            let moveSB = UIStoryboard(name: "SelectCategoryViewController", bundle: nil)
            guard let moveVC = moveSB.instantiateViewController(withIdentifier: "SelectCategoryViewController") as? SelectCategoryViewController
            else { preconditionFailure("Cannot instantiate SelectCategoryViewController") }
            if moveVC.setInput(parameter: albumData, for: .moveAlbum) {
                moveVC.user = user
                self.pushAlbumDelegate?.pushAlbumView(moveVC, completion: completionHandler)
            }
        })
        move.backgroundColor = PwgColor.brown
        move.image = UIImage(systemName: "rectangle.stack", withConfiguration: combinedConfig)
        
        // Album renaming
        let rename = UIContextualAction(style: .normal, title: nil,
                                        handler: { action, view, completionHandler in
            let rename = AlbumRenaming(albumData: albumData, user: user, mainContext: self.mainContext,
                                       topViewController: topViewController)
            rename.displayAlert(completion: completionHandler)
        })
        rename.backgroundColor = PwgColor.orange
        rename.image = UIImage(systemName: "character.cursor.ibeam", withConfiguration: combinedConfig)

        // Disallow user to delete the active auto-upload destination album
        if (UploadVars.shared.autoUploadCategoryId == Int(albumData.pwgID)),
            UploadVars.shared.isAutoUploadActive {
            return UISwipeActionsConfiguration(actions: [move, rename])
        } else {
            return UISwipeActionsConfiguration(actions: [trash, move, rename])
        }
    }
}
