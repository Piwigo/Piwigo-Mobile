//
//  AppUpdateChecker.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 18/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
// Looks up the latest version of Piwigo on the App Store (iTunes Lookup API)
// and tells whether the user should be invited to update the app.
/// - The request is sent at most once per day.
/// - The user is invited only once per App Store version:
///   after `markInvitationAsShown(for:)`, the next invitation will be
///   for the next version available on the App Store.

import Foundation
import PwgKit

enum AppUpdateChecker {

    // Logs update checks
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    private static let logger = PwgLogger(subsystem: "org.piwigo", category: String(describing: AppUpdateChecker.self))

    // MARK: - Public Types
    /// Version of the app available on the App Store
    struct AvailableUpdate: Sendable, Equatable {
        let version: String         // e.g. "4.5"
        let storeURL: URL           // Product page on the App Store
    }

    // MARK: - Constants
    /// App Store identifier of Piwigo
    /// See https://itunes.apple.com/us/app/piwigo/id472225196
    private static let appStoreId = "472225196"

    /// Minimum delay between two requests
    private static let minimumDelay: TimeInterval = 24.0 * 60.0 * 60.0     // i.e. one day

    /// Time out of the request
    private static let requestTimeout: TimeInterval = 15.0


    // MARK: - Check For Update
    /// Returns the update to propose to the user, or nil if there is none or if the user was already invited for it.
    /// - The iTunes Lookup API is queried only if the last request is more than a day old.
    /// - Within that delay, the version returned by the last request is reused.
    /// - Can be called from any thread, returns quickly when no request is needed.
    static func updateToPropose() async -> AvailableUpdate? {
        // Query the App Store if the last request is old enough
        if Date.timeIntervalSinceReferenceDate - AppVars.shared.dateOfLastUpdateCheck >= minimumDelay {
            // Remember the attempt even if it fails, to not hammer the server
            AppVars.shared.dateOfLastUpdateCheck = Date.timeIntervalSinceReferenceDate
            do {
                let lookup = try await fetchLatestRelease()
                AppVars.shared.latestStoreVersion = lookup.version
                AppVars.shared.latestStoreURL = lookup.storeURL.absoluteString
            }
            catch {
                logger.error("Could not look up the App Store version: \(error.localizedDescription)")
            }
        }

        // Compare the version known to be on the App Store with the one of the app
        let storeVersion = AppVars.shared.latestStoreVersion
        guard storeVersion.isEmpty == false,
              let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              isVersion(storeVersion, newerThan: currentVersion),
              isVersion(storeVersion, newerThan: AppVars.shared.lastInvitedStoreVersion),
              let storeURL = URL(string: AppVars.shared.latestStoreURL)
        else { return nil }

        return AvailableUpdate(version: storeVersion, storeURL: storeURL)
    }

    /// Call when the invitation has been presented so that
    /// the user is not asked again until a newer version is available.
    static func markInvitationAsShown(for update: AvailableUpdate) {
        AppVars.shared.lastInvitedStoreVersion = update.version
    }


    // MARK: - iTunes Lookup API
    /// Response of https://itunes.apple.com/lookup?id=472225196
    private struct LookupResponse: Decodable, Sendable {
        let results: [Result]

        struct Result: Decodable, Sendable {
            let version: String
            let trackViewUrl: String
            let minimumOsVersion: String?
        }
    }

    private enum LookupError: Error {
        case badResponse
        case noResult
        case invalidURL
        case osTooOld
    }

    private static func fetchLatestRelease() async throws -> AvailableUpdate {
        // Build the request
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        var queryItems = [URLQueryItem(name: "id", value: appStoreId)]
        /// The release of a new version may differ from one storefront to another
        if let region = Locale.current.regionCode, region.count == 2 {
            queryItems.append(URLQueryItem(name: "country", value: region.lowercased()))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw LookupError.invalidURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: requestTimeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Send the request
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else { throw LookupError.badResponse }

        // Decode the response
        let lookup = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard let result = lookup.results.first else { throw LookupError.noResult }
        guard let storeURL = URL(string: result.trackViewUrl) else { throw LookupError.invalidURL }

        // Do not invite users who cannot install the new version
        if let minimumOS = result.minimumOsVersion,
           isOperatingSystemAtLeast(minimumOS) == false {
            throw LookupError.osTooOld
        }

        return AvailableUpdate(version: result.version, storeURL: storeURL)
    }


    // MARK: - Version Comparisons
    /// Compares dotted version strings numerically, e.g. "4.10" > "4.9"
    private static func isVersion(_ version: String, newerThan reference: String) -> Bool {
        return version.compare(reference, options: .numeric) == .orderedDescending
    }

    private static func isOperatingSystemAtLeast(_ version: String) -> Bool {
        let numbers = version.split(separator: ".").map { Int($0) ?? 0 }
        let osVersion = OperatingSystemVersion(majorVersion: numbers.count > 0 ? numbers[0] : 0,
                                               minorVersion: numbers.count > 1 ? numbers[1] : 0,
                                               patchVersion: numbers.count > 2 ? numbers[2] : 0)
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(osVersion)
    }
}
