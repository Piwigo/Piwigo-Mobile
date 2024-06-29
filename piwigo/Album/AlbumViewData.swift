//
//  AlbumViewData.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 12/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import CoreData
import Foundation
import piwigoKit

class AlbumViewData: NSObject
{
    private var albumData: Album

    init(withAlbum albumData: Album) {
        self.albumData = albumData
        super.init()
    }
    

    // MARK: - Core Data Object Contexts
    private lazy var mainContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = DataController.shared.mainContext
        return context
    }()


    // MARK: - Sub-Albums
    private lazy var albumPredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "parentId == $catID"))
        andPredicates.append(NSPredicate(format: "user.server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()
    
    private lazy var fetchAlbumsRequest: NSFetchRequest = {
        // Sort albums by globalRank i.e. the order in which they are presented in the web UI
        let fetchRequest = Album.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                         selector: #selector(NSString.localizedStandardCompare(_:)))]
        fetchRequest.predicate = albumPredicate.withSubstitutionVariables(["catID" : albumData.pwgID])
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()
    
    lazy var albums: NSFetchedResultsController<Album> = {
        let albums = NSFetchedResultsController(fetchRequest: fetchAlbumsRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        return albums
    }()
    

    // MARK: - Images
    private lazy var imagePredicate: NSPredicate = {
        var andPredicates = [NSPredicate]()
        andPredicates.append(NSPredicate(format: "server.path == %@", NetworkVars.serverPath))
        andPredicates.append(NSPredicate(format: "ANY albums.pwgID == $catID"))
        andPredicates.append(NSPredicate(format: "ANY albums.user.username == %@", NetworkVars.username))
        return NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
    }()

    // The image sort type depends on the nature of the album and then on user settings
    private func getSortKeys(for sortOption: pwgImageSort) -> String {
        switch sortOption {
        case .albumDefault:
            if albumData.imageSort.isEmpty {
                // Piwigo version < 14 does not provide the image sort type
                if AlbumVars.shared.defaultSort.rawValue > pwgImageSort.random.rawValue {
                    AlbumVars.shared.defaultSort = .dateCreatedAscending
                }
                // Select the image sort option set in Settings
                return AlbumVars.shared.defaultSort.param
            }
            else {
                // The default image sort option is the one returned with the album data
                return albumData.imageSort
            }
        case .nameAscending, .nameDescending:
            fallthrough
        case .dateCreatedDescending, .dateCreatedAscending:
            fallthrough
        case .datePostedDescending, .datePostedAscending:
            fallthrough
        case .fileNameAscending, .fileNameDescending:
            fallthrough
        case .ratingScoreDescending, .ratingScoreAscending:
            fallthrough
        case .visitsDescending, .visitsAscending:
            fallthrough
        case .rankAscending, .random:
            fallthrough
        case .idAscending, .idDescending:
            fallthrough
        default:
            return sortOption.param
        }
    }
    
    private func sortDescriptors(from sortKeys: String) -> [NSSortDescriptor] {
        var descriptors = [NSSortDescriptor]()
        let items = sortKeys.components(separatedBy: ",")
        for item in items {
            var fixedItem = item
            // Remove extra space at the begining and end
            while fixedItem.hasPrefix(" ") {
                fixedItem.removeFirst()
            }
            while fixedItem.hasSuffix(" ") {
                fixedItem.removeLast()
            }
            // Convert to sort descriptors
            let sortDesc = fixedItem.components(separatedBy: " ")
            if sortDesc[0].contains(pwgImageOrder.random.rawValue) {
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.rankRandom), ascending: true))
                continue
            }
            if sortDesc.count != 2 { continue }
            let isAscending = sortDesc[1].lowercased() == pwgImageOrder.ascending.rawValue ? true : false
            // PS: Comparator blocks are not supported with Core Data
            switch sortDesc[0] {
            case pwgImageAttr.title.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.titleStr), ascending: isAscending, selector: #selector(NSString.localizedCaseInsensitiveCompare)))
            case pwgImageAttr.dateCreated.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.dateCreated), ascending: isAscending))
            case pwgImageAttr.datePosted.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: isAscending))
            case pwgImageAttr.fileName.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.fileName), ascending: isAscending, selector: #selector(NSString.localizedCompare)))
            case pwgImageAttr.rating.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.ratingScore), ascending: isAscending))
            case pwgImageAttr.visits.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.visits), ascending: isAscending))
            case pwgImageAttr.identifier.rawValue:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: isAscending))
            case pwgImageAttr.rank.rawValue, "`\(pwgImageAttr.rank.rawValue)`":
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.rankManual), ascending: true))
            default:
                descriptors.append(NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: isAscending))
            }
        }
        if descriptors.isEmpty {
            let sortByPosted = NSSortDescriptor(key: #keyPath(Image.datePosted), ascending: false)
            let sortByFile = NSSortDescriptor(key: #keyPath(Image.fileName), ascending: true)
            let sortById = NSSortDescriptor(key: #keyPath(Image.pwgID), ascending: true)
            return [sortByPosted, sortByFile, sortById]
        } else {
            return descriptors
        }
    }

    private func sectionKey(for sortKeys: String) -> String? {
        // Extract the first key
        guard var firstKey = sortKeys.components(separatedBy: ",").first
        else { return nil }
        
        // Remove extra space at the begining and end
        while firstKey.hasPrefix(" ") {
            firstKey.removeFirst()
        }
        while firstKey.hasSuffix(" ") {
            firstKey.removeLast()
        }

        // Set section key from the default grouping setting
        guard let sortKey = firstKey.components(separatedBy: " ").first
        else { return nil}
        switch sortKey {
        case pwgImageOrder.random.rawValue:
            return nil
        case pwgImageAttr.title.rawValue:
            return nil
        case pwgImageAttr.dateCreated.rawValue:
            return AlbumVars.shared.defaultGroup.dateCreatedSectionKey
        case pwgImageAttr.datePosted.rawValue:
            return AlbumVars.shared.defaultGroup.datePostedSectionKey
        case pwgImageAttr.fileName.rawValue:
            return nil
        case pwgImageAttr.rating.rawValue:
            return nil
        case pwgImageAttr.visits.rawValue:
            return nil
        case pwgImageAttr.identifier.rawValue:
            return nil
        case pwgImageAttr.rank.rawValue, "`\(pwgImageAttr.rank.rawValue)`":
            return nil
        default:
            return nil
        }
    }
    
    private lazy var fetchImagesRequest: NSFetchRequest = {
        let fetchRequest = Image.fetchRequest()
        fetchRequest.predicate = imagePredicate.withSubstitutionVariables(["catID" : albumData.pwgID])
        fetchRequest.fetchBatchSize = 20
        return fetchRequest
    }()
    
    private lazy var images: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: nil, cacheName: nil)
        return images
    }()

    private lazy var imagesByDayOfDateCreated: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.day.dateCreatedSectionKey,
                                                cacheName: nil)
        return images
    }()

    private lazy var imagesByWeekOfDateCreated: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.week.dateCreatedSectionKey,
                                                cacheName: nil)
        return images
    }()

    private lazy var imagesByMonthOfDateCreated: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.month.dateCreatedSectionKey,
                                                cacheName: nil)
        return images
    }()

    private lazy var imagesByDayOfDatePosted: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.day.datePostedSectionKey,
                                                cacheName: nil)
        return images
    }()

    private lazy var imagesByWeekOfDatePosted: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.week.datePostedSectionKey,
                                                cacheName: nil)
        return images
    }()

    private lazy var imagesByMonthOfDatePosted: NSFetchedResultsController<Image> = {
        let images = NSFetchedResultsController(fetchRequest: fetchImagesRequest,
                                                managedObjectContext: mainContext,
                                                sectionNameKeyPath: pwgImageGroup.month.datePostedSectionKey,
                                                cacheName: nil)
        return images
    }()


    // MARK: - Common Methods
    func switchToAlbum(withID catID: Int32) {
        // Called from a sub-album to:
        /// - return to the default album when an album is unavailable in the CoreData database
        /// - switch to another default album from the Settings page
        /// - display searched images
        /// Sort and section keys are unchanged.
        fetchAlbumsRequest.predicate = albumPredicate.withSubstitutionVariables(["catID" : catID])
        fetchImagesRequest.predicate = imagePredicate.withSubstitutionVariables(["catID" : catID])
    }
    
    func images(sortedBy sort: pwgImageSort = AlbumVars.shared.defaultSort,
                groupedBy group: pwgImageGroup = AlbumVars.shared.defaultGroup) -> NSFetchedResultsController<Image> {
        // Update default settings if the album is not a specific smart album
        if [pwgSmartAlbum.best.rawValue, pwgSmartAlbum.visits.rawValue].contains(albumData.pwgID) == false {
            AlbumVars.shared.defaultSort = sort
            AlbumVars.shared.defaultGroup = group
        }
        
        // Update sort descriptors
        /// when sort = .default, the image sort option is the one returned with the album data
        let sortKeys = getSortKeys(for: sort)
        fetchImagesRequest.sortDescriptors = sortDescriptors(from: sortKeys)
        
        // Determine the most appropriate section key
        /// when sort = .default, the section key depends on the sort option returned with the album data
        let sectionKey = sectionKey(for: sortKeys)

        // Return the appropriate fetch controller
        switch sectionKey {
        case pwgImageGroup.day.dateCreatedSectionKey:
            return imagesByDayOfDateCreated
        case pwgImageGroup.week.dateCreatedSectionKey:
            return imagesByWeekOfDateCreated
        case pwgImageGroup.month.dateCreatedSectionKey:
            return imagesByMonthOfDateCreated
        case pwgImageGroup.day.datePostedSectionKey:
            return imagesByDayOfDatePosted
        case pwgImageGroup.week.datePostedSectionKey:
            return imagesByWeekOfDatePosted
        case pwgImageGroup.month.datePostedSectionKey:
            return imagesByMonthOfDatePosted
        case nil:
            fallthrough
        default:
            return images
        }
    }
}
