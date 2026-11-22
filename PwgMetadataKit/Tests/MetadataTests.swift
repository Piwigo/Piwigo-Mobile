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

    /// A JPEG whose only metadata is an XMP packet: ImageIO writes the IPTC block as well, which is removed
    private func makeJPEG(xmp packet: String) throws -> URL {
        let url = try makeJPEG(properties: [:])
        let metadata = try XCTUnwrap(CGImageMetadataCreateFromXMPData(Data(packet.utf8) as CFData))
        let context = CGContext(data: nil, width: 8, height: 6, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImageAndMetadata(destination, context.makeImage()!, metadata, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        // Drop the segments of the Photoshop resources (marker 0xED), which hold the IPTC block
        let data = try Data(contentsOf: url)
        var stripped = data.prefix(2), index = 2
        while index + 4 <= data.count, data[index] == 0xFF {
            let marker = data[index + 1]
            if marker == 0xDA { stripped.append(data.suffix(from: index)); break }
            let length = Int(data[index + 2]) << 8 | Int(data[index + 3])
            if marker != 0xED { stripped.append(data[index..<(index + 2 + length)]) }
            index += 2 + length
        }
        try stripped.write(to: url)
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

    func testXmpOnlyFileGivesItsMetadata() throws {
        let packet = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:xmp="http://ns.adobe.com/xap/1.0/" \
        xmlns:xmpRights="http://ns.adobe.com/xap/1.0/rights/" xmp:Rating="4" xmp:CreatorTool="Probe 1.0" \
        xmp:CreateDate="2024-01-05T12:34:56+01:00" xmpRights:Marked="True" xmpRights:WebStatement="https://example.org/rights">
        <dc:title><rdf:Alt><rdf:li xml:lang="x-default">The title</rdf:li></rdf:Alt></dc:title>
        <dc:subject><rdf:Bag><rdf:li>alpha</rdf:li><rdf:li>beta</rdf:li></rdf:Bag></dc:subject>
        </rdf:Description></rdf:RDF></x:xmpmeta>
        """
        let url = try makeJPEG(xmp: packet)
        let metadata = ImageMetadata.read(in: [url])
        var model = MetadataTableModel()
        model.update(with: metadata, isKnown: true)

        // ImageIO gives the title, keywords and rating with the IPTC metadata
        let description = model.list(of: .group(.description)).entries
        XCTAssertEqual(description.first(where: { $0.key == "ObjectName" })?.value, "The title")
        XCTAssertEqual(description.first(where: { $0.key == "Keywords" })?.value, "alpha; beta")
        XCTAssertNotNil(description.first(where: { $0.key == "StarRating" }))
        // The rest is read from the packet
        let dates = model.list(of: .group(.dateTime)).entries
        XCTAssertTrue(try XCTUnwrap(dates.first(where: { $0.key == "DateDigitized" })).value.hasSuffix("+01:00"))
        let rights = model.list(of: .group(.rights)).entries
        XCTAssertEqual(rights.first(where: { $0.key == "Marked" })?.value, "Yes")
        XCTAssertEqual(rights.first(where: { $0.key == "WebStatement" })?.value, "https://example.org/rights")
        XCTAssertEqual(model.list(of: .group(.image)).entries.first(where: { $0.key == "CreatorTool" })?.value, "Probe 1.0")
    }

    func testMomentsAreParsedAndWrittenWithTheirOffset() throws {
        typealias Moment = ImageDatesReader.Moment
        XCTAssertTrue(try XCTUnwrap(Moment(iso: "2024-01-05T12:34:56+01:00")).text.hasSuffix("+01:00"))
        XCTAssertTrue(try XCTUnwrap(Moment(iso: "2024-01-05T12:34Z")).text.hasSuffix(" UTC"))
        XCTAssertTrue(try XCTUnwrap(Moment(iso: "2024-01-05T12:34:56.789")).text.contains(":34:56.789"))
        XCTAssertFalse(try XCTUnwrap(Moment(iso: "2024-01-05")).text.contains(":"))
        XCTAssertNil(Moment(iso: "last Tuesday"))
        XCTAssertNil(Moment(iso: "2024-13-05"))
        // Exif, with sub-seconds and offset which have keys of their own
        let exif = try XCTUnwrap(Moment(exif: "2015:10:11 14:23:17", subsec: "538", offset: "+09:00"))
        XCTAssertTrue(exif.text.contains(":23:17.538") && exif.text.hasSuffix("+09:00"))
        // IPTC writes the offset without a colon
        let iptc = try XCTUnwrap(Moment(iptcDate: "20151011", time: "142317+0900"))
        XCTAssertEqual(iptc.offset, "+09:00")
        XCTAssertTrue(exif.isSameMoment(as: iptc))
        // The GPS tells UTC
        XCTAssertEqual(Moment(gpsDate: "2015:10:11", time: "05:23:11")?.offset, "UTC")
        XCTAssertFalse(exif.isSameMoment(as: try XCTUnwrap(Moment(iptcDate: "20151011", time: "142318"))))
    }

    func testDatesAreMergedByMeaning() throws {
        let url = try makeJPEG(properties: [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2015:10:11 14:23:17",
                kCGImagePropertyExifSubsecTimeOriginal as String: "538",
                kCGImagePropertyExifDateTimeDigitized as String: "2015:10:11 14:23:17",
                "OffsetTimeOriginal": "+09:00"],
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFDateTime as String: "2015:10:12 08:00:00"],
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSDateStamp as String: "2015:10:11", kCGImagePropertyGPSTimeStamp as String: "05:23:11"],
            kCGImagePropertyIPTCDictionary as String: [
                kCGImagePropertyIPTCDateCreated as String: "20151011", kCGImagePropertyIPTCTimeCreated as String: "142317+0900"]])
        var model = MetadataTableModel()
        model.update(with: ImageMetadata.read(in: [url]), isKnown: true)
        let dates = model.list(of: .group(.dateTime)).entries
        // One row for each moment, the date, time, sub-seconds and offset together
        XCTAssertEqual(dates.map(\.key), ["DateTaken", "DateDigitized", "DateModified", "GPSDateTime"])
        XCTAssertTrue(dates[0].value.contains(":23:17.538") && dates[0].value.hasSuffix("+09:00"))
        XCTAssertTrue(dates[3].value.hasSuffix("UTC"))
        // The rows of the directories are not shown again
        XCTAssertNil(model.list(of: .group(.dateTime)).entries.first(where: { $0.key == "TimeCreated" }))
    }

    func testAnotherMomentOfADirectoryHasARowOfItsOwn() throws {
        typealias Moment = ImageDatesReader.Moment
        typealias Candidate = ImageDatesReader.Candidate
        let exif = Candidate(source: "Exif", moment: try XCTUnwrap(Moment(iso: "2015-10-11T14:23:17")), consumed: ["exif.A"])
        let same = Candidate(source: "IPTC", moment: try XCTUnwrap(Moment(iso: "2015-10-11T14:23:17+09:00")), consumed: ["iptc.B"])
        let other = Candidate(source: "XMP", moment: try XCTUnwrap(Moment(iso: "2020-03-04T05:06:07")), consumed: [])
        let merged = ImageDatesReader.merge("DateDigitized", "Date Digitized", [exif, same, other])
        XCTAssertEqual(merged.entries.map(\.key), ["DateDigitized", "DateDigitized.XMP"])
        XCTAssertEqual(merged.entries.map(\.name), ["Date Digitized", "Date Digitized (XMP)"])
        // The directory which agrees completes the moment with its offset
        XCTAssertTrue(merged.entries[0].value.hasSuffix("+09:00"))
        XCTAssertEqual(merged.consumed, ["exif.A", "iptc.B"])
    }

    // MARK: - Coordinates
    func testCoordinatesAreParsedInAllFormats() throws {
        func parsed(_ text: String) -> (Double, Double)? {
            return GeographicCoordinates.parse(text).map { ($0.latitude, $0.longitude) }
        }
        // Decimal degrees
        for text in ["48.8566, 2.3522", "48.8566 2.3522", "48.8566,2.3522", "48,8566 2,3522", "48.8566;2.3522",
                     "48.8566° N, 2.3522° E", "N 48.8566 E 2.3522", "2.3522° E 48.8566° N", "+48.8566 +2.3522"] {
            let value = try XCTUnwrap(parsed(text), text)
            XCTAssertEqual(value.0, 48.8566, accuracy: 1e-6, text)
            XCTAssertEqual(value.1, 2.3522, accuracy: 1e-6, text)
        }
        // Degrees and decimal minutes
        let ddm = try XCTUnwrap(parsed("N 48° 51.396' E 2° 21.132'"))
        XCTAssertEqual(ddm.0, 48.8566, accuracy: 1e-6)
        XCTAssertEqual(ddm.1, 2.3522, accuracy: 1e-6)
        // Degrees, minutes and seconds, with typographic marks and the hemisphere after
        for text in ["48°51'23.76\"N 2°21'7.92\"E", "48° 51′ 23.76″ N, 2° 21′ 7.92″ E"] {
            let dms = try XCTUnwrap(parsed(text), text)
            XCTAssertEqual(dms.0, 48.8566, accuracy: 1e-6, text)
            XCTAssertEqual(dms.1, 2.3522, accuracy: 1e-6, text)
        }
        // South and west are negative
        let south = try XCTUnwrap(parsed("33.8688° S, 70.6693° W"))
        XCTAssertEqual(south.0, -33.8688, accuracy: 1e-6)
        XCTAssertEqual(south.1, -70.6693, accuracy: 1e-6)
        let signed = try XCTUnwrap(parsed("-33.8688,-70.6693"))
        XCTAssertEqual(signed.0, -33.8688, accuracy: 1e-6)
        XCTAssertEqual(signed.1, -70.6693, accuracy: 1e-6)
        // A single comma may separate the two numbers
        let comma = try XCTUnwrap(parsed("48,2"))
        XCTAssertEqual(comma.0, 48, accuracy: 1e-6)
        XCTAssertEqual(comma.1, 2, accuracy: 1e-6)
    }

    func testAddressesAndInvalidCoordinatesAreNotParsed() {
        for text in ["", "Paris", "10 rue de Rivoli 75001 Paris", "91.0, 2.0", "48.0, 181.0", "48.5", "48° 75' N 2° 3' E",
                     "N 48.0 N 2.0", "48.0 E 2.0 N N"] {
            XCTAssertNil(GeographicCoordinates.parse(text), text)
        }
    }

    func testCoordinatesAreWrittenWithTheirHemisphere() {
        XCTAssertEqual(GeographicCoordinates.string(latitude: 48.8566, longitude: 2.3522, digits: 4)
            .replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: ". ", with: ", "), "48.8566° N, 2.3522° E")
        XCTAssertTrue(GeographicCoordinates.string(latitude: -33.8688, longitude: -70.6693).hasSuffix("W"))
    }

    // MARK: - Writing the location
    private var locatedProperties: [String: Any] {
        return [kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2015:10:11 14:23:17",
                                                          kCGImagePropertyExifLensModel as String: "Test lens"],
                kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFMake as String: "Maker",
                                                          kCGImagePropertyTIFFModel as String: "Model"],
                kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 52.0001,
                                                         kCGImagePropertyGPSLatitudeRef as String: "N",
                                                         kCGImagePropertyGPSLongitude as String: 4.354,
                                                         kCGImagePropertyGPSLongitudeRef as String: "E",
                                                         kCGImagePropertyGPSAltitude as String: 12.5,
                                                         kCGImagePropertyGPSAltitudeRef as String: 0,
                                                         kCGImagePropertyGPSSpeed as String: 3.0,
                                                         kCGImagePropertyGPSSpeedRef as String: "K",
                                                         kCGImagePropertyGPSTrack as String: 90.0,
                                                         kCGImagePropertyGPSTrackRef as String: "T",
                                                         kCGImagePropertyGPSHPositioningError as String: 5.0,
                                                         kCGImagePropertyGPSImgDirection as String: 45.0,
                                                         kCGImagePropertyGPSImgDirectionRef as String: "T",
                                                         kCGImagePropertyGPSDateStamp as String: "2015:10:11",
                                                         kCGImagePropertyGPSTimeStamp as String: "13:23:17.00"]]
    }

    private func gpsProperties(of url: URL) throws -> [String: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        return properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
    }

    func testLocationIsMovedAndObsoleteTagsAreRemoved() throws {
        let source = try makeJPEG(properties: locatedProperties)
        let destination = source.deletingLastPathComponent().appendingPathComponent("moved.jpg")
        try ImageGpsWriter.write(latitude: -33.8688, longitude: -70.6693, from: source, to: destination)

        // New position, with the signs
        let gps = try gpsProperties(of: destination)
        XCTAssertEqual((gps[kCGImagePropertyGPSLatitude as String] as? Double) ?? 0, 33.8688, accuracy: 1e-4)
        XCTAssertEqual(gps[kCGImagePropertyGPSLatitudeRef as String] as? String, "S")
        XCTAssertEqual((gps[kCGImagePropertyGPSLongitude as String] as? Double) ?? 0, 70.6693, accuracy: 1e-4)
        XCTAssertEqual(gps[kCGImagePropertyGPSLongitudeRef as String] as? String, "W")
        let read = try XCTUnwrap(ImageMetadata.read(in: [destination]).gps)
        XCTAssertEqual(try XCTUnwrap(read.latitude), -33.8688, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(read.longitude), -70.6693, accuracy: 1e-4)

        // Altitude, speed, track and positioning error are gone, the others stay
        for key in [kCGImagePropertyGPSAltitude, kCGImagePropertyGPSAltitudeRef, kCGImagePropertyGPSSpeed,
                    kCGImagePropertyGPSSpeedRef, kCGImagePropertyGPSTrack, kCGImagePropertyGPSTrackRef,
                    kCGImagePropertyGPSHPositioningError] {
            XCTAssertNil(gps[key as String], key as String)
        }
        XCTAssertEqual(gps[kCGImagePropertyGPSDateStamp as String] as? String, "2015:10:11")
        XCTAssertNotNil(gps[kCGImagePropertyGPSTimeStamp as String])
        XCTAssertEqual((gps[kCGImagePropertyGPSImgDirection as String] as? Double) ?? 0, 45, accuracy: 1e-6)
    }

    func testOtherMetadataAndPixelsAreUnchanged() throws {
        let source = try makeJPEG(properties: locatedProperties)
        let destination = source.deletingLastPathComponent().appendingPathComponent("moved.jpg")
        try ImageGpsWriter.write(latitude: 35.6762, longitude: 139.6503, from: source, to: destination)

        func properties(_ url: URL) throws -> [String: Any] {
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        }
        let before = try properties(source), after = try properties(destination)
        for key in [kCGImagePropertyExifDictionary, kCGImagePropertyTIFFDictionary] {
            let old = try XCTUnwrap(before[key as String] as? [String: Any])
            let new = try XCTUnwrap(after[key as String] as? [String: Any])
            for (name, value) in old {
                XCTAssertEqual("\(new[name] ?? "missing")", "\(value)", "\(key) \(name)")
            }
        }
        XCTAssertEqual(before[kCGImagePropertyPixelWidth as String] as? Int, after[kCGImagePropertyPixelWidth as String] as? Int)

        // The image data is copied, not encoded again: the same pixels come out
        func pixels(_ url: URL) throws -> Data {
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            return try XCTUnwrap(image.dataProvider?.data as Data?)
        }
        XCTAssertEqual(try pixels(source), try pixels(destination))
    }

    func testLocationIsAddedToAFileWithoutGps() throws {
        let source = try makeJPEG(properties: [kCGImagePropertyExifDictionary as String:
                                                [kCGImagePropertyExifDateTimeOriginal as String: "2015:10:11 14:23:17"]])
        XCTAssertNil(ImageMetadata.read(in: [source]).gps)
        let destination = source.deletingLastPathComponent().appendingPathComponent("located.jpg")
        try ImageGpsWriter.write(latitude: 48.8566, longitude: 2.3522, from: source, to: destination)
        let gps = try XCTUnwrap(ImageMetadata.read(in: [destination]).gps)
        XCTAssertEqual(try XCTUnwrap(gps.latitude), 48.8566, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(gps.longitude), 2.3522, accuracy: 1e-4)
    }

    func testWriterReplacesTheDestinationAndRefusesOtherFormats() throws {
        let source = try makeJPEG(properties: locatedProperties)
        // The source itself can be the destination
        try ImageGpsWriter.write(latitude: 10, longitude: 20, from: source, to: source)
        let gps = try XCTUnwrap(ImageMetadata.read(in: [source]).gps)
        XCTAssertEqual(try XCTUnwrap(gps.latitude), 10, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(gps.longitude), 20, accuracy: 1e-4)

        XCTAssertFalse(ImageGpsWriter.canWriteLocation(inFileWithExtension: "png"))
        XCTAssertFalse(ImageGpsWriter.canWriteLocation(inFileWithExtension: "webp"))
        XCTAssertTrue(ImageGpsWriter.canWriteLocation(inFileWithExtension: "HEIC"))
        let png = source.deletingLastPathComponent().appendingPathComponent("a.png")
        try FileManager.default.copyItem(at: source, to: png)
        XCTAssertThrowsError(try ImageGpsWriter.write(latitude: 1, longitude: 2, from: png, to: png))
        XCTAssertThrowsError(try ImageGpsWriter.write(latitude: 91, longitude: 2, from: source, to: source))
    }
}
