//
//  Data+AppTools.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/02/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import var CommonCrypto.CC_MD5_DIGEST_LENGTH
import func CommonCrypto.CC_MD5
import typealias CommonCrypto.CC_LONG

#if canImport(CryptoKit)
import CryptoKit        // Requires iOS 13
#endif

extension Data {
    // Return the MD5 checksum of data
    public func MD5checksum() -> String {
        var md5Checksum = ""

        // Determine MD5 checksum of video file to upload
        if #available(iOS 13.0, *) {
            #if canImport(CryptoKit)        // Requires iOS 13
            md5Checksum = self.MD5(data: self)
            #endif
        } else {
            // Fallback on earlier versions
            md5Checksum = self.oldMD5(data: self)
        }
        return md5Checksum
    }

    #if canImport(CryptoKit)        // Requires iOS 13
    @available(iOS 13.0, *)
    private func MD5(data: Data?) -> String {
        let digest = Insecure.MD5.hash(data: data ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    #endif

    private func oldMD5(data: Data?) -> String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = data ?? Data()
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
                messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress,
                    let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - MIME type and file extension sniffing
extension Data {
    // Return contentType of image data
    func contentType() -> String? {
        var bytes: [UInt8] = Array(repeating: UInt8(0), count: 12)
        (self as NSData).getBytes(&bytes, length: 12)

        var jpg = jpgSignature()
        if memcmp(bytes, &jpg, jpg.count) == 0 { return "image/jpeg" }
        
        var heic = heicSignature()
        if memcmp(bytes, &heic, heic.count) == 0 { return "image/heic" }
        
        var png = pngSignature()
        if memcmp(bytes, &png, png.count) == 0 { return "image/png" }
        
        var gif87a = gif87aSignature()
        var gif89a = gif89aSignature()
        if memcmp(bytes, &gif87a, gif87a.count) == 0 ||
            memcmp(bytes, &gif89a, gif89a.count) == 0 { return "image/gif" }
        
        var bmp = bmpSignature()
        if memcmp(bytes, &bmp, bmp.count) == 0 { return "image/x-ms-bmp" }
        
        var psd = psdSignature()
        if memcmp(bytes, &psd, psd.count) == 0 { return "image/vnd.adobe.photoshop" }
        
        var iff = iffSignature()
        if memcmp(bytes, &iff, iff.count) == 0 { return "image/iff" }
        
        var webp = webpSignature()
        if memcmp(bytes, &webp, webp.count) == 0 { return "image/webp" }
        
        var win_ico = win_icoSignature()
        var win_cur = win_curSignature()
        if memcmp(bytes, &win_ico, win_ico.count) == 0 ||
            memcmp(bytes, &win_cur, win_cur.count) == 0 { return "image/x-icon" }
        
        var tif_ii = tif_iiSignature()
        var tif_mm = tif_mmSignature()
        if memcmp(bytes, &tif_ii, tif_ii.count) == 0 ||
            memcmp(bytes, &tif_mm, tif_mm.count) == 0 { return "image/tiff" }
        
        var jp2 = jp2Signature()
        if memcmp(bytes, &jp2, jp2.count) == 0 { return "image/jp2" }
        
        return nil
    }

    // Return file extension corresponding to image data
    func fileExtension() -> String? {
        var bytes: [UInt8] = Array(repeating: UInt8(0), count: 12)
        (self as NSData).getBytes(&bytes, length: 12)

        var jpg = jpgSignature()
        if memcmp(bytes, &jpg, jpg.count) == 0 { return "jpg" }
        
        var heic = heicSignature()
        if memcmp(bytes, &heic, heic.count) == 0 { return "heic" }

        var png = pngSignature()
        if memcmp(bytes, &png, png.count) == 0 { return "png" }
        
        var gif87a = gif87aSignature()
        var gif89a = gif89aSignature()
        if memcmp(bytes, &gif87a, gif87a.count) == 0 ||
            memcmp(bytes, &gif89a, gif89a.count) == 0 { return "gif" }
        
        var bmp = bmpSignature()
        if memcmp(bytes, &bmp, bmp.count) == 0 { return "bmp" }

        var psd = psdSignature()
        if memcmp(bytes, &psd, psd.count) == 0 { return "psd" }
        
        var iff = iffSignature()
        if memcmp(bytes, &iff, iff.count) == 0 { return "iff" }
        
        var webp = webpSignature()
        if memcmp(bytes, &webp, webp.count) == 0 { return "webp" }

        var win_ico = win_icoSignature()
        if memcmp(bytes, &win_ico, win_ico.count) == 0 { return "ico" }

        var win_cur = win_curSignature()
        if memcmp(bytes, &win_cur, win_cur.count) == 0 { return "cur" }
        
        var tif_ii = tif_iiSignature()
        var tif_mm = tif_mmSignature()
        if memcmp(bytes, &tif_ii, tif_ii.count) == 0 ||
            memcmp(bytes, &tif_mm, tif_mm.count) == 0 { return "tif" }
        
        var jp2 = jp2Signature()
        if memcmp(bytes, &jp2, jp2.count) == 0 { return "jp2" }
        
        return nil
    }

    // MARK: - Image Formats
    // See https://en.wikipedia.org/wiki/List_of_file_signatures
    // https://mimesniff.spec.whatwg.org/#sniffing-in-an-image-context

    // https://en.wikipedia.org/wiki/BMP_file_format
    private func bmpSignature() -> [UInt8] {
        return "BM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/GIF
    private func gif87aSignature() -> [UInt8] {
        return "GIF87a".map { $0.asciiValue! }
    }
    private func gif89aSignature() -> [UInt8] {
        return "GIF89a".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/High_Efficiency_Image_File_Format
    private func heicSignature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x18] + "ftypheic".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ILBM
    private func iffSignature() -> [UInt8] {
        return "FORM".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/JPEG
    private func jpgSignature() -> [UInt8] {
        return [0xff, 0xd8, 0xff]
    }
    
    // https://en.wikipedia.org/wiki/JPEG_2000
    private func jp2Signature() -> [UInt8] {
        return [0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Portable_Network_Graphics
    private func pngSignature() -> [UInt8] {
        return [0x89] + "PNG".map { $0.asciiValue! } + [0x0d, 0x0a, 0x1a, 0x0a]
    }
    
    // https://en.wikipedia.org/wiki/Adobe_Photoshop#File_format
    private func psdSignature() -> [UInt8] {
        return "8BPS".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/TIFF
    private func tif_iiSignature() -> [UInt8] {
        return "II".map { $0.asciiValue! } + [0x2a, 0x00]
    }
    private func tif_mmSignature() -> [UInt8] {
        return "MM".map { $0.asciiValue! } + [0x00, 0x2a]
    }
    
    // https://en.wikipedia.org/wiki/WebP
    private func webpSignature() -> [UInt8] {
        return "RIFF".map { $0.asciiValue! }
    }
    
    // https://en.wikipedia.org/wiki/ICO_(file_format)
    private func win_icoSignature() -> [UInt8] {
        return [0x00, 0x00, 0x01, 0x00]
    }
    private func win_curSignature() -> [UInt8] {
        return [0x00, 0x00, 0x02, 0x00]
    }
}
