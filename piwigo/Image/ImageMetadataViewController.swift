//
//  ImageMetadataViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Table presenting the metadata of a photo or a video: a map centred on the location
//  where it was taken with the address of this location, and the EXIF metadata of the file.
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
    /// Number of EXIF metadata shown before the user asks for more
    static let exifRowsLimit = 5

    /// Called when the height of the content changes, e.g. when the EXIF metadata are known
    var onContentChange: (() -> Void)?


    // MARK: - Sections and Rows
    private enum Section: Int {
        case location = 0, exif
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


    // MARK: - EXIF
    private(set) var exif: ImageExif?
    /// The section is shown once the file has been read: without EXIF metadata, it tells so.
    private var isExifKnown = false
    private var isExifExpanded = false
    private var heightWhileReading: CGFloat?
    private var measuredHeight: CGFloat = 0
    private var measuredWidth: CGFloat = 0
    /// ID of the image whose EXIF metadata are presented or being read
    var exifImageID: Int64?

    private var hasExifSection: Bool {
        return isExifKnown
    }
    private var displayedExifCount: Int {
        guard let count = exif?.entries.count else { return 0 }
        return isExifExpanded ? count : min(count, Self.exifRowsLimit)
    }
    private var showsMoreRow: Bool {
        guard let count = exif?.entries.count else { return false }
        return isExifExpanded == false && count > Self.exifRowsLimit
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
        tableView.estimatedRowHeight = Self.addressRowHeight
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


    // MARK: - EXIF Data
    /// Presents the EXIF metadata of a photo or a video, or tells that the file has none.
    @MainActor
    func configure(exif newExif: ImageExif?) {
        update(exif: (newExif?.entries.isEmpty == false) ? newExif : nil, isKnown: true)
    }

    /// Removes the section while the EXIF metadata of the file are not known.
    /// The panel keeps its height while they are read, which usually leaves it unchanged
    /// and spares the user a panel and a photo that resize twice.
    @MainActor
    func clearExif(keepingHeight: Bool = false) {
        if keepingHeight == false { heightWhileReading = nil }
        update(exif: nil, isKnown: false)
    }

    @MainActor
    private func update(exif newExif: ImageExif?, isKnown: Bool) {
        let hadSection = hasExifSection
        exif = newExif
        isExifKnown = isKnown
        isExifExpanded = false
        guard isViewLoaded else { return }

        // Only the section changes: the map and the address remain as they are
        UIView.performWithoutAnimation {
            tableView.performBatchUpdates {
                switch (hadSection, hasExifSection) {
                case (false, true):
                    tableView.insertSections([Section.exif.rawValue], with: .none)
                case (true, false):
                    tableView.deleteSections([Section.exif.rawValue], with: .none)
                case (true, true):
                    tableView.reloadSections([Section.exif.rawValue], with: .none)
                default:
                    break
                }
            }
            tableView.layoutIfNeeded()
        }
        onContentChange?()
    }

    /// Shows all the EXIF metadata
    @MainActor
    private func expandExif() {
        guard showsMoreRow, let count = exif?.entries.count else { return }
        let limit = Self.exifRowsLimit
        isExifExpanded = true
        tableView.performBatchUpdates {
            tableView.deleteRows(at: [IndexPath(row: limit, section: Section.exif.rawValue)], with: .fade)
            tableView.insertRows(at: (limit..<count).map { IndexPath(row: $0, section: Section.exif.rawValue) },
                                 with: .fade)
        }
        onContentChange?()
    }

    private var exifHeaderContent: (title: String, text: String) {
        guard let version = exif?.version else { return ("EXIF", "") }
        return ("EXIF\n", String(format: String(localized: "imageExifHeader_version", comment: "Version %@"), version))
    }

    /// Height of the whole table, to size the panel presenting it
    @MainActor
    var contentHeight: CGFloat {
        // Height measured once the table has been laid out
        /// It is not read from the table, whose properties would be tracked by the layout of the parent:
        /// the panel sizes itself from the table which sizes itself from the panel.
        if measuredHeight > 0 {
            if isExifKnown {
                heightWhileReading = measuredHeight
                return measuredHeight
            }
            return max(measuredHeight, heightWhileReading ?? 0)
        }
        
        // Estimation otherwise
        var height = Self.preferredContentHeight(hasLocation: coordinate != nil)
        if hasExifSection {
            let header = exifHeaderContent
            let width = measuredWidth > 0 ? measuredWidth : 375
            height += TableViewUtilities.heightOfHeader(withTitle: header.title, text: header.text, width: width)
            height += CGFloat(max(displayedExifCount, 1)) * TableViewUtilities.rowHeight
            height += showsMoreRow ? Self.moreRowHeight : 0
            height += Self.sectionGap
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
        return hasExifSection ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .exif:
            return exif == nil ? 1 : displayedExifCount + (showsMoreRow ? 1 : 0)
        default:
            return coordinate == nil ? 0 : Row.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // EXIF metadata
        if Section(rawValue: indexPath.section) == .exif {
            if exif == nil || indexPath.row < displayedExifCount {
                let identifier = traitCollection.preferredContentSizeCategory < .accessibilityMedium
                    ? "LabelTableViewCell" : "LabelTableViewCell2"
                guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? LabelTableViewCell
                else { preconditionFailure("Could not load LabelTableViewCell") }
                if let entries = exif?.entries {
                    cell.configure(with: entries[indexPath.row].name, detail: entries[indexPath.row].value)
                } else {
                    cell.configure(with: String(localized: "imageExifNone_message", comment: "No metadata"), detail: "")
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
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if Section(rawValue: indexPath.section) == .exif {
            return exif == nil || indexPath.row < displayedExifCount ? UITableView.automaticDimension : Self.moreRowHeight
        }
        switch Row(rawValue: indexPath.row) {
        case .map:
            return Self.mapRowHeight
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if Section(rawValue: indexPath.section) == .exif {
            return exif == nil || indexPath.row < displayedExifCount ? TableViewUtilities.rowHeight : Self.moreRowHeight
        }
        return Row(rawValue: indexPath.row) == .map ? Self.mapRowHeight : Self.addressRowHeight
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .exif {
            let header = exifHeaderContent
            return TableViewUtilities.heightOfHeader(withTitle: header.title, text: header.text,
                                                     width: tableView.bounds.width)
        }
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .exif {
            let header = exifHeaderContent
            return TableViewUtilities.viewOfHeader(withTitle: header.title, text: header.text)
        }
        return UIView()
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = PwgColor.cellBackground
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // Only the location and the cell asking for more metadata respond to taps
        if Section(rawValue: indexPath.section) == .exif {
            return showsMoreRow && indexPath.row == displayedExifCount
        }
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .exif {
            if showsMoreRow, indexPath.row == displayedExifCount { expandExif() }
            return
        }
        presentLocationActions()
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
