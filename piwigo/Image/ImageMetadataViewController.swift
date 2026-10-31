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
import PwgMetadataKit

final class ImageMetadataViewController: UITableViewController
{
    // MARK: - Dimensions
    /// Height of the cell presenting the map
    static let mapRowHeight: CGFloat = 155
    /// Estimated height of the cell presenting the address (two lines of text)
    static let addressRowHeight: CGFloat = 72
    /// Space above and below the group of cells
    static let sectionGap: CGFloat = 16

    /// Height of the summary: the file, the camera, the lens and the settings of the shot, with the space above
    static let summaryHeight: CGFloat = 200 + sectionGap

    /// Height of the table content for a default size of text
    static func preferredContentHeight(hasLocation: Bool) -> CGFloat {
        return 2 * sectionGap + summaryHeight + (hasLocation ? mapRowHeight + addressRowHeight : 0)
    }


    /// Height of the cell inviting to show more metadata
    static let moreRowHeight: CGFloat = 39
    /// Number of metadata of a section shown before the user asks for more
    static let metadataRowsLimit = MetadataList.rowsLimit

    /// Called when the height of the content changes, e.g. when the metadata are known
    var onContentChange: (() -> Void)?


    // MARK: - Sections and Rows
    /// The sections shown depend on the metadata of the file: see the model of the table
    private typealias Section = MetadataSection
    private enum Row: Int, CaseIterable {
        case map = 0, address
    }
    /// Rows of the summary: the settings of the shot of a photo, or the frame rate and the duration of a video
    private enum SummaryRow: Int, CaseIterable {
        case file = 0, camera, settings
    }
    /// Rows of the summary of a PDF: the file, its title with its author and its size, its dates and its producer
    private enum PdfRow: Int, CaseIterable {
        case file = 0, title, creationDate, modificationDate, producer
    }

    // MARK: - Summary
    private var model = MetadataTableModel()
    private var summary: ImageSummary {
        get { model.summary }
        set { model.summary = newValue }
    }

    /// Presents the summary of the photo or video, whose file and camera are known as soon as its data are
    @MainActor
    func configure(summaryOf source: ImageSummary.Source) {
        guard summary.source != source else { return }
        // A PDF has a summary of its own and no other section: the table changes of structure
        let changesKind = summary.source.isPDF != source.isPDF
        if source.fileName != summary.source.fileName { summary.pdf = nil }
        summary.source = source
        if changesKind {
            if isViewLoaded {
                UIView.performWithoutAnimation {
                    tableView.reloadData()
                    tableView.layoutIfNeeded()
                }
                onContentChange?()
            }
            return
        }
        guard isViewLoaded, let index = visibleSections.firstIndex(of: .summary) else { return }
        UIView.performWithoutAnimation {
            tableView.reloadSections(IndexSet(integer: index), with: .none)
            tableView.layoutIfNeeded()
        }
        onContentChange?()
    }

    /// Presents what the document of a PDF tells about itself, nil while it is not known
    @MainActor
    func configure(pdf: PdfInfo?) {
        summary.pdf = pdf
        guard isViewLoaded, summary.source.isPDF, let index = visibleSections.firstIndex(of: .summary) else { return }
        UIView.performWithoutAnimation {
            tableView.reloadSections(IndexSet(integer: index), with: .none)
            tableView.layoutIfNeeded()
        }
        onContentChange?()
    }


    // MARK: - Location
    private(set) var coordinate: CLLocationCoordinate2D? {
        didSet { model.hasLocation = (coordinate != nil) }
    }
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
    /// The sections are shown once the file has been read: without metadata, they tell so.
    private var isMetadataKnown: Bool { model.isKnown }
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
        return model.list(of: section)
    }

    private var visibleSections: [Section] {
        return model.sections
    }

    private func section(at index: Int) -> Section? {
        let sections = visibleSections
        return sections.indices.contains(index) ? sections[index] : nil
    }


    // MARK: - View Lifecycle
    /// Text to copy with the menu shown when the user taps a row, and the interaction presenting it
    private var pendingCopyText: String?
    private var editMenuInteraction: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Menu proposing to copy the value of a row
        if #available(iOS 16.0, *) {
            let interaction = UIEditMenuInteraction(delegate: self)
            tableView.addInteraction(interaction)
            editMenuInteraction = interaction
        }

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
        model.update(with: metadata, isKnown: isKnown)
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
        guard let index = visibleSections.firstIndex(of: section) else { return }
        let limit = Self.metadataRowsLimit
        let count = list(of: section).entries.count
        guard model.expand(section) else { return }
        tableView.performBatchUpdates {
            tableView.deleteRows(at: [IndexPath(row: limit, section: index)], with: .fade)
            tableView.insertRows(at: (limit..<count).map { IndexPath(row: $0, section: index) },
                                 with: .fade)
        }
        onContentChange?()
    }

    private func headerContent(of section: Section) -> (title: String, text: String) {
        let header = model.header(of: section)
        return (header.title, header.text)
    }

    /// Width of the table for which the layout of the rows was chosen
    private var widthOfRowLayouts: CGFloat = 0

    /// Space taken beside the text of a row: margins of its cell,
    /// and the minimum space between the title and the value
    private static let rowSideSpace: CGFloat = 2 * 20 + 10

    /// Width of the cells as displayed, which depends on the insets of the grouped table
    /// (margins of the card, readable width, safe area…) and is known only once a cell is displayed
    private var measuredCellWidth: CGFloat?

    /// The title and the value of an entry fit on a single line of the table
    private func fitsOnOneLine(_ entry: ImageMetadataEntry) -> Bool {
        widthOfRowLayouts = tableView.bounds.width
        let cellWidth = measuredCellWidth ?? (widthOfRowLayouts - 2 * 20)
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        let titleWidth = ceil((entry.name as NSString).size(withAttributes: attributes).width)
        let valueWidth = ceil((entry.value as NSString).size(withAttributes: attributes).width)
        return titleWidth + valueWidth <= cellWidth - Self.rowSideSpace
    }

    /// The width of the displayed cells differs from the one the layouts were chosen for:
    /// the rows are created again
    private func updateMeasuredCellWidth(with cell: UITableViewCell) {
        let width = cell.bounds.width
        guard width > 0, isMetadataKnown, abs(width - (measuredCellWidth ?? 0)) > 1 else { return }
        let isFirstMeasure = measuredCellWidth == nil
        measuredCellWidth = width
        let sections = IndexSet(visibleSections.indices.filter { visibleSections[$0].isList })
        guard sections.isEmpty == false, isFirstMeasure == false || abs(width - (widthOfRowLayouts - 2 * 20)) > 1
        else { return }
        DispatchQueue.main.async { [weak self] in
            UIView.performWithoutAnimation {
                self?.tableView.reloadSections(sections, with: .none)
            }
        }
    }

    /// The layout of the rows depends on the width of the table, which may not be final
    /// when the rows are first created: they are created again if it changed.
    private func updateRowLayoutsIfNeeded() {
        let width = tableView.bounds.width
        guard width > 0, isMetadataKnown, abs(width - widthOfRowLayouts) > 1 else { return }
        widthOfRowLayouts = width
        let sections = IndexSet(visibleSections.indices.filter {
            visibleSections[$0].isList })
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
            case .summary:
                height += summary.source.isPDF ? 300 + Self.sectionGap : Self.summaryHeight
            case .location:
                height += Self.mapRowHeight + Self.addressRowHeight + Self.sectionGap
            case .empty:
                height += Self.sectionGap + TableViewUtilities.rowHeight + footerHeight(of: .empty, width: width)
            case .loading:
                height += 2 * Self.sectionGap + TableViewUtilities.rowHeight
            case .exif, .gps, .iptc, .webp, .nikon, .canon, .apple, .properties:
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
               let section = visibleSections.firstIndex(of: .location),
               let mapCell = tableView.cellForRow(at: IndexPath(row: Row.map.rawValue, section: section)) as? MapTableViewCell,
               let coordinate = coordinate {
                mapCell.onRendered = { [weak self] in self?.mapDidRender() }
                mapCell.configure(with: coordinate)
                tableView.reloadRows(at: [IndexPath(row: Row.address.rawValue, section: section)], with: .none)
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
        guard isViewLoaded, let section = visibleSections.firstIndex(of: .location) else { return }
        let indexPath = IndexPath(row: Row.address.rawValue, section: section)
        guard tableView.numberOfRows(inSection: section) > indexPath.row else { return }
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
        case .exif, .gps, .iptc, .webp, .nikon, .canon, .apple, .properties:
            return list(of: self.section(at: section)!).rowCount
        case .empty, .loading:
            return 1
        case .summary:
            return summary.source.isPDF ? PdfRow.allCases.count : SummaryRow.allCases.count
        case .location:
            return Row.allCases.count
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Summary
        if section(at: indexPath.section) == .summary {
            return summaryCell(at: indexPath)
        }

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
                    cell.configure(with: String(localized: "imageExifNone_message", bundle: .pwgMetadataKit, comment: "No metadata"), detail: "")
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


    // MARK: - Summary Cells
    private func summaryCell(at indexPath: IndexPath) -> UITableViewCell {
        if summary.source.isPDF { return pdfCell(at: indexPath) }
        func labelCell(stacked: Bool) -> LabelTableViewCell {
            let identifier = stacked ? "LabelTableViewCell2" : "LabelTableViewCell"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            cell.accessoryView = nil
            return cell
        }

        switch SummaryRow(rawValue: indexPath.row) {
        case .file:
            // Name of the original file and its format
            let cell = labelCell(stacked: false)
            cell.configure(with: summary.title, detail: "")
            if summary.format.isEmpty == false {
                cell.accessoryView = formatBadge(summary.format)
            }
            return cell
        case .camera:
            // Camera, lens, and size of the image
            guard let cell = tableView.dequeueReusableCell(withIdentifier: LabelTableViewCell4.reuseIdentifier,
                                                           for: indexPath) as? LabelTableViewCell4
            else { preconditionFailure("Could not load LabelTableViewCell4") }
            cell.accessoryView = nil
            cell.configure(with: summary.camera, detail: summary.lens, bottomDetail: summary.details,
                           showsFlash: summary.flashFired)
            return cell
        default:
            if summary.source.isVideo {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: VideoSummaryTableViewCell.reuseIdentifier,
                                                               for: indexPath) as? VideoSummaryTableViewCell
                else { preconditionFailure("Could not load VideoSummaryTableViewCell") }
                cell.configure(with: summary.video)
                return cell
            }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MetadataSummaryTableViewCell.reuseIdentifier,
                                                           for: indexPath) as? MetadataSummaryTableViewCell
            else { preconditionFailure("Could not load MetadataSummaryTableViewCell") }
            cell.configure(with: summary.shooting)
            return cell
        }
    }

    /// Rows of the summary of a PDF
    private func pdfCell(at indexPath: IndexPath) -> UITableViewCell {
        func labelCell(stacked: Bool) -> LabelTableViewCell {
            let identifier = stacked ? "LabelTableViewCell2" : "LabelTableViewCell"
            guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? LabelTableViewCell
            else { preconditionFailure("Could not load LabelTableViewCell") }
            cell.accessoryView = nil
            return cell
        }
        /// A date or the producer: the value goes under the title if both do not fit on one line
        func entryCell(name: String, value: String) -> LabelTableViewCell {
            let entry = ImageMetadataEntry(key: "", name: name, value: value)
            let cell = labelCell(stacked: traitCollection.preferredContentSizeCategory >= .accessibilityMedium
                                           || fitsOnOneLine(entry) == false)
            cell.configure(with: name, detail: value)
            return cell
        }

        switch PdfRow(rawValue: indexPath.row) {
        case .file:
            let cell = labelCell(stacked: false)
            cell.configure(with: summary.title, detail: "")
            if summary.format.isEmpty == false {
                cell.accessoryView = formatBadge(summary.format)
            }
            return cell
        case .title:
            // Title, author, and pages, size of the page and size of the file
            guard let cell = tableView.dequeueReusableCell(withIdentifier: LabelTableViewCell4.reuseIdentifier,
                                                           for: indexPath) as? LabelTableViewCell4
            else { preconditionFailure("Could not load LabelTableViewCell4") }
            cell.accessoryView = nil
            cell.configure(with: summary.pdfTitle, detail: summary.pdfAuthor, bottomDetail: summary.pdfDetails)
            return cell
        case .creationDate:
            return entryCell(name: String(localized: "imagePdf_creationDate", comment: "Creation Date"),
                             value: summary.pdfCreationDate)
        case .modificationDate:
            return entryCell(name: String(localized: "imagePdf_modificationDate", comment: "Modification Date"),
                             value: summary.pdfModificationDate)
        default:
            return entryCell(name: String(localized: "imagePdf_producer", comment: "Producer"),
                             value: summary.pdfProducer)
        }
    }

    /// Grey filled capsule naming the format of a file
    private func formatBadge(_ format: String) -> UIButton {
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .capsule
        configuration.title = format
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize,
                                                weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.isUserInteractionEnabled = false
        button.sizeToFit()
        return button
    }


    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let kind = self.section(at: section), kind.isList {
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
        if let kind = self.section(at: section), kind.isList {
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
        if cell is LabelTableViewCell { updateMeasuredCellWidth(with: cell) }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // The location, the cell asking for more metadata and the rows holding a value respond to taps
        switch section(at: indexPath.section) {
        case .exif?, .gps?, .iptc?, .webp?, .nikon?, .canon?, .apple?, .properties?:
            return true
        case .summary?:
            return copyableText(at: indexPath)?.isEmpty == false
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
        case .exif, .gps, .iptc, .webp, .nikon, .canon, .apple, .properties:
            if list(of: section).showsMoreRow, indexPath.row == list(of: section).displayedCount {
                expand(section)
            } else {
                presentCopyMenu(at: indexPath)
            }
        case .location:
            presentLocationActions()
        case .summary:
            presentCopyMenu(at: indexPath)
        case .empty, .loading:
            break
        }
    }


    // MARK: - Copy
    /// A tap on a row proposes to copy its value, in the menu which the system shows above a text
    private func presentCopyMenu(at indexPath: IndexPath) {
        guard let text = copyableText(at: indexPath), text.isEmpty == false else { return }
        pendingCopyText = text
        let rect = tableView.rectForRow(at: indexPath)
        if #available(iOS 16.0, *), let interaction = editMenuInteraction as? UIEditMenuInteraction {
            let point = CGPoint(x: rect.midX, y: rect.midY)
            interaction.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point))
        } else {
            presentLegacyCopyMenu(from: rect)
        }
    }

    @available(iOS, deprecated: 16.0)
    private func presentLegacyCopyMenu(from rect: CGRect) {
        becomeFirstResponder()
        UIMenuController.shared.showMenu(from: tableView, rect: rect)
    }

    // Responds to the "Copy" of the menu of iOS 15
    override var canBecomeFirstResponder: Bool { true }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:)) && pendingCopyText != nil
    }

    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = pendingCopyText
    }

    /// Value of a metadata, address of the location or its coordinates
    private func copyableText(at indexPath: IndexPath) -> String? {
        guard let section = section(at: indexPath.section) else { return nil }
        switch section {
        case .exif, .gps, .iptc, .webp, .nikon, .canon, .apple, .properties:
            let entries = list(of: section).entries
            return entries.indices.contains(indexPath.row) && indexPath.row < list(of: section).displayedCount
                ? entries[indexPath.row].value : nil
        case .location:
            if Row(rawValue: indexPath.row) == .address, placeName.isEmpty == false {
                return [placeName, streetName].filter { $0.isEmpty == false }.joined(separator: "\n")
            }
            return coordinateString
        case .summary:
            if summary.source.isPDF {
                switch PdfRow(rawValue: indexPath.row) {
                case .file:             return summary.title
                case .title:            return [summary.pdfTitle, summary.pdfAuthor, summary.pdfDetails].joined(separator: "\n")
                case .creationDate:     return summary.pdfCreationDate
                case .modificationDate: return summary.pdfModificationDate
                default:                return summary.pdfProducer
                }
            }
            switch SummaryRow(rawValue: indexPath.row) {
            case .file:     return summary.title
            case .camera:   return [summary.camera, summary.lens, summary.details].joined(separator: "\n")
            default:        return (summary.source.isVideo ? summary.video : summary.shooting).joined(separator: " | ")
            }
        case .empty, .loading:
            return nil
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
        let copyAction = UIAlertAction(title: String(localized: "imageLocation_copy", bundle: .pwgMetadataKit, comment: "Copy GPS Coordinates"),
                                       style: .default) { [coordinateString] _ in
            UIPasteboard.general.string = coordinateString
        }
        alert.addAction(copyAction)

        // Open Apple Maps at the location
        let mapsAction = UIAlertAction(title: String(localized: "imageLocation_openMaps", bundle: .pwgMetadataKit, comment: "Open in Maps"),
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


// MARK: - UIEditMenuInteractionDelegate
@available(iOS 16.0, *)
extension ImageMetadataViewController: @MainActor UIEditMenuInteractionDelegate
{
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration,
                             suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let text = pendingCopyText else { return nil }
        let copy = UIAction(title: String(localized: "imageMetadata_copy", bundle: .pwgMetadataKit, comment: "Copy"),
                            image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = text
        }
        return UIMenu(children: [copy])
    }
}
