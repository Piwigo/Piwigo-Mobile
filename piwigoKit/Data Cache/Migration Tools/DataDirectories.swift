//
//  DataDirectories.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 18/02/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation

public class DataDirectories
{
    // MARK: - Singleton
    public static let shared = DataDirectories()
    
    
    // MARK: - App Group Container
    /// AppGroup/… container shared by the app and the extensions
    lazy var containerDirectory : URL = {
        // We use different App Groups:
        /// - Development: one chosen by the developer
        /// - Release: the official group.org.piwigo
#if DEBUG
        let AppGroup = "group.net.lelievre-berna.piwigo"
#else
        let AppGroup = "group.org.piwigo"
#endif
        
        // Get path of group container
        let fm = FileManager.default
        guard let containerDirectory = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup) else {
            fatalError("Unable to retrieve the Group Container directory.")
        }
        return containerDirectory
    }()
    
    // "Library/Application Support/Piwigo" in the AppGroup container.
    /// - The shared database and temporary files to upload are stored in the App Group
    ///   container so that they can be used and shared by the app and the extensions.
    lazy var appGroupDirectory: URL = {
        // Get path of group container
        let piwigoURL = containerDirectory.appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("Piwigo")
        
        // Create the Piwigo directory in the container if needed
        let fm = FileManager.default
        if fm.fileExists(atPath: piwigoURL.path) == false {
            do {
                try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                fatalError("Unable to create the \"Piwigo\" directory in the App Group container (\(error.localizedDescription).")
            }
        }
        
        debugPrint("••> appGroupDirectory: \(piwigoURL)")
        return piwigoURL
    }()
    
    // "Library/Application Support/Piwigo" in the AppGroup container.
    /// - The Uploads directory into which image/video files are temporarily stored.
    public lazy var appUploadsDirectory: URL = {
        // Get path of Uploads directory
        let uploadURL = appGroupDirectory.appendingPathComponent("Uploads")
        
        // Create the Piwigo/Uploads directory if needed
        let fm = FileManager.default
        if !fm.fileExists(atPath: uploadURL.path) {
            var errorCreatingDirectory: Error? = nil
            do {
                try fm.createDirectory(at: uploadURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create the \"Uploads\" directory in the App Group container (\(error.localizedDescription).")
            }
        }
        
        debugPrint("••> uploadsDirectory: \(uploadURL)")
        return uploadURL
    }()
    
    // "Library/Caches/Piwigo" in the AppGroup container.
    /// - Folder in which we store the images referenced in the Core Data store
    public lazy var cacheDirectory: URL = {
        let fm = FileManager.default
        do {
            // Get path of the Caches directory in the AppGroup container
            let cacheDirectory = containerDirectory.appendingPathComponent("Library")
                .appendingPathComponent("Caches")
            
            // Append Piwigo
            let pwgDirectory = cacheDirectory.appendingPathComponent("Piwigo")
            
            // Create the Piwigo directory if needed
            if fm.fileExists(atPath: pwgDirectory.path) == false {
                try fm.createDirectory(at: pwgDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            debugPrint("••> cacheDirectory: \(pwgDirectory)")
            return pwgDirectory
        } catch {
            fatalError("Unable to create the \"Caches/Piwgo\" directory (\(error.localizedDescription)")
        }
    }()
    
    
    // MARK: - App Sandbox
    // "Library/Application Support/Piwigo" inside the Data Container of the Sandbox.
    /// - This is where the incompatible Core Data stores are stored.
    /// - The contents of this directory are backed up by iTunes and iCloud.
    /// - This is the directory where the application used to store the Core Data store files
    ///   and files to upload before the creation of extensions.
    lazy var appSupportDirectory: URL = {
        let fm = FileManager.default
        guard let applicationSupportDirectory = fm.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask).last else {
            fatalError("Unable to retrieve the \"Library/Application Support\" directory.")
        }
        let piwigoURL = applicationSupportDirectory.appendingPathComponent("Piwigo")
        
        // Create the Piwigo directory in "Library/Application Support" if needed
        if fm.fileExists(atPath: piwigoURL.path) == false {
            do {
                try fm.createDirectory(at: piwigoURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create the \"Piwigo\" directory in \"Library/Application Support\" (\(error.localizedDescription).")
            }
        }
        
        debugPrint("••> appSupportDirectory: \(piwigoURL)")
        return piwigoURL
    }()
    
    // "Documents" inside the Data Container of the Sandbox.
    /// - This is the directory where the application used to store the Core Data store files long ago.
    lazy var appDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let appDocumentsDirectory = urls[urls.count-1]
        
        debugPrint("••> appDocumentsDirectory: \(appDocumentsDirectory)")
        return appDocumentsDirectory
    }()
    
    // "Library/Application Support/Piwigo" inside the Data Container of the Sandbox.
    /// - The Backup directory into which data stores are backuped.
    public lazy var appBackupDirectory: URL = {
        // Get path of Backup directory
        let backupURL = appSupportDirectory.appendingPathComponent("Backup")

        // Create the Piwigo/Backup directory if needed
        let fm = FileManager.default
        if fm.fileExists(atPath: backupURL.path) == false {
            do {
                try fm.createDirectory(at: backupURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create the \"Backup\" directory in \"Library/Application Support\" (\(error.localizedDescription).")
            }
        }

        debugPrint("••> backupDirectory: \(backupURL)")
        return backupURL
    }()
}
