//
//  MapTableViewCell.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 28/10/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//
//  Cell of the metadata table presenting the location on a map.
//  The map is an image taken once by a snapshotter, which spares the memory of a live map view.
//

import UIKit
import MapKit
import CoreLocation

final class MapTableViewCell: UITableViewCell
{
    static let reuseIdentifier = "MapTableViewCell"

    /// Called when the snapshot of the map has been taken, or has failed
    var onRendered: (() -> Void)?

    @IBOutlet weak var mapImageView: UIImageView!
    private let regionSize: CLLocationDistance = 400    // meters
    private static let snapshots = NSCache<NSString, UIImage>()

    private var coordinate: CLLocationCoordinate2D?
    private var snapshotter: MKMapSnapshotter?
    private var snapshotKey: String?

    override func awakeFromNib() {
        super.awakeFromNib()

        // The table handles touches (scrolling, tap)
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .image
        mapImageView.contentMode = .scaleAspectFill
        mapImageView.clipsToBounds = true
        mapImageView.backgroundColor = .secondarySystemFill
    }

    func configure(with coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        accessibilityLabel = String(localized: "imageLocation_map", comment: "Map")
        takeSnapshotIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The size of the image is known once the cell is laid out
        takeSnapshotIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        snapshotter?.cancel()
        snapshotter = nil
        snapshotKey = nil
        coordinate = nil
        mapImageView.image = nil
    }

    private func takeSnapshotIfNeeded() {
        guard let coordinate = coordinate else { return }
        let size = mapImageView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        // Same map as the one shown?
        let isDark = traitCollection.userInterfaceStyle == .dark
        let key = String(format: "%.5f,%.5f,%.0fx%.0f,%.0f,%d", coordinate.latitude, coordinate.longitude,
                         size.width, size.height, traitCollection.displayScale, isDark ? 1 : 0)
        guard key != snapshotKey else { return }
        snapshotKey = key
        snapshotter?.cancel()

        // Snapshot already taken?
        if let image = Self.snapshots.object(forKey: key as NSString) {
            mapImageView.image = image
            DispatchQueue.main.async { [weak self] in self?.onRendered?() }
            return
        }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: regionSize, longitudinalMeters: regionSize)
        options.size = size
        options.traitCollection = traitCollection
        options.pointOfInterestFilter = .includingAll
        let snapshotter = MKMapSnapshotter(options: options)
        self.snapshotter = snapshotter
        snapshotter.start(with: .main) { [weak self] snapshot, _ in
            guard let self, self.snapshotKey == key else { return }
            if let snapshot = snapshot {
                let image = Self.image(of: snapshot, marking: coordinate)
                Self.snapshots.setObject(image, forKey: key as NSString)
                self.mapImageView.image = image
            }
            self.onRendered?()
        }
    }

    /// The snapshot does not draw annotations: a pin is drawn at the location
    private static func image(of snapshot: MKMapSnapshotter.Snapshot, marking coordinate: CLLocationCoordinate2D) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        let pin = UIImage(systemName: "mappin", withConfiguration: configuration)?
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        return UIGraphicsImageRenderer(size: snapshot.image.size).image { _ in
            snapshot.image.draw(at: .zero)
            guard let pin = pin else { return }
            let point = snapshot.point(for: coordinate)
            pin.draw(at: CGPoint(x: point.x - pin.size.width / 2, y: point.y - pin.size.height))
        }
    }
}
