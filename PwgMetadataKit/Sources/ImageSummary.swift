//
//  ImageSummary.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 29/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Summary of a photo or a video, presented at the top of the metadata table:
//  the name and format of the original file, the camera, the lens, the size of the image
//  and the main settings of the shot, or the frame rate and the duration of a video.
//

import Foundation
import ImageIO
import PDFKit

public struct ImageSummary: Sendable {
    /// What the data of the image tell, even before any file is read
    public struct Source: Sendable, Equatable {
        public var fileName = ""
        public var fileSize: Int64 = 0
        public var width = 0
        public var height = 0
        public var isVideo = false
        public var isPDF = false
        public var duration: TimeInterval?
        public var frameRate: Float?

        public init() {}

        /// What a file tells: its name, its size and the dimensions of its image
        public init(fileURL: URL) {
            fileName = fileURL.lastPathComponent
            fileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            if let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                width = (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue ?? 0
                height = (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue ?? 0
            }
        }
    }

    public var source = Source()
    public var exif: ImageExif?
    public var pdf: PdfInfo?

    public init() {}

    /// Written in place of a value which is not available
    public static let unavailable = "-"


    // MARK: - Original File
    /// Name of the original file without its extension
    public var title: String {
        return (source.fileName as NSString).deletingPathExtension
    }

    /// Format of the original file, e.g. "HEIC", "JPEG" or "GIF"
    public var format: String {
        let fileExtension = (source.fileName as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "jpg", "jpeg": return "JPEG"
        case "tif", "tiff": return "TIFF"
        default:            return fileExtension.uppercased()
        }
    }


    // MARK: - Camera and Lens
    /// Make and model of the camera, without repeating the make if the model starts with it
    public var camera: String {
        let make = exif?.value(forKey: "Make")?.trimmingCharacters(in: .whitespaces) ?? ""
        let model = exif?.value(forKey: "Model")?.trimmingCharacters(in: .whitespaces) ?? ""
        if model.isEmpty {
            return make.isEmpty ? String(localized: "imageSummary_noCamera", bundle: .module, comment: "No camera information") : make
        }
        return make.isEmpty || Self.model(model, containsPartOf: make) ? model : make + " " + model
    }

    /// Words of a company name which do not name the maker
    private static let companyWords: Set<String> = ["corporation", "corp", "company", "inc", "ltd", "limited", "gmbh",
                                                    "and", "the", "group", "holdings", "electronics", "imaging"]

    /// A part of the make is in the model, e.g. "NIKON CORPORATION" in "NIKON D90": the model alone names the camera
    private static func model(_ model: String, containsPartOf make: String) -> Bool {
        let model = model.lowercased()
        let words = make.lowercased().split(whereSeparator: { $0.isLetter == false && $0.isNumber == false })
            .map(String.init).filter { $0.count >= 3 && companyWords.contains($0) == false }
        return words.contains { model.contains($0) }
    }

    /// Model of the lens without the model of the camera which often starts it, e.g. "iPhone X back dual camera 4mm f/1.8"
    /// is written "Back dual camera 4mm f/1.8"
    public var lens: String {
        guard var lens = exif?.value(forKey: "LensModel")?.trimmingCharacters(in: .whitespaces), lens.isEmpty == false
        else { return String(localized: "imageSummary_noLens", bundle: .module, comment: "No lens information") }
        for prefix in [exif?.value(forKey: "Model"), exif?.value(forKey: "Make")] {
            guard let prefix = prefix?.trimmingCharacters(in: .whitespaces), prefix.isEmpty == false,
                  lens.lowercased().hasPrefix(prefix.lowercased()), lens.count > prefix.count
            else { continue }
            let rest = lens.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            if rest.isEmpty == false {
                lens = rest.prefix(1).uppercased() + rest.dropFirst()
                break
            }
        }
        return lens
    }

    /// Number of pixels, dimensions and size of the original file, e.g. "12 MP • 4032 × 3024 • 1.2 MB"
    public var details: String {
        var parts = [String]()
        if source.width > 1, source.height > 1 {
            let megapixels = Double(source.width) * Double(source.height) / 1_000_000
            parts.append(ImageMetadataFormatter.plain(megapixels >= 10 ? megapixels.rounded()
                                                                        : (megapixels * 10).rounded() / 10) + " MP")
            parts.append("\(source.width) × \(source.height)")
        }
        if source.fileSize > 0 {
            parts.append(Self.fileSize(source.fileSize))
        }
        return parts.isEmpty ? Self.unavailable : parts.joined(separator: " • ")
    }

    /// Size in KB, or in MB or GB with one decimal
    public static func fileSize(_ bytes: Int64) -> String {
        let size = Double(bytes)
        if size < 1_000_000 { return ImageMetadataFormatter.plain((size / 1_000).rounded()) + " KB" }
        if size < 1_000_000_000 { return ImageMetadataFormatter.fixed(size / 1_000_000, digits: 1) + " MB" }
        return ImageMetadataFormatter.fixed(size / 1_000_000_000, digits: 1) + " GB"
    }


    // MARK: - Settings of the Shot
    /// The flash fired
    public var flashFired: Bool {
        return exif?.flashFired ?? false
    }

    /// ISO speed, focal length (35 mm), exposure bias, f-number and exposure time
    public var shooting: [String] {
        let iso = ["ISOSpeedRatings", "ISOSpeed", "RecommendedExposureIndex", "StandardOutputSensitivity"]
            .lazy.compactMap { exif?.value(forKey: $0) }.first
        let values = [iso,
                      exif?.value(forKey: "FocalLenIn35mmFilm"),
                      exif?.value(forKey: "ExposureBiasValue"),
                      exif?.value(forKey: "FNumber"),
                      exif?.value(forKey: "ExposureTime")]
        return values.map { $0 ?? Self.unavailable }
    }


    // MARK: - Video
    /// Frame rate and duration of a video
    public var video: [String] {
        let frameRate = source.frameRate.flatMap { $0 > 0 ? ImageMetadataFormatter.plain(Double(($0 * 100).rounded() / 100)) + " fps" : nil }
        return [frameRate ?? Self.unavailable, Self.duration(source.duration) ?? Self.unavailable]
    }

    /// Minutes and seconds, or hours, minutes and seconds beyond an hour
    public static func duration(_ duration: TimeInterval?) -> String? {
        guard let duration = duration, duration.isFinite, duration > 0 else { return nil }
        let seconds = Int(duration.rounded())
        if seconds < 3600 {
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }


    // MARK: - PDF
    /// Title of the document, or a text telling it has none; unknown until the document is read
    public var pdfTitle: String {
        guard let pdf = pdf else { return Self.unavailable }
        return pdf.title ?? String(localized: "imagePdf_noTitle", bundle: .module, comment: "No title")
    }

    public var pdfAuthor: String {
        guard let pdf = pdf else { return Self.unavailable }
        return pdf.author ?? String(localized: "imagePdf_noAuthor", bundle: .module, comment: "No author information")
    }

    /// Number of pages, size of the first page and size of the file, e.g. "5 pages • 21.59 × 27.94 cm • 12.1 MB"
    public var pdfDetails: String {
        var parts = [String]()
        if let pdf = pdf {
            if pdf.pageCount > 0 {
                parts.append(String.localizedStringWithFormat(
                    String(localized: "pdfPageCount", bundle: .module, comment: "%lld pages"), pdf.pageCount))
            }
            if let size = pdf.pageSize, size.width > 0, size.height > 0 {
                let width = ImageMetadataFormatter.fixed(Double(size.width) * 2.54 / 72, digits: 2)
                let height = ImageMetadataFormatter.fixed(Double(size.height) * 2.54 / 72, digits: 2)
                parts.append("\(width) × \(height) cm")
            }
        }
        if source.fileSize > 0 {
            parts.append(Self.fileSize(source.fileSize))
        }
        return parts.isEmpty ? Self.unavailable : parts.joined(separator: " • ")
    }

    public var pdfCreationDate: String {
        return pdf?.creationDate.map { Self.dateFormatter.string(from: $0) } ?? Self.unavailable
    }

    public var pdfModificationDate: String {
        return pdf?.modificationDate.map { Self.dateFormatter.string(from: $0) } ?? Self.unavailable
    }

    public var pdfProducer: String {
        return pdf?.producer ?? Self.unavailable
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}


// MARK: - PDF Document
/// What the document of a PDF file tells about itself
public struct PdfInfo: Sendable {
    public var title: String?
    public var author: String?
    public var producer: String?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var pageCount = 0
    /// Size of the first page in points (1/72 inch), as it is displayed
    public var pageSize: CGSize?

    public init() {}

    /// Reads the attributes of the document of a file, nil if it cannot be opened
    public static func read(from url: URL) -> PdfInfo? {
        guard let document = PDFDocument(url: url) else { return nil }
        let attributes = document.documentAttributes ?? [:]
        func text(_ key: PDFDocumentAttribute) -> String? {
            let value = (attributes[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return value?.isEmpty == false ? value : nil
        }
        var info = PdfInfo()
        info.title = text(.titleAttribute)
        info.author = text(.authorAttribute)
        info.producer = text(.producerAttribute)
        info.creationDate = attributes[PDFDocumentAttribute.creationDateAttribute] as? Date
        info.modificationDate = attributes[PDFDocumentAttribute.modificationDateAttribute] as? Date
        info.pageCount = document.pageCount
        if let page = document.page(at: 0) {
            let size = page.bounds(for: .mediaBox).size
            info.pageSize = page.rotation % 180 == 0 ? size : CGSize(width: size.height, height: size.width)
        }
        return info
    }
}
