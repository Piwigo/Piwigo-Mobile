//
//  ImageUtilities.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 09/01/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

class ImageUtilities {
    
    class func fixContents(of originalMetadata:[CFString : Any], from image:UIImage) -> [CFString : Any] {
        var metadata = originalMetadata

        // Extract image data from UIImage object
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return originalMetadata
        }
        
        // Create image source from image data
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return originalMetadata
        }

        // Extract image source container properties
        if let sourceMetadata = CGImageSourceCopyProperties(source, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the container
            metadata = fixProperties(of: metadata, from: sourceMetadata)
        }

        // Extract image properties from image data
        if let imageMetadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString : Any] {
            // Update TIFF, GIF, etc. metadata from properties found in the image
            metadata = fixProperties(of: metadata, from: imageMetadata)
        
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
    
    class func fixProperties(of originalMetadata: [CFString : Any],
                             from imageMetadata : [CFString : Any]) -> [CFString : Any] {
        var metadata = originalMetadata

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
    
    class func stripGPSdata(from originalMetadata:[CFString:Any]) -> (Bool, [CFString:Any]) {
        var metadata = originalMetadata
        var didChangeMetadata = false

        // GPS dictionary
        if let GPSdata = metadata[kCGImagePropertyGPSDictionary] as? [CFString:Any] {
            print("=> remove GPS metadata = \(GPSdata)")
            metadata.removeValue(forKey: kCGImagePropertyGPSDictionary)
            didChangeMetadata = true
        }

        // EXIF dictionary
        if var EXIFdata = metadata[kCGImagePropertyExifDictionary] as? [CFString:Any] {
            var didChangeEXIFMetadata = false
            
            // Remove user's comment
            if let value = EXIFdata[kCGImagePropertyExifUserComment] {
                print("remove EXIF User Comment metadata = \(value)")
                EXIFdata.removeValue(forKey: kCGImagePropertyExifUserComment)
                didChangeEXIFMetadata = true
            }
            // Remove location data
            if let value = EXIFdata[kCGImagePropertyExifSubjectLocation] {
                print("remove EXIF Subject Location metadata = \(value)")
                EXIFdata.removeValue(forKey: kCGImagePropertyExifSubjectLocation)
                didChangeEXIFMetadata = true
            }
        
            // Update metadata
            if didChangeEXIFMetadata {
                metadata[kCGImagePropertyExifDictionary] = EXIFdata
                didChangeMetadata = true
            }
        }

        return (didChangeMetadata, metadata)
    }
}
