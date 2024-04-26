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
    private var updateOperations = [BlockOperation]()
    private var didUpdateCellHeight = false             // Workaround for iOS 12 - 15.x
    
    // MARK: - Core Data Source
    var user: User!
    var albumData: Album!
    private lazy var mainContext: NSManagedObjectContext = {
        guard let context: NSManagedObjectContext = user?.managedObjectContext
        else { fatalError("!!! Missing Managed Object Context !!!") }
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
    
    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: self.mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        albums.delegate = self
        return albums
    }()
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("••> viewDidLoad albums…")

        // Set collection view layout
        collectionView?.collectionViewLayout = AlbumCollectionViewFlowLayout()
        
        // Register AlbumCollectionViewCell class
        collectionView?.register(AlbumHeaderReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeader")
        collectionView?.register(AlbumCollectionViewCell.self, forCellWithReuseIdentifier: "AlbumCollectionViewCell")
        collectionView?.register(ImageFooterReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooter")
        
        // Register palette changes
        NotificationCenter.default.addObserver(self,selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    @objc func applyColorPalette() {
        // Background color of the view
        view.backgroundColor = UIColor.piwigoColorBackground()
        
        // Collection view
        collectionView?.indicatorStyle = AppVars.shared.isDarkPaletteActive ? .white : .black
        (collectionView?.visibleCells ?? []).forEach { cell in
            if let albumCell = cell as? AlbumCollectionViewCell {
                albumCell.applyColorPalette()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("••> viewWillAppear albums…")

        // Set colors, fonts, etc.
        applyColorPalette()
        
        // Initialise data source
        do {
            if albumData.pwgID >= Int32.zero {
                try albums.performFetch()
            }
        } catch {
            print("Error: \(error)")
        }
        
        // Album collection
//        collectionView?.reloadData()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        print("••> viewDidLayoutSubviews albumCollectionView: ", collectionView?.collectionViewLayout.collectionViewContentSize as Any)
        
        // Update table row height after collection view layouting
        if let albumImageVC = parent as? AlbumImageTableViewController {
            albumImageVC.albumCollectionCell?.invalidateIntrinsicContentSize()
            if #available(iOS 16, *) {
                // NOP — AlbumCollectionTableViewCell height updated automatically
            } else if didUpdateCellHeight == false {
                // Update AlbumCollectionTableViewCell height manually once
                DispatchQueue.main.async {
                    UIView.performWithoutAnimation {
                        albumImageVC.albumImageTableView?.beginUpdates()
                        albumImageVC.albumImageTableView?.endUpdates()
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        didUpdateCellHeight = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Update the navigation bar on orientation change, to match the new width of the table.
        coordinator.animate(alongsideTransition: { [self] context in
            // Reload collection
            collectionView?.reloadData()
        })
    }
    
    deinit {
        // Cancel all block operations
        for operation in updateOperations {
            operation.cancel()
        }
        updateOperations.removeAll(keepingCapacity: false)
        
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - Album Data
    private func attributedComment() -> NSMutableAttributedString {
        let desc = NSMutableAttributedString(attributedString: albumData.comment)
        let wholeRange = NSRange(location: 0, length: desc.string.count)
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        let attributes = [
            NSAttributedString.Key.foregroundColor: UIColor.piwigoColorHeader(),
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13, weight: .light),
            NSAttributedString.Key.paragraphStyle: style
        ]
        desc.addAttributes(attributes, range: wholeRange)
        return desc
    }
    
    private func getImageCount() -> String {
        // Get total number of images
        var totalCount = Int64.zero
        if albumData.pwgID == 0 {
            // Root Album only contains albums  => calculate total number of images
            (albums.fetchedObjects ?? []).forEach({ album in
                totalCount += album.totalNbImages
            })
        } else {
            // Number of images in current album
            totalCount = albumData.nbImages
        }
        
        // Build footer content
        var legend = ""
        if totalCount == Int64.min {
            // Is loading…
            legend = NSLocalizedString("loadingHUD_label", comment:"Loading…")
        }
        else if totalCount == Int64.zero {
            // Not loading and no images
            if albumData.pwgID == Int64.zero {
                legend = NSLocalizedString("categoryMainEmtpy", comment: "No albums in your Piwigo yet.\rYou may pull down to refresh or re-login.")
            } else {
                legend = NSLocalizedString("noImages", comment:"No Images")
            }
        }
        else {
            // Display number of images…
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let number = numberFormatter.string(from: NSNumber(value: totalCount)) {
                let format:String = totalCount > 1 ? NSLocalizedString("severalImagesCount", comment:"%@ photos") : NSLocalizedString("singleImageCount", comment:"%@ photo")
                legend = String(format: format, number)
            }
            else {
                legend = String(format: NSLocalizedString("severalImagesCount", comment:"%@ photos"), "?")
            }
        }
        return legend
    }
    
    func updateNberOfImagesInFooter() {
        // Update number of images in footer
        DispatchQueue.main.async { [self] in
            let indexPath = IndexPath(item: 0, section: 0)
            if let footer = collectionView?.supplementaryView(forElementKind: UICollectionView.elementKindSectionFooter, at: indexPath) as? ImageFooterReusableView {
                footer.nberImagesLabel?.text = getImageCount()
            }
        }
    }
    
    func resetPredicateAndPerformFetch() {
        // Update albums
        fetchAlbumsRequest.predicate = albumPredicate.withSubstitutionVariables(["catId" : albumData.pwgID])
        try? albums.performFetch()
    }
}


// MARK: - UICollectionViewDataSource
extension AlbumCollectionViewController
{
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AlbumHeader", for: indexPath) as? AlbumHeaderReusableView else { fatalError("!!! NO AlbumHeaderReusableView class !!!")}
            header.commentLabel?.attributedText = attributedComment()
            return header
        }

        if albumData.pwgID == 0, kind == UICollectionView.elementKindSectionFooter {
            guard let footer = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "ImageFooter", for: indexPath) as? ImageFooterReusableView else { fatalError("!!! NO ImageFooterReusableView class !!!")}
            footer.nberImagesLabel?.textColor = UIColor.piwigoColorHeader()
            footer.nberImagesLabel?.text = getImageCount()
            return footer
        }

        let view = UICollectionReusableView(frame: CGRect.zero)
        return view
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let objects = albums.fetchedObjects
        return objects?.count ?? 0
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCollectionViewCell", for: indexPath) as? AlbumCollectionViewCell else { fatalError("No AlbumCollectionViewCell!") }

        // Configure cell with album data
        let album = albums.object(at: indexPath)
        if album.isFault {
            // The album is not fired yet.
            album.willAccessValue(forKey: nil)
            album.didAccessValue(forKey: nil)
        }
        cell.albumData = album
        
        // Parent dependent configuration
        if let parent = parent as? AlbumImageTableViewController {
            cell.pushAlbumDelegate = parent
            cell.deleteAlbumDelegate = parent
            
            // Disable category cells in Image selection mode
            if parent.imageCollectionVC.isSelect {
                cell.contentView.alpha = 0.5
                cell.isUserInteractionEnabled = false
            } else {
                cell.contentView.alpha = 1.0
                cell.isUserInteractionEnabled = true
            }
        }
        return cell
    }
}


// MARK: - UICollectionViewDelegateFlowLayout
extension AlbumCollectionViewController: UICollectionViewDelegateFlowLayout
{
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        if elementKind == UICollectionView.elementKindSectionHeader {
            view.layer.zPosition = 0 // Below scroll indicator
            view.backgroundColor = UIColor.piwigoColorBackground().withAlphaComponent(0.75)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        // Header height?
        guard !albumData.comment.string.isEmpty else {
            return CGSize.zero
        }
        let desc = attributedComment()
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let headerRect = desc.boundingRect(with: CGSize(width: collectionView.frame.size.width - 30.0,
                                                        height: CGFloat.greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin, context: context)
        return CGSize(width: collectionView.frame.size.width - 30.0,
                      height: ceil(headerRect.size.height + 8.0))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        // Only for the root album
        if albumData.pwgID != 0 { return CGSize.zero }
        
        // Get number of images and status
        let footer = getImageCount()
        if footer.isEmpty { return CGSize.zero }

        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .light)]
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 1.0
        let footerRect = footer.boundingRect(
            with: CGSize(width: collectionView.frame.size.width - 30.0, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes, context: context)
        return CGSize(width: collectionView.frame.size.width - 30.0, 
                      height: ceil(footerRect.size.height + 8.0))
    }
}


// MARK: - NSFetchedResultsControllerDelegate
extension AlbumCollectionViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if collectionView?.window == nil || controller != albums { return }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        // Check that this update should be managed by this view controller
        guard let fetchDelegate = controller.delegate as? AlbumCollectionViewController else { return }
        if collectionView?.window == nil || controller != albums { return }

        // Collect operation changes
        switch type.rawValue {
        case NSFetchedResultsChangeType.delete.rawValue:
            guard let indexPath = indexPath else { return }
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Delete album #\(fetchDelegate.albumData.pwgID) at \(indexPath)")
                self?.collectionView?.deleteItems(at: [indexPath])
            })
        case NSFetchedResultsChangeType.update.rawValue:
            guard let indexPath = indexPath else { return }
            guard let album = anObject as? Album else { return }
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Update album at \(indexPath) of album #\(fetchDelegate.albumData.pwgID)")
                if let cell = self?.collectionView?.cellForItem(at: indexPath) as? AlbumCollectionViewCell {
                    // Re-configure album cell
                    cell.albumData = album
                }
            })
        case NSFetchedResultsChangeType.insert.rawValue:
            guard let newIndexPath = newIndexPath else { return }
            updateOperations.append( BlockOperation { [weak self] in
                debugPrint("••> Insert album #\(fetchDelegate.albumData.pwgID) at \(newIndexPath)")
                self?.collectionView?.insertItems(at: [newIndexPath])
            })
        case NSFetchedResultsChangeType.move.rawValue:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath,
                  indexPath != newIndexPath else { return }
            updateOperations.append( BlockOperation {  [weak self] in
                debugPrint("••> Move album #\(fetchDelegate.albumData.pwgID) from \(indexPath) to \(newIndexPath)")
                self?.collectionView?.moveItem(at: indexPath, to: newIndexPath)
            })
        default:
            fatalError("AlbumViewController: unknown NSFetchedResultsChangeType")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // Check that this update should be managed by this view controller
        if collectionView?.window == nil || controller != albums || updateOperations.isEmpty { return }

        // Update objects
        collectionView?.performBatchUpdates { [weak self] in
            self?.updateOperations.forEach({ $0.start()})
        } completion: { [weak self] _ in
            // Update footer
            self?.updateNberOfImagesInFooter()
        }
    }
}
