//
//  UploadPhotos.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 03/07/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData
import AppIntents
import UniformTypeIdentifiers
import PwgKit
import PwgCacheKit
import PwgUploadKit

@available(iOS 16.0, *)
struct UploadPhotos: AppIntent {
    
    // Logs shortcut activity
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = PwgLogger(subsystem: "org.piwigo", category: String(describing: UploadPhotos.self))
    
    static let title = LocalizedStringResource("uploadPhotos", table: "In-AppIntents",
                                               comment: "Upload Photos")
    
    static let description = IntentDescription(
        LocalizedStringResource("UploadPhotosDescription", table: "In-AppIntents",
                                comment: "Appends photos to the upload queue."),
        categoryName: LocalizedStringResource("severalImages"),
        searchKeywords: [LocalizedStringResource("tabBar_upload"),
                         LocalizedStringResource("severalImages"), "Piwigo"])
    
    /// Tell the system to bring the app to the foreground when the intent runs.
    static let openAppWhenRun: Bool = true
    
    // The app's deployment target is iOS 16, so this uses the `supportedTypeIdentifiers`
    // initializer available since iOS 16 rather than `supportedContentTypes`, which requires iOS 18.
    // `supportedTypeIdentifiers` must be a compile-time constant, hence the raw UTI strings
    // instead of `UTType.image.identifier` / `UTType.movie.identifier`.
    @Parameter(title: LocalizedStringResource("severalImages"),
               supportedTypeIdentifiers: ["public.image", "public.movie"])
    var photos: [IntentFile]

    @Parameter(title: LocalizedStringResource("categorySelection_title"))
    var album: AlbumEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Upload \(\.$photos) to \(\.$album)")
    }

    /**
     When the system runs the intent, it calls `perform()`.
     Intents run on an arbitrary queue. Intents that manipulate UI need to annotate `perform()` with `@MainActor`
     so that the UI operations run on the main actor.
     */
    @UploadManagerActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UploadPhotos.logger.notice("In-app intent starting...")
        
        // If a migration is planned, invite the user to perform the migration.
        let migrator = DataMigrator()
        if migrator.requiresMigration() {
            UploadPhotos.logger.notice("Core Data migration required")
            return .result(dialog: .responseFailure(error: .migrationRequired))
        }
        
        guard photos.isEmpty == false
        else {
            UploadPhotos.logger.notice("No photos to upload")
            return .result(dialog: .responseFailure(error: .noPhotos))
        }
        
        // Re-validate the album: it may have been configured long before the shortcut ran,
        // and the server or the user's upload rights may have changed since.
        guard let refreshedAlbum = try? await AlbumQuery().entities(for: [album.id]).first
        else {
            UploadPhotos.logger.notice("Invalid destination album")
            return .result(dialog: .responseFailure(error: .invalidAlbum))
        }
        
        let shareDate: String = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
            return dateFormatter.string(from: Date())
        }()
        
        // Copy each attachment into the shared Uploads folder, exactly like the share
        // extension does — but skip its JSON sidecar / deep-link round trip since this
        // intent already runs in-process and can build the upload requests directly.
        var uploadRequests: [UploadProperties] = []
        autoreleasepool {
            for (index, file) in photos.enumerated() {
                let fileType = file.type ?? .data
                let suffix = fileType.conforms(to: .movie) ? kMovieSuffix : kImageSuffix
                let identifier = kIntentPrefix + shareDate + suffix + String(index + 1)
                let fileURL = DataDirectories.appUploadsDirectory
                    .appendingPathComponent(identifier)
                
                // Remove stale file from a previous incomplete attempt.
                try? FileManager.default.removeItem(at: fileURL)
                
                // Store our own copy for a future upload
                debugPrint("file URL: \(String(describing: file.fileURL)), type: \(String(describing: file.type)), filename: \(file.filename)")
                do {
                    // Try to preserve data without loading it all in memory
                    if let srcURL = file.fileURL {
                        let scoped = srcURL.startAccessingSecurityScopedResource()
                        defer { if scoped { srcURL.stopAccessingSecurityScopedResource() } }
                        try FileManager.default.copyItem(at: srcURL, to: fileURL)
                    }
                    else {
                        // Try by loading data into memory
                        let data = file.data
                        guard !data.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
                        try data.write(to: fileURL, options: .atomic)
                    }
                }
                catch {
                    UploadPhotos.logger.notice("Could not save file: \(error.localizedDescription)")
                    continue    // Skip this attachment, keep processing the rest.
                }
                
                // Files produced by other Shortcuts actions may lack a filename extension,
                // yet the upload preparation relies on it to determine the file format
                // (see prepareImageFromFile() and the share extension which does the same).
                var fileName = file.filename
                if URL(fileURLWithPath: fileName).pathExtension.isEmpty {
                    let defaultExt = fileType.conforms(to: .movie) ? "mov" : "jpeg"
                    fileName += "." + (fileType.preferredFilenameExtension ?? defaultExt)
                    UploadPhotos.logger.notice("Filename extension added: \(fileName)")
                }
                
                // Create upload request
                uploadRequests.append(UploadProperties(localIdentifier: identifier,
                                                       fileName: fileName,
                                                       category: refreshedAlbum.pwgID))
            }
        }
        
        // Inform user if the import failed
        guard uploadRequests.isEmpty == false
        else {
            UploadPhotos.logger.notice("No upload requests to process")
            return .result(dialog: .responseFailure(error: .importFailed))
        }

        // Queue and process upload requests
        do {
            // Append upload requests to database
            let uploadIDs = try await UploadManager.shared.importUploads(from: uploadRequests)
            
            // Add upload requests to queue
            UploadVars.shared.isPaused = false
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 26.0, *) {
                // Launch new continued upload task if possible
                if UploadVars.shared.isContinuedProcessingTaskActive == false {
                    UploadManager.shared.runContinuedUploadTask()
                }
            } else {
                // Queue uploads to prepare
                await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)

                // Process next uploads if possible
                await UploadManagerActor.shared.processNextUpload()
            }
            #elseif targetEnvironment(macCatalyst)
            // Queue uploads to prepare
            await UploadManagerActor.shared.addUploadsToPrepare(withIDs: uploadIDs)

            // Process next uploads if possible
            await UploadManagerActor.shared.processNextUpload()
            #endif

            // Inform user that the shortcut was executed with success
            UploadPhotos.logger.notice("\(uploadIDs.count) upload requests added")
            return .result(dialog: .responseSuccess(photos: uploadIDs.count))
        }
        catch {
            // Inform user that the shortcut was executed with error
            UploadPhotos.logger.notice("Import of upload requests failed: \(error.localizedDescription)")
            return .result(dialog: .responseFailure(error: .importFailed))
        }
    }
}

@available(iOS 16.0, *)
fileprivate extension IntentDialog {
    static func responseSuccess(photos: Int) -> Self {
        if photos == 0 {
            .init(LocalizedStringResource("No photo added", table: "In-AppIntents"))
        } else {
            .init(LocalizedStringResource("\(photos) photos added", table: "In-AppIntents"))
        }
    }

    static func responseFailure(error: UploadPhotosError) -> Self {
        "\(error.localizedDescription)"
    }
}
