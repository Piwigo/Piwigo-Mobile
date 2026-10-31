//
//  MetadataExport.swift
//  PwgMetadataKit
//
//  Created by Eddy Lelièvre-Berna on 31/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  The location and the metadata of a photo as text: a list for people, a JSON object for programs.
//  Both follow the order of the sections of the table.
//

import Foundation

/// Where a photo was taken
public struct MetadataLocation: Sendable {
    public var latitude: Double
    public var longitude: Double
    /// Name of the place and its address, which are not always known
    public var place: String
    public var address: String

    public init(latitude: Double, longitude: Double, place: String = "", address: String = "") {
        self.latitude = latitude
        self.longitude = longitude
        self.place = place
        self.address = address
    }

    /// Coordinates written with a decimal point whatever the language of the user
    var coordinates: String {
        return unsafe String(format: "%.6f, %.6f", latitude, longitude)
    }

    /// Name of the place followed by its address
    var fullAddress: String {
        return [place, address].filter { $0.isEmpty == false }.joined(separator: ", ")
    }
}

extension MetadataTableModel {
    /// A group of metadata with the name it is given in each export
    private struct ExportedSection {
        let title: String                       // e.g. "Exif - Camera", as in the list
        let path: [String]                      // e.g. ["Exif", "camera"], as in the JSON object
        let entries: [ImageMetadataEntry]
    }

    /// The sections listing metadata of the file, as shown in the table
    private var exportedSections: [ExportedSection] {
        return sections.compactMap { section in
            let entries = list(of: section).entries
            guard section.isList, entries.isEmpty == false else { return nil }
            switch section {
            case .exif(let group):
                return ExportedSection(title: "Exif - " + group.title, path: ["Exif", String(describing: group)],
                                       entries: entries)
            case .gps:
                return ExportedSection(title: "GPS", path: ["GPS"], entries: entries)
            case .iptc:
                return ExportedSection(title: "IPTC", path: ["IPTC"], entries: entries)
            case .webp:
                return ExportedSection(title: "WebP", path: ["WebP"], entries: entries)
            case .nikon:
                return ExportedSection(title: "Nikon", path: ["Nikon"], entries: entries)
            case .canon:
                return ExportedSection(title: "Canon", path: ["Canon"], entries: entries)
            case .apple:
                return ExportedSection(title: "Apple", path: ["Apple"], entries: entries)
            case .properties(let kind):
                return ExportedSection(title: kind.title, path: [kind.rawValue.uppercased()], entries: entries)
            default:
                return nil
            }
        }
    }


    // MARK: - List
    /// The location and the metadata as text: a block per section, whose metadata are sorted alphabetically
    public func asciiList(location: MetadataLocation? = nil) -> String {
        var blocks = [String]()
        if let location = location {
            var rows = [(name: String, value: String)]()
            rows.append((String(localized: "imageLocation_coordinates", bundle: .module, comment: "Coordinates"),
                         location.coordinates))
            if location.fullAddress.isEmpty == false {
                rows.append((String(localized: "imageLocation_address", bundle: .module, comment: "Address"),
                             location.fullAddress))
            }
            let title = String(localized: "imageLocation_title", bundle: .module, comment: "Location")
            blocks.append(Self.block(title: title, rows: rows))
        }
        for section in exportedSections {
            blocks.append(Self.block(title: section.title, rows: section.entries.map { ($0.name, $0.value) }))
        }
        return blocks.joined(separator: "\n\n")
    }

    private static func block(title: String, rows: [(name: String, value: String)]) -> String {
        let sorted = rows.sorted {
            let result = $0.name.localizedStandardCompare($1.name)
            return result == .orderedSame ? $0.value < $1.value : result == .orderedAscending
        }
        let lines = sorted.map { "\($0.name): \(singleLine($0.value))" }
        return (["[\(title)]"] + lines).joined(separator: "\n")
    }

    private static func singleLine(_ value: String) -> String {
        return value.components(separatedBy: .newlines).filter { $0.isEmpty == false }.joined(separator: " ")
    }


    // MARK: - JSON
    /// The location and the metadata as a JSON object with the groups in the order of the table.
    /// The keys do not depend on the language: they are those of the metadata, and the values are as readable as in the table.
    public func jsonObject(location: MetadataLocation? = nil) -> String {
        var root = JSONNode()
        if let location = location {
            var node = JSONNode()
            node.add("latitude", number: location.latitude)
            node.add("longitude", number: location.longitude)
            if location.place.isEmpty == false { node.add("place", string: location.place) }
            if location.address.isEmpty == false { node.add("address", string: location.address) }
            root.add("Location", node: node)
        }
        for section in exportedSections {
            var node = JSONNode()
            for entry in section.entries.sorted(by: { $0.key.localizedStandardCompare($1.key) == .orderedAscending }) {
                node.add(entry.key, string: entry.value)
            }
            root.insert(node, at: section.path)
        }
        return root.text()
    }
}


// MARK: - JSON Writer
/// A JSON object whose members keep the order in which they were added, which JSONSerialization does not allow
private struct JSONNode {
    private enum Value {
        case string(String)
        case number(Double)
        case node(JSONNode)
    }
    private var members = [(key: String, value: Value)]()

    mutating func add(_ key: String, string: String) { members.append((key, .string(string))) }
    mutating func add(_ key: String, number: Double) { members.append((key, .number(number))) }
    mutating func add(_ key: String, node: JSONNode) { members.append((key, .node(node))) }

    /// Puts a node at the end of a path of objects, which are created when they do not exist yet
    mutating func insert(_ node: JSONNode, at path: [String]) {
        guard let first = path.first else { return }
        if path.count == 1 {
            add(first, node: node)
            return
        }
        if let index = members.firstIndex(where: { $0.key == first }), case .node(var child) = members[index].value {
            child.insert(node, at: Array(path.dropFirst()))
            members[index].value = .node(child)
        } else {
            var child = JSONNode()
            child.insert(node, at: Array(path.dropFirst()))
            add(first, node: child)
        }
    }

    func text(indent: Int = 0) -> String {
        guard members.isEmpty == false else { return "{}" }
        let inner = String(repeating: "  ", count: indent + 1)
        let lines = members.map { member -> String in
            let value: String
            switch member.value {
            case .string(let string):   value = Self.literal(string)
            case .number(let number):   value = unsafe String(format: "%.6f", number)
            case .node(let node):       value = node.text(indent: indent + 1)
            }
            return "\(inner)\(Self.literal(member.key)): \(value)"
        }
        return "{\n" + lines.joined(separator: ",\n") + "\n" + String(repeating: "  ", count: indent) + "}"
    }

    /// A string between quotes, with the characters which JSON requires to escape
    private static func literal(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8)
        else { return "\"\"" }
        return text
    }
}
