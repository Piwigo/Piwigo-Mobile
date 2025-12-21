//
//  ImageMetadata.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import ImageIO
import UIKit

// MARK: Private Metadata Properties
// Exif private metadata properties
/// See https://www.exiftool.org/TagNames/EXIF.html
fileprivate let exifPrivateProperties: [String] = {
    let properties = [kCGImagePropertyExifUserComment,          // User's comment
                      kCGImagePropertyExifSubjectLocation,      // Image’s primary subject
                      kCGImagePropertyExifMakerNote             // Information specified by the camera manufacturer
    ]
    return properties as [String]
}()

// ExifEx private metadata properties
/// See https://www.exiftool.org/TagNames/EXIF.html
fileprivate let exifExPrivateProperties: [String] = {
    let properties = [kCGImagePropertyExifCameraOwnerName,      // Owner's name
                      kCGImagePropertyExifBodySerialNumber,     // Serial numbers
                      kCGImagePropertyExifLensSerialNumber      // Lens serial number
    ]
    return properties as [String]
}()

// ExifAux private metadata properties
/// See https://www.exiftool.org/TagNames/EXIF.html
fileprivate let exifAuxPrivateProperties: [String] = {
    let properties = [kCGImagePropertyExifAuxSerialNumber,      // Serial number
                      kCGImagePropertyExifAuxLensSerialNumber,  // Lens serial number
                      kCGImagePropertyExifAuxOwnerName          // Owner's name
    ]
    return properties as [String]
}()
    
// Exif creation date (YY:MM:DD HH:MM:SS format)
/// https://en.wikipedia.org/wiki/Exif
/// https://web.archive.org/web/20190624045241if_/http://www.cipa.jp:80/std/documents/e/DC-008-Translation-2019-E.pdf
fileprivate let exifDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    formatter.timeZone = TimeZone(abbreviation: "UTC")!
    return formatter
}()

// IPTC private metadata properties
/// See https://www.exiftool.org/TagNames/IPTC.html
/// See https://www.iptc.org/std/photometadata/specification/IPTC-PhotoMetadata
fileprivate let iptcPrivateProperties: [String] = {
    let properties = [kCGImagePropertyIPTCContentLocationCode,  // Content location code
                      kCGImagePropertyIPTCContentLocationName,  // Content location name
                      kCGImagePropertyIPTCByline,               // Name of the person who created the image
                      kCGImagePropertyIPTCBylineTitle,          // Title of the person who created the image
                      kCGImagePropertyIPTCCity,                 // City where the image was created
                      kCGImagePropertyIPTCSubLocation,          // Location within the city where the image was created
                      kCGImagePropertyIPTCProvinceState,        // Province or state
                      kCGImagePropertyIPTCCountryPrimaryLocationCode,   // Country primary location code
                      kCGImagePropertyIPTCCountryPrimaryLocationName,   // Country primary location name
                      kCGImagePropertyIPTCOriginalTransmissionReference,// Call letter/number combination
                      kCGImagePropertyIPTCHeadline,             // Summary of the contents of the image
                      kCGImagePropertyIPTCCredit,               // Name of the service that provided the image
                      kCGImagePropertyIPTCSource,               // Original owner of the image
                      kCGImagePropertyIPTCContact,              // Contact information for further information
                      kCGImagePropertyIPTCWriterEditor,         // Name of the person who wrote or edited the description
                      kCGImagePropertyIPTCCreatorContactInfo,   // Creator’s contact info (dictionary)
    ]
    return properties as [String]
}()
    
// IPTC creation date and time
/// https://en.wikipedia.org/wiki/IPTC_Information_Interchange_Model
/// https://iptc.org/standards/photo-metadata/iptc-standard/
fileprivate let iptcDateFormatter1: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd"
    formatter.timeZone = TimeZone(abbreviation: "UTC")!
    return formatter
}()

fileprivate let iptcDateFormatter2: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMM"
    formatter.timeZone = TimeZone(abbreviation: "UTC")!
    return formatter
}()

fileprivate let iptcDateFormatter3: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy"
    formatter.timeZone = TimeZone(abbreviation: "UTC")!
    return formatter
}()

fileprivate let iptcTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd'T'HHmmss"
    formatter.timeZone = TimeZone(abbreviation: "UTC")!
    return formatter
}()

fileprivate func iptcTimeSinceReferenceDate(timeStr: String?) -> TimeInterval? {
    guard let timeStr = timeStr else { return nil }
    
    let dateStr = "20010101T" + timeStr.prefix(6)                   // Remove time zone if any
    if let iptcTime = iptcTimeFormatter.date(from: dateStr) {
        return iptcTime.timeIntervalSinceReferenceDate
    }
    return nil
}

// PNG private metadata properties
/// See https://www.exiftool.org/TagNames/PNG.html
fileprivate let pngPrivateProperties: [String] = {
    let properties = [kCGImagePropertyPNGAuthor                     // String that identifies the author
    ]
    return properties as [String]
}()
    
// TIFF private metadata properties
fileprivate let tiffPrivateProperties: [String] = {
    let properties = [kCGImagePropertyTIFFArtist                    // Artist who created the image
    ]
    return properties as [String]
}()
    
// DNG private metadata properties
fileprivate let dngPrivateProperties: [String] = {
    let properties = [kCGImagePropertyDNGCameraSerialNumber         // Camera serial number
    ]
    return properties as [String]
}()
    
// CIFF private metadata properties
fileprivate let ciffPrivateProperties: [String] = {
    let properties = [kCGImagePropertyCIFFOwnerName,                // Camera’s owner
                      kCGImagePropertyCIFFRecordID,                 // Number of images taken since the camera shipped
                      kCGImagePropertyCIFFCameraSerialNumber        // Camera serial number
    ]
    return properties as [String]
}()
    
// Canon private metadata properties
fileprivate let canonPrivateProperties: [String] = {
    let properties = [kCGImagePropertyMakerCanonOwnerName,          // Camera’s owner
                      kCGImagePropertyMakerCanonCameraSerialNumber  // Camera serial number
    ]
    return properties as [String]
}()
    
// Nikon private metadata properties
fileprivate let nikonPrivateProperties: [String] = {
    let properties = [kCGImagePropertyMakerNikonCameraSerialNumber  // Camera’s owner
    ]
    return properties as [String]
}()


// MARK: - Get Creation Date
extension Dictionary where Key == CFString, Value == Any {
    // Creation date from EXIF or IPTC metadata
    func creationDate() -> Date? {
        if let date = self.exifCreationDate() {
            return date
        }
        if let date = self.iptcCreationDate() {
            return date
        }
        return nil
    }
    
    // EXIF creation date
    fileprivate func exifCreationDate() -> Date? {
        // Any EXIF metadata?
        if let exifDict = self[kCGImagePropertyExifDictionary] as? [CFString:Any] {
            // Time the image was created (YY:MM:DD HH:MM:SS format)
            if let exifDate = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
                return exifDateFormatter.date(from: exifDate)
            }

            // Time the image was digitalized (YY:MM:DD HH:MM:SS format)
            if let exifDate = exifDict[kCGImagePropertyExifDateTimeDigitized] as? String {
               return exifDateFormatter.date(from: exifDate)
            }
        }
        return nil
    }
    
    // IPTC creation date
    fileprivate func iptcCreationDate() -> Date? {
        if let iptcDict = self[kCGImagePropertyIPTCDictionary] as? [CFString:Any],
           let dateStr = iptcDict[kCGImagePropertyIPTCDateCreated] as? String {
            // Are the year, month and day all known?
            if let iptcDate = iptcDateFormatter1.date(from: dateStr) {
                if let timeStr = iptcDict[kCGImagePropertyIPTCTimeCreated] as? String,
                   let iptcTimeOffset = iptcTimeSinceReferenceDate(timeStr: timeStr) {
                    let iptcTimeInterval = iptcDate.timeIntervalSinceReferenceDate
                    return Date(timeIntervalSinceReferenceDate: iptcTimeInterval + iptcTimeOffset)
                }
                return iptcDate
            }
            // Are the year and month known?
            if let iptcDate = iptcDateFormatter2.date(from: dateStr) {
                return iptcDate
            }
            // Is the year known?
            if let iptcDate = iptcDateFormatter3.date(from: dateStr) {
                return iptcDate
            }
        }
        return nil
    }
}


// MARK: - Strip Private Metadata
extension CGImageMetadata {
    // Remove CGImage private metadata
    // The GPS metadata will be removed using the kCGImageMetadataShouldExcludeGPS option
    public func stripPrivateMetadata() -> CGImageMetadata {
        guard let metadata = CGImageMetadataCreateMutableCopy(self)
        else { return self }

        // Get prefixes and keys of privata metadata
        var dictOfKeys = [CFString : [String]]()
        dictOfKeys[kCGImageMetadataPrefixExif] = exifPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixExifEX] = exifExPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixExifAux] = exifAuxPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixIPTCCore] = iptcPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixTIFF] = tiffPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixIPTCExtension] = iptcPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixXMPBasic] = pngPrivateProperties

        // Loop over all tags
        CGImageMetadataEnumerateTagsUsingBlock(self, nil, nil) { _, tag in
            // Retrieve path
            let prefix = CGImageMetadataTagCopyPrefix(tag)!
            let name = CGImageMetadataTagCopyName(tag)! as String
            let path = ((prefix as String) + ":" + name) as CFString
//            debugPrint("=> Tag: \(prefix):\(name)")

            // Check presence of dictionary
            if let properties = dictOfKeys[prefix] {
                // Remove tag if it contains private data
                if properties.contains(name) {
                    CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                    return true
                }
            }
            
            // Check remaining names
            if pngPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                return true
            }
            if dngPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                return true
            }
            if ciffPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                return true
            }
            if canonPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                return true
            }
            if nikonPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path)
                return true
            }
            return true
        }
        return metadata
    }
}

extension Dictionary where Key == CFString, Value == Any {
    // Remove GPS and other private metadata
    public func stripPrivateProperties() -> [CFString:Any] {
        var properties = self as [CFString:Any]
        
        // Remove GPS dictionary
        if let GPSdata = properties[kCGImagePropertyGPSDictionary] as? [CFString:Any] {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
            debugPrint("=> removed GPS metadata = \(GPSdata)")
        }
        
        // Get other dictionaries with keys of privata data
        var dictOfKeys = [CFString : [String]]()
        var exifPrivateProperties = exifPrivateProperties
        exifPrivateProperties.append(contentsOf: exifExPrivateProperties)
        dictOfKeys[kCGImagePropertyExifDictionary] = exifPrivateProperties
        dictOfKeys[kCGImagePropertyExifAuxDictionary] = exifAuxPrivateProperties
        dictOfKeys[kCGImagePropertyIPTCDictionary] = iptcPrivateProperties
        dictOfKeys[kCGImagePropertyPNGDictionary] = pngPrivateProperties
        dictOfKeys[kCGImagePropertyTIFFDictionary] = tiffPrivateProperties
        dictOfKeys[kCGImagePropertyDNGDictionary] = dngPrivateProperties
        dictOfKeys[kCGImagePropertyCIFFDictionary] = ciffPrivateProperties
        dictOfKeys[kCGImagePropertyMakerCanonDictionary] = canonPrivateProperties
        dictOfKeys[kCGImagePropertyMakerNikonDictionary] = nikonPrivateProperties
        
        // Loop over the dictionaries
        for dict in dictOfKeys {
            // Check presence of dictionary
            if var dictData = properties[dict.key] as? [CFString:Any] {
                // Loop over the keys of private data
                for key in dict.value {
                    // Remove private metadata if any
                    if let value = dictData[key as NSString] {
                        dictData.removeValue(forKey: key as NSString)
                        debugPrint("=> removed private metadata [\(key) : \(value)]")
                    }
                }
                // Update properties
                properties[dict.key] = dictData
            }
        }
        return properties
    }
}
    

// MARK: - Fix Metadata
extension Dictionary where Key == CFString, Value == Any {
    // Fix image properties from resized/converted image
    mutating func fixContents(from image:CGImage, resettingOrientation: Bool) {
        var metadata = self

        // Extract image source from UIImage object (orientation managed)
        guard let imageData = UIImage(cgImage: image).jpegData(compressionQuality: 1.0),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return
        }

        // Extract image source container properties
        if let sourceMetadata = CGImageSourceCopyProperties(source, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the container
            metadata.fixProperties(from: sourceMetadata, resettingOrientation)
        }

        // Extract image properties from image data
        if let imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the image
            metadata.fixProperties(from: imageMetadata, resettingOrientation)
            
            // Update/add width from image properties
            if let width = imageMetadata[kCGImagePropertyPixelWidth] {
                metadata[kCGImagePropertyPixelWidth] = width
            }

            // Update/add height from image properties
            if let height = imageMetadata[kCGImagePropertyPixelHeight] {
                metadata[kCGImagePropertyPixelHeight] = height
            }

            // Reset orientation if requested (according to the TIFF and EXIF specifications)
            if resettingOrientation {
                metadata[kCGImagePropertyOrientation] = CGImagePropertyOrientation.up.rawValue
            }
        }
        
        self = metadata
    }

    // Fix image properties from (resized) image metadata
    mutating func fixProperties(from imageMetadata: [CFString: Any], _ resettingOrientation: Bool) {
        var metadata = self

        // Common Image Properties
        // Update/add Exif dictionary from image metadata
        if var imageEXIFDictionary = imageMetadata[kCGImagePropertyExifDictionary] as? [CFString : Any] {
            // Should we reset the orientation?
            /// See https://www.exiftool.org/TagNames/EXIF.html
            if resettingOrientation {
                imageEXIFDictionary[kCGImagePropertyExifSceneCaptureType] = NSNumber(value: 1)
            }
            // Image contains an EXIF dictionary
            if var metadataEXIFDictionary = metadata[kCGImagePropertyExifDictionary] as? [CFString : Any] {
                // An EXIF dictionary already exists -> update key/value pairs
                for (k, v) in imageEXIFDictionary { metadataEXIFDictionary[k] = v }
                metadata[kCGImagePropertyExifDictionary] = metadataEXIFDictionary
            } else {
                // No EXIF dictionary -> Add it
                metadata[kCGImagePropertyExifDictionary] = imageEXIFDictionary
            }
        }

        // Update/add ExifAux dictionary from image metadata
        if let imageExifAuxDictionary = imageMetadata[kCGImagePropertyExifAuxDictionary] as? [CFString : Any] {
            // Image contains an EXIF Aux dictionary
            if var metadataExifAuxDictionary = metadata[kCGImagePropertyExifAuxDictionary] as? [CFString : Any] {
                // An EXIF Aux dictionary already exists -> update key/value pairs
                for (k, v) in imageExifAuxDictionary { metadataExifAuxDictionary[k] = v }
                metadata[kCGImagePropertyExifAuxDictionary] = metadataExifAuxDictionary
            } else {
                // No EXIF Aux dictionary -> Add it
                metadata[kCGImagePropertyExifAuxDictionary] = imageExifAuxDictionary
            }
        }
        
        // Update/add IPTC dictionary from image metadata
        if let imageIPTCDictionary = metadata[kCGImagePropertyIPTCDictionary] as? [CFString : Any] {
            // Image contains an IPTC dictionary
            if var metadataIPTCDictionary = metadata[kCGImagePropertyIPTCDictionary] as? [CFString : Any] {
                // A IPTC dictionary already exists -> update key/value pairs
                for (k, v) in imageIPTCDictionary { metadataIPTCDictionary[k] = v }
                metadata[kCGImagePropertyIPTCDictionary] = metadataIPTCDictionary
            } else {
                // No IPTC dictionary -> Add it
                metadata[kCGImagePropertyIPTCDictionary] = imageIPTCDictionary
            }
        }
        
        // Update/add GPS dictionary from image metadata
        if let imageGPSDictionary = metadata[kCGImagePropertyGPSDictionary] as? [CFString : Any] {
            // Image contains a GPS dictionary
            if var metadataGPSDictionary = metadata[kCGImagePropertyGPSDictionary] as? [CFString : Any] {
                // A GPS dictionary already exists -> update key/value pairs
                for (k, v) in imageGPSDictionary { metadataGPSDictionary[k] = v }
                metadata[kCGImagePropertyGPSDictionary] = metadataGPSDictionary
            } else {
                // No GPS dictionary -> Add it
                metadata[kCGImagePropertyGPSDictionary] = imageGPSDictionary
            }
        }
        
        // Update/add WebP dictionary from image metadata
        if let imageWebPDictionary = metadata[kCGImagePropertyWebPDictionary] as? [CFString : Any] {
            // Image contains a WebP dictionary
            if var metadataWebPDictionary = metadata[kCGImagePropertyWebPDictionary] as? [CFString : Any] {
                // A WebP dictionary already exists -> update key/value pairs
                for (k, v) in imageWebPDictionary { metadataWebPDictionary[k] = v }
                metadata[kCGImagePropertyGPSDictionary] = metadataWebPDictionary
            } else {
                // No WebP dictionary -> Add it
                metadata[kCGImagePropertyGPSDictionary] = imageWebPDictionary
            }
        }
        
        // Format-Specific Properties
        // Update/add CIFF dictionary from image metadata
        if let imageCIFFDictionary = imageMetadata[kCGImagePropertyCIFFDictionary] as? [CFString : Any] {
            // Image contains a CIFF dictionary
            if var metadataCIFFDictionary = metadata[kCGImagePropertyCIFFDictionary] as? [CFString : Any] {
                // A CIFF dictionary already exists -> update key/value pairs
                for (k, v) in imageCIFFDictionary { metadataCIFFDictionary[k] = v }
                metadata[kCGImagePropertyCIFFDictionary] = metadataCIFFDictionary
            } else {
                // No CIFF dictionary -> Add it
                metadata[kCGImagePropertyCIFFDictionary] = imageCIFFDictionary
            }
        }

        // Update/add DNG dictionary from image metadata
        if let imageDNGDictionary = imageMetadata[kCGImagePropertyDNGDictionary] as? [CFString : Any] {
            // Image contains a DNG dictionary
            if var metadataDNGDictionary = metadata[kCGImagePropertyDNGDictionary] as? [CFString : Any] {
                // A DNG dictionary already exists -> update key/value pairs
                for (k, v) in imageDNGDictionary { metadataDNGDictionary[k] = v }
                metadata[kCGImagePropertyDNGDictionary] = metadataDNGDictionary
            } else {
                // No DNG dictionary -> Add it
                metadata[kCGImagePropertyDNGDictionary] = imageDNGDictionary
            }
        }

        // Update/add GIF dictionary from image metadata
        if let imageGIFDictionary = imageMetadata[kCGImagePropertyGIFDictionary] as? [CFString : Any] {
            // Image contains a GIF dictionary
            if var metadataGIFDictionary = metadata[kCGImagePropertyGIFDictionary] as? [CFString : Any] {
                // A GIF dictionary already exists -> update key/value pairs
                for (k, v) in imageGIFDictionary { metadataGIFDictionary[k] = v }
                metadata[kCGImagePropertyGIFDictionary] = metadataGIFDictionary
            } else {
                // No GIF dictionary -> Add it
                metadata[kCGImagePropertyGIFDictionary] = imageGIFDictionary
            }
        }

        // Update/add HEIC dictionary from image metadata
        if let imageHEICDictionary = imageMetadata[kCGImagePropertyHEICSDictionary] as? [CFString : Any] {
            // Image contains an HEIC dictionary
            if var metadataHEICDictionary = metadata[kCGImagePropertyHEICSDictionary] as? [CFString : Any] {
                // An HEIC dictionary already exists -> update key/value pairs
                for (k, v) in imageHEICDictionary { metadataHEICDictionary[k] = v }
                metadata[kCGImagePropertyHEICSDictionary] = metadataHEICDictionary
            } else {
                // No HEIC dictionary -> Add it
                metadata[kCGImagePropertyHEICSDictionary] = imageHEICDictionary
            }
        }

        // Update/add JFIF dictionary from image metadata
        if let imageJFIFDictionary = imageMetadata[kCGImagePropertyJFIFDictionary] as? [CFString : Any] {
            // Image contains a JFIF dictionary
            if var metadataJFIFDictionary = metadata[kCGImagePropertyJFIFDictionary] as? [CFString : Any] {
                // A JIFF dictionary already exists -> update key/value pairs
                for (k, v) in imageJFIFDictionary { metadataJFIFDictionary[k] = v }
                metadata[kCGImagePropertyJFIFDictionary] = metadataJFIFDictionary
            } else {
                // No JIFF dictionary -> Add it
                metadata[kCGImagePropertyJFIFDictionary] = imageJFIFDictionary
            }
        }

        // Update/add PNG dictionary from image metadata
        if let imagePNGDictionary = imageMetadata[kCGImagePropertyPNGDictionary] as? [CFString : Any] {
            // Image contains a PNG dictionary
            if var metadataPNGDictionary = metadata[kCGImagePropertyPNGDictionary] as? [CFString : Any] {
                // A PNG dictionary already exists -> update key/value pairs
                for (k, v) in imagePNGDictionary { metadataPNGDictionary[k] = v }
                metadata[kCGImagePropertyPNGDictionary] = metadataPNGDictionary
            } else {
                // No PNG dictionary -> Add it
                metadata[kCGImagePropertyPNGDictionary] = imagePNGDictionary
            }
        }

        // Update/add TGA dictionary from image metadata
        if let imageTGADictionary = imageMetadata[kCGImagePropertyTGADictionary] as? [CFString : Any] {
            // Image contains a TGA dictionary
            if var metadataTGADictionary = metadata[kCGImagePropertyTGADictionary] as? [CFString : Any] {
                // A TGA dictionary already exists -> update key/value pairs
                for (k, v) in imageTGADictionary { metadataTGADictionary[k] = v }
                metadata[kCGImagePropertyTIFFDictionary] = metadataTGADictionary
            } else {
                // No TGA dictionary -> Add it
                metadata[kCGImagePropertyTGADictionary] = imageTGADictionary
            }
        }
        
        // Update TIFF dictionary from image metadata
        if var imageTIFFDictionary = imageMetadata[kCGImagePropertyTIFFDictionary] as? [CFString : Any] {
            // Should we reset the orientation?
            if resettingOrientation {
                imageTIFFDictionary[kCGImagePropertyTIFFOrientation] = NSNumber(value: 1)
            }
            // Image contains a TIFF dictionary
            if var metadataTIFFDictionary = metadata[kCGImagePropertyTIFFDictionary] as? [CFString : Any] {
                // A TIFF dictionary already exists -> update key/value pairs
                for (k, v) in imageTIFFDictionary { metadataTIFFDictionary[k] = v }
                metadata[kCGImagePropertyTIFFDictionary] = metadataTIFFDictionary
            } else {
                // No TIFF dictionary -> Add it
                metadata[kCGImagePropertyTIFFDictionary] = imageTIFFDictionary
            }
        }

        // Update/add 8BIM dictionary from image metadata
        if let image8BIMDictionary = imageMetadata[kCGImageProperty8BIMDictionary] as? [CFString : Any] {
            // Image contains a 8BIM dictionary
            if var metadata8BIMDictionary = metadata[kCGImageProperty8BIMDictionary] as? [CFString : Any] {
                // A 8BIM dictionary already exists -> update key/value pairs
                for (k, v) in image8BIMDictionary { metadata8BIMDictionary[k] = v }
                metadata[kCGImageProperty8BIMDictionary] = metadata8BIMDictionary
            } else {
                // No 8BIM dictionary -> Add it
                metadata[kCGImageProperty8BIMDictionary] = image8BIMDictionary
            }
        }

        // Update RAW dictionary from image metadata
        if let imageRawDictionary = imageMetadata[kCGImagePropertyRawDictionary] as? [CFString : Any] {
            // Image contains a RAW dictionary
            if var metadataRawDictionary = metadata[kCGImagePropertyRawDictionary] as? [CFString : Any] {
                // A Raw dictionary already exists -> update key/value pairs
                for (k, v) in imageRawDictionary { metadataRawDictionary[k] = v }
                metadata[kCGImagePropertyRawDictionary] = metadataRawDictionary
            } else {
                // No Raw dictionary -> Add it
                metadata[kCGImagePropertyRawDictionary] = imageRawDictionary
            }
        }

        self = metadata
    }
}
