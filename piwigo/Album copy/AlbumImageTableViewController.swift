//
//  AlbumImageTableViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit

class AlbumImageTableViewController: UITableViewController
{
    var categoryId = Int32.zero
    
    
    // MARK: - Core Data Providers
    private lazy var userProvider: UserProvider = {
        return UserProvider.shared
    }()

    lazy var albumProvider: AlbumProvider = {
        return AlbumProvider.shared
    }()


    // MARK: - Core Data Object Contexts
    lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()

    
    // MARK: - Core Data Source
    lazy var user: User = {
        guard let user = userProvider.getUserAccount(inContext: mainContext) else {
            // Unknown user instance! ► Back to login view
            ClearCache.closeSession()
            return User()
        }
        // User available ► Job done
        if user.isFault {
            // The user is not fired yet.
            user.willAccessValue(forKey: nil)
            user.didAccessValue(forKey: nil)
        }
        return user
    }()
    
    lazy var albumData: Album = {
        return currentAlbumData()
    }()
    private func currentAlbumData() -> Album {
        // Did someone delete this album?
        if let album = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
            // Album available ► Job done
            if album.isFault {
                // The album is not fired yet.
                album.willAccessValue(forKey: nil)
                album.didAccessValue(forKey: nil)
            }
            return album
        }
        
        // Album not available anymore ► Back to default album?
        categoryId = AlbumVars.shared.defaultCategory
        if let defaultAlbum = albumProvider.getAlbum(ofUser: user, withId: categoryId) {
//            changeAlbumID()
            if defaultAlbum.isFault {
                // The default album is not fired yet.
                defaultAlbum.willAccessValue(forKey: nil)
                defaultAlbum.didAccessValue(forKey: nil)
            }
            return defaultAlbum
        }

        // Default album deleted ► Back to root album
        categoryId = Int32.zero
        guard let rootAlbum = albumProvider.getAlbum(ofUser: user, withId: Int32.zero)
        else { fatalError("••> Could not create root album!") }
        if rootAlbum.isFault {
            // The root album is not fired yet.
            rootAlbum.willAccessValue(forKey: nil)
            rootAlbum.didAccessValue(forKey: nil)
        }
//        changeAlbumID()
        return rootAlbum
    }


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("===============================")
        print("••> viewDidLoad albumImage: \(categoryId)")

        // Register table view cells of album and image collections
        tableView.register(UINib(nibName: "AlbumCollectionTableViewCell", bundle: nil), forCellReuseIdentifier: "AlbumCollectionTableViewCell")
        tableView.register(UINib(nibName: "ImageCollectionTableViewCell", bundle: nil), forCellReuseIdentifier: "ImageCollectionTableViewCell")

        // Initialise AlbumCollectionViewController
//        children.forEach { viewController in
//            if let albumVC = viewController as? AlbumCollectionViewController {
//                // Initialise album collection view controller
//                albumVC.user = self.user
//                albumVC.albumData = self.albumData
//            }
//        }

        // Navigation bar
        navigationController?.navigationBar.accessibilityIdentifier = "AlbumImagesNav"

        // Hide toolbar
        navigationController?.isToolbarHidden = true

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: .pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Table view
        tableView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
}


// MARK: - UITableViewDelegate
extension AlbumImageTableViewController
{
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:     // Album collection
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumCollectionTableViewCell") as? AlbumCollectionTableViewCell else { fatalError("!!! NO AlbumCollectionTableViewCell !!!") }

            cell.albumCollectionVC.user = self.user
            cell.albumCollectionVC.albumData = self.albumData
            return cell

        default:    // Image collection
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCollectionTableViewCell") as? ImageCollectionTableViewCell else { fatalError("!!! NO ImageCollectionTableViewCell !!!") }

            cell.imageCollectionVC.user = self.user
            cell.imageCollectionVC.albumData = self.albumData
            return cell
        }
    }

//    private func add(asChildViewController viewController: UIViewController) {
//        // Add Child View Controller
//        addChild(viewController)
//
//        // Add Child View as Subview
//        view.addSubview(viewController.view)
//
//        // Define Constraints
//        NSLayoutConstraint.activate([
//            viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
//            viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//        ])
//
//        // Notify Child View Controller
//        viewController.didMove(toParent: self)
//    }
}

// MARK: - UITableViewDelegate
extension AlbumImageTableViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}


extension UIView {
    var parentViewController: UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.parentViewController
        } else {
            return nil
        }
    }
}

extension UITableViewCell {
    var tableView: UITableView? {
        return (next as? UITableView) ?? (parentViewController as? UITableViewController)?.tableView
    }
}

extension UITableView {
    // Update table layout without reloading rows
    func updateRowHeightsWithoutReloadingRows(animated: Bool = false) {
        let block = {
            self.beginUpdates()
            self.endUpdates()
        }
        
        if animated {
            block()
        }
        else {
            UIView.performWithoutAnimation {
                block()
            }
        }
    }
}
