//
//  ImageExif.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  EXIF metadata of an image file, as presented by the table of the metadata:
//  one entry per EXIF key, with the natural name of the key and a readable value.
//

import Foundation
import ImageIO

/// Groups of the EXIF metadata, in the order they are presented
/// (the grouping of the tags follows the one of https://exif.pro/tags)
enum ImageExifGroup: CaseIterable, Sendable {
    case camera, exposure, image, dateTime, authorship, other

    /// Title of the section
    var title: String {
        switch self {
        case .camera:       return String(localized: "imageExifGroup_camera", comment: "Camera")
        case .exposure:     return String(localized: "imageExifGroup_exposure", comment: "Exposure")
        case .image:        return String(localized: "imageExifGroup_image", comment: "Image")
        case .dateTime:     return String(localized: "imageExifGroup_dateTime", comment: "Date and Time")
        case .authorship:   return String(localized: "imageExifGroup_authorship", comment: "Authorship")
        case .other:        return String(localized: "imageExifGroup_other", comment: "Other")
        }
    }

    /// Keys of each group, in the order they are presented: from the body of the camera to its lens,
    /// from the mode of the exposure to its measures, from the dimensions of the image to its origin.
    private static let keys: [ImageExifGroup: [String]] = [
        .camera: ["Make", "Model", "BodySerialNumber", "CameraOwnerName",
                  "LensMake", "LensSpecification", "LensModel", "LensSerialNumber",
                  "FocalLength", "FocalLenIn35mmFilm", "MaxApertureValue",
                  "SensingMethod", "CFAPattern", "FocalPlaneXResolution", "FocalPlaneYResolution",
                  "MakerNote"],
        .exposure: ["ExposureProgram", "ExposureMode", "MeteringMode",
                    "ExposureTime", "FNumber", "ISOSpeedRatings", "ISOSpeed", "SensitivityType",
                    "StandardOutputSensitivity", "RecommendedExposureIndex", "ExposureBiasValue",
                    "ShutterSpeedValue", "ApertureValue", "BrightnessValue",
                    "Flash", "FlashEnergy", "WhiteBalance", "LightSource",
                    "SubjectDistance", "SubjectDistRange", "DigitalZoomRatio", "SceneCaptureType",
                    "GainControl", "Contrast", "Saturation", "Sharpness", "CustomRendered"],
        .image: ["PixelXDimension", "PixelYDimension", "ColorSpace", "ComponentsConfiguration",
                 "CompressedBitsPerPixel", "SubjectArea", "SubjectLocation", "SceneType",
                 "FileSource", "CompositeImage", "ImageUniqueID", "FlashPixVersion"],
        .dateTime: ["DateTimeOriginal", "SubsecTimeOriginal", "OffsetTimeOriginal",
                    "DateTimeDigitized", "SubsecTimeDigitized", "OffsetTimeDigitized",
                    "SubsecTime", "OffsetTime"],
        .authorship: ["Artist", "Copyright", "ImageDescription", "UserComment", "Software"]
    ]

    /// Group and rank in the group of the known keys
    private static let positions: [String: (group: ImageExifGroup, rank: Int)] = {
        var positions = [String: (group: ImageExifGroup, rank: Int)]()
        for (group, names) in keys {
            for (rank, name) in names.enumerated() { positions[name] = (group, rank) }
        }
        return positions
    }()

    /// Group of a key: the camera and its lens, the settings of the exposure, the properties of the image,
    /// the dates, the authors, rights and software. Unknown keys go to the last group.
    static func group(ofKey key: String) -> ImageExifGroup {
        return positions[key]?.group ?? .other
    }

    /// Entries in the order of the table of keys, then alphabetically for the unknown ones
    static func sorted(_ entries: [ImageMetadataEntry]) -> [ImageMetadataEntry] {
        let alphabetical = entries.sortedByName()
        return alphabetical.enumerated().sorted {
            let rank0 = positions[$0.element.key]?.rank ?? Int.max
            let rank1 = positions[$1.element.key]?.rank ?? Int.max
            return rank0 == rank1 ? $0.offset < $1.offset : rank0 < rank1
        }.map { $0.element }
    }
}

struct ImageExif: Sendable {
    /// Version of the EXIF standard, e.g. "2.3"
    let version: String?
    /// Entries of each group, in the order of the table of keys (unknown keys alphabetically)
    let groups: [ImageExifGroup: [ImageMetadataEntry]]
    /// The flash fired
    let flashFired: Bool

    /// Text presenting the value of a key, whatever its group
    func value(forKey key: String) -> String? {
        for entries in groups.values {
            if let entry = entries.first(where: { $0.key == key }) { return entry.value }
        }
        return nil
    }
}

enum ImageExifReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageExif>()

    /// Returns the EXIF data of a file already read, without reading it again
    static func cachedExif(at url: URL) -> ImageExif?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the EXIF data of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageExif? {
        if let cached = cachedExif(at: url) { return cached }
        let exif = readFile(at: url)
        cache.store(exif, at: url)
        return exif
    }

    private static func readFile(at url: URL) -> ImageExif? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any]
        else { return nil }

        // Collect the EXIF values
        var values = [String: Any]()
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            values = exif
        }
        // Make, model and others are stored in the TIFF directory but belong to the EXIF set
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            for key in tiffKeys {
                if let value = tiff[key] { values[key] = value }
            }
        }
        guard values.isEmpty == false else { return nil }

        // Version of the EXIF standard
        let version = (values[kCGImagePropertyExifVersion as String]).flatMap { ImageMetadataFormatter.formattedVersion($0) }

        // Entries of each group in their natural order
        var groups = [ImageExifGroup: [ImageMetadataEntry]]()
        /// The unit of the focal plane resolutions is shown with them
        let unitKey = kCGImagePropertyExifFocalPlaneResolutionUnit as String
        for (key, value) in values where key != kCGImagePropertyExifVersion as String && key != unitKey {
            let formatted: String?
            switch key {
            case let key where key == kCGImagePropertyExifFocalPlaneXResolution as String
                            || key == kCGImagePropertyExifFocalPlaneYResolution as String:
                formatted = formattedFocalPlaneResolution(value, unit: (values[unitKey] as? NSNumber)?.intValue)
                    ?? formattedValue(of: value, forKey: key)
            case "ISOSpeedRatings", "ISOSpeed", "RecommendedExposureIndex", "StandardOutputSensitivity":
                /// One prefix for all the values, which cameras often repeat: "ISO 800; 800" is shown "ISO 800"
                let numbers = (value as? [Any] ?? [value]).compactMap { ($0 as? NSNumber)?.doubleValue }
                var distinct = [Double]()
                for number in numbers where distinct.contains(number) == false { distinct.append(number) }
                formatted = distinct.isEmpty ? formattedValue(of: value, forKey: key)
                    : "ISO " + distinct.map { ImageMetadataFormatter.plain($0) }.joined(separator: "; ")
            case let key where key == kCGImagePropertyExifFlashPixVersion as String:
                /// Written "1.0" even if the minor number is zero
                formatted = ImageMetadataFormatter.formattedVersion(value).map { $0.contains(".") ? $0 : $0 + ".0" }
            case let key where key == kCGImagePropertyExifSubjectArea as String
                            || key == kCGImagePropertyExifSubjectLocation as String:
                formatted = formattedSubjectArea(value) ?? formattedValue(of: value, forKey: key)
            case let key where key == kCGImagePropertyExifComponentsConfiguration as String:
                formatted = formattedComponents(value) ?? formattedValue(of: value, forKey: key)
            case let key where key == kCGImagePropertyExifSceneType as String
                            || key == kCGImagePropertyExifFileSource as String:
                /// Bytes of undefined type, the first of which counts: ImageIO may give them as a number, a list of numbers or data
                let number = (value as? NSNumber) ?? (value as? [Any])?.first as? NSNumber
                    ?? (value as? Data)?.first.map { NSNumber(value: $0) }
                formatted = number.flatMap { meaning(of: $0.doubleValue, forKey: key) }
                    ?? formattedValue(of: value, forKey: key)
            case let key where key == kCGImagePropertyExifLensSpecification as String:
                formatted = ImageMetadataFormatter.formattedLensSpecification(value) ?? formattedValue(of: value, forKey: key)
            default:
                formatted = formattedValue(of: value, forKey: key)
            }
            guard let text = formatted, text.isEmpty == false else { continue }
            groups[ImageExifGroup.group(ofKey: key), default: []]
                .append(ImageMetadataEntry(key: key, name: naturalName(ofKey: key), value: text))
        }
        return groups.isEmpty ? nil : ImageExif(version: version, groups: groups.mapValues { ImageExifGroup.sorted($0) },
                                                  flashFired: ((values[kCGImagePropertyExifFlash as String] as? NSNumber)?.intValue ?? 0) & 1 != 0)
    }

    private static let tiffKeys = [kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel,
                                   kCGImagePropertyTIFFSoftware, kCGImagePropertyTIFFArtist,
                                   kCGImagePropertyTIFFCopyright].map { $0 as String }


    // MARK: - Names
    /// Natural name of an EXIF key: translated if known, otherwise the key split into words
    static func naturalName(ofKey key: String) -> String {
        return ImageMetadataFormatter.naturalName(ofKey: key, prefix: "imageExif_")
    }


    // MARK: - Values
    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    /// Text presenting the value of an EXIF key
    static func formattedValue(of value: Any, forKey key: String) -> String? {
        return ImageMetadataFormatter.formattedValue(of: value, forKey: key) { value, key in
            typealias Formatter = ImageMetadataFormatter
            if let number = (value as? NSNumber)?.doubleValue {
                if let meaning = meaning(of: number, forKey: key) { return meaning }
                switch key {
                case "Flash":
                    return flash(Int(number))
                case "PixelXDimension", "PixelYDimension":
                    return Formatter.plain(number) + " px"
                case "CompressedBitsPerPixel":
                    return Formatter.plain((number * 10).rounded() / 10) + " bpp"
                case "DigitalZoomRatio":
                    return Formatter.plain((number * 100).rounded() / 100) + "×"
                case "ApertureValue", "MaxApertureValue":
                    return fNumber(pow(2, number / 2))
                case "ShutterSpeedValue":
                    return shutterSpeed(fromAPEX: number)
                case "BrightnessValue":
                    return brightness(fromAPEX: number)
                case "MeteringMode":
                    return meteringMode(Int(number))
                case "ExposureMode":
                    return exposureMode(Int(number))
                case "ExposureProgram":
                    return exposureProgram(Int(number))
                case "ExposureTime":
                    guard number > 0 else { return nil }
                    return number < 1 ? "1/\(Int((1 / number).rounded())) s" : "\(Formatter.plain(number)) s"
                case "FNumber":
                    return fNumber(number)
                case "FocalLength", "FocalLenIn35mmFilm":
                    return Formatter.plain(number) + " mm"
                case "SubjectDistance":
                    return Formatter.plain(number) + " m"
                case "ExposureBiasValue":
                    return Formatter.exposureCompensation(number) + " EV"
                default:
                    return nil
                }
            }
            if let text = value as? String, key == "LensModel" {
                return Formatter.spacedMillimetres(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            // Dates are written "2024:01:05 12:34:56"
            if let text = value as? String, key == "DateTimeOriginal" || key == "DateTimeDigitized",
               let date = exifDateFormatter.date(from: text) {
                return displayDateFormatter.string(from: date)
            }
            return nil
        }
    }

    /// Number of pixels per unit of length at the focal plane, e.g. 5728.1 → "5728.1 px/in" (unit 2, the default),
    /// "px/cm" (unit 3), "px/mm" (unit 4) or "px/µm" (unit 5); the number alone for any other unit
    private static func formattedFocalPlaneResolution(_ value: Any, unit: Int?) -> String? {
        guard let number = (value as? NSNumber)?.doubleValue else { return nil }
        let text = ImageMetadataFormatter.plain((number * 10).rounded() / 10)
        switch unit ?? 2 {
        case 2:     return text + " px/in"
        case 3:     return text + " px/cm"
        case 4:     return text + " px/mm"
        case 5:     return text + " px/µm"
        default:    return text
        }
    }

    /// Area of the main subject, in pixels from the top-left corner of the image: its centre and, if any,
    /// its size, e.g. [2016, 1512] → "(2016, 1512)", [2016, 1512, 300] → "(2016, 1512) · ⌀ 300"
    /// and [2016, 1512, 2200, 1400] → "(2016, 1512) · 2200 × 1400"
    private static func formattedSubjectArea(_ value: Any) -> String? {
        guard let numbers = (value as? [Any])?.compactMap({ ($0 as? NSNumber)?.doubleValue }),
              (2...4).contains(numbers.count), numbers.count == (value as? [Any])?.count
        else { return nil }
        let text = numbers.map { ImageMetadataFormatter.plain($0) }
        let centre = "(" + text[0] + ", " + text[1] + ")"
        switch numbers.count {
        case 3:     return centre + " · ⌀ " + text[2]
        case 4:     return centre + " · " + text[2] + " × " + text[3]
        default:    return centre
        }
    }

    /// Channels of the image data, given as four bytes: [1, 2, 3, 0] → "YCbCr", [4, 5, 6, 0] → "RGB"
    /// and, for any other combination, the channels written one by one with "–" for an unused one
    private static func formattedComponents(_ value: Any) -> String? {
        let bytes: [Int]
        if let numbers = value as? [Any] {
            bytes = numbers.compactMap { ($0 as? NSNumber)?.intValue }
        } else if let data = value as? Data {
            bytes = data.map { Int($0) }
        } else {
            return nil
        }
        let names = [0: "–", 1: "Y", 2: "Cb", 3: "Cr", 4: "R", 5: "G", 6: "B"]
        guard bytes.isEmpty == false, bytes.allSatisfy({ names[$0] != nil }) else { return nil }
        let used = Array(bytes.reversed().drop(while: { $0 == 0 }).reversed())
        switch used {
        case [1, 2, 3]: return "YCbCr"
        case [4, 5, 6]: return "RGB"
        default:        return bytes.compactMap { names[$0] }.joined(separator: " ")
        }
    }

    /// F-number written with up to two decimals: 1.78 → "ƒ1.78", 2.8 → "ƒ2.8" and 4 → "ƒ4"
    private static func fNumber(_ value: Double) -> String {
        return "ƒ" + ImageMetadataFormatter.plain((value * 100).rounded() / 100)
    }

    /// Shutter speed from its APEX value: Tv = -log2(t), e.g. 8 → "1/256 s" and -1 → "2 s"
    private static func shutterSpeed(fromAPEX value: Double) -> String? {
        let time = pow(2, -value)
        guard time.isFinite, time > 0 else { return nil }
        return time < 1 ? "1/\(Int((1 / time).rounded())) s" : ImageMetadataFormatter.plain((time * 10).rounded() / 10) + " s"
    }

    /// Brightness of the scene from its APEX value: B = 3.426 cd/m² × 2^Bv (3.426 cd/m² being 1 foot-lambert)
    private static func brightness(fromAPEX value: Double) -> String? {
        let luminance = 3.426 * pow(2, value)
        guard luminance.isFinite else { return nil }
        let digits = luminance < 10 ? 1 : 0
        return ImageMetadataFormatter.plain((value * 10).rounded() / 10) + " EV ("
            + ImageMetadataFormatter.fixed(luminance, digits: digits) + " cd/m²)"
    }

    /// Keys whose numbers are the values of an enumeration, with the values whose meaning is translated
    private static let meanings: [String: Set<Int>] = [
        "ColorSpace": [1, 65535],
        "Contrast": [0, 1, 2],
        "CustomRendered": [0, 1],
        "GainControl": [0, 1, 2, 3, 4],
        "LightSource": [0, 1, 2, 3, 4, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 255],
        "Saturation": [0, 1, 2],
        "FileSource": [1, 2, 3],
        "DigitalZoomRatio": [0],
        "SceneType": [1],
        "CompositeImage": [0, 1, 2, 3],
        "SensitivityType": [0, 1, 2, 3, 4, 5, 6, 7],
        "SceneCaptureType": [0, 1, 2, 3],
        "SensingMethod": [1, 2, 3, 4, 5, 7, 8],
        "Sharpness": [0, 1, 2],
        "SubjectDistRange": [0, 1, 2, 3],
        "WhiteBalance": [0, 1]
    ]

    /// Meaning of the number of an enumeration, if it has one
    private static func meaning(of number: Double, forKey key: String) -> String? {
        guard let value = Int(exactly: number), meanings[key]?.contains(value) == true else { return nil }
        let localizationKey = "imageExif\(key)_\(value)"
        let text = Bundle.main.localizedString(forKey: localizationKey, value: nil, table: nil)
        return text.caseInsensitiveCompare(localizationKey) == .orderedSame ? nil : text
    }

    /// Description of the value of the flash, a bit field: bit 0 tells if the flash fired, bits 1 and 2 the detection
    /// of the strobe return light, bits 3 and 4 the mode, bit 5 the absence of flash function, bit 6 the red-eye reduction.
    /// E.g. 0 → "Flash did not fire", 25 → "Flash fired, auto mode", 89 → "Flash fired, auto mode, red-eye reduction mode"
    private static func flash(_ value: Int) -> String? {
        guard (0...127).contains(value) else { return nil }
        let fired = value & 1 != 0
        let returnLight = (value >> 1) & 3         // 2: not detected, 3: detected
        let mode = (value >> 3) & 3                // 1 and 2: compulsory, 3: auto
        let hasNoFunction = value & 0x20 != 0
        let redEyeReduction = value & 0x40 != 0

        // The detection of the return light alone describes the flash which fired in the default mode
        if fired, hasNoFunction == false, mode == 0, redEyeReduction == false, returnLight >= 2 {
            return returnLight == 2
                ? String(localized: "imageExifFlash_returnNotDetected", comment: "Strobe return light not detected")
                : String(localized: "imageExifFlash_returnDetected", comment: "Strobe return light detected")
        }
        var parts = [String]()
        if hasNoFunction {
            parts.append(String(localized: "imageExifFlash_noFunction", comment: "No flash function"))
        } else if fired {
            parts.append(String(localized: "imageExifFlash_fired", comment: "Flash fired"))
        } else {
            parts.append(String(localized: "imageExifFlash_notFired", comment: "Flash did not fire"))
        }
        switch mode {
        case 1, 2:
            parts.append(String(localized: "imageExifFlash_compulsory", comment: "compulsory flash mode"))
        case 3:
            parts.append(String(localized: "imageExifFlash_auto", comment: "auto mode"))
        default:
            break
        }
        if returnLight == 2 {
            parts.append(String(localized: "imageExifFlash_partReturnNotDetected", comment: "strobe return light not detected"))
        } else if returnLight == 3 {
            parts.append(String(localized: "imageExifFlash_partReturnDetected", comment: "strobe return light detected"))
        }
        if redEyeReduction {
            parts.append(String(localized: "imageExifFlash_redEye", comment: "red-eye reduction mode"))
        }
        let separator = String(localized: "imageExifFlash_separator", comment: "Separator of the parts of the description of the flash")
        return parts.joined(separator: separator)
    }

    /// Meaning of the value of the exposure program
    private static func exposureProgram(_ value: Int) -> String? {
        switch value {
        case 0: return String(localized: "imageExifExposureProgram_0", comment: "Not defined")
        case 1: return String(localized: "imageExifExposureProgram_1", comment: "Manual")
        case 2: return String(localized: "imageExifExposureProgram_2", comment: "Normal program")
        case 3: return String(localized: "imageExifExposureProgram_3", comment: "Aperture priority")
        case 4: return String(localized: "imageExifExposureProgram_4", comment: "Shutter priority")
        case 5: return String(localized: "imageExifExposureProgram_5", comment: "Creative program")
        case 6: return String(localized: "imageExifExposureProgram_6", comment: "Action program")
        case 7: return String(localized: "imageExifExposureProgram_7", comment: "Portrait mode")
        case 8: return String(localized: "imageExifExposureProgram_8", comment: "Landscape mode")
        default: return nil
        }
    }

    /// Meaning of the value of the metering mode
    private static func meteringMode(_ value: Int) -> String? {
        switch value {
        case 0: return String(localized: "imageExifMeteringMode_0", comment: "Unknown")
        case 1: return String(localized: "imageExifMeteringMode_1", comment: "Average")
        case 2: return String(localized: "imageExifMeteringMode_2", comment: "Center-weighted average")
        case 3: return String(localized: "imageExifMeteringMode_3", comment: "Spot")
        case 4: return String(localized: "imageExifMeteringMode_4", comment: "Multi-spot")
        case 5: return String(localized: "imageExifMeteringMode_5", comment: "Pattern")
        case 6: return String(localized: "imageExifMeteringMode_6", comment: "Partial")
        case 255: return String(localized: "imageExifMeteringMode_255", comment: "Other")
        default: return nil
        }
    }

    /// Meaning of the value of the exposure mode
    private static func exposureMode(_ value: Int) -> String? {
        switch value {
        case 0: return String(localized: "imageExifExposureMode_0", comment: "Auto exposure")
        case 1: return String(localized: "imageExifExposureMode_1", comment: "Manual exposure")
        case 2: return String(localized: "imageExifExposureMode_2", comment: "Auto bracket")
        default: return nil
        }
    }

    /// "SubjectDistRange" → "Subject Dist Range", "ISOSpeed" → "ISO Speed"
    static func humanized(_ key: String) -> String {
        return ImageMetadataFormatter.humanized(key)
    }
}
