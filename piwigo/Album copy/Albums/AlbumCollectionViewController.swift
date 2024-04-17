//
//  AlbumCollectionViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 07/04/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit

class AlbumCollectionViewController: UICollectionViewController
{
    var user: User!
    var albumData: Album!

    // https://viet-tran.medium.com/uicollectionview-inside-a-uitableviewcell-with-self-sizing-beccb6de4159
    // Set this action during initialization to get a callback when the collection view finishes its layout.
    // To prevent infinite loop, this action should be called only once. Once it is called, it resets itself
    // to nil.
    var didLayoutAction: (() -> Void)?

    @IBOutlet private var albumCollectionView: AlbumCollectionView!
    
    
    // MARK: - Core Data Source
    private lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext else {
            fatalError("!!! Missing Managed Object Context !!!")
        }
        return context
    }()

    private lazy var albumPredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "parentId == $catId"))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    private lazy var fetchAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        fetchRequest.predicate = albumPredicate.withSubstitutionVariables(["catId" : albumData.pwgID])
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()

    private lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
//        albums.delegate = self
        return albums
    }()

    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Register AlbumCollectionViewCell class
        albumCollectionView.register(AlbumCollectionViewCell.self, forCellWithReuseIdentifier: "AlbumCollectionViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Initialise data source
        do {
            if albumData.pwgID >= Int32.zero {
                try albums.performFetch()
            }
        } catch {
            print("Error: \(error)")
        }

        albumCollectionView.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Update table row height after first collection view layouting
        didLayoutAction?()
        didLayoutAction = nil   //  Call only once
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
}


// MARK: - UICollectionViewDataSource
extension AlbumCollectionViewController
{
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let objects = albums.fetchedObjects
        return objects?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCell", for: indexPath) as? AlbumCollectionViewCell else { fatalError("No AlbumCollectionViewCell!") }

        // Configure cell with album data
        let albumCell = albums.object(at: indexPath)
        if albumCell.isFault {
            // The album is not fired yet.
            albumCell.willAccessValue(forKey: nil)
            albumCell.didAccessValue(forKey: nil)
        }
        cell.albumData = albumCell
//        cell.categoryDelegate = self

        // Disable category cells in Image selection mode
//        if isSelect {
//            cell.contentView.alpha = 0.5
//            cell.isUserInteractionEnabled = false
//        } else {
//            cell.contentView.alpha = 1.0
//            cell.isUserInteractionEnabled = true
//        }
        return cell
    }
}


// MARK: - UICollectionViewDelegate
extension AlbumCollectionViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        // Avoid unwanted spaces
        if collectionView.numberOfItems(inSection: section) == 0 {
            return UIEdgeInsets(top: 0, left: AlbumUtilities.kAlbumMarginsSpacing,
                                bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
        } else if albumData.pwgID == 0 {
            if #available(iOS 13.0, *) {
                return UIEdgeInsets(top: 0, left: AlbumUtilities.kAlbumMarginsSpacing,
                                    bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
            } else {
                return UIEdgeInsets(top: 10, left: AlbumUtilities.kAlbumMarginsSpacing,
                                    bottom: 0, right: AlbumUtilities.kAlbumMarginsSpacing)
            }
        } else {
            return UIEdgeInsets(top: 10, left: AlbumUtilities.kAlbumMarginsSpacing, bottom: 0,
                                right: AlbumUtilities.kAlbumMarginsSpacing)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return AlbumUtilities.kAlbumCellSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let size = AlbumUtilities.albumSize(forView: collectionView, maxWidth: 384.0)
        return CGSize(width: size, height: 156.5)
    }
}
