//
//  ImageMetadataViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Table presenting the metadata of a photo or a video: a map centred on the location
//  where it was taken with the address of this location, then the EXIF and IPTC metadata of the file.
//

import UIKit
import MapKit
import CoreLocation
import PwgKit
import PwgCacheKit
import PwgUIKit

final class ImageMetadataViewController: UITableViewController
{
    // MARK: - Dimensions
    /// Height of the cell presenting the map
    static let mapRowHeight: CGFloat = 155
    /// Estimated height of the cell presenting the address (two lines of text)
    static let addressRowHeight: CGFloat = 72
    /// Space above and below the group of cells
    static let sectionGap: CGFloat = 16

    /// Height of the table content for a default size of text
    static func preferredContentHeight(hasLocation: Bool) -> CGFloat {
        return 2 * sectionGap + (hasLocation ? mapRowHeight + addressRowHeight : 0)
    }


    /// Height of the cell inviting to show more metadata
    static let moreRowHeight: CGFloat = 39
    /// Number of metadata of a section shown before the user asks for more
    static let metadataRowsLimit = 5

    /// Called when the height of the content changes, e.g. when the metadata are known
    var onContentChange: (() -> Void)?


    // MARK: - Sections and Rows
    /// The sections shown depend on the metadata of the file: there is always one,
    /// the last one telling that the file has no metadata.
    private enum Section {
        case location, exif, gps, iptc, webp, empty, loading
    }
    private enum Row: Int, CaseIterable {
        case map = 0, address
    }


    // MARK: - Location
    private(set) var coordinate: CLLocationCoordinate2D?
    private var placeName = ""
    private var streetName = ""
    private var isRequestPending = false
    private var isMapPending = false                    // Tiles of the map not yet rendered
    private var mapGeneration = 0
    private var mapKey: String?
    private static var renderedMaps = Set<String>()     // Maps rendered once, whose tiles MapKit keeps
    private var locationHash: Int?
    private let locationProvider = LocationProvider()

    // MARK: - EXIF and IPTC
    /// Metadata of a section: at most a few rows are shown until the user asks for more
    private struct MetadataList {
        var entries = [ImageMetadataEntry]()
        var isExpanded = false

        var displayedCount: Int {
            return isExpanded ? entries.count : min(entries.count, ImageMetadataViewController.metadataRowsLimit)
        }
        var showsMoreRow: Bool {
            return isExpanded == false && entries.count > ImageMetadataViewController.metadataRowsLimit
        }
        /// A section without metadata tells so in its only row
        var rowCount: Int {
            return entries.isEmpty ? 1 : displayedCount + (showsMoreRow ? 1 : 0)
        }
    }
    private var lists: [Section: MetadataList] = [.exif: MetadataList(), .gps: MetadataList(),
                                                   .iptc: MetadataList(), .webp: MetadataList()]
    private var exifVersion: String?
    private var gpsVersion: String?
    /// The sections are shown once the file has been read: without metadata, they tell so.
    private var isMetadataKnown = false
    /// The file read is smaller than the original and may have lost its metadata
    private var noteAboutSize = false
    private var heightWhileReading: CGFloat?
    private var measuredHeight: CGFloat = 0
    private var measuredWidth: CGFloat = 0
    /// ID of the image whose metadata are presented or being read
    var metadataImageID: Int64?
    /// Number of the last reading of the files: only the result of the last one is presented
    var metadataLoadNumber = 0

    private func list(of section: Section) -> MetadataList {
        return lists[section] ?? MetadataList()
    }

    private var visibleSections: [Section] {
        var sections = [Section]()
        if coordinate != nil { sections.append(.location) }
        if isMetadataKnown == false {
            /// The metadata are being read, or the file holding them is being downloaded
            sections.append(.loading)
        } else {
            if list(of: .exif).entries.isEmpty == false { sections.append(.exif) }
            if list(of: .gps).entries.isEmpty == false { sections.append(.gps) }
            if list(of: .iptc).entries.isEmpty == false { sections.append(.iptc) }
            if list(of: .webp).entries.isEmpty == false { sections.append(.webp) }
            if sections.isEmpty { sections.append(.empty) }
        }
        return sections
    }

    private func section(at index: Int) -> Section? {
        let sections = visibleSections
        return sections.indices.contains(index) ? sections[index] : nil
    }


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Table
        tableView.alwaysBounceVertical = false
        if #available(iOS 26.0, *) {
            // The table sits beside the toolbar: no blur where its content passes under the bars
            tableView.topEdgeEffect.isHidden = true
            tableView.bottomEdgeEffect.isHidden = true
        }
        /// The heights of the rows come from the constraints of their cells, as the text wraps
        /// differently when the table changes of width: the map has a fixed height in the storyboard.
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = TableViewUtilities.rowHeight
        tableView.accessibilityIdentifier = "ImageMetadata"

        // Register palette changes
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
        // Register font changes
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeContentSizeCategory),
                                               name: UIContentSizeCategory.didChangeNotification, object: nil)
        // Register the availability of place names
        NotificationCenter.default.addObserver(self, selector: #selector(didReceivePlaceNames(_:)),
                                               name: Notification.Name.pwgPlaceNamesAvailable, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyColorPalette()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateRowLayoutsIfNeeded()

        // Keep the height of the content for the panel or the card presenting the table
        let height = tableView.contentSize.height
        let width = tableView.bounds.width
        guard width > 0, height > 0, abs(height - measuredHeight) > 1 else { return }
        measuredHeight = height
        measuredWidth = width
        DispatchQueue.main.async { [weak self] in
            self?.onContentChange?()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @MainActor
    @objc func applyColorPalette() {
        // The palette of the app is independent from the appearance of the system
        overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        view.backgroundColor = .clear
        tableView.backgroundColor = .clear
        tableView.separatorColor = PwgColor.separator
        tableView.reloadData()
    }

    @MainActor
    @objc func didChangeContentSizeCategory(_ notification: NSNotification) {
        tableView.reloadData()
    }


    // MARK: - Metadata of the File
    /// Presents the EXIF, GPS, IPTC and WebP metadata of a photo or a video, or tells that the file has none.
    @MainActor
    func configure(_ metadata: ImageMetadata, noteAboutSize: Bool = false) {
        update(metadata, isKnown: true, noteAboutSize: noteAboutSize)
    }

    /// Removes the sections while the metadata of the file are not known.
    /// The panel keeps its height while they are read, which usually leaves it unchanged
    /// and spares the user a panel and a photo that resize twice.
    @MainActor
    func clearMetadata(keepingHeight: Bool = false) {
        if keepingHeight == false { heightWhileReading = nil }
        update(ImageMetadata(), isKnown: false, noteAboutSize: false)
    }

    @MainActor
    private func update(_ metadata: ImageMetadata, isKnown: Bool, noteAboutSize: Bool) {
        let oldSections = visibleSections
        lists = [.exif: MetadataList(entries: metadata.exif?.entries ?? []),
                 .gps: MetadataList(entries: metadata.gps?.entries ?? []),
                 .iptc: MetadataList(entries: metadata.iptc?.entries ?? []),
                 .webp: MetadataList(entries: metadata.webp?.entries ?? [])]
        exifVersion = metadata.exif?.version
        gpsVersion = metadata.gps?.version
        isMetadataKnown = isKnown
        self.noteAboutSize = noteAboutSize
        guard isViewLoaded else { return }

        // Only the sections of the metadata change: the map and the address remain as they are
        let newSections = visibleSections
        let removed = IndexSet(oldSections.indices.filter { newSections.contains(oldSections[$0]) == false })
        let inserted = IndexSet(newSections.indices.filter { oldSections.contains(newSections[$0]) == false })
        let reloaded = IndexSet(oldSections.indices.filter {
            oldSections[$0] != .location && newSections.contains(oldSections[$0]) })
        UIView.performWithoutAnimation {
            tableView.performBatchUpdates {
                tableView.deleteSections(removed, with: .none)
                tableView.insertSections(inserted, with: .none)
                tableView.reloadSections(reloaded, with: .none)
            }
            tableView.layoutIfNeeded()
        }
        onContentChange?()
    }

    /// Shows all the metadata of a section
    @MainActor
    private func expand(_ section: Section) {
        var list = list(of: section)
        guard list.showsMoreRow, let index = visibleSections.firstIndex(of: section) else { return }
        let limit = Self.metadataRowsLimit
        let count = list.entries.count
        list.isExpanded = true
        lists[section] = list
        tableView.performBatchUpdates {
            tableView.deleteRows(at: [IndexPath(row: limit, section: index)], with: .fade)
            tableView.insertRows(at: (limit..<count).map { IndexPath(row: $0, section: index) },
                                 with: .fade)
        }
        onContentChange?()
    }

    private func headerContent(of section: Section) -> (title: String, text: String) {
        switch section {
        case .exif, .gps, .iptc, .webp:
            // "Version 2.3 • 31 items" or "31 items"
            var parts = [String]()
            let version = section == .exif ? exifVersion : section == .gps ? gpsVersion : nil
            if let version = version {
                parts.append(String(format: String(localized: "imageExifHeader_version", comment: "Version %@"), version))
            }
            parts.append(String.localizedStringWithFormat(
                String(localized: "imageMetadata_itemCount", comment: "%lld items"), list(of: section).entries.count))
            let titles: [Section: String] = [.exif: "Exif", .gps: "GPS", .iptc: "IPTC", .webp: "WebP"]
            let title = titles[section] ?? ""
            return (title + "\n", parts.joined(separator: " • "))
        case .location, .empty, .loading:
            return ("", "")
        }
    }

    /// Width of the table for which the layout of the rows was chosen
    private var widthOfRowLayouts: CGFloat = 0

    /// Space taken beside the text of a row: margins of the grouped table and of its cells,
    /// and the minimum space between the title and the value
    private static let rowSideSpace: CGFloat = 2 * 20 + 2 * 20 + 10

    /// The title and the value of an entry fit on a single line of the table
    private func fitsOnOneLine(_ entry: ImageMetadataEntry) -> Bool {
        widthOfRowLayouts = tableView.bounds.width
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        let titleWidth = ceil((entry.name as NSString).size(withAttributes: attributes).width)
        let valueWidth = ceil((entry.value as NSString).size(withAttributes: attributes).width)
        return titleWidth + valueWidth <= widthOfRowLayouts - Self.rowSideSpace
    }

    /// The layout of the rows depends on the width of the table, which may not be final
    /// when the rows are first created: they are created again if it changed.
    private func updateRowLayoutsIfNeeded() {
        let width = tableView.bounds.width
        guard width > 0, isMetadataKnown, abs(width - widthOfRowLayouts) > 1 else { return }
        widthOfRowLayouts = width
        let sections = IndexSet(visibleSections.indices.filter {
            [.exif, .gps, .iptc, .webp].contains(visibleSections[$0]) })
        guard sections.isEmpty == false else { return }
        DispatchQueue.main.async { [weak self] in
            UIView.performWithoutAnimation {
                self?.tableView.reloadSections(sections, with: .none)
            }
        }
    }

    /// Explanation given when a file without metadata is smaller than the original
    private var sizeNote: String? {
        guard noteAboutSize else { return nil }
        return String(localized: "imageMetadata_sizeNote",
                      comment: "Note that metadata are not available below a certain preview size…")
    }

    private func footerHeight(of section: Section, width: CGFloat) -> CGFloat {
        if section == .empty, let note = sizeNote {
            return TableViewUtilities.heightOfFooter(withText: note, width: width)
        }
        return Self.sectionGap
    }

    /// Height of the whole table, to size the panel presenting it
    @MainActor
    var contentHeight: CGFloat {
        // Height measured once the table has been laid out
        /// It is not read from the table, whose properties would be tracked by the layout of the parent:
        /// the panel sizes itself from the table which sizes itself from the panel.
        if measuredHeight > 0 {
            if isMetadataKnown {
                heightWhileReading = measuredHeight
                return measuredHeight
            }
            return max(measuredHeight, heightWhileReading ?? 0)
        }

        // Estimation otherwise
        var height: CGFloat = 0
        let width = measuredWidth > 0 ? measuredWidth : 375
        for section in visibleSections {
            switch section {
            case .location:
                height += Self.preferredContentHeight(hasLocation: true)
            case .empty:
                height += Self.sectionGap + TableViewUtilities.rowHeight + footerHeight(of: .empty, width: width)
            case .loading:
                height += 2 * Self.sectionGap + TableViewUtilities.rowHeight
            case .exif, .gps, .iptc, .webp:
                let header = headerContent(of: section)
                height += TableViewUtilities.heightOfHeader(withTitle: header.title, text: header.text, width: width)
                height += CGFloat(list(of: section).rowCount) * TableViewUtilities.rowHeight
                height += Self.sectionGap
            }
        }
        return height
    }


    // MARK: - Location Data
    /// Presents the location of a photo or a video and requests its address if needed.
    /// A nil location empties the table.
    @MainActor
    func configure(with coordinate: CLLocationCoordinate2D?) {
        // Same location?
        if let old = self.coordinate, let new = coordinate,
           old.latitude == new.latitude, old.longitude == new.longitude {
            return
        }

        // Reset the address
        let hadLocation = (self.coordinate != nil)
        self.coordinate = coordinate
        placeName = ""
        streetName = ""
        isRequestPending = false
        locationHash = nil
        waitForMap(for: coordinate)
        
        // The cells are updated where they are, without animation: reloading them
        /// would create new cells whose size could animate from zero when the location
        /// changes while the bars or the pages are animating.
        UIView.performWithoutAnimation {
            if hadLocation, coordinate != nil, isViewLoaded,
               let mapCell = tableView.cellForRow(at: IndexPath(row: Row.map.rawValue, section: 0)) as? MapTableViewCell,
               let coordinate = coordinate {
                mapCell.onRendered = { [weak self] in self?.mapDidRender() }
                mapCell.configure(with: coordinate)
                tableView.reloadRows(at: [IndexPath(row: Row.address.rawValue, section: 0)], with: .none)
            } else {
                tableView.reloadData()
            }
            tableView.layoutIfNeeded()
        }

        // Request the address
        guard let coordinate = coordinate else { return }
        requestAddress(at: coordinate)
    }

    /// Checks whether the address is in cache. If not, the location provider retrieves it
    /// and stores it in cache before posting a notification.
    @MainActor
    private func requestAddress(at coordinate: CLLocationCoordinate2D) {
        // The location provider decides whether a known place covers this location.
        /// Places are matched within a few meters before being compared to their own radius.
        let location = CLLocation(coordinate: coordinate, altitude: 0,
                                  horizontalAccuracy: kCLLocationAccuracyNearestTenMeters,
                                  verticalAccuracy: kCLLocationAccuracyReduced, timestamp: Date())
        isRequestPending = true
        locationProvider.getPlaceName(for: location) { [weak self] placeName, streetName in
            self?.setAddress(placeName: placeName, streetName: streetName)
        } pending: { [weak self] hash in
            self?.locationHash = hash
        } failure: { [weak self] in
            self?.setAddress(placeName: "", streetName: "")
        }
        
        // The address cell shows the spinner while the address is retrieved
        /// A cached address is delivered at once, which leaves nothing pending.
        if isRequestPending {
            reloadAddressRow()
        }
    }

    @MainActor
    @objc func didReceivePlaceNames(_ notification: Notification) {
        guard let info = notification.userInfo,
              let hash = info["hash"] as? Int, hash == locationHash,
              let placeName = info["placeName"] as? String,
              let streetName = info["streetName"] as? String
        else { return }
        setAddress(placeName: placeName, streetName: streetName)
    }

    @MainActor
    private func setAddress(placeName: String, streetName: String) {
        self.placeName = placeName
        self.streetName = streetName
        isRequestPending = false
        locationHash = nil

        // Update the address cell if visible
        reloadAddressRow()
    }
    
    /// The spinner of the address cell also covers the rendering of the map.
    /// A timeout releases it if the map never reports its end (e.g. no network).
    @MainActor
    private func waitForMap(for coordinate: CLLocationCoordinate2D?) {
        // A map already rendered may not report anything again
        mapGeneration += 1
        mapKey = coordinate.map { String(format: "%.4f,%.4f", $0.latitude, $0.longitude) }
        isMapPending = mapKey != nil && Self.renderedMaps.contains(mapKey!) == false
        guard isMapPending else { return }
        let generation = mapGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self = self, self.mapGeneration == generation else { return }
            self.mapDidRender(isRendered: false)
        }
    }
    
    @MainActor
    private func mapDidRender(isRendered: Bool = true) {
        if isRendered, let key = mapKey {
            Self.renderedMaps.insert(key)
        }
        guard isMapPending else { return }
        isMapPending = false
        reloadAddressRow()
    }
    
    @MainActor
    private func reloadAddressRow() {
        let indexPath = IndexPath(row: Row.address.rawValue, section: 0)
        guard isViewLoaded, tableView.numberOfRows(inSection: 0) > indexPath.row else { return }
        UIView.performWithoutAnimation {
            tableView.reloadRows(at: [indexPath], with: .none)
            tableView.layoutIfNeeded()
        }
    }


    // MARK: - Coordinates
    /// Coordinates written with a decimal point whatever the language of the user
    private var coordinateString: String {
        guard let coordinate = coordinate else { return "" }
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    /// Coordinates written for the user, with the number of digits of the GPS precision
    private var readableCoordinateString: String {
        guard let coordinate = coordinate else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 5
        formatter.maximumFractionDigits = 5
        let latitude = formatter.string(from: NSNumber(value: abs(coordinate.latitude))) ?? ""
        let longitude = formatter.string(from: NSNumber(value: abs(coordinate.longitude))) ?? ""
        let latitudeRef = coordinate.latitude >= 0 ? "N" : "S"
        let longitudeRef = coordinate.longitude >= 0 ? "E" : "W"
        return "\(latitude)° \(latitudeRef), \(longitude)° \(longitudeRef)"
    }


    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return visibleSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.section(at: section) {
        case .exif, .gps, .iptc, .webp:
            return list(of: self.section(at: section)!).rowCount
        case .empty, .loading:
            return 1
        case .location:
            return Row.allCases.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // EXIF and IPTC metadata, or the absence of metadata
        if let section = section(at: indexPath.section), section != .location {
            let list = list(of: section)
            if section == .empty || section == .loading || indexPath.row < list.displayedCount {
                /// The value goes under the title when both do not fit on one line
                let isEntry = section != .empty && section != .loading
                let isStacked = traitCollection.preferredContentSizeCategory >= .accessibilityMedium
                    || (isEntry && fitsOnOneLine(list.entries[indexPath.row]) == false)
                let identifier = isStacked ? "LabelTableViewCell2" : "LabelTableViewCell"
                guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                cell.accessoryView = nil
                if section == .empty {
                    cell.configure(with: String(localized: "imageExifNone_message", comment: "No metadata"), detail: "")
                } else if section == .loading {
                    /// The metadata are being read, or the file holding them is being downloaded
                    cell.configure(with: Localized.loading, detail: "")
                    let spinner = UIActivityIndicatorView(style: .medium)
                    spinner.color = PwgColor.rightLabel
                    spinner.startAnimating()
                    cell.accessoryView = spinner
                } else {
                    cell.configure(with: list.entries[indexPath.row].name, detail: list.entries[indexPath.row].value)
                }
                return cell
            }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "LocalAlbumsMoreTableViewCell", for: indexPath) as? LocalAlbumsMoreTableViewCell
            else { preconditionFailure("Could not load LocalAlbumsMoreTableViewCell") }
            cell.configure()
            return cell
        }
        
        // Location
        switch Row(rawValue: indexPath.row) {
        case .map:
            let cell = tableView.dequeueReusableCell(withIdentifier: MapTableViewCell.reuseIdentifier,
                                                     for: indexPath) as! MapTableViewCell
            cell.onRendered = { [weak self] in self?.mapDidRender() }
            if let coordinate = coordinate {
                cell.configure(with: coordinate)
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.reuseIdentifier,
                                                     for: indexPath) as! AddressTableViewCell
            if placeName.isEmpty {
                cell.configure(title: readableCoordinateString, subtitle: "", isLoading: isRequestPending || isMapPending)
            } else {
                cell.configure(title: placeName, subtitle: streetName, isLoading: isMapPending)
            }
            return cell
        }
    }


    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let kind = self.section(at: section), kind == .exif || kind == .gps || kind == .iptc || kind == .webp {
            let header = headerContent(of: kind)
            return TableViewUtilities.heightOfHeader(withTitle: header.title, text: header.text,
                                                     width: tableView.bounds.width)
        }
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let kind = self.section(at: section) else { return Self.sectionGap }
        return footerHeight(of: kind, width: tableView.bounds.width)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let kind = self.section(at: section), kind == .exif || kind == .gps || kind == .iptc || kind == .webp {
            let header = headerContent(of: kind)
            return TableViewUtilities.viewOfHeader(withTitle: header.title, text: header.text)
        }
        return UIView()
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if self.section(at: section) == .empty, let note = sizeNote {
            return TableViewUtilities.viewOfFooter(withText: note)
        }
        return UIView()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = PwgColor.cellBackground
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Only the location and the cell asking for more metadata respond to taps
        switch section(at: indexPath.section) {
        case .exif?, .gps?, .iptc?, .webp?:
            let list = list(of: section(at: indexPath.section)!)
            return list.showsMoreRow && indexPath.row == list.displayedCount
        case .empty?, .loading?:
            return false
        default:
            return true
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = section(at: indexPath.section) else { return }
        switch section {
        case .exif, .gps, .iptc, .webp:
            if list(of: section).showsMoreRow, indexPath.row == list(of: section).displayedCount { expand(section) }
        case .location:
            presentLocationActions()
        case .empty, .loading:
            break
        }
    }


    // MARK: - Location Actions
    /// Proposes to copy the GPS coordinates or to open Apple Maps at the location
    @MainActor
    private func presentLocationActions() {
        guard let coordinate = coordinate else { return }

        let alert = UIAlertController(title: readableCoordinateString, message: placeName.isEmpty ? nil
                                      : [placeName, streetName].filter({ $0.isEmpty == false }).joined(separator: "\n"),
                                      preferredStyle: .alert)

        // Copy the GPS coordinates
        let copyAction = UIAlertAction(title: String(localized: "imageLocation_copy", comment: "Copy GPS Coordinates"),
                                       style: .default) { [coordinateString] _ in
            UIPasteboard.general.string = coordinateString
        }
        alert.addAction(copyAction)

        // Open Apple Maps at the location
        let mapsAction = UIAlertAction(title: String(localized: "imageLocation_openMaps", comment: "Open in Maps"),
                                       style: .default) { [placeName] _ in
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = placeName.isEmpty ? nil : placeName
            mapItem.openInMaps(launchOptions: nil)
        }
        alert.addAction(mapsAction)

        // Cancel the request
        alert.addAction(UIAlertAction(title: Localized.cancel, style: .cancel, handler: nil))

        alert.view.tintColor = PwgColor.tintColor
        present(alert, animated: true) {
            // Bugfix: iOS9 - Tint not fully Applied without Reapplying
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}
