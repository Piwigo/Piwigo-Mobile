//
//  AlbumEntity.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData
import AppIntents
import PwgKit
import PwgCacheKit

/// Lightweight, `Sendable` stand-in for an `Album` managed object so it can cross actor
/// boundaries safely (Core Data objects themselves are not `Sendable`).
@available(iOS 16.0, *)
struct AlbumEntity: AppEntity, Sendable {
    let pwgID: Int32
    let name: String

    // `Int32` doesn't conform to `EntityIdentifierConvertible`, only `Int` does.
    var id: Int { Int(pwgID) }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Album", table: "In-AppIntents"))
    static let defaultQuery = AlbumQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 16.0, *)
struct AlbumQuery: EntityStringQuery {

    @MainActor
    private func currentUser() -> User? {
        try? UserProvider().getUserAccount(inContext: DataController.shared.mainContext)
    }

    /// Only exposes albums the current user is allowed to upload to, matching the rules
    /// the share extension applies (see `ShareViewController+DataSource.swift`).
    @MainActor
    private func uploadableAlbums(matching predicate: NSPredicate?) -> [AlbumEntity] {
        guard let user = currentUser()
        else { return [] }

        var andPredicates = [
            NSPredicate(format: "user.server.path == %@", ServerVars.shared.serverPath),
            NSPredicate(format: "user.username == %@", ServerVars.shared.user),
            NSPredicate(format: "pwgID > 0")   // Exclude the root and smart albums.
        ]
        if let predicate { andPredicates.append(predicate) }

        let request = Album.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: andPredicates)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(Album.globalRank), ascending: true,
                                                    selector: #selector(NSString.localizedStandardCompare(_:)))]

        let albums = (try? DataController.shared.mainContext.fetch(request)) ?? []
        
        // User with admin rights?
        if user.hasAdminRights {
            return albums.map { AlbumEntity(pwgID: $0.pwgID, name: $0.name) }
        }
        
        // User with normal rights?
        if ServerVars.shared.userStatus != .normal { return [] }
        let uploadRights = user.uploadRights.components(separatedBy: ",").compactMap { Int32($0) }
        return albums
            .filter { uploadRights.contains($0.pwgID) }
            .map { AlbumEntity(pwgID: $0.pwgID, name: $0.name) }
    }

    @MainActor
    func entities(for identifiers: [Int]) async throws -> [AlbumEntity] {
        let pwgIDs = identifiers.map { Int32($0) }
        return uploadableAlbums(matching: NSPredicate(format: "pwgID IN %@", pwgIDs))
    }

    @MainActor
    func entities(matching string: String) async throws -> [AlbumEntity] {
        uploadableAlbums(matching: NSPredicate(format: "name CONTAINS[cd] %@", string))
    }

    @MainActor
    func suggestedEntities() async throws -> [AlbumEntity] {
        // Same "recent albums" list the share extension shows first.
        let recentCatIds: [Int32] = CacheVars.shared.recentCategories
            .components(separatedBy: ",").compactMap { Int32($0) }
            .filter { $0 != pwgSmartAlbum.root.rawValue }
        guard recentCatIds.isEmpty == false
        else { return uploadableAlbums(matching: nil) }
        return uploadableAlbums(matching: NSPredicate(format: "pwgID IN %@", recentCatIds))
    }
}
