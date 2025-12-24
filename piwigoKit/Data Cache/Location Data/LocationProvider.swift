//
//  LocationProvider.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 17/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//


import CoreData
import CoreLocation

let pwgMaxNberOfLocationsToDecode: Int = 10
let a: Double = 6378137.0               // Equatorial radius in meters
let e2: Double = 0.00669437999014       // Earth eccentricity squared

public final class LocationProvider: NSObject {
        
    // MARK: - Initialisation
    public override init() {
        // Prepare list of operations
        queue.maxConcurrentOperationCount = 1   // Make it a serial queue
        queue.qualityOfService = .background    // fetch location names in the background
        // Initialise locations in queue
        queuedLocations = Set<LocationProperties>()
    }
    
    private var geocoder = CLGeocoder()
    private var queue = OperationQueue()
    private var queuedLocations: Set<LocationProperties>

        
    // MARK: - Fetch Place Names
    /**
     Submits a reverse-geocoding request for the specified location, imports it into Core Data,
     and notify views when the new place name is available.
     The requests are stored in a queue and performed one after the other by a shared instance.
    */
    private func fetchPlaceName(at location: LocationProperties, 
                                completionHandler: @escaping (PwgKitError?) -> Void) {
        
        // Add Geocoder request in queue
        let operation = BlockOperation(block: {
            let semaphore = DispatchSemaphore(value: 0)

            // Initialisation
            let bckgContext = DataController.shared.newTaskContext()
            let newLocation = CLLocation(latitude: location.latitude!, longitude: location.longitude!)

            // Request place name
            self.geocoder.reverseGeocodeLocation(newLocation, completionHandler: { placemarks, error in

                // Extract existing data
                if error == nil && placemarks != nil && (placemarks?.count ?? 0) > 0 {
                    // Extract data
                    let placeMark = placemarks?[0]
                    let country: String = placeMark?.country ?? ""
                    let administrativeArea: String = placeMark?.administrativeArea ?? ""
                    let subAdministrativeArea: String = placeMark?.subAdministrativeArea ?? ""
                    let region: CLCircularRegion = placeMark?.region as! CLCircularRegion
                    let locality: String = placeMark?.locality ?? ""
                    let subLocality: String = placeMark?.subLocality ?? ""
                    let thoroughfare: String = placeMark?.thoroughfare ?? ""
                    let subThoroughfare: String = placeMark?.subThoroughfare ?? ""
                    let inlandWater: String = placeMark?.inlandWater ?? ""
                    let ocean: String = placeMark?.ocean ?? ""

                    // Define place name
                    var placeName = ""
                    var streetName = ""

                    // => Display ocean name if somewhere in an ocean
                    if ocean.count > 0 {
                        placeName = ocean
                        if country.count > 0 {
                            streetName = country
                        }
                    }
                    // => Display name of inland body of water if somewhere in such inland body
                    else if inlandWater.count > 0 {
                        placeName = inlandWater
                        if country.count > 0 {
                            streetName = country
                        }
                    }
                    // => Display thoroughfare if available
                    else if thoroughfare.count != 0 {
                        placeName = thoroughfare
                        if subThoroughfare.count != 0, subThoroughfare != thoroughfare {
                            placeName = String(format: "%@ %@", subThoroughfare, thoroughfare)
                        }
                        if subLocality.count != 0, subLocality != thoroughfare {
                            streetName = subLocality
                        } else if locality.count != 0, locality != subLocality {
                            streetName = locality
                        } else if subAdministrativeArea.count != 0, subAdministrativeArea != subLocality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0, administrativeArea != subLocality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // => Display sublocality if available
                    else if subLocality.count != 0 {
                        placeName = subLocality
                        if locality.count != 0, locality != subLocality {
                            streetName = locality
                        } else if subAdministrativeArea.count != 0, subAdministrativeArea != subLocality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0, administrativeArea != subLocality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // => Display locality if available
                    else if locality.count != 0 {
                        placeName = locality
                        if subAdministrativeArea.count != 0, subAdministrativeArea != locality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0, administrativeArea != locality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // Locality not available, use administrative info if possible
                    else if subAdministrativeArea.count != 0 {
                        placeName = subAdministrativeArea
                        if administrativeArea.count != 0, administrativeArea != subAdministrativeArea {
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // subAdministrativeArea not available, use administrative info if possible
                    else if administrativeArea.count != 0 {
                        placeName = administrativeArea
                        if country.count != 0 {
                            streetName = country
                        }
                    }

                    // If all images are not localised in this place, add comment
                    if region.radius < location.radius ?? kCLLocationAccuracyBestForNavigation {
                        placeName.append(String(localized: "andMore", bundle: piwigoKit, comment: " & more"))
                    }

                    // Log placemarks[0]
//                    debugPrint("\n===>> name:\(placeMark?.name ?? ""), country:\(country), administrativeArea:\(administrativeArea), subAdministrativeArea:\(subAdministrativeArea), locality:\(locality), subLocality:\(subLocality), thoroughfare:\(thoroughfare), subThoroughfare:\(placeMark?.subThoroughfare ?? ""), region:\(region), areasOfInterest:\(placeMark?.areasOfInterest?[0] ?? ""), inlandWater:\(inlandWater), ocean:\(ocean)\n")

                    DispatchQueue.global(qos: .background).async { [self] in
                        // Add new location to CoreData store
                        let newLocation = LocationProperties(latitude: location.latitude,
                                                             longitude: location.longitude,
                                                             radius: region.radius,
                                                             placeName: placeName, streetName: streetName)
                        self.importOneLocation(newLocation, taskContext: bckgContext) {
                            // Remove location from queue
                            self.queuedLocations.remove(location)
                            // Update corresponding headers
                            DispatchQueue.main.async {
                                let userInfo = ["hash" : location.hashValue,
                                                "placeName" : placeName,
                                                "streetName" : streetName]
                                NotificationCenter.default.post(name: Notification.Name.pwgPlaceNamesAvailable,
                                                                object: nil, userInfo: userInfo)
                            }
                        }
                    }
                } else {
                    // Did not return place names
                    debugPrint(String(format: "Geocoder: no place mark returned!\n=> %@", error?.localizedDescription ?? ""))
                }
                semaphore.signal()
            })

            _ = (semaphore.wait(timeout: DispatchTime.distantFuture) == .success ? 0 : -1)
        })

        queue.addOperation(operation)
//        debugPrint("===> fetchPlaceName operations:", queue.operationCount)
    }


    /**
     Imports one location, creating a managed object from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    private func importOneLocation(_ locationData: LocationProperties, taskContext: NSManagedObjectContext,
                                   completion: @escaping () -> Void) -> Void {
        
        // taskContext.performAndWait runs on a background queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Create a Location managed object on the private queue context.
            guard let newLocation = NSEntityDescription.insertNewObject(forEntityName: "Location", into: taskContext) as? Location
            else {
                debugPrint(PwgKitError.locationCreationError.localizedDescription)
                return
            }
            
            // Populate the Location's properties using the raw data.
            do {
                try newLocation.update(with: locationData)
            }
            catch PwgKitError.missingLocationData {
                // Delete invalid Location from the private queue context.
                debugPrint(PwgKitError.missingLocationData.localizedDescription)
                taskContext.delete(newLocation)
            }
            catch {
                debugPrint(error.localizedDescription)
            }
            
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()
                }
                catch {
                    debugPrint("Error: \(error.localizedDescription)\nCould not save Core Data context.")
                    return
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()
            }
        }
        
        // Remove location from queue and update headers
        completion()
    }
    

    // MARK: - Clear Locations
    /**
        Return number of locations stored in cache
     */
    public func getObjectCount(inContext taskContext: NSManagedObjectContext) -> Int64 {

        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<NSNumber>(entityName: "Location")
        fetchRequest.resultType = .countResultType
        
        // Fetch number of objects
        do {
            let countResult = try taskContext.fetch(fetchRequest)
            return countResult.first!.int64Value
        }
        catch let error {
            debugPrint("••> Location count not fetched: \(error.localizedDescription)")
        }
        return Int64.zero
    }
    
    /**
     Clear cached Core Data location entry
    */
    public func clearAll() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = Location.fetchRequest()

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<any NSFetchRequestResult>)

        // Execute batch delete request
        let bckgContext = DataController.shared.newTaskContext()
        try? bckgContext.executeAndMergeChanges(using: batchDeleteRequest)
    }


    // MARK: - Get Place Names
    /**
     Routine returning the place name of a location
     This routine adds an operation fetching the place name if necessary
     */
    @MainActor
    public func getPlaceName(for location: CLLocation,
                             completion: @escaping (String, String) -> Void,
                             pending: @escaping (Int) -> Void,
                             failure: @escaping () -> Void) -> Void {

        // Check coordinates
        if !CLLocationCoordinate2DIsValid(location.coordinate) ||
            ((location.coordinate.latitude == -180.0) && (location.coordinate.longitude == -180.0)) {
            // Invalid location -> No place name
            failure()
            return
        }

        // Create a fetch request for the location
        let fetchRequest = Location.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Location.latitude), ascending: true),
                                        NSSortDescriptor(key: #keyPath(Location.longitude), ascending: true)]
        let deltaLatitude = getDeltaLatitude(for: location.coordinate.latitude, radius: location.horizontalAccuracy)
        let latitudeMinPredicate = NSPredicate(format: "latitude >= %lf", location.coordinate.latitude - deltaLatitude)
        let latitudeMaxPredicate = NSPredicate(format: "latitude <= %lf", location.coordinate.latitude + deltaLatitude)
        let deltaLongitude = getDeltaLongitude(for: location.coordinate.latitude, radius: location.horizontalAccuracy)
        let longitudeMinPredicate = NSPredicate(format: "longitude >= %lf", location.coordinate.longitude - deltaLongitude)
        let longitudeMaxPredicate = NSPredicate(format: "longitude <= %lf", location.coordinate.longitude + deltaLongitude)
        var compoundPredicate = NSCompoundPredicate()
        compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [latitudeMinPredicate,latitudeMaxPredicate,longitudeMinPredicate, longitudeMaxPredicate])
        fetchRequest.predicate = compoundPredicate
        
        // Loop over known places
        let mainContext = DataController.shared.mainContext
        do {
            let knownPlaceNames = try mainContext.fetch(Location.fetchRequest())
            for knownPlace: Location in knownPlaceNames {
                // Known location
                let knownLatitude = knownPlace.latitude
                let knownLongitude = knownPlace.longitude
                let knownLocation = CLLocation(latitude: knownLatitude, longitude: knownLongitude)

                // Do we know the place of this location?
                if location.distance(from: knownLocation) <= knownPlace.radius {
                    completion(knownPlace.placeName, knownPlace.streetName)
                    return
                }
            }
        }
        catch {
            failure()
            return
        }
        
        // Place names unknown —> Prepare fetch
        let newLocation = LocationProperties(latitude: location.coordinate.latitude,
                                             longitude: location.coordinate.longitude,
                                             radius: location.horizontalAccuracy,
                                             placeName: "", streetName: "")
        
        // Place names not in cache, but may be in queue
        if queuedLocations.contains(newLocation) {
            pending(newLocation.hashValue)
            return
        }
        
        // Try to retrieve place names
        if queue.operationCount < pwgMaxNberOfLocationsToDecode {
            // Add location to queue
            queuedLocations.insert(newLocation)
            
            // Fetch place names at location in serial queue
            fetchPlaceName(at: newLocation) { (error) in
                debugPrint("=> location could not be requested: \(error?.localizedDescription ?? "Unknnown error")")
            }
            pending(newLocation.hashValue)
            return
        }
        
        failure()
    }
    
    private func getDeltaLatitude(for latitude: CLLocationDegrees, radius: CLLocationDistance) -> CLLocationDegrees {
        // See https://en.wikipedia.org/wiki/Latitude
        var deltaLat: Double = radius as Double
        let num = a * (1.0 - e2)
        let den = pow(1.0 - e2 * pow(sin(latitude * Double.pi / 180.0),2), 1.5)
        deltaLat = deltaLat / num * den
        return abs(deltaLat * 180.0 / Double.pi) as CLLocationDegrees
    }

    private func getDeltaLongitude(for latitude: CLLocationDegrees, radius: CLLocationDistance) -> CLLocationDegrees {
        // See https://en.wikipedia.org/wiki/Latitude
        var deltaLong: Double = radius as Double
        let num = a * cos(latitude * Double.pi / 180.0)
        let den = pow(1.0 - e2 * pow(sin(latitude * Double.pi / 180.0),2), 0.5)
        deltaLong = deltaLong / num * den
        return abs(deltaLong * 180.0 / Double.pi) as CLLocationDegrees
    }

    /**
     A fetched results controller to fetch Location records sorted by coordinate and radius.
     */
//    public lazy var fetchedResultsController: NSFetchedResultsController<Location> = {
//        
//        // Create a fetch request for the Tag entity sorted by name.
//        let fetchRequest = Location.fetchRequest()
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Location.latitude), ascending: true),
//                                        NSSortDescriptor(key: #keyPath(Location.longitude), ascending: true),
//                                        NSSortDescriptor(key: #keyPath(Location.radius), ascending: true)]
//
//        // Create a fetched results controller and set its fetch request, context, and delegate.
//        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
//                                            managedObjectContext: mainContext,
//                                              sectionNameKeyPath: nil, cacheName: nil)
//        
//        // Perform the fetch.
//        do {
//            try controller.performFetch()
//        } catch {
//            fatalError("Unresolved error \(error)")
//        }
//        
//        return controller
//    }()
}
