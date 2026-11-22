//
//  LocationPanelViewController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/11/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Lets the user choose where a photo was taken: the map moves under a pin fixed at its centre,
//  the user types an address or pastes GPS coordinates (DD, DDM or DMS) in the search field.
//

import UIKit
import MapKit
import CoreLocation
import Contacts
import PwgKit
import PwgUIKit
import PwgMetadataKit

@MainActor
protocol LocationPanelDelegate: AnyObject {
    /// The panel is dismissed: the delegate updates the location of the photo
    func locationPanel(_ panel: LocationPanelViewController, didChoose coordinate: CLLocationCoordinate2D)
    /// The panel is dismissed without any change
    func locationPanelDidCancel(_ panel: LocationPanelViewController)
}

/// Modes of the map, named and ordered as in the Maps app
enum LocationMapMode: Int, CaseIterable {
    case explore, driving, transit, satellite

    var title: String {
        switch self {
        case .explore:   return String(localized: "locationMapMode_explore", comment: "Explore")
        case .driving:   return String(localized: "locationMapMode_driving", comment: "Driving")
        case .transit:   return String(localized: "locationMapMode_transit", comment: "Transit")
        case .satellite: return String(localized: "locationMapMode_satellite", comment: "Satellite")
        }
    }

    /// Icon of the mode. The one of the satellite mode is the globe showing the area of the coordinate, if it is known.
    func symbolName(near coordinate: CLLocationCoordinate2D? = nil) -> String {
        switch self {
        case .explore:   return "map.fill"
        case .driving:   return "car.fill"
        case .transit:   return "tram.fill"
        case .satellite: return Self.globeSymbolName(near: coordinate)
        }
    }

    /// The globes of SF Symbols, from the west to the east: the Americas, Europe and Africa,
    /// central and south Asia, east Asia and Australia
    static func globeSymbolName(near coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate, CLLocationCoordinate2DIsValid(coordinate),
              abs(coordinate.latitude) > 1e-6 || abs(coordinate.longitude) > 1e-6
        else { return "globe.fill" }
        let name: String
        switch coordinate.longitude {
        case ..<(-30):     name = "globe.americas.fill"
        case ..<60:        name = "globe.europe.africa.fill"
        case ..<110:       name = "globe.central.south.asia.fill"
        default:           name = "globe.asia.australia.fill"
        }
        /// The globe of central and south Asia is more recent than the other ones
        return UIImage(systemName: name) != nil ? name : "globe.fill"
    }

    /// Applies the mode to the map
    @MainActor
    func apply(to mapView: MKMapView) {
        switch self {
        case .explore:
            mapView.mapType = .standard
            mapView.showsTraffic = false
            mapView.pointOfInterestFilter = .includingAll
        case .driving:
            mapView.mapType = .mutedStandard
            mapView.showsTraffic = true
            mapView.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation, .evCharger, .parking])
        case .transit:
            mapView.mapType = .mutedStandard
            mapView.showsTraffic = false
            mapView.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        case .satellite:
            mapView.mapType = .hybrid
            mapView.showsTraffic = false
            mapView.pointOfInterestFilter = .includingAll
        }
    }
}

final class LocationPanelViewController: UIViewController
{
    weak var delegate: (any LocationPanelDelegate)?

    /// Location known for the photo, nil if it has none: the map then starts at the last location chosen
    var originalCoordinate: CLLocationCoordinate2D?

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pinImageView: UIImageView!
    @IBOutlet weak var coordinatesLabel: UILabel!

    private var saveButton: UIBarButtonItem!
    private var mapModeButton: UIButton!
    /// Centre of the map once it is laid out, which the choice must differ from when the photo has a location
    private var startCoordinate: CLLocationCoordinate2D?
    private lazy var locationManager = CLLocationManager()
    private var searchTask: Task<Void, Never>?
    private let geocoder = CLGeocoder()
    private var addressTask: Task<Void, Never>?


    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Title is the command which opened the panel
        title = originalCoordinate == nil
            ? String(localized: "imageOptions_addLocation", comment: "Add Location")
            : String(localized: "imageOptions_adjustLocation", comment: "Adjust Location")
        isModalInPresentation = true

        // Buttons: Cancel on the left, Save on the right once the choice differs from the current location
        let cancel = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelChoice))
        cancel.accessibilityIdentifier = "cancelLocation"
        saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveChoice))
        saveButton.accessibilityIdentifier = "saveLocation"
        navigationItem.leftBarButtonItem = cancel
        navigationItem.rightBarButtonItem = saveButton

        // Search field
        searchBar.placeholder = String(localized: "locationPanel_search", comment: "Address or GPS coordinates")
        searchBar.returnKeyType = .search
        searchBar.autocapitalizationType = .none
        searchBar.accessibilityIdentifier = "searchLocation"

        // Map under a pin fixed at its centre: the tip of the pin marks the location
        mapView.delegate = self
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        configureMapModeButton()
        pinImageView.image = UIImage(systemName: "mappin", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold))
        pinImageView.tintColor = .systemRed
        pinImageView.isUserInteractionEnabled = false
        pinImageView.isAccessibilityElement = false

        // Coordinates below the map
        coordinatesLabel.font = .monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        coordinatesLabel.accessibilityIdentifier = "locationCoordinates"

        applyColorPalette()
        locationManager.delegate = self
        centreMapAtStart()
        updateCoordinates()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The layout of the map is final: its centre is the one to compare with
        if startCoordinate == nil {
            startCoordinate = mapView.centerCoordinate
            updateCoordinates()
            scheduleAddressUpdate(after: 0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(applyColorPalette),
                                               name: Notification.Name.pwgPaletteChanged, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.pwgPaletteChanged, object: nil)
        searchTask?.cancel()
        addressTask?.cancel()
        geocoder.cancelGeocode()
    }

    @MainActor
    @objc func applyColorPalette() {
        view.backgroundColor = PwgColor.background
        navigationController?.navigationBar.configAppearance(withLargeTitles: false)
        searchBar.tintColor = PwgColor.tintColor
        coordinatesLabel.textColor = PwgColor.leftLabel
        mapView.tintColor = PwgColor.tintColor
    }


    // MARK: - Mode of the Map
    private var mapMode: LocationMapMode {
        return LocationMapMode(rawValue: ImageVars.shared.locationMapMode) ?? .explore
    }

    /// A button over the map, as in the Maps app, with the compass below it
    private func configureMapModeButton() {
        let button = UIButton(type: .system)
        if #available(iOS 26.0, *) {
            button.configuration = .glass()
        } else {
            var configuration = UIButton.Configuration.plain()
            configuration.background.backgroundColor = .secondarySystemBackground
            configuration.background.cornerRadius = 10
            button.configuration = configuration
        }
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = String(localized: "locationMapMode_title", comment: "Map Mode")
        button.accessibilityIdentifier = "mapModeButton"
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        mapModeButton = button

        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .adaptive
        compass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(compass)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            compass.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 12),
            compass.centerXAnchor.constraint(equalTo: button.centerXAnchor)
        ])
        mapMode.apply(to: mapView)
        updateMapModeMenu()
    }

    /// The satellite icon follows the area under the pin
    private func refreshMapModeIcon() {
        guard let mapModeButton else { return }
        mapModeButton.configuration?.image = UIImage(systemName: mapMode.symbolName(near: mapView.centerCoordinate))
    }

    /// The button shows the icon of the current mode, the menu lists the modes with a check mark on the current one
    private func updateMapModeMenu() {
        refreshMapModeIcon()
        let actions = LocationMapMode.allCases.map { mode in
            UIAction(title: mode.title, image: UIImage(systemName: mode.symbolName(near: mapView.centerCoordinate)),
                     state: mode == mapMode ? .on : .off) { [weak self] _ in
                guard let self else { return }
                ImageVars.shared.locationMapMode = mode.rawValue
                mode.apply(to: mapView)
                updateMapModeMenu()
            }
        }
        mapModeButton.menu = UIMenu(title: String(localized: "locationMapMode_title", comment: "Map Mode"),
                                    options: .singleSelection, children: actions)
    }


    // MARK: - Position of the Map
    /// The map starts
    /// - at the location of the photo, if it has one,
    /// - otherwise at the last location chosen,
    /// - otherwise at the current location of the device: the user is asked for the authorisation only once,
    ///   the map starts at (0, 0) when it is refused.
    private func centreMapAtStart() {
        if let coordinate = originalCoordinate {
            centre(on: coordinate, meters: 1000)
            return
        }
        let last = CLLocationCoordinate2D(latitude: ImageVars.shared.lastLocationLatitude,
                                          longitude: ImageVars.shared.lastLocationLongitude)
        if CLLocationCoordinate2DIsValid(last), isZero(last) == false {
            centre(on: last, meters: 2000)
            return
        }
        centreOnWholeWorld()
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    private func centre(on coordinate: CLLocationCoordinate2D, meters: CLLocationDistance, animated: Bool = false) {
        mapView.setRegion(MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters),
                          animated: animated)
    }

    private func centreOnWholeWorld() {
        mapView.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                             span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)),
                          animated: false)
    }

    private func isZero(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return abs(coordinate.latitude) < 1e-6 && abs(coordinate.longitude) < 1e-6
    }

    /// Coordinates shown below the map, Save available once the choice differs from the location of the photo
    private func updateCoordinates() {
        let coordinate = mapView.centerCoordinate
        coordinatesLabel.text = GeographicCoordinates.string(latitude: coordinate.latitude, longitude: coordinate.longitude)
        saveButton?.isEnabled = isValidChoice(coordinate)
        if mapMode == .satellite { refreshMapModeIcon() }
    }

    /// (0, 0) means "no location" for the server. A location already known is worth a change of more than a metre.
    private func isValidChoice(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate), isZero(coordinate) == false else { return false }
        if originalCoordinate != nil {
            guard let start = startCoordinate else { return false }
            return abs(coordinate.latitude - start.latitude) > 1e-5 || abs(coordinate.longitude - start.longitude) > 1e-5
        }
        return true
    }


    // MARK: - Buttons
    @objc private func cancelChoice() {
        dismiss(animated: true) { [self] in
            delegate?.locationPanelDidCancel(self)
        }
    }

    @objc private func saveChoice() {
        let coordinate = mapView.centerCoordinate
        guard isValidChoice(coordinate) else { return }
        ImageVars.shared.lastLocationLatitude = coordinate.latitude
        ImageVars.shared.lastLocationLongitude = coordinate.longitude
        dismiss(animated: true) { [self] in
            delegate?.locationPanel(self, didChoose: coordinate)
        }
    }


    // MARK: - Address
    /// The search field shows the address under the pin: the one of the location of the photo when the panel opens,
    /// then the one of the place where the user moves the map. It does not change while the user types in it.
    private func scheduleAddressUpdate(after delay: TimeInterval) {
        addressTask?.cancel()
        addressTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard Task.isCancelled == false, let self else { return }
            await updateAddress()
        }
    }

    private func updateAddress() async {
        let coordinate = mapView.centerCoordinate
        guard isZero(coordinate) == false, searchBar.isFirstResponder == false else { return }
        geocoder.cancelGeocode()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        // A newer move or the user typing made this address obsolete
        guard Task.isCancelled == false, searchBar.isFirstResponder == false else { return }
        searchBar.text = placemark.flatMap(addressText(of:)) ?? ""
    }

    private func addressText(of placemark: CLPlacemark) -> String? {
        let address: String
        if let postalAddress = placemark.postalAddress {
            address = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
                .replacingOccurrences(of: "\n", with: ", ")
        } else {
            address = [placemark.name, placemark.locality, placemark.country].compactMap { $0 }.joined(separator: ", ")
        }
        return address.isEmpty ? nil : address
    }


    // MARK: - Search
    /// GPS coordinates are taken as they are, anything else is an address
    private func search(_ text: String) {
        if let position = GeographicCoordinates.parse(text) {
            let coordinate = CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
            centre(on: coordinate, meters: 500, animated: true)
            return
        }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            request.region = mapView.region
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard Task.isCancelled == false else { return }
                if let item = response.mapItems.first {
                    centre(on: item.placemark.coordinate, meters: 1000, animated: true)
                } else {
                    showNoPlace()
                }
            } catch {
                guard Task.isCancelled == false else { return }
                showNoPlace()
            }
        }
    }

    private func showNoPlace() {
        let alert = UIAlertController(title: String(localized: "locationPanel_noPlaceTitle", comment: "No Place Found"),
                                      message: String(localized: "locationPanel_noPlaceMessage",
                                                      comment: "Check the address or enter GPS coordinates."),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.ok, style: .cancel))
        alert.view.tintColor = PwgColor.tintColor
        present(alert, animated: true) {
            alert.view.tintColor = PwgColor.tintColor
        }
    }
}


// MARK: - UISearchBarDelegate
extension LocationPanelViewController: UISearchBarDelegate
{
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        let text = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        search(text)
    }
}


// MARK: - MKMapViewDelegate
extension LocationPanelViewController: MKMapViewDelegate
{
    /// The coordinates follow the map while it moves
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        updateCoordinates()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        updateCoordinates()
        // Once the map stops, after the first layout, the address of the new place
        if startCoordinate != nil {
            scheduleAddressUpdate(after: 0.6)
        }
    }
}


// MARK: - CLLocationManagerDelegate
extension LocationPanelViewController: @MainActor CLLocationManagerDelegate
{
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // The user may have started to move the map: do not take it away
        guard let location = locations.last, isZero(mapView.centerCoordinate) else { return }
        centre(on: location.coordinate, meters: 2000, animated: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // The map stays where it is
    }
}
