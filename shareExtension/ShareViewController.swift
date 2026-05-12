//
//  ShareViewController.swift
//  shareExtension
//
//  Created by Eddy Lelièvre-Berna on 09/05/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import UIKit
import UniformTypeIdentifiers
import piwigoKit
import uploadKit

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Retrieve shared items
        Task {
            let context = extensionContext
            await copySharedItems(fromContext: context)
        }
    }
    
    
    // MARK: - Copy Shared Items to Uploads folder
    private nonisolated func copySharedItems(fromContext context: NSExtensionContext?) async {
        // Retrieve input item
        guard let context,
              let extensionItem = context.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments
        else {
            context?.cancelRequest(withError: URLError(.cancelled))
            return
        }
        
        // Get date of share
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmssSSSS"
        let sharedDateTime = dateFormatter.string(from: Date())
        
        // Loop over all shared items
        /// Shared items are identified with identifiers of the type "pwgShared-yyyyMMdd-HHmmssSSSS-typ-####" where:
        /// - "pwgShared" is a header telling that the image/video comes from the share extension (see kSharedPrefix)
        /// - "yyyyMMdd-HHmmssSSSS" is the date at which the items were shared
        /// - "typ" is "-img-" or "-mov-" depending on the nature of the object (see kImageSuffix, kMovieSuffix)
        /// - "####" is the index of the object being shared
        var sharedItems: [(identifier: String, fileName: String)] = []
        for (index, provider) in attachments.enumerated() {
            // Movies first because objects may contain both movies and images
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                if let (identifier, fileName) = await self.getSharedMovie(atIndex: index + 1, from: provider, on: sharedDateTime) {
                    sharedItems.append((identifier, fileName))
                }
            }
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let (identifier, fileName) = await self.getSharedImage(atIndex: index + 1, from: provider, on: sharedDateTime) {
                    sharedItems.append((identifier, fileName))
                }
            }
        }
        
        context.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    private nonisolated func getSharedImage(atIndex index: Int, from provider: NSItemProvider, on sharedDateTime: String) async -> (String, String)? {
        return await withCheckedContinuation { continuation in
            // Asynchronously writes a copy of the provided, typed data to a temporary file, returning a progress object.
            if #available(iOS 16.0, *) {
                _ = provider.loadFileRepresentation(for: .image, openInPlace: false) { url, _, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            } else {
                // Fallback on older version
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            }
        }
    }
    
    private nonisolated func getSharedMovie(atIndex index: Int, from provider: NSItemProvider, on sharedDateTime: String) async -> (String, String)? {
        return await withCheckedContinuation { continuation in
            // Asynchronously writes a copy of the provided, typed data to a temporary file, returning a progress object.
            if #available(iOS 16.0, *) {
                _ = provider.loadFileRepresentation(for: .movie, openInPlace: false) { url, _, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy image to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kImageSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            } else {
                // Fallback on older version
                _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    var result: (String, String)? = nil
                    defer { continuation.resume(returning: result) }
                    
                    guard let url else {
                        print("Shared item load error: \(error?.localizedDescription ?? "unknown")")
                        return
                    }
                    
                    // Copy video to the shared container immediately
                    let fileName = url.lastPathComponent
                    let identifier = kSharedPrefix + sharedDateTime + kMovieSuffix + String(index)
                    let fileURL = DataDirectories.appUploadsDirectory
                        .appendingPathComponent(identifier)
                    
                    // Remove stale file from a previous incomplete attempt
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // Store our own copy for a future upload
                    do {
                        try FileManager.default.copyItem(at: url, to: fileURL)
                        result = (identifier, fileName)
                    } catch {
                        print("Failed to copy shared item: \(error)")
                    }
                }
            }
        }
    }
}
