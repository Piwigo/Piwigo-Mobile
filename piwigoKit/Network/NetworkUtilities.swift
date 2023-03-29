//
//  NetworkUtilities.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

public class NetworkUtilities: NSObject {
    
    // MARK: - Piwigo Server Methods
    static let JSONsession = PwgSession.shared

    public static
    func getMethods(completion: @escaping () -> Void,
                    failure: @escaping (NSError) -> Void) {
        print("••> Get methods…")
        // Launch request
        JSONsession.postRequest(withMethod: kReflectionGetMethodList, paramDict: [:],
                                jsonObjectClientExpectsToReceive: ReflectionGetMethodListJSON.self,
                                countOfBytesClientExpectsToReceive: 32500) { jsonData in
            // Decode the JSON object and set variables.
            do {
                // Decode the JSON into codable type ReflectionGetMethodListJSON.
                let decoder = JSONDecoder()
                let methodsJSON = try decoder.decode(ReflectionGetMethodListJSON.self, from: jsonData)

                // Piwigo error?
                if methodsJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: methodsJSON.errorCode,
                                                                    errorMessage: methodsJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Check if the Community extension is installed and active (> 2.9a)
                NetworkVars.usesCommunityPluginV29 = methodsJSON.data.contains("community.session.getStatus")
                
                // Check if the pwg.images.uploadAsync method is available
                NetworkVars.usesUploadAsync = methodsJSON.data.contains("pwg.images.uploadAsync")

                // Check if the pwg.categories.calculateOrphans method is available
                NetworkVars.usesCalcOrphans = methodsJSON.data.contains("pwg.categories.calculateOrphans")

                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    public static
    func sessionLogin(withUsername username:String, password:String,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        print("••> Session login…")
        // Prepare parameters for retrieving image/video infos
        let paramsDict: [String : Any] = ["username" : username,
                                          "password" : password]
        // Launch request
        JSONsession.postRequest(withMethod: pwgSessionLogin, paramDict: paramsDict,
                                jsonObjectClientExpectsToReceive: SessionLoginJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the login was successful
            do {
                // Decode the JSON into codable type SessionLoginJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLoginJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                 errorMessage: loginJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Login successful
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    public static
    func communityGetStatus(completion: @escaping () -> Void,
                            failure: @escaping (NSError) -> Void) {
        print("••> Get community status…")
        // Launch request
        JSONsession.postRequest(withMethod: kCommunitySessionGetStatus, paramDict: [:],
                                jsonObjectClientExpectsToReceive: CommunitySessionGetStatusJSON.self,
                                countOfBytesClientExpectsToReceive: 2100) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type CommunitySessionGetStatusJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(CommunitySessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: statusJSON.errorCode,
                                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // Update user's status
                guard statusJSON.realUser.isEmpty == false,
                      let userStatus = pwgUserStatus(rawValue: statusJSON.realUser) else {
                    failure(UserError.unknownUserStatus as NSError)
                    return
                }
                NetworkVars.userStatus = userStatus
                completion()
            }
            catch {
                // Data cannot be digested
                NetworkVars.userStatus = pwgUserStatus.guest
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    public static
    func sessionGetStatus(completion: @escaping () -> Void,
                          failure: @escaping (NSError) -> Void) {
        print("••> Get session status…")
        // Launch request
        JSONsession.postRequest(withMethod: pwgSessionGetStatus, paramDict: [:],
                                jsonObjectClientExpectsToReceive: SessionGetStatusJSON.self,
                                countOfBytesClientExpectsToReceive: 7400) { jsonData in
            // Decode the JSON object and retrieve the status
            do {
                // Decode the JSON into codable type SessionGetStatusJSON.
                let decoder = JSONDecoder()
                let statusJSON = try decoder.decode(SessionGetStatusJSON.self, from: jsonData)

                // Piwigo error?
                if statusJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: statusJSON.errorCode,
                                                                    errorMessage: statusJSON.errorMessage)
                    failure(error as NSError)
                    return
                }
                
                // No status returned?
                guard let data = statusJSON.data else {
                    failure(JsonError.authenticationFailed as NSError)
                    return
                }

                // Update Piwigo token
                if let pwgToken = data.pwgToken {
                    NetworkVars.pwgToken = pwgToken
                }
                
                // Default language
                NetworkVars.language = data.language ?? ""
                
                // Piwigo server version should be of format 1.2.3
                var versionStr = data.version ?? ""
                let components = versionStr.components(separatedBy: ".")
                switch components.count {
                    case 1:     // Version of type 1
                    versionStr.append(".0.0")
                    case 2:     // Version of type 1.2
                    versionStr.append(".0")
                    default:
                        break
                }
                NetworkVars.pwgVersion = versionStr

                // Community users cannot upload with uploadAsync with Piwigo 11.x
                if NetworkVars.usesCommunityPluginV29,
                   NetworkVars.userStatus == pwgUserStatus.normal,
                   "11.0.0".compare(versionStr, options: .numeric) != .orderedDescending,
                   "12.0.0".compare(versionStr, options: .numeric) != .orderedAscending {
                    NetworkVars.usesUploadAsync = false
                }

                // Retrieve charset used by the Piwigo server
                let charset = (data.charset ?? "UTF-8").uppercased()
                switch charset {
                case "UNICODE":
                    NetworkVars.stringEncoding = String.Encoding.unicode.rawValue
                case "UNICODEFFFE":
                    NetworkVars.stringEncoding = String.Encoding.utf16BigEndian.rawValue
                case "UTF-8":
                    NetworkVars.stringEncoding = String.Encoding.utf8.rawValue
                case "UTF-16":
                    NetworkVars.stringEncoding = String.Encoding.utf16.rawValue
                case "UTF-32":
                    NetworkVars.stringEncoding = String.Encoding.utf32.rawValue
                case "ISO-2022-JP":
                    NetworkVars.stringEncoding = String.Encoding.iso2022JP.rawValue
                case "ISO-8859-1":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1252.rawValue
                case "ISO-8859-3":
                    NetworkVars.stringEncoding = String.Encoding.isoLatin1.rawValue
                case "CP870":
                    NetworkVars.stringEncoding = String.Encoding.isoLatin2.rawValue
                case "MACINTOSH":
                    NetworkVars.stringEncoding = String.Encoding.macOSRoman.rawValue
                case "SHIFT-JIS":
                    NetworkVars.stringEncoding = String.Encoding.shiftJIS.rawValue
                case "WINDOWS-1250":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1250.rawValue
                case "WINDOWS-1251":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1251.rawValue
                case "WINDOWS-1252":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1252.rawValue
                case "WINDOWS-1253":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1253.rawValue
                case "WINDOWS-1254":
                    NetworkVars.stringEncoding = String.Encoding.windowsCP1254.rawValue
                case "X-EUC":
                    NetworkVars.stringEncoding = String.Encoding.japaneseEUC.rawValue
                case "US-ASCII":
                    NetworkVars.stringEncoding = String.Encoding.ascii.rawValue
                default:
                    NetworkVars.stringEncoding = String.Encoding.utf8.rawValue
                }
                print("    version: \(NetworkVars.pwgVersion), usesUploadAsync: \(NetworkVars.usesUploadAsync ? "\"true\"" : "\"false\""), charset: \(charset)")

                // Upload chunk size is null if not provided by server
                if let uploadChunkSize = data.uploadChunkSize, uploadChunkSize != 0 {
                    UploadVars.uploadChunkSize = uploadChunkSize
                } else {
                    UploadVars.uploadChunkSize = 500    // i.e. 500 ko
                }

                // Images and videos can be uploaded if their file types are found.
                // The iPhone creates mov files that will be uploaded in mp4 format.
                UploadVars.serverFileTypes = data.uploadFileTypes ?? "jpg,jpeg,png,gif"
                
                // User rights are determined by Community extension (if installed)
                if let status = data.userStatus, status.isEmpty == false,
                   let userStatus = pwgUserStatus(rawValue: status) {
                    if NetworkVars.usesCommunityPluginV29 == false {
                        NetworkVars.userStatus = userStatus
                    }
                } else {
                    failure(UserError.unknownUserStatus as NSError)
                    return
                }

                // Retrieve the list of available sizes
                NetworkVars.hasSquareSizeImages  = data.imageSizes?.contains("square") ?? false
                NetworkVars.hasThumbSizeImages   = data.imageSizes?.contains("thumb") ?? false
                NetworkVars.hasXXSmallSizeImages = data.imageSizes?.contains("2small") ?? false
                NetworkVars.hasXSmallSizeImages  = data.imageSizes?.contains("xsmall") ?? false
                NetworkVars.hasSmallSizeImages   = data.imageSizes?.contains("small") ?? false
                NetworkVars.hasMediumSizeImages  = data.imageSizes?.contains("medium") ?? false
                NetworkVars.hasLargeSizeImages   = data.imageSizes?.contains("large") ?? false
                NetworkVars.hasXLargeSizeImages  = data.imageSizes?.contains("xlarge") ?? false
                NetworkVars.hasXXLargeSizeImages = data.imageSizes?.contains("xxlarge") ?? false
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }

    public static
    func sessionLogout(completion: @escaping () -> Void,
                       failure: @escaping (NSError) -> Void) {
        print("••> Session logout…")
        // Launch request
        JSONsession.postRequest(withMethod: pwgSessionLogout, paramDict: [:],
                                jsonObjectClientExpectsToReceive: SessionLogoutJSON.self,
                                countOfBytesClientExpectsToReceive: 620) { jsonData in
            // Decode the JSON object and check if the logout was successful
            do {
                // Decode the JSON into codable type SessionLogoutJSON.
                let decoder = JSONDecoder()
                let loginJSON = try decoder.decode(SessionLogoutJSON.self, from: jsonData)

                // Piwigo error?
                if loginJSON.errorCode != 0 {
                    let error = PwgSession.shared.localizedError(for: loginJSON.errorCode,
                                                                    errorMessage: loginJSON.errorMessage)
                    failure(error as NSError)
                    return
                }

                // Logout successful
                completion()
            }
            catch {
                // Data cannot be digested
                let error = error as NSError
                failure(error)
            }
        } failure: { error in
            /// - Network communication errors
            /// - Returned JSON data is empty
            /// - Cannot decode data returned by Piwigo server
            failure(error)
        }
    }
    
    
    // MARK: - Sessionn Management
    public static
    func requestServerMethods(completion: @escaping () -> Void,
                              didRejectCertificate: @escaping (NSError) -> Void,
                              didFailHTTPauthentication: @escaping (NSError) -> Void,
                              didFailSecureConnection: @escaping (NSError) -> Void,
                              failure: @escaping (NSError) -> Void) {
        // Collect list of methods supplied by Piwigo server
        // => Determine if Community extension 2.9a or later is installed and active
        getMethods {
            // Known methods, pursue logging in…
            completion()
        } failure: { error in
            // If Piwigo uses a non-trusted certificate, ask permission
            if NetworkVars.didRejectCertificate {
                // The SSL certificate is not trusted
                didRejectCertificate(error)
                return
            }

            // HTTP Basic authentication required?
            if (error as NSError).code == 401 || (error as NSError).code == 403 || NetworkVars.didFailHTTPauthentication {
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so we request HTTP credentials
                didFailHTTPauthentication(error)
                return
            }

            switch (error as NSError).code {
            case NSURLErrorUserAuthenticationRequired:
                // Without prior knowledge, the app already tried Piwigo credentials
                // but unsuccessfully, so must now request HTTP credentials
                didFailHTTPauthentication(error)
                return
            case NSURLErrorUserCancelledAuthentication:
                failure(error)
                return
            case NSURLErrorBadServerResponse, NSURLErrorBadURL, NSURLErrorCallIsActive, NSURLErrorCannotDecodeContentData, NSURLErrorCannotDecodeRawData, NSURLErrorCannotFindHost, NSURLErrorCannotParseResponse, NSURLErrorClientCertificateRequired, NSURLErrorDataLengthExceedsMaximum, NSURLErrorDataNotAllowed, NSURLErrorDNSLookupFailed, NSURLErrorHTTPTooManyRedirects, NSURLErrorInternationalRoamingOff, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet, NSURLErrorRedirectToNonExistentLocation, NSURLErrorRequestBodyStreamExhausted, NSURLErrorTimedOut, NSURLErrorUnknown, NSURLErrorUnsupportedURL, NSURLErrorZeroByteResource:
                failure(error)
                return
            case NSURLErrorCannotConnectToHost,    // Happens when the server does not reply to the request (HTTP or HTTPS)
                NSURLErrorSecureConnectionFailed:
                // HTTPS request failed ?
                if NetworkVars.serverProtocol == "https://" {
                    // Suggest HTTP connection if HTTPS attempt failed
                    didFailSecureConnection(error)
                    return
                }
                return
            case NSURLErrorClientCertificateRejected, NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid, NSURLErrorServerCertificateUntrusted:
                // The SSL certificate is not trusted
                didRejectCertificate(error)
                return
            default:
                break
            }

            // Display error message
            failure(error)
        }
    }
    
    // Re-login if session was closed
    public static
    func checkSession(ofUser user: User?,
                      completion: @escaping () -> Void,
                      failure: @escaping (NSError) -> Void) {
        // Determine if the session is active and for how long before fetching
        let pwgToken = NetworkVars.pwgToken
        NetworkUtilities.sessionGetStatus { [self] in
            print("••> token: \(pwgToken) vs \(NetworkVars.pwgToken)")
            if pwgToken.isEmpty || NetworkVars.pwgToken != pwgToken {
                let dateOfLogin = Date()
                // Collect list of methods supplied by Piwigo server
                // => Determine if Community extension 2.9a or later is installed and active
                requestServerMethods {
                    // Known methods, perform re-login
                    // Don't use userStatus as it may not be known after Core Data migration
                    if NetworkVars.username.isEmpty || NetworkVars.username.lowercased() == "guest" {
                        print("••> Checking guest session…")
                        // Update date of accesss to the server by guest
                        user?.lastUsed = dateOfLogin
                        user?.server?.lastUsed = dateOfLogin
                        user?.status = NetworkVars.userStatus.rawValue
                        
                        // Session now opened
                        getPiwigoConfig {
                            completion()
                        } failure: { error in
                            failure(error)
                        }
                    } else {
                        // Perform login
                        print("••> Checking user session…")
                        let username = NetworkVars.username
                        let password = KeychainUtilities.password(forService: NetworkVars.serverPath, account: username)
                        NetworkUtilities.sessionLogin(withUsername: username, password: password) {
                            // Update date of accesss to the server by user
                            user?.lastUsed = dateOfLogin
                            user?.server?.lastUsed = dateOfLogin
                            user?.status = NetworkVars.userStatus.rawValue
                            
                            // Session now opened
                            getPiwigoConfig {
                                completion()
                            } failure: { error in
                                failure(error)
                            }
                        } failure: { error in
                            failure(error)
                        }
                    }
                } didRejectCertificate: { error in
                    failure(error)
                } didFailHTTPauthentication: { error in
                    failure(error)
                } didFailSecureConnection: { error in
                    failure(error)
                } failure: { error in
                    failure(error)
                }
            } else {
                completion()
            }
        } failure: { error in
            failure(error)
        }
    }
    
    static func getPiwigoConfig(completion: @escaping () -> Void,
                                failure: @escaping (NSError) -> Void) {
        // Check Piwigo version, get token, available sizes, etc.
        if NetworkVars.usesCommunityPluginV29 {
            NetworkUtilities.communityGetStatus {
                NetworkUtilities.sessionGetStatus {
                    completion()
                } failure: { error in
                    failure(error)
                }
            } failure: { error in
                failure(error)
            }
        } else {
            NetworkUtilities.sessionGetStatus {
                completion()
            } failure: { error in
                failure(error)
            }
        }
    }


    // MARK: - UTF-8 encoding on 3 and 4 bytes
    public static
    func utf8mb4String(from string: String?) -> String {
        // Return empty string if nothing provided
        guard let strToConvert = string, strToConvert.isEmpty == false else {
            return ""
        }
        
        // Convert string to UTF-8 encoding
        let serverEncoding = String.Encoding(rawValue: NetworkVars.stringEncoding )
        if let strData = strToConvert.data(using: serverEncoding, allowLossyConversion: true) {
            return String(data: strData, encoding: .utf8) ?? strToConvert
        }
        return ""
    }

    // Piwigo supports the 3-byte UTF-8, not the standard UTF-8 (4 bytes)
    // See https://github.com/Piwigo/Piwigo-Mobile/issues/429, https://github.com/Piwigo/Piwigo/issues/750
    public static
    func utf8mb3String(from string: String?) -> String {
        // Return empty string is nothing provided
        guard let strToFilter = string, strToFilter.isEmpty == false else {
            return ""
        }

        // Replace characters encoded on 4 bytes
        var utf8mb3String = ""
        for char in strToFilter {
            if char.utf8.count > 3 {
                // 4-byte char => Not handled by Piwigo Server
                utf8mb3String.append("\u{FFFD}")  // Use the Unicode replacement character
            } else {
                // Up to 3-byte char
                utf8mb3String.append(char)
            }
        }
        return utf8mb3String
    }

    
    // MARK: - Clean URLs of Images
    public static
    func encodedImageURL(_ originalURL:String?) -> NSURL? {
        // Return nil if originalURL is nil and a placeholder will be used
        guard let okURL = originalURL else { return nil }
        
        // TEMPORARY PATCH for case where $conf['original_url_protection'] = 'images';
        /// See https://github.com/Piwigo/Piwigo-Mobile/issues/503
        let patchedURL = okURL.replacingOccurrences(of: "&amp;part=", with: "&part=")
        var serverURL: NSURL? = NSURL(string: patchedURL)
        
        // Servers may return incorrect URLs
        // See https://tools.ietf.org/html/rfc3986#section-2
        if serverURL == nil {
            // URL not RFC compliant!
            var leftURL = patchedURL

            // Remove protocol header
            if patchedURL.hasPrefix("http://") { leftURL.removeFirst(7) }
            if patchedURL.hasPrefix("https://") { leftURL.removeFirst(8) }
            
            // Retrieve authority
            guard let endAuthority = leftURL.firstIndex(of: "/") else {
                // No path, incomplete URL —> return image.jpg but should never happen
                return nil
            }
            let authority = String(leftURL.prefix(upTo: endAuthority))
            leftURL.removeFirst(authority.count)

            // The Piwigo server may not be in the root e.g. example.com/piwigo/…
            // So we remove the path to avoid a duplicate if necessary
            if let loginURL = URL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"),
               loginURL.path.count > 0, leftURL.hasPrefix(loginURL.path) {
                leftURL.removeFirst(loginURL.path.count)
            }

            // Retrieve path
            if let endQuery = leftURL.firstIndex(of: "?") {
                // URL contains a query
                let query = (String(leftURL.prefix(upTo: endQuery)) + "?").replacingOccurrences(of: "??", with: "?")
                guard let newQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return nil
                }
                leftURL.removeFirst(query.count)
                guard let newPath = leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                    // Could not apply percent encoding —> return image.jpg but should never happen
                    return nil
                }
                serverURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(newQuery)\(newPath)")
            } else {
                // No query -> remaining string is a path
                let newPath = String(leftURL.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
                serverURL = NSURL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(newPath)")
            }
            
            // Last check
            if serverURL == nil {
                // Could not apply percent encoding —> return nil
                return nil
            }
        }
        
        // Servers may return image URLs different from those used to login (e.g. wrong server settings)
        // We only keep the path+query because we only accept to download images from the same server.
        guard var cleanPath = serverURL?.path else {
            return nil
        }
        if let paramStr = serverURL?.parameterString {
            cleanPath.append(paramStr)
        }
        if let query = serverURL?.query {
            cleanPath.append("?" + query)
        }
        if let fragment = serverURL?.fragment {
            cleanPath.append("#" + fragment)
        }

        // The Piwigo server may not be in the root e.g. example.com/piwigo/…
        // So we remove the path to avoid a duplicate if necessary
        if let loginURL = URL(string: "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)"),
           loginURL.path.count > 0, cleanPath.hasPrefix(loginURL.path) {
            cleanPath.removeFirst(loginURL.path.count)
        }
        
        // Remove the .php?, i? prefixes if any
        var prefix = ""
        if let pos = cleanPath.range(of: "?") {
            // The path contains .php? or i?
            prefix = String(cleanPath.prefix(upTo: pos.upperBound))
            cleanPath.removeFirst(prefix.count)
        }

        // Path may not be encoded
        if let decodedPath = cleanPath.removingPercentEncoding, cleanPath == decodedPath,
           let test = cleanPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            cleanPath = test
        }

        // Compile final URL using the one provided at login
        let encodedImageURL = "\(NetworkVars.serverProtocol)\(NetworkVars.serverPath)\(prefix)\(cleanPath)"
        #if DEBUG
        if encodedImageURL != originalURL {
            print("=> originalURL:\(String(describing: originalURL))")
            print("    encodedURL:\(encodedImageURL)")
            print("    path=\(String(describing: serverURL?.path)), parameterString=\(String(describing: serverURL?.parameterString)), query:\(String(describing: serverURL?.query)), fragment:\(String(describing: serverURL?.fragment))")
        }
        #endif
        return NSURL(string: encodedImageURL)
    }
}


// MARK: - RFC 3986 allowed characters
extension CharacterSet {
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-2.2
    /// Section 2.2 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// https://datatracker.ietf.org/doc/html/rfc3986/#section-3.4
    /// Section 3.4 states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    ///
    public static let pwgURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}
