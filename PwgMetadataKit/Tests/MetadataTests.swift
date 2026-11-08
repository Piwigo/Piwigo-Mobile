//
//  MetadataTests.swift
//  PwgMetadataKitTests
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import XCTest
import ImageIO
import UniformTypeIdentifiers
@testable import PwgMetadataKit

final class MetadataTests: XCTestCase
{
    /// A small JPEG file with the metadata given
    private func makeJPEG(properties: [String: Any], named name: String = "IMG_0042.jpg") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let width = 8, height = 6
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private var phoneProperties: [String: Any] {
        return [
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Apple",
                kCGImagePropertyTIFFModel as String: "iPhone 16 Pro"],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifLensModel as String: "iPhone 16 Pro back camera 6.86mm f/1.78",
                kCGImagePropertyExifFNumber as String: 1.78,
                kCGImagePropertyExifExposureTime as String: 1.0 / 727.0,
                kCGImagePropertyExifISOSpeedRatings as String: [80, 80],
                kCGImagePropertyExifFocalLenIn35mmFilm as String: 24,
                kCGImagePropertyExifExposureBiasValue as String: 0,
                kCGImagePropertyExifFlash as String: 25,
                kCGImagePropertyExifLensSpecification as String: [2.2, 9, 1.78, 2.8]],
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 52.0001,
                kCGImagePropertyGPSLatitudeRef as String: "S",
                kCGImagePropertyGPSLongitude as String: 4.354,
                kCGImagePropertyGPSLongitudeRef as String: "W"]
        ]
    }

    func testSummaryOfAPhoto() throws {
        let url = try makeJPEG(properties: phoneProperties)
        let metadata = ImageMetadata.read(in: [url])
        var summary = ImageSummary()
        summary.source = ImageSummary.Source(fileURL: url)
        summary.exif = metadata.exif

        XCTAssertEqual(summary.title, "IMG_0042")
        XCTAssertEqual(summary.format, "JPEG")
        XCTAssertEqual(summary.camera, "Apple iPhone 16 Pro")
        XCTAssertEqual(summary.lens, "Back camera 6.86 mm f/1.78")
        XCTAssertEqual(summary.shooting, ["ISO 80", "24 mm", "0 EV", "ƒ1.78", "1/727 s"])
        XCTAssertTrue(summary.flashFired)
        XCTAssertEqual(summary.source.width, 8)
        XCTAssertEqual(summary.source.height, 6)
        XCTAssertGreaterThan(summary.source.fileSize, 0)
        XCTAssertTrue(summary.details.contains("8 × 6"))
    }

    func testMakeRepeatedInTheModelIsNotWrittenTwice() throws {
        let url = try makeJPEG(properties: [
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "NIKON CORPORATION",
                kCGImagePropertyTIFFModel as String: "NIKON D90"]])
        var summary = ImageSummary()
        summary.exif = ImageMetadata.read(in: [url]).exif
        XCTAssertEqual(summary.camera, "NIKON D90")
    }

    func testGpsCoordinateHasTheSignOfItsReference() throws {
        let url = try makeJPEG(properties: phoneProperties)
        let gps = try XCTUnwrap(ImageMetadata.read(in: [url]).gps)
        XCTAssertEqual(try XCTUnwrap(gps.latitude), -52.0001, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(gps.longitude), -4.354, accuracy: 1e-6)
    }

    func testExposureCompensationIsWrittenAsAFraction() {
        typealias Formatter = ImageMetadataFormatter
        XCTAssertEqual(Formatter.exposureCompensation(0), "0")
        XCTAssertEqual(Formatter.exposureCompensation(1.0 / 3.0), "+1/3")
        XCTAssertEqual(Formatter.exposureCompensation(-2.0 / 3.0), "-2/3")
        XCTAssertEqual(Formatter.exposureCompensation(1.333), "+1 1/3")
        XCTAssertEqual(Formatter.exposureCompensation(-1.5), "-1 1/2")
    }

    func testLensSpecification() {
        typealias Formatter = ImageMetadataFormatter
        XCTAssertEqual(Formatter.formattedLensSpecification([24, 70, 2.8, 4] as [Any]), "24–70 mm f/2.8–4.0")
        XCTAssertEqual(Formatter.formattedLensSpecification([50, 50, 1.8, 1.8] as [Any]), "50 mm f/1.8")
        XCTAssertNil(Formatter.formattedLensSpecification([0, 70, 2.8, 4] as [Any]))
    }

    func testSpacedMillimetres() {
        typealias Formatter = ImageMetadataFormatter
        XCTAssertEqual(Formatter.spacedMillimetres("back camera 4mm f/1.8"), "back camera 4 mm f/1.8")
        XCTAssertEqual(Formatter.spacedMillimetres("24-70mm"), "24-70 mm")
        XCTAssertEqual(Formatter.spacedMillimetres("4 mm"), "4 mm")
    }

    func testSectionsOfTheTable() throws {
        let url = try makeJPEG(properties: phoneProperties)
        var model = MetadataTableModel()

        // While the file is being read
        XCTAssertEqual(model.sections, [.summary, .loading])

        // With the metadata of the file
        model.hasLocation = true
        model.update(with: ImageMetadata.read(in: [url]), isKnown: true)
        let sections = model.sections
        XCTAssertEqual(Array(sections.prefix(2)), [.summary, .location])
        // The themes come in a fixed order whatever the directories of the file which feed them
        XCTAssertEqual(Array(sections.dropFirst(2)), [.group(.cameraLens), .group(.exposure), .group(.location), .group(.image)])
        XCTAssertFalse(sections.contains(.empty))

        // Without any
        model.hasLocation = false
        model.update(with: ImageMetadata(), isKnown: true)
        XCTAssertEqual(model.sections, [.summary, .empty])
    }

    func testListShowsAMoreRowOnlyFromSevenEntries() {
        func entries(_ count: Int) -> [ImageMetadataEntry] {
            return (0..<count).map { ImageMetadataEntry(key: "K\($0)", name: "Key \($0)", value: "\($0)") }
        }
        XCTAssertFalse(MetadataList(entries: entries(6)).showsMoreRow)
        XCTAssertEqual(MetadataList(entries: entries(6)).rowCount, 6)

        var list = MetadataList(entries: entries(7))
        XCTAssertTrue(list.showsMoreRow)
        XCTAssertEqual(list.displayedCount, 5)
        XCTAssertEqual(list.rowCount, 6)
        list.isExpanded = true
        XCTAssertEqual(list.rowCount, 7)
    }

    func testHeaderOfAGroup() throws {
        let url = try makeJPEG(properties: phoneProperties)
        var model = MetadataTableModel()
        model.update(with: ImageMetadata.read(in: [url]), isKnown: true)
        let header = model.header(of: .group(.cameraLens))
        XCTAssertTrue(header.title.hasPrefix(MetadataGroup.cameraLens.title))
        XCTAssertFalse(header.text.isEmpty)
        // Only the number of items is told: the source of the metadata is not
        XCTAssertFalse(header.text.contains("Exif"))
    }

    func testMetadataOfSeveralDirectoriesShareATheme() {
        var metadata = ImageMetadata()
        metadata.iptc = ImageIptc(entries: [
            ImageMetadataEntry(key: "Caption/Abstract", name: "Caption", value: "A caption"),
            ImageMetadataEntry(key: "Byline", name: "Creator", value: "Eddy"),
            ImageMetadataEntry(key: "City", name: "City", value: "Grenoble"),
            ImageMetadataEntry(key: "DateCreated", name: "Date Created", value: "5 Jan 2024")])
        metadata.gps = ImageGps(version: "2.2", entries: [
            ImageMetadataEntry(key: "Latitude", name: "Latitude", value: "45° N"),
            ImageMetadataEntry(key: "DateStamp", name: "Date Stamp", value: "5 Jan 2024")],
                                latitude: 45, longitude: 5)
        var model = MetadataTableModel()
        model.update(with: metadata, isKnown: true)
        XCTAssertEqual(model.sections, [.summary, .group(.description), .group(.dateTime), .group(.location),
                                        .group(.rights)])
        XCTAssertEqual(model.list(of: .group(.location)).entries.map(\.key), ["Latitude", "City", "GPSVersion"])
        XCTAssertEqual(model.list(of: .group(.dateTime)).entries.map(\.key), ["DateStamp", "DateCreated"])
    }

    func testListOfTheMetadataIsGroupedAndSorted() throws {
        let url = try makeJPEG(properties: phoneProperties)
        var model = MetadataTableModel()
        model.update(with: ImageMetadata.read(in: [url]), isKnown: true)
        let location = MetadataLocation(latitude: 52.0116, longitude: -4.3571, place: "Delft", address: "Markt 57")
        let text = model.asciiList(location: location)
        let blocks = text.components(separatedBy: "\n\n")
        XCTAssertEqual(blocks.first?.components(separatedBy: "\n").first, "[Location]")
        XCTAssertTrue(text.contains("52.011600, -4.357100"))
        XCTAssertTrue(text.contains("Delft, Markt 57"))
        // The sections come in the order of the table, and their rows are sorted by name
        let titles = blocks.compactMap { $0.components(separatedBy: "\n").first }
        XCTAssertEqual(titles.firstIndex(of: "[Location]"), 0)
        XCTAssertEqual(titles.contains("[\(MetadataGroup.cameraLens.title)]"), true)
        for block in blocks {
            let names = block.components(separatedBy: "\n").dropFirst().map { $0.components(separatedBy: ": ")[0] }
            XCTAssertEqual(names, names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        }
    }

    func testJsonObjectKeepsTheOrderOfTheSections() throws {
        let url = try makeJPEG(properties: phoneProperties)
        var model = MetadataTableModel()
        model.update(with: ImageMetadata.read(in: [url]), isKnown: true)
        let text = model.jsonObject(location: MetadataLocation(latitude: 1, longitude: 2, place: "A \"quoted\" place"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertNotNil(object["CameraLens"] as? [String: Any])
        XCTAssertEqual((object["Location"] as? [String: Any])?["place"] as? String, "A \"quoted\" place")
        // Location, then the other groups; the GPS metadata join the location of the map
        let location = try XCTUnwrap(text.range(of: "\"Location\""))
        let camera = try XCTUnwrap(text.range(of: "\"CameraLens\""))
        XCTAssertLessThan(location.lowerBound, camera.lowerBound)
        XCTAssertNotNil((object["Location"] as? [String: Any])?["Latitude"])
        XCTAssertEqual(text.components(separatedBy: "\"Location\"").count, 2)
        XCTAssertEqual(MetadataTableModel().jsonObject(), "{}")
    }
}
