//
//  MultipartFormData.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 23/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Encodes the parts of a multipart/form-data body, see https://tools.ietf.org/html/rfc7578
//  Shared by the uploads of the queue and the replacement of the file of an image.
//

import Foundation

enum MultipartFormData
{
    /// The boundary is derived from an identifier (the checksum of the file) rather than from a UUID,
    /// to be able to test uploads with a simulator.
    static func boundary(from identifier: String) -> String {
        var suffix = ""
        if #available(iOS 16.0, *) {
            suffix = identifier.replacing("/", with: "").map { $0.lowercased() }.joined()
        } else {
            // Fallback on earlier versions
            suffix = identifier.replacingOccurrences(of: "/", with: "").map { $0.lowercased() }.joined()
        }
        return String(repeating: "-", count: max(68 - suffix.count, 0)) + suffix
    }

    static func field(named name: String, value: String, using boundary: String) -> Data {
        return Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)
    }

    static func file(fieldName: String, fileName: String, mimeType: String,
                     fileData: Data, using boundary: String) -> Data {
        var data = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)\r\n\r\n".utf8)
        data.append(fileData)
        data.append(Data("\r\n".utf8))
        return data
    }

    static func closing(using boundary: String) -> Data {
        return Data("--\(boundary)--".utf8)
    }
}
