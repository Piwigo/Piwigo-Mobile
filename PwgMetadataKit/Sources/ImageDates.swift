//
//  ImageDates.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  The dates of an image file, gathered by meaning instead of by directory: the moment the photo was taken,
//  digitized and last modified, and the time the GPS gave. Each is one row with its date, its time, its
//  sub-seconds and its offset from UTC, however many directories (Exif, TIFF, IPTC, XMP, GPS) tell it.
//  A directory which tells another moment than the first one is given its own row, named after it.
//

import Foundation
import ImageIO

public struct ImageDates: Sendable {
    /// Taken, digitized, modified, then the time of the GPS, in the order of the table
    public let entries: [ImageMetadataEntry]
    /// Metadata of the directories which these rows replace, e.g. "exif.DateTimeOriginal"
    let consumedKeys: Set<String>
}

enum ImageDatesReader
{
    // MARK: - Cache
    private static let cache = ImageMetadataCache<ImageDates>()

    /// Returns the dates of a file already read, without reading it again
    static func cachedDates(at url: URL) -> ImageDates?? {
        return cache.cachedValue(at: url)
    }


    // MARK: - Reading
    /// Reads the dates of an image file. Returns nil if the file has none.
    static func read(from url: URL) -> ImageDates? {
        if let cached = cachedDates(at: url) { return cached }
        let dates = readFile(at: url)
        cache.store(dates, at: url)
        return dates
    }

    /// A moment told by a directory of the file
    struct Candidate {
        let source: String                  // e.g. "IPTC"
        var moment: Moment
        let consumed: [String]              // Keys of the metadata it comes from
    }

    private static func readFile(at url: URL) -> ImageDates? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [String: Any]
        else { return nil }
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        let xmp = CGImageSourceCopyMetadataAtIndex(source, 0, options)
        func text(_ values: [String: Any], _ key: String) -> String? {
            let text = (values[key] as? String) ?? (values[key] as? NSNumber)?.stringValue
            return text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        func xmpText(_ path: String) -> String? {
            guard let xmp = xmp else { return nil }
            return CGImageMetadataCopyStringValueWithPath(xmp, nil, path as CFString) as String?
        }

        /// A date written by Exif, with its sub-seconds and offset, which have keys of their own
        func exifCandidate(date: String, subsec: String, offset: String, in values: [String: Any],
                           source: String, consumed: String) -> Candidate? {
            guard let moment = Moment(exif: text(values, date), subsec: text(exif, subsec), offset: text(exif, offset))
            else { return nil }
            return Candidate(source: source, moment: moment,
                             consumed: [consumed + "." + date, "exif." + subsec, "exif." + offset])
        }
        func iptcCandidate(date: String, time: String, xmp path: String) -> [Candidate] {
            var candidates = [Candidate]()
            if let moment = Moment(iptcDate: text(iptc, date), time: text(iptc, time)) {
                candidates.append(Candidate(source: "IPTC", moment: moment, consumed: ["iptc." + date, "iptc." + time]))
            }
            if let moment = Moment(iso: xmpText(path)) {
                candidates.append(Candidate(source: "XMP", moment: moment, consumed: []))
            }
            return candidates
        }

        var taken = [Candidate](), digitized = [Candidate](), modified = [Candidate](), gpsTime = [Candidate]()
        taken += exifCandidate(date: "DateTimeOriginal", subsec: "SubsecTimeOriginal", offset: "OffsetTimeOriginal",
                               in: exif, source: "Exif", consumed: "exif").map { [$0] } ?? []
        taken += iptcCandidate(date: "DateCreated", time: "TimeCreated", xmp: "photoshop:DateCreated")
        digitized += exifCandidate(date: "DateTimeDigitized", subsec: "SubsecTimeDigitized", offset: "OffsetTimeDigitized",
                                   in: exif, source: "Exif", consumed: "exif").map { [$0] } ?? []
        digitized += iptcCandidate(date: "DigitalCreationDate", time: "DigitalCreationTime", xmp: "xmp:CreateDate")
        modified += exifCandidate(date: "DateTime", subsec: "SubsecTime", offset: "OffsetTime",
                                  in: tiff, source: "TIFF", consumed: "tiff").map { [$0] } ?? []
        if let moment = Moment(iso: xmpText("xmp:ModifyDate")) {
            modified.append(Candidate(source: "XMP", moment: moment, consumed: []))
        }
        if let moment = Moment(gpsDate: text(gps, "DateStamp"), time: text(gps, "TimeStamp")) {
            gpsTime.append(Candidate(source: "GPS", moment: moment, consumed: ["gps.DateStamp", "gps.TimeStamp"]))
        }

        var entries = [ImageMetadataEntry]()
        var consumed = Set<String>()
        func add(_ key: String, _ name: String, _ candidates: [Candidate]) {
            let merged = merge(key, name, candidates)
            entries += merged.entries
            consumed.formUnion(merged.consumed)
        }
        add("DateTaken", String(localized: "imageExif_DateTimeOriginal", bundle: .module, comment: "Date Taken"), taken)
        add("DateDigitized", String(localized: "imageExif_DateTimeDigitized", bundle: .module, comment: "Date Digitized"), digitized)
        add("DateModified", String(localized: "imageDates_modified", bundle: .module, comment: "Date Modified"), modified)
        add("GPSDateTime", String(localized: "imageDates_gps", bundle: .module, comment: "GPS Date and Time"), gpsTime)
        return entries.isEmpty ? nil : ImageDates(entries: entries, consumedKeys: consumed)
    }


    /// The first moment gives the row; the directories which agree with it complete it, those which do not have a row
    static func merge(_ key: String, _ name: String, _ candidates: [Candidate]) -> (entries: [ImageMetadataEntry], consumed: Set<String>) {
        guard var primary = candidates.first else { return ([], []) }
        var entries = [ImageMetadataEntry]()
        var consumed = Set(primary.consumed)
        var others = [Candidate]()
        for candidate in candidates.dropFirst() {
            consumed.formUnion(candidate.consumed)
            if primary.moment.isSameMoment(as: candidate.moment) {
                primary.moment.complete(with: candidate.moment)
            } else {
                others.append(candidate)
            }
        }
        entries.append(ImageMetadataEntry(key: key, name: name, value: primary.moment.text))
        for other in others {
            entries.append(ImageMetadataEntry(key: key + "." + other.source, name: name + " (" + other.source + ")",
                                              value: other.moment.text))
        }
        return (entries, consumed)
    }


    // MARK: - Moments
    /// A date, most often with a time which may have sub-seconds, and an offset from UTC: the numbers are those
    /// written in the file, without any conversion
    struct Moment {
        var year: Int, month: Int, day: Int
        var hour: Int?, minute: Int?, second: Int?
        var fraction: String?               // Digits after the seconds, e.g. "538"
        var offset: String?                 // e.g. "+09:00" or "UTC"

        /// The moment at the precision of the less precise one: the seconds, or the day if one has no time
        func isSameMoment(as other: Moment) -> Bool {
            guard (year, month, day) == (other.year, other.month, other.day) else { return false }
            guard let hour = hour, let otherHour = other.hour else { return true }
            return hour == otherHour && minute == other.minute && (second ?? 0) == (other.second ?? 0)
        }

        /// Takes what this moment does not tell from another one which tells the same
        mutating func complete(with other: Moment) {
            if fraction == nil { fraction = other.fraction }
            if offset == nil { offset = other.offset }
            if hour == nil, other.hour != nil {
                (hour, minute, second) = (other.hour, other.minute, other.second)
            }
        }

        /// "2015:10:11 14:23:17" with "538" for its sub-seconds and "+09:00" for its offset
        init?(exif date: String?, subsec: String?, offset: String?) {
            guard let date = date, let numbers = Self.numbers(Self.exifPattern, in: date), numbers.count == 6
            else { return nil }
            self.init(numbers: numbers)
            self.fraction = Self.digits(subsec)
            self.offset = Self.offset(offset)
        }

        /// "20151011" and "142317+0900"
        init?(iptcDate date: String?, time: String?) {
            guard let date = date, let numbers = Self.numbers(Self.iptcDatePattern, in: date), numbers.count == 3
            else { return nil }
            self.init(numbers: numbers)
            if let time = time, let match = Self.groups(Self.iptcTimePattern, in: time) {
                self.hour = Int(match[0] ?? ""); self.minute = Int(match[1] ?? ""); self.second = Int(match[2] ?? "")
                self.offset = match[3].map { Self.offset($0 + (match[4] ?? "") + (match[5] ?? "")) } ?? nil
                if Self.isValid(hour: hour, minute: minute, second: second) == false {
                    (hour, minute, second, offset) = (nil, nil, nil, nil)
                }
            }
        }

        /// "2024-01-05T12:34:56.789+01:00", the time, its seconds and its offset being optional
        init?(iso text: String?) {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let match = Self.groups(Self.isoPattern, in: text),
                  let year = Int(match[0] ?? ""), let month = Int(match[1] ?? ""), let day = Int(match[2] ?? "")
            else { return nil }
            self.init(numbers: [year, month, day])
            if let hour = Int(match[3] ?? ""), let minute = Int(match[4] ?? "") {
                (self.hour, self.minute, self.second) = (hour, minute, Int(match[5] ?? ""))
                self.fraction = Self.digits(match[6])
                self.offset = Self.offset(match[7])
                if Self.isValid(hour: hour, minute: minute, second: second) == false { return nil }
            }
        }

        /// "2015:10:11" and "05:23:11", the time of the GPS being UTC
        init?(gpsDate date: String?, time: String?) {
            guard let date = date, let numbers = Self.numbers(Self.gpsDatePattern, in: date), numbers.count == 3,
                  let time = time, let match = Self.groups(Self.gpsTimePattern, in: time)
            else { return nil }
            self.init(numbers: numbers)
            (hour, minute, second) = (Int(match[0] ?? ""), Int(match[1] ?? ""), Int(match[2] ?? ""))
            guard Self.isValid(hour: hour, minute: minute, second: second) else { return nil }
            fraction = Self.digits(match[3])
            offset = "UTC"
        }

        /// Year, month and day, then if there are three more, the time
        private init?(numbers: [Int]) {
            guard numbers.count >= 3, (1...12).contains(numbers[1]), (1...31).contains(numbers[2]) else { return nil }
            (year, month, day) = (numbers[0], numbers[1], numbers[2])
            if numbers.count == 6 {
                guard Self.isValid(hour: numbers[3], minute: numbers[4], second: numbers[5]) else { return nil }
                (hour, minute, second) = (numbers[3], numbers[4], numbers[5])
            }
        }

        private static func isValid(hour: Int?, minute: Int?, second: Int?) -> Bool {
            return (0...23).contains(hour ?? 0) && (0...59).contains(minute ?? 0) && (0...60).contains(second ?? 0)
        }

        // MARK: Text
        private static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            return calendar
        }()

        /// The date, the time with its sub-seconds, and the offset, written as the language of the user wants
        var text: String {
            var components = DateComponents(year: year, month: month, day: day)
            (components.hour, components.minute, components.second) = (hour ?? 0, minute ?? 0, second ?? 0)
            guard let date = Self.calendar.date(from: components) else { return "" }
            let formatter = DateFormatter()
            formatter.timeZone = Self.calendar.timeZone
            if hour == nil {
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
            } else {
                var pattern = DateFormatter.dateFormat(fromTemplate: second == nil ? "yMMMdjmm" : "yMMMdjmmss",
                                                       options: 0, locale: Locale.current) ?? "d MMM y HH:mm:ss"
                if let fraction = fraction, second != nil {
                    let separator = Locale.current.decimalSeparator ?? "."
                    pattern = pattern.replacingOccurrences(of: "ss", with: "ss'" + separator + fraction + "'")
                }
                formatter.dateFormat = pattern
            }
            return formatter.string(from: date) + (offset.map { " " + $0 } ?? "")
        }

        // MARK: Parsing
        private static let exifPattern = try! NSRegularExpression(
            pattern: #"^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$"#)
        private static let iptcDatePattern = try! NSRegularExpression(pattern: #"^(\d{4})(\d{2})(\d{2})"#)
        /// 1, 2, 3: the time; 4, 5, 6: the sign, hours and minutes of the offset
        private static let iptcTimePattern = try! NSRegularExpression(
            pattern: #"^(\d{2}):?(\d{2}):?(\d{2})(?:([+-])(\d{2}):?(\d{2}))?$"#)
        private static let gpsDatePattern = try! NSRegularExpression(pattern: #"^(\d{4}):(\d{2}):(\d{2})$"#)
        private static let gpsTimePattern = try! NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2}):(\d{2})(?:\.(\d+))?$"#)
        /// 1-3: the day; 4-6: the time; 7: its fraction; 8: the offset
        private static let isoPattern = try! NSRegularExpression(
            pattern: #"^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.(\d+))?)?(Z|[+-]\d{2}(?::?\d{2})?)?$"#)
        private static let offsetPattern = try! NSRegularExpression(pattern: #"^(Z|[+-]\d{2}(?::?\d{2})?)$"#)

        /// The groups of the first match of a pattern, nil for those which did not match
        private static func groups(_ pattern: NSRegularExpression, in text: String) -> [String?]? {
            guard let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            return (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) }
            }
        }

        private static func numbers(_ pattern: NSRegularExpression, in text: String) -> [Int]? {
            guard let groups = groups(pattern, in: text) else { return nil }
            let numbers = groups.compactMap { $0.flatMap { Int($0) } }
            return numbers.count == groups.count ? numbers : nil
        }

        /// The digits of a fraction of a second, e.g. "538", nil if there are none
        private static func digits(_ text: String?) -> String? {
            let digits = text?.filter(\.isNumber)
            return digits?.isEmpty == false ? digits : nil
        }

        /// An offset written "+09:00", "+0900", "+09" or "Z", shown "+09:00" or "UTC"
        static func offset(_ text: String?) -> String? {
            guard let text = text?.trimmingCharacters(in: .whitespaces), text.isEmpty == false,
                  groups(offsetPattern, in: text) != nil
            else { return nil }
            if text == "Z" { return "UTC" }
            let digits = text.dropFirst().filter(\.isNumber)
            return String(text.prefix(1)) + digits.prefix(2) + ":" + (digits.count >= 4 ? digits.dropFirst(2).prefix(2) : "00")
        }
    }
}
