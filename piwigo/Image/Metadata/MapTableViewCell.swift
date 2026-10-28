//
//  MapTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Cell of the metadata table presenting the location on a map.
//

import UIKit
import MapKit
import CoreLocation

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

        // The map only shows the location: it neither moves nor zooms
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
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
