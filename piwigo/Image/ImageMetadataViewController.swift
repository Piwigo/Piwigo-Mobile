//
//  ImageMetadataViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 26/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Table presenting the metadata of a photo or a video: for the time being,
//  a map centred on the location where it was taken and the address of this location.
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


    // MARK: - Rows
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coordinate == nil ? 0 : Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        switch Row(rawValue: indexPath.row) {
        case .map:
            return Self.mapRowHeight
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return Self.sectionGap
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = PwgColor.cellBackground
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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


// MARK: - Map Cell
final class MapTableViewCell: UITableViewCell, MKMapViewDelegate
{
    static let reuseIdentifier = "MapTableViewCell"

    /// Called when the map has rendered its tiles, or has failed to load them
    var onRendered: (() -> Void)?

    @IBOutlet weak var mapView: MKMapView!
    private let regionSize: CLLocationDistance = 400    // meters

    override func awakeFromNib() {
        super.awakeFromNib()

        // The table handles touches (scrolling, tap)
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .image
        mapView.delegate = self
    }

    func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
        onRendered?()
    }

    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
        onRendered?()
    }

    func configure(with coordinate: CLLocationCoordinate2D) {
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        mapView.setRegion(MKCoordinateRegion(center: coordinate,
                                             latitudinalMeters: regionSize,
                                             longitudinalMeters: regionSize), animated: false)
        accessibilityLabel = String(localized: "imageLocation_map", comment: "Map")
    }
}


// MARK: - Address Cell
final class AddressTableViewCell: UITableViewCell
{
    static let reuseIdentifier = "AddressTableViewCell"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var spinner: UIActivityIndicatorView!

    func configure(title: String, subtitle: String, isLoading: Bool) {
        titleLabel.text = title
        titleLabel.textColor = PwgColor.leftLabel
        subtitleLabel.text = subtitle
        subtitleLabel.textColor = PwgColor.rightLabel
        subtitleLabel.isHidden = subtitle.isEmpty
        spinner.color = PwgColor.rightLabel
        if isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
        spinner.stopAnimating()
    }
}


// MARK: - Floating Card (iPad)
/// Card floating over the photo, presenting the metadata table below a title and a close button.
/// The user drags the card by its title or its grabber, and it settles in the nearest corner.
final class MetadataCardView: UIView, UIGestureRecognizerDelegate
{
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    // MARK: - Dimensions
    static let width: CGFloat = pwgPadSubViewWidth
    static let headerHeight: CGFloat = 56
    static let footerHeight: CGFloat = 24
    static func preferredHeight(hasLocation: Bool) -> CGFloat {
        return headerHeight + ImageMetadataViewController.preferredContentHeight(hasLocation: hasLocation) + footerHeight
    }
    
    // MARK: - Views
    var onClose: (() -> Void)?
    let panGesture = UIPanGestureRecognizer()
    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let grabber = UIView()
    
    // MARK: - Initialisation
    init(contentView: UIView) {
        super.init(frame: .zero)
        
        // Shadow, around a view clipping its content to rounded corners
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        accessibilityIdentifier = "ImageMetadataCard"
        
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 24
        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        // Title
        titleLabel.text = String(localized: "imageInfo_title", comment: "Information")
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = PwgColor.leftLabel
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.accessibilityTraits = .header
        
        // Close button
        closeButton.setImage(UIImage(systemName: "xmark",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)),
                             for: .normal)
        closeButton.tintColor = PwgColor.leftLabel
        closeButton.accessibilityLabel = Localized.dismiss
        closeButton.accessibilityIdentifier = "closeMetadata"
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Grabber
        grabber.backgroundColor = PwgColor.rightLabel.withAlphaComponent(0.6)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        
        // Table
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let container = effectView.contentView
        container.addSubview(contentView)
        container.addSubview(titleLabel)
        container.addSubview(closeButton)
        container.addSubview(grabber)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: container.topAnchor, constant: Self.headerHeight / 2 + 4),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            contentView.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.headerHeight),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.footerHeight),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grabber.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5)
        ])
        
        // The card is dragged by its title and its grabber, not by the table
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        // Colors follow the palette of the app
        applyColorPalette()
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @MainActor
    @objc func applyColorPalette() {
        // The palette of the app is independent from the appearance of the system:
        /// the material, the label colors and the map in the table adopt that of the palette.
        overrideUserInterfaceStyle = UIVars.shared.isDarkPaletteActive ? .dark : .light
        titleLabel.textColor = PwgColor.leftLabel
        closeButton.tintColor = PwgColor.leftLabel
        grabber.backgroundColor = PwgColor.rightLabel.withAlphaComponent(0.6)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 24).cgPath
    }
    
    // MARK: - Actions
    @objc private func didTapClose() {
        onClose?()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let y = touch.location(in: self).y
        return y < Self.headerHeight || y > bounds.height - Self.footerHeight
    }
}
