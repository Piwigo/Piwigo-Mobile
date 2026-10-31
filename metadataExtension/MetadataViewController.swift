//
//  MetadataViewController.swift
//  metadataExtension
//
//  Created by Eddy Lelièvre-Berna on 30/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Action extension presenting the metadata of a photo: the photo, a summary, a map centred
//  on the location where it was taken with its address, then the EXIF, GPS, IPTC… metadata of its file.
//

import UIKit
import MapKit
import Contacts
import CoreLocation
import UniformTypeIdentifiers
import ImageIO
import PwgUIKit
import PwgMetadataKit

final class MetadataViewController: UITableViewController
{
    // MARK: - Sections and Rows
    private typealias Section = MetadataSection
    private enum Row: Int, CaseIterable {
        case map = 0, address
    }
    private enum SummaryRow: Int, CaseIterable {
        case file = 0, camera, settings
    }

    /// Space above and below the groups of cells
    private static let sectionGap: CGFloat = 16

    private var model = MetadataTableModel()
    private var summary: ImageSummary { model.summary }

    // Photo and its file
    private var fileURL: URL?
    private var headerImage: UIImage?

    // Location
    private var coordinate: CLLocationCoordinate2D?
    private var placeName = ""
    private var streetName = ""
    private var isAddressPending = false
    private var isMapPending = false
    private let geocoder = CLGeocoder()

    /// Text to copy with the menu shown when the user taps a row, and the interaction presenting it
    private var pendingCopyText: String?
    private var editMenuInteraction: Any?

    /// Width of the cells as displayed, known once a cell is displayed
    private var measuredCellWidth: CGFloat?
    private static let rowSideSpace: CGFloat = 2 * 20 + 10


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = String(localized: "metadataExtension_title", comment: "Metadata")
        let closeButton = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        closeButton.style = .plain
        closeButton.tintColor = PwgColor.tintColor
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: actionsMenu())
        if #available(iOS 16.0, *) {
            let interaction = UIEditMenuInteraction(delegate: self)
            tableView.addInteraction(interaction)
            editMenuInteraction = interaction
        }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = TableViewUtilities.rowHeight
        applyColorPalette()
        loadPhoto()
    }

    deinit {
        // The copy of the photo made at the start
        if let fileURL = fileURL {
            try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // The palette follows the settings of the app, shared through the app group, and the system appearance.
        /// The window of the extension is never told that the system appearance changed while it is shown
        let systemStyle = view.window?.windowScene?.traitCollection.userInterfaceStyle ?? traitCollection.userInterfaceStyle
        UITools.shared.applyColorPalette(for: systemStyle)
        applyColorPalette()
    }

    private func applyColorPalette() {
        // The palette of the app is independent from the appearance of the system
        let style: UIUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        overrideUserInterfaceStyle = style
        navigationController?.overrideUserInterfaceStyle = style
        view.backgroundColor = PwgColor.background
        tableView.backgroundColor = PwgColor.background
        tableView.separatorColor = PwgColor.separator
        tableView.indicatorStyle = UIVars.shared.isDarkPaletteActive ? .white : .black
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        navigationItem.leftBarButtonItem?.tintColor = PwgColor.tintColor
        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderView()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tableView.reloadData()
        }
    }


    // MARK: - Photo
    /// Finds the photo shared with the extension and makes a copy of its file, which is deleted once the request is over
    private func loadPhoto() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) })
        else {
            model.update(with: ImageMetadata(), isKnown: true)
            return
        }
        let identifier = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier
        let type = UTType(identifier) ?? .image
        let suggestedName = provider.suggestedName
        model.update(with: ImageMetadata(), isKnown: false)

        // The file only exists during this call
        let handleLoadedFile: @Sendable (URL?) -> Void = { [weak self] url in
            var copy: URL?
            if let url = url {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let name = suggestedName.map { $0 + "." + url.pathExtension } ?? url.lastPathComponent
                let destination = directory.appendingPathComponent(name)
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: destination)
                    copy = destination
                } catch { copy = nil }
            }
            Task { @MainActor in
                self?.didReceive(fileAt: copy)
            }
        }

        // Asynchronously writes a copy of the provided, typed data to a temporary file
        if #available(iOS 16.0, *) {
            _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, _ in
                handleLoadedFile(url)
            }
        } else {
            // Fallback on older version
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                handleLoadedFile(url)
            }
        }
    }

    /// What is read in the file, which does not move to the main thread
    private struct Loaded: @unchecked Sendable {
        let source: ImageSummary.Source
        let metadata: ImageMetadata
        let image: UIImage?
    }

    @MainActor
    private func didReceive(fileAt url: URL?) {
        guard let url = url else {
            model.update(with: ImageMetadata(), isKnown: true)
            tableView.reloadData()
            return
        }
        fileURL = url
        let width = max(view.bounds.width, 320) * view.traitCollection.displayScale
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                Loaded(source: ImageSummary.Source(fileURL: url), metadata: ImageMetadata.read(in: [url]),
                       image: Self.thumbnail(of: url, maxPixelSize: width))
            }.value
            show(loaded)
        }
    }

    /// Small version of the photo, upright: the photo itself is never decoded, which would exhaust the memory of the extension
    nonisolated private static func thumbnail(of url: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                       kCGImageSourceShouldCache: false] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options).map { UIImage(cgImage: $0) }
    }

    @MainActor
    private func show(_ loaded: Loaded) {
        model.summary.source = loaded.source
        model.update(with: loaded.metadata, isKnown: true)
        headerImage = loaded.image

        // Location
        if let latitude = loaded.metadata.gps?.latitude, let longitude = loaded.metadata.gps?.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                self.coordinate = coordinate
                model.hasLocation = true
                isAddressPending = true
                isMapPending = true
                requestAddress(at: coordinate)
            }
        }
        updateHeaderView(force: true)
        tableView.reloadData()
        updateActionsMenu()
    }


    // MARK: - Photo at the top of the table
    private var headerWidth: CGFloat = 0

    private func updateHeaderView(force: Bool = false) {
        guard let image = headerImage else {
            /// Setting the header again, even to nil, lays the table out again, which calls this method
            if tableView.tableHeaderView != nil { tableView.tableHeaderView = nil }
            return
        }
        let width = tableView.bounds.width
        guard width > 0, force || abs(width - headerWidth) > 1 else { return }
        headerWidth = width

        // The photo is as large as the table, up to a part of the screen
        let margin: CGFloat = 20
        let maxHeight = view.bounds.height * 0.45
        let imageWidth = width - 2 * margin
        let height = min(imageWidth * image.size.height / max(image.size.width, 1), maxHeight)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height + Self.sectionGap))
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: margin, y: 0, width: imageWidth, height: height)
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        container.addSubview(imageView)
        tableView.tableHeaderView = container
    }


    // MARK: - Address
    /// The address is found by the geocoder of the system, without keeping it
    private func requestAddress(at coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let placemark = placemarks?.first
            let place = placemark?.areasOfInterest?.first ?? placemark?.locality ?? placemark?.name ?? ""
            var address = ""
            if let postal = placemark?.postalAddress {
                address = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                    .replacingOccurrences(of: "\n", with: ", ")
            }
            Task { @MainActor in
                self?.setAddress(placeName: place, streetName: address)
            }
        }
    }

    @MainActor
    private func setAddress(placeName: String, streetName: String) {
        self.placeName = placeName
        self.streetName = placeName == streetName ? "" : streetName
        isAddressPending = false
        reloadAddressRow()
    }

    private func reloadAddressRow() {
        guard isViewLoaded, let section = model.sections.firstIndex(of: .location) else { return }
        let indexPath = IndexPath(row: Row.address.rawValue, section: section)
        guard tableView.numberOfRows(inSection: section) > indexPath.row else { return }
        UIView.performWithoutAnimation {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    @MainActor
    private func mapDidRender() {
        guard isMapPending else { return }
        isMapPending = false
        reloadAddressRow()
    }

    /// Coordinates written with a decimal point whatever the language of the user
    private var coordinateString: String {
        guard let coordinate = coordinate else { return "" }
        return unsafe String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    private var readableCoordinateString: String {
        guard let coordinate = coordinate else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 5
        formatter.maximumFractionDigits = 5
        let latitude = formatter.string(from: NSNumber(value: abs(coordinate.latitude))) ?? ""
        let longitude = formatter.string(from: NSNumber(value: abs(coordinate.longitude))) ?? ""
        return "\(latitude)° \(coordinate.latitude >= 0 ? "N" : "S"), \(longitude)° \(coordinate.longitude >= 0 ? "E" : "W")"
    }


    // MARK: - UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        return model.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let kind = self.section(at: section) else { return 0 }
        switch kind {
        case .summary:      return SummaryRow.allCases.count
        case .location:     return Row.allCases.count
        case .empty, .loading: return 1
        default:            return model.list(of: kind).rowCount
        }
    }

    private func section(at index: Int) -> Section? {
        let sections = model.sections
        return sections.indices.contains(index) ? sections[index] : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let kind = section(at: indexPath.section) else { return UITableViewCell() }
        switch kind {
        case .summary:
            return summaryCell(at: indexPath)
        case .location:
            return locationCell(at: indexPath)
        case .empty:
            let cell = labelCell("LabelTableViewCell", at: indexPath)
            cell.configure(with: String(localized: "imageExifNone_message", bundle: .pwgMetadataKit, comment: "No metadata"), detail: "")
            return cell
        case .loading:
            let cell = labelCell("LabelTableViewCell", at: indexPath)
            cell.configure(with: Localized.loading, detail: "")
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = PwgColor.rightLabel
            spinner.startAnimating()
            cell.accessoryView = spinner
            return cell
        default:
            let list = model.list(of: kind)
            guard indexPath.row < list.displayedCount else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "MoreTableViewCell", for: indexPath) as? MoreTableViewCell
                else { preconditionFailure("Could not load MoreTableViewCell") }
                cell.configure()
                return cell
            }
            // The value goes under the title when both do not fit on one line
            let entry = list.entries[indexPath.row]
            let stacked = traitCollection.preferredContentSizeCategory >= .accessibilityMedium || fitsOnOneLine(entry) == false
            let cell = labelCell(stacked ? "LabelTableViewCell2" : "LabelTableViewCell", at: indexPath)
            cell.configure(with: entry.name, detail: entry.value)
            return cell
        }
    }

    private func labelCell(_ identifier: String, at indexPath: IndexPath) -> LabelTableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as? LabelTableViewCell
        else { preconditionFailure("Could not load \(identifier)") }
        cell.accessoryView = nil
        return cell
    }

    private func summaryCell(at indexPath: IndexPath) -> UITableViewCell {
        switch SummaryRow(rawValue: indexPath.row) {
        case .file:
            // Name of the original file and its format
            let cell = labelCell("LabelTableViewCell", at: indexPath)
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
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MetadataSummaryTableViewCell.reuseIdentifier,
                                                           for: indexPath) as? MetadataSummaryTableViewCell
            else { preconditionFailure("Could not load MetadataSummaryTableViewCell") }
            cell.configure(with: summary.shooting)
            return cell
        }
    }

    private func locationCell(at indexPath: IndexPath) -> UITableViewCell {
        switch Row(rawValue: indexPath.row) {
        case .map:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MapTableViewCell.reuseIdentifier,
                                                           for: indexPath) as? MapTableViewCell
            else { preconditionFailure("Could not load MapTableViewCell") }
            cell.onRendered = { [weak self] in self?.mapDidRender() }
            if let coordinate = coordinate {
                cell.configure(with: coordinate)
            }
            return cell
        default:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.reuseIdentifier,
                                                           for: indexPath) as? AddressTableViewCell
            else { preconditionFailure("Could not load AddressTableViewCell") }
            if placeName.isEmpty {
                cell.configure(title: readableCoordinateString, subtitle: "", isLoading: isAddressPending || isMapPending)
            } else {
                cell.configure(title: placeName, subtitle: streetName, isLoading: isMapPending)
            }
            return cell
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

    /// The title and the value of an entry fit on a single line of the table
    private func fitsOnOneLine(_ entry: ImageMetadataEntry) -> Bool {
        let cellWidth = measuredCellWidth ?? (tableView.bounds.width - 2 * 20)
        let attributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        let titleWidth = ceil((entry.name as NSString).size(withAttributes: attributes).width)
        let valueWidth = ceil((entry.value as NSString).size(withAttributes: attributes).width)
        return titleWidth + valueWidth <= cellWidth - Self.rowSideSpace
    }


    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let kind = self.section(at: section), kind.isList {
            let header = model.header(of: kind)
            return TableViewUtilities.heightOfHeader(withTitle: header.title, text: header.text,
                                                     width: tableView.bounds.width)
        }
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let kind = self.section(at: section), kind.isList {
            let header = model.header(of: kind)
            return TableViewUtilities.viewOfHeader(withTitle: header.title, text: header.text)
        }
        return UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = PwgColor.cellBackground

        // The layout of the rows depends on the width of the cells, known once one is displayed
        guard cell is LabelTableViewCell, cell.bounds.width > 0,
              abs(cell.bounds.width - (measuredCellWidth ?? 0)) > 1
        else { return }
        let isFirstMeasure = measuredCellWidth == nil
        measuredCellWidth = cell.bounds.width
        guard isFirstMeasure == false || abs(cell.bounds.width - (tableView.bounds.width - 2 * 20)) > 1
        else { return }
        let sections = IndexSet(model.sections.indices.filter { model.sections[$0].isList })
        guard sections.isEmpty == false else { return }
        DispatchQueue.main.async { [weak self] in
            UIView.performWithoutAnimation {
                self?.tableView.reloadSections(sections, with: .none)
            }
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        // The location, the cell asking for more metadata and the rows holding a value respond to taps
        guard let kind = section(at: indexPath.section) else { return false }
        switch kind {
        case .location:                         return true
        case .empty, .loading:                  return false
        case .summary:                          return copyableText(at: indexPath)?.isEmpty == false
        default:
            let list = model.list(of: kind)
            return (list.showsMoreRow && indexPath.row == list.displayedCount) || indexPath.row < list.displayedCount
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let kind = section(at: indexPath.section) else { return }
        switch kind {
        case .location:
            presentLocationActions()
        case .empty, .loading:
            break
        case .summary:
            presentCopyMenu(at: indexPath)
        default:
            let list = model.list(of: kind)
            if list.showsMoreRow, indexPath.row == list.displayedCount {
                expand(kind, at: indexPath.section)
            } else {
                presentCopyMenu(at: indexPath)
            }
        }
    }

    /// Shows all the metadata of a section
    private func expand(_ section: Section, at index: Int) {
        let limit = MetadataList.rowsLimit
        let count = model.list(of: section).entries.count
        guard model.expand(section) else { return }
        tableView.performBatchUpdates {
            tableView.deleteRows(at: [IndexPath(row: limit, section: index)], with: .fade)
            tableView.insertRows(at: (limit..<count).map { IndexPath(row: $0, section: index) }, with: .fade)
        }
    }


    // MARK: - Copy of a Value
    /// Value of a metadata, or lines of the summary
    private func copyableText(at indexPath: IndexPath) -> String? {
        guard let kind = section(at: indexPath.section) else { return nil }
        switch kind {
        case .summary:
            switch SummaryRow(rawValue: indexPath.row) {
            case .file:     return summary.title
            case .camera:   return [summary.camera, summary.lens, summary.details].filter { $0.isEmpty == false }.joined(separator: "\n")
            default:        return summary.shooting.joined(separator: " | ")
            }
        case .location, .empty, .loading:
            return nil
        default:
            let list = model.list(of: kind)
            return indexPath.row < list.displayedCount ? list.entries[indexPath.row].value : nil
        }
    }

    /// Proposes to copy the value of a row, in the menu which the system shows above a text
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


    // MARK: - Menu of the Navigation Bar
    /// The location of the photo as it is known
    private var exportedLocation: MetadataLocation? {
        guard let coordinate = coordinate else { return nil }
        return MetadataLocation(latitude: coordinate.latitude, longitude: coordinate.longitude,
                                place: placeName, address: streetName)
    }

    /// Copy of all the metadata, as a list or as a JSON object
    private func actionsMenu() -> UIMenu {
        let hasContent = model.sections.contains { $0.isList } || coordinate != nil
        let attributes: UIMenuElement.Attributes = hasContent ? [] : .disabled
        let copyList = UIAction(title: String(localized: "metadataExtension_copyList", comment: "Copy as List"),
                                image: UIImage(systemName: "list.bullet"), attributes: attributes) { [weak self] _ in
            guard let self = self else { return }
            UIPasteboard.general.string = self.model.asciiList(location: self.exportedLocation)
        }
        let copyJSON = UIAction(title: String(localized: "metadataExtension_copyJSON", comment: "Copy as JSON Object"),
                                image: UIImage(systemName: "curlybraces"), attributes: attributes) { [weak self] _ in
            guard let self = self else { return }
            UIPasteboard.general.string = self.model.jsonObject(location: self.exportedLocation)
        }
        return UIMenu(children: [copyList, copyJSON])
    }

    private func updateActionsMenu() {
        navigationItem.rightBarButtonItem?.menu = actionsMenu()
    }


    // MARK: - Location Actions
    /// Proposes to copy the GPS coordinates or to open Apple Maps at the location
    private func presentLocationActions() {
        guard let coordinate = coordinate else { return }
        let alert = UIAlertController(title: readableCoordinateString,
                                      message: placeName.isEmpty ? nil
                                      : [placeName, streetName].filter({ $0.isEmpty == false }).joined(separator: "\n"),
                                      preferredStyle: .alert)
        let coordinates = coordinateString
        alert.addAction(UIAlertAction(title: String(localized: "imageLocation_copy", bundle: .pwgMetadataKit,
                                                    comment: "Copy GPS Coordinates"), style: .default) { _ in
            UIPasteboard.general.string = coordinates
        })
        let name = placeName
        alert.addAction(UIAlertAction(title: String(localized: "imageLocation_openMaps", bundle: .pwgMetadataKit,
                                                    comment: "Open in Maps"), style: .default) { _ in
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = name.isEmpty ? nil : name
            mapItem.openInMaps(launchOptions: nil)
        })
        alert.addAction(UIAlertAction(title: Localized.cancel, style: .cancel))
        present(alert, animated: true)
    }
}


// MARK: - UIEditMenuInteractionDelegate
@available(iOS 16.0, *)
extension MetadataViewController: @MainActor UIEditMenuInteractionDelegate
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
