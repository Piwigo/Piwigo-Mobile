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

class ImageMetadata {
        
    // MARK: - Private metadata properties
    // Exif private metadata properties
    /// See https://www.exiftool.org/TagNames/EXIF.html
    let exifPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyExifUserComment,          // User's comment
                          kCGImagePropertyExifSubjectLocation,      // Image’s primary subject
                          kCGImagePropertyExifMakerNote             // Information specified by the camera manufacturer
        ]
        return properties
    }()

    // ExifEx private metadata properties
    /// See https://www.exiftool.org/TagNames/EXIF.html
    let exifExPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyExifCameraOwnerName,      // Owner's name
                          kCGImagePropertyExifBodySerialNumber,     // Serial numbers
                          kCGImagePropertyExifLensSerialNumber      // Lens serial number
        ]
        return properties
    }()

    // ExifAux private metadata properties
    /// See https://www.exiftool.org/TagNames/EXIF.html
    let exifAuxPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyExifAuxSerialNumber,      // Serial number
                          kCGImagePropertyExifAuxLensSerialNumber,  // Lens serial number
                          kCGImagePropertyExifAuxOwnerName          // Owner's name
        ]
        return properties
    }()
        
    // IPTC private metadata properties
    /// See https://www.exiftool.org/TagNames/IPTC.html
    /// See https://www.iptc.org/std/photometadata/specification/IPTC-PhotoMetadata
    let iptcPrivateProperties: [CFString] = {
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
        return properties
    }()
        
    // PNG private metadata properties
    /// See https://www.exiftool.org/TagNames/PNG.html
    let pngPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyPNGAuthor                 // String that identifies the author
        ]
        return properties
    }()
        
    // TIFF private metadata properties
    let tiffPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyTIFFArtist                // Artist who created the image
        ]
        return properties
    }()
        
    // DNG private metadata properties
    let dngPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyDNGCameraSerialNumber     // Camera serial number
        ]
        return properties
    }()
        
    // CIFF private metadata properties
    let ciffPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyCIFFOwnerName,            // Camera’s owner
                          kCGImagePropertyCIFFRecordID,             // Number of images taken since the camera shipped
                          kCGImagePropertyCIFFCameraSerialNumber    // Camera serial number
        ]
        return properties
    }()
        
    // Canon private metadata properties
    let canonPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyMakerCanonOwnerName,      // Camera’s owner
                          kCGImagePropertyMakerCanonCameraSerialNumber // Camera serial number
        ]
        return properties
    }()
        
    // Nikon private metadata properties
    let nikonPrivateProperties: [CFString] = {
        let properties = [kCGImagePropertyMakerNikonCameraSerialNumber  // Camera’s owner
        ]
        return properties
    }()    

}

extension CGImageMetadata {
    // Remove CGImage private metadata
    // The GPS metadata will be removed using the kCGImageMetadataShouldExcludeGPS option
    public func stripPrivateMetadata() -> CGImageMetadata {
        guard let metadata = CGImageMetadataCreateMutableCopy(self) else {
            return self
        }

        // Get prefixes and keys of privata metadata
        var dictOfKeys = [CFString : [CFString]]()
        dictOfKeys[kCGImageMetadataPrefixExif] = ImageMetadata().exifPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixExifEX] = ImageMetadata().exifExPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixExifAux] = ImageMetadata().exifAuxPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixIPTCCore] = ImageMetadata().iptcPrivateProperties
        dictOfKeys[kCGImageMetadataPrefixTIFF] = ImageMetadata().tiffPrivateProperties
        if #available(iOS 11.3, *) {
            dictOfKeys[kCGImageMetadataPrefixIPTCExtension] = ImageMetadata().iptcPrivateProperties
        }
        dictOfKeys[kCGImageMetadataPrefixXMPBasic] = ImageMetadata().pngPrivateProperties

        // Loop over all tags
        CGImageMetadataEnumerateTagsUsingBlock(self, nil, nil) { _, tag in
            // Retrieve path
            let prefix = CGImageMetadataTagCopyPrefix(tag)!
            let name = CGImageMetadataTagCopyName(tag)!
            let path = ((prefix as String) + ":" + (name as String)) as CFString
//            print("=> Tag: \(prefix):\(name)")

            // Check presence of dictionary
            if let properties = dictOfKeys[prefix] {
                // Remove tag if it contains private data
                if properties.contains(name as CFString) {
                    CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                    return true
                }
            }
            
            // Check remaining names
            if ImageMetadata().pngPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                return true
            }
            if ImageMetadata().dngPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                return true
            }
            if ImageMetadata().ciffPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                return true
            }
            if ImageMetadata().canonPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                return true
            }
            if ImageMetadata().nikonPrivateProperties.contains(name) {
                CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString)
                return true
            }
            return true
        }
        return metadata
    }
}

extension Dictionary where Key == CFString, Value == Any {
    // Remove CGImage properties w/o GPS and other private data
    public func stripPrivateProperties() -> [CFString:Any] {
        var properties = self as [CFString:Any]
        
        // Remove GPS dictionary
        if let GPSdata = properties[kCGImagePropertyGPSDictionary] as? [CFString:Any] {
            properties.removeValue(forKey: kCGImagePropertyGPSDictionary)
            print("=> removed GPS metadata = \(GPSdata)")
        }
        
        // Get other dictionaries with keys of privata data
        var dictOfKeys = [CFString : [CFString]]()
        var exifPrivateProperties = ImageMetadata().exifPrivateProperties
        exifPrivateProperties.append(contentsOf: ImageMetadata().exifExPrivateProperties)
        dictOfKeys[kCGImagePropertyExifDictionary] = exifPrivateProperties
        dictOfKeys[kCGImagePropertyExifAuxDictionary] = ImageMetadata().exifAuxPrivateProperties
        dictOfKeys[kCGImagePropertyIPTCDictionary] = ImageMetadata().iptcPrivateProperties
        dictOfKeys[kCGImagePropertyPNGDictionary] = ImageMetadata().pngPrivateProperties
        dictOfKeys[kCGImagePropertyTIFFDictionary] = ImageMetadata().tiffPrivateProperties
        dictOfKeys[kCGImagePropertyDNGDictionary] = ImageMetadata().dngPrivateProperties
        dictOfKeys[kCGImagePropertyCIFFDictionary] = ImageMetadata().ciffPrivateProperties
        dictOfKeys[kCGImagePropertyMakerCanonDictionary] = ImageMetadata().canonPrivateProperties
        dictOfKeys[kCGImagePropertyMakerNikonDictionary] = ImageMetadata().nikonPrivateProperties

        // Loop over the dictionaries
        for dict in dictOfKeys {
            // Check presence of dictionary
            if var dictData = properties[dict.key] as? [CFString:Any] {
                // Loop over the keys of private data
                for key in dict.value {
                    // Remove private metadata if any
                    if let value = dictData[key] {
                        dictData.removeValue(forKey: key)
                        print("=> removed private metadata [\(key) : \(value)]")
                    }
                }
                // Update properties
                properties[dict.key] = dictData
            }
        }
        return properties
    }
    
    // Fix image container properties from UIImage
    func fixContents(from image:UIImage) -> [CFString : Any] {
        var metadata = self

        // Extract image data from UIImage object
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return self
        }
        
        // Create image source from image data
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return self
        }

        // Extract image source container properties
        if let sourceMetadata = CGImageSourceCopyProperties(source, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the container
            metadata = metadata.fixProperties(from: sourceMetadata)
        }

        // Extract image properties from image data
        if let imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the image
            metadata = metadata.fixProperties(from: imageMetadata)
        
            // Update/add DPI height from image properties
            if let DPIheight = imageMetadata[kCGImagePropertyDPIHeight] {
                metadata[kCGImagePropertyDPIHeight] = DPIheight
            }

            // Update/add DPI width from image properties
            if let DPIwidth = imageMetadata[kCGImagePropertyDPIWidth] {
                metadata[kCGImagePropertyDPIHeight] = DPIwidth
            }

            // Update/add width from image properties
            if let width = imageMetadata[kCGImagePropertyPixelWidth] {
                metadata[kCGImagePropertyPixelWidth] = width
            }

            // Update/add height from image properties
            if let height = imageMetadata[kCGImagePropertyPixelHeight] {
                metadata[kCGImagePropertyPixelHeight] = height
            }

            // Update/add depth from image properties
            if let depth = imageMetadata[kCGImagePropertyDepth] {
                metadata[kCGImagePropertyDepth] = depth
            }

            // Update/add orientation from image properties
            if let orientation = imageMetadata[kCGImagePropertyOrientation] {
                metadata[kCGImagePropertyOrientation] = orientation
            }

            // Update/add isFloat from image properties
            if let isFloat = imageMetadata[kCGImagePropertyIsFloat] {
                metadata[kCGImagePropertyIsFloat] = isFloat
            }

            // Update/add isIndexed from image properties
            if let isIndexed = imageMetadata[kCGImagePropertyIsIndexed] {
                metadata[kCGImagePropertyIsIndexed] = isIndexed
            }

            // Update/add asAlpha from image properties
            if let asAlpha = imageMetadata[kCGImagePropertyHasAlpha] {
                metadata[kCGImagePropertyHasAlpha] = asAlpha
            }

            // Update/add colour model from image properties
            if let colorModel = imageMetadata[kCGImagePropertyColorModel] {
                metadata[kCGImagePropertyColorModel] = colorModel
            }

            // Update/add ICC profile from image properties
            if let iccProfile = imageMetadata[kCGImagePropertyProfileName] {
                metadata[kCGImagePropertyProfileName] = iccProfile
            }
            
            // Compression quality (1.0 for lossless)
//            metadata[kCGImageDestinationLossyCompressionQuality] = 0.99
        }
        
        return metadata
    }

    // Fix image properties from (resized) imaga metadata
    func fixProperties(from imageMetadata: [CFString:Any]) -> [CFString:Any] {
        var metadata = self

        // Update TIFF dictionary from image metadata
        if let imageTIFFDictionary = imageMetadata[kCGImagePropertyTIFFDictionary] as? [CFString : Any] {
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

        // Update/add Exif dictionary from image metadata
        if let imageEXIFDictionary = imageMetadata[kCGImagePropertyExifDictionary] as? [CFString : Any] {
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
                // A IPTC dictionary already exists -> update key/value pairs
                for (k, v) in imageGPSDictionary { metadataGPSDictionary[k] = v }
                metadata[kCGImagePropertyGPSDictionary] = metadataGPSDictionary
            } else {
                // No IPTC dictionary -> Add it
                metadata[kCGImagePropertyGPSDictionary] = imageGPSDictionary
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

        return metadata
    }
}
