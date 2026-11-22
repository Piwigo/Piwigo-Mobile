//
//  GeographicCoordinates.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Reads and writes geographic coordinates as people type, copy or read them:
//  decimal degrees (DD), degrees and decimal minutes (DDM), degrees, minutes and seconds (DMS).
//

import Foundation

public enum GeographicCoordinates
{
    // MARK: - Parsing
    /// One coordinate: either a hemisphere letter before the value, or an optional one after it.
    /// Value: a sign, degrees, optional minutes and seconds. Minutes and seconds are only taken when the marks ° ' "
    /// tell what they are, so that "48.8566 2.3522" stays two numbers.
    /// Groups: 1 letter, 2 sign, 3 degrees, 4 minutes, 5 seconds | 6 sign, 7 degrees, 8 minutes, 9 seconds, 10 letter
    private static let coordinatePattern: NSRegularExpression = {
        let number = #"\d+(?:[.,]\d+)?"#
        let value = #"([+\-]?)\s*("# + number + #")\s*(?:°\s*(?:("# + number + #")\s*'\s*(?:("# + number + #")\s*"\s*)?)?)?"#
        let pattern = #"(?:([NSEWnsew])\s*"# + value + #")|(?:"# + value + #"\s*([NSEWnsew])?)"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// Marks written in many ways, brought back to ° ' "
    private static func normalised(_ text: String) -> String {
        var result = text
        for (old, new) in [("º", "°"), ("˚", "°"), ("′", "'"), ("’", "'"), ("‘", "'"), ("ʹ", "'"),
                           ("″", "\""), ("”", "\""), ("“", "\""), ("''", "\""), ("−", "-"), ("–", "-"), ("\u{00A0}", " ")] {
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Latitude and longitude written in `text`, nil if the text is not made of two valid coordinates.
    /// Examples: `48.8566, 2.3522` · `48.8566° N 2.3522° E` · `N 48° 51.396' E 2° 21.132'` · `48°51'23.8"N 2°21'7.9"E` · `-33.8688;-70.6693`
    public static func parse(_ text: String) -> (latitude: Double, longitude: Double)? {
        let text = normalised(text)
        guard text.isEmpty == false else { return nil }

        // Two numbers separated by a comma and nothing else, e.g. "48,2" or "48.8566,2.3522"
        var coordinates = scan(text)
        if coordinates?.count != 2, text.filter({ $0 == "," }).count == 1 {
            let parts = text.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if parts.count == 2, let first = scan(parts[0]), let second = scan(parts[1]),
               first.count == 1, second.count == 1 {
                coordinates = first + second
            }
        }
        guard let coordinates, coordinates.count == 2 else { return nil }

        // Which one is the latitude? The hemisphere letters tell it, otherwise the first one is.
        let first = coordinates[0], second = coordinates[1]
        var latitude = first, longitude = second
        if first.isLongitudeByLetter || second.isLatitudeByLetter {
            latitude = second
            longitude = first
        }
        guard latitude.isLongitudeByLetter == false, longitude.isLatitudeByLetter == false,
              abs(latitude.value) <= 90, abs(longitude.value) <= 180
        else { return nil }
        return (latitude.value, longitude.value)
    }

    private struct Coordinate {
        let value: Double
        let letter: Character?
        var isLatitudeByLetter: Bool { letter == "N" || letter == "S" }
        var isLongitudeByLetter: Bool { letter == "E" || letter == "W" }
    }

    /// The coordinates found in a text which contains nothing else but coordinates and separators
    private static func scan(_ text: String) -> [Coordinate]? {
        let range = NSRange(text.startIndex..., in: text)
        let matches = coordinatePattern.matches(in: text, range: range)
        guard matches.isEmpty == false else { return nil }

        // Nothing but separators between the coordinates
        var covered = 0
        var coordinates = [Coordinate]()
        let separators = CharacterSet(charactersIn: " ,;/|\t")
        for match in matches {
            guard match.range.length > 0 else { return nil }
            let gap = (text as NSString).substring(with: NSRange(location: covered, length: match.range.location - covered))
            guard gap.unicodeScalars.allSatisfy({ separators.contains($0) }) else { return nil }
            covered = match.range.location + match.range.length

            func group(_ index: Int) -> String? {
                let r = match.range(at: index)
                return r.location == NSNotFound ? nil : (text as NSString).substring(with: r)
            }
            func number(_ index: Int) -> Double? {
                return group(index).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
            }
            // First form: the letter is before the value, second form: it is after, if any
            let shift = group(3) == nil ? 4 : 0
            guard let degrees = number(3 + shift) else { return nil }
            let minutes = number(4 + shift) ?? 0, seconds = number(5 + shift) ?? 0
            guard minutes < 60, seconds < 60 else { return nil }
            let letter = (group(1) ?? group(10))?.uppercased().first
            let sign = group(2 + shift)

            var value = degrees + minutes / 60 + seconds / 3600
            if sign == "-" || letter == "S" || letter == "W" { value = -value }
            coordinates.append(Coordinate(value: value, letter: letter))
        }
        let tail = (text as NSString).substring(from: covered)
        guard tail.unicodeScalars.allSatisfy({ separators.contains($0) }) else { return nil }
        return coordinates
    }


    // MARK: - Writing
    /// Coordinates as shown below the map: `48.85660° N, 2.35220° E`
    public static func string(latitude: Double, longitude: Double, digits: Int = 5) -> String {
        func part(_ value: Double, _ positive: String, _ negative: String) -> String {
            return String(format: "%.\(digits)f", locale: Locale.current, abs(value)) + "° " + (value < 0 ? negative : positive)
        }
        return part(latitude, "N", "S") + ", " + part(longitude, "E", "W")
    }
}
