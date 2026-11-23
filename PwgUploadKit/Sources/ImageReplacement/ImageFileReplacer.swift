//
//  ImageFileReplacer.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Replaces the file of an image already on the server, in the foreground, by uploading a new file
//  with pwg.images.uploadAsync and the identifier of the image.
//  The server keeps the identity of the image, its albums and its owner, but reads again the metadata
//  of the new file: the properties of the image are sent again so that they win over the ones of the file.
//

import Foundation
import UniformTypeIdentifiers
import PwgKit
import PwgAPIKit
import PwgCacheKit

public struct ImageFileReplacement: Sendable {
    public let imageID: Int64
    /// An album containing the image. The Community plugin needs it, Piwigo 13 and later accept it.
    public let albumID: Int32
    public let fileURL: URL
    /// Name of the file on the server: the new file keeps it
    public let fileName: String
    // Properties of the image which the metadata of the new file must not change
    public let title: String
    public let author: String
    public let comment: String
    /// "yyyy-MM-dd HH:mm:ss"
    public let dateCreated: String
    public let privacyLevel: String
    /// Identifiers of the tags separated by commas
    public let tagIDs: String

    public init(imageID: Int64, albumID: Int32, fileURL: URL, fileName: String,
                title: String, author: String, comment: String, dateCreated: String,
                privacyLevel: String, tagIDs: String) {
        self.imageID = imageID
        self.albumID = albumID
        self.fileURL = fileURL
        self.fileName = fileName
        self.title = title
        self.author = author
        self.comment = comment
        self.dateCreated = dateCreated
        self.privacyLevel = privacyLevel
        self.tagIDs = tagIDs
    }
}

public enum ImageFileReplacer
{
    /// Uploads the file chunk after chunk. Returns when the server accepted the last one.
    /// - Parameter progress: fraction of the chunks sent, called on an arbitrary thread
    /// - Throws: when a chunk is refused or cannot be sent. The last chunk may have been processed even if the reply
    ///   is unusable (other plugins print warnings and errors around the JSON): the caller checks the checksum of the image.
    public static func replace(with replacement: ImageFileReplacement,
                               progress: @escaping @Sendable (Float) -> Void) async throws(PwgKitError) {
        // Content of the file
        let fileData: Data
        do { fileData = try Data(contentsOf: replacement.fileURL, options: .alwaysMapped) }
        catch let error as CocoaError { throw .fileOperationFailed(innerError: error) }
        catch { throw .otherError(innerError: error) }
        guard fileData.isEmpty == false, replacement.fileName.isEmpty == false else { throw .missingUploadParameter }

        // Chunks
        let chunkSize = max(ServerVars.shared.customUploadChunkSize, 500) * 1000
        let chunks = Int((Double(fileData.count) / Double(chunkSize)).rounded(.up))
        let md5Sum = fileData.MD5checksum

        // Request
        guard let uploadURL = URL(string: ServerVars.shared.service + "/ws.php?format=json&method=\(pwgImagesUploadAsync)")
        else { throw .wrongServerURL }
        let username = ServerVars.shared.login
        let password = KeychainUtilities.password(forService: ServerVars.shared.serverPath, account: username)
        guard password.isEmpty == false else { throw .invalidCredentials }
        let boundary = MultipartFormData.boundary(from: md5Sum)
        let mimeType = UTType(filenameExtension: URL(fileURLWithPath: replacement.fileName).pathExtension)?
            .preferredMIMEType ?? "application/octet-stream"

        for chunk in 0..<chunks {
            let chunkData = fileData.subdata(in: chunk * chunkSize ..< min((chunk + 1) * chunkSize, fileData.count))
            var body = Data()

            // Credentials, unless API keys are used
            if (NetworkVars.shared.usesAPIkeys && username.isValidPublicKey() &&
                NetworkVars.shared.apiKeysProhibitedMethods.contains(pwgImagesUploadAsync) == false) == false {
                body.append(MultipartFormData.field(named: "username", value: username, using: boundary))
                body.append(MultipartFormData.field(named: "password", value: password, using: boundary))
            }
            if ServerVars.shared.pwgToken.isEmpty == false {
                body.append(MultipartFormData.field(named: "pwg_token", value: ServerVars.shared.pwgToken, using: boundary))
            }

            // Parameters of the method: image_id makes the server replace the file of the image
            body.append(MultipartFormData.field(named: "chunk", value: "\(chunk)", using: boundary))
            body.append(MultipartFormData.field(named: "chunks", value: "\(chunks)", using: boundary))
            body.append(MultipartFormData.field(named: "original_sum", value: md5Sum, using: boundary))
            body.append(MultipartFormData.field(named: "image_id", value: "\(replacement.imageID)", using: boundary))
            body.append(MultipartFormData.field(named: "category", value: "\(replacement.albumID)", using: boundary))
            body.append(MultipartFormData.field(named: "filename", value: replacement.fileName, using: boundary))
            body.append(MultipartFormData.field(named: "name", value: replacement.title.utf8mb3Encoded, using: boundary))
            body.append(MultipartFormData.field(named: "author", value: replacement.author.utf8mb3Encoded, using: boundary))
            body.append(MultipartFormData.field(named: "comment", value: replacement.comment.utf8mb3Encoded, using: boundary))
            body.append(MultipartFormData.field(named: "date_creation", value: replacement.dateCreated, using: boundary))
            body.append(MultipartFormData.field(named: "level", value: replacement.privacyLevel, using: boundary))
            body.append(MultipartFormData.field(named: "tag_ids", value: replacement.tagIDs, using: boundary))
            body.append(MultipartFormData.field(named: "chunk_sum", value: chunkData.MD5checksum, using: boundary))
            body.append(MultipartFormData.file(fieldName: "file", fileName: replacement.fileName, mimeType: mimeType,
                                               fileData: chunkData, using: boundary))
            body.append(MultipartFormData.closing(using: boundary))

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setAPIKeyHTTPHeader(for: pwgImagesUploadAsync)

            let (data, statusCode) = try await send(request, body: body)
            try check(reply: data, statusCode: statusCode, isLastChunk: chunk == chunks - 1)
            progress(Float(chunk + 1) / Float(chunks))
        }
    }


    // MARK: - Replies
    /// A chunk is accepted when the server answers "ok". The reply of the last chunk may be surrounded by the warnings
    /// and errors which a plugin prints (e.g. the Community plugin of a server using a recent PHP).
    private static func check(reply data: Data, statusCode: Int, isLastChunk: Bool) throws(PwgKitError) {
        guard let json = firstJSONObject(in: data) else {
            throw statusCode >= 200 && statusCode < 300 ? PwgKitError.invalidJSONobject : .invalidStatusCode(statusCode: statusCode)
        }
        do {
            let reply = try JSONDecoder().decode(ImagesUploadAsyncJSON.self, from: json)
            if reply.status != "ok" { throw PwgKitError.invalidResponse }
        }
        catch let error as DecodingError {
            // Error returned by the server
            if case .dataCorrupted(let context) = error, let pwgError = context.underlyingError as? PwgKitError {
                throw pwgError
            }
            throw .decodingFailed(innerError: error)
        }
        catch let error as PwgKitError { throw error }
        catch { throw .otherError(innerError: error) }
    }

    /// The first JSON object of a text, which may be preceded and followed by anything
    static func firstJSONObject(in data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard let start = bytes.firstIndex(of: UInt8(ascii: "{")) else { return nil }
        var depth = 0, isInString = false, isEscaped = false
        for index in start ..< bytes.count {
            let byte = bytes[index]
            if isInString {
                if isEscaped { isEscaped = false }
                else if byte == UInt8(ascii: "\\") { isEscaped = true }
                else if byte == UInt8(ascii: "\"") { isInString = false }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""): isInString = true
            case UInt8(ascii: "{"): depth += 1
            case UInt8(ascii: "}"):
                depth -= 1
                if depth == 0 { return Data(bytes[start...index]) }
            default: break
            }
        }
        return nil
    }


    // MARK: - Requests
    private static func send(_ request: URLRequest, body: Data) async throws(PwgKitError) -> (Data, Int) {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let task = dataSession.uploadTask(with: request, from: body) { data, response, error in
                    if let error = error as? URLError {
                        continuation.resume(throwing: PwgKitError.requestFailed(innerError: error))
                    }
                    else if let data, let httpResponse = response as? HTTPURLResponse {
                        continuation.resume(returning: (data, httpResponse.statusCode))
                    }
                    else {
                        continuation.resume(throwing: PwgKitError.invalidResponse)
                    }
                }
                task.resume()
            }
        }
        catch let error as PwgKitError { throw error }
        catch { throw .otherError(innerError: error) }
    }
}
