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
    let serverPath: String
    let name: String

    // The identifier persisted in the shortcut includes the server path so that an album
    // configured for one server can never resolve to an unrelated album which happens to
    // have the same category ID on another server the user logs into later.
    // ("|" cannot appear in a server path and the category ID is numeric.)
    var id: String { serverPath + "|" + String(pwgID) }

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
        let serverPath = ServerVars.shared.serverPath
        if user.hasAdminRights {
            return albums.map { AlbumEntity(pwgID: $0.pwgID, serverPath: serverPath, name: $0.name) }
        }

        // User with normal rights?
        if ServerVars.shared.userStatus != .normal { return [] }
        let uploadRights = user.uploadRights.components(separatedBy: ",").compactMap { Int32($0) }
        return albums
            .filter { uploadRights.contains($0.pwgID) }
            .map { AlbumEntity(pwgID: $0.pwgID, serverPath: serverPath, name: $0.name) }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        // Ignore identifiers configured for another server (see AlbumEntity.id).
        let serverPath = ServerVars.shared.serverPath
        let pwgIDs: [Int32] = identifiers.compactMap { identifier in
            guard let sepIndex = identifier.lastIndex(of: "|"),
                  identifier[..<sepIndex] == serverPath
            else { return nil }
            return Int32(identifier[identifier.index(after: sepIndex)...])
        }
        guard pwgIDs.isEmpty == false else { return [] }
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
