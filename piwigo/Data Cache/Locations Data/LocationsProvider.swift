//
//  LocationsProvider.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/04/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
//  A class to fetch data from the remote server and save it to the Core Data store.

import CoreData
import CoreLocation

let kPiwigoMaxNberOfLocationsToDecode: Int = 10
let a: Double = 6378137.0               // Equatorial radius in meters
let e2: Double = 0.00669437999014       // Earth eccentricity squared

class LocationsProvider: NSObject {
    
    // Singleton
    static let shared = LocationsProvider()
    
    // Initialisation
    private var geocoder = CLGeocoder()
    private var queue = OperationQueue()
    private var queuedLocations: [LocationProperties]
    
    override init() {
        // Prepare list of operations
        queue.maxConcurrentOperationCount = 1   // Make it a serial queue
        queue.qualityOfService = .background    // fetch location names in the background
        // Initialise locations in queue
        queuedLocations = []
    }
    

    // MARK: - Core Data object context
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let context:NSManagedObjectContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        return context
    }()

    
    // MARK: - Fetch Place Names
    /**
     Submits a reverse-geocoding request for the specified location, imports it into Core Data,
     and notify views when the new place name is available.
     The requests are stored in a queue and performed one after the other by a shared instance.
    */
    private func fetchPlaceName(at location: LocationProperties, completionHandler: @escaping (Error?) -> Void) {
        
        // Add Geocoder request
        let operation = BlockOperation(block: {
            let semaphore = DispatchSemaphore.init(value: 0)

            // Initialise
            let latitude = location.coordinate!.latitude as CLLocationDistance
            let longitude = location.coordinate!.longitude as CLLocationDistance
            let newLocation = CLLocation(latitude: latitude, longitude: longitude)

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
                        if subLocality.count != 0 && subLocality != thoroughfare {
                            streetName = subLocality
                        } else if locality.count != 0 && locality != subLocality {
                            streetName = locality
                        } else if subAdministrativeArea.count != 0 && subAdministrativeArea != subLocality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0 && administrativeArea != subLocality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // => Display sublocality if available
                    else if subLocality.count != 0 {
                        placeName = subLocality
                        if locality.count != 0 && locality != subLocality {
                            streetName = locality
                        } else if subAdministrativeArea.count != 0 && subAdministrativeArea != subLocality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0 && administrativeArea != subLocality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // => Display locality if available
                    else if locality.count != 0 {
                        placeName = locality
                        if subAdministrativeArea.count != 0 && subAdministrativeArea != locality {
                            streetName = subAdministrativeArea
                        } else if administrativeArea.count != 0 && administrativeArea != locality{
                            streetName = administrativeArea
                        } else if country.count != 0 {
                            streetName = country
                        }
                    }
                    // Locality not available, use administrative info if possible
                    else if subAdministrativeArea.count != 0 {
                        placeName = subAdministrativeArea
                        if administrativeArea.count != 0 && administrativeArea != subAdministrativeArea {
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
                        placeName.append(NSLocalizedString("andMore", comment: " & more"))
                    }

                    // Log placemarks[0]
//                    print("\n===>> name:\(placeMark?.name ?? ""), country:\(country), administrativeArea:\(administrativeArea), subAdministrativeArea:\(subAdministrativeArea), locality:\(locality), subLocality:\(subLocality), thoroughfare:\(thoroughfare), subThoroughfare:\(placeMark?.subThoroughfare ?? ""), region:\(region), areasOfInterest:\(placeMark?.areasOfInterest?[0] ?? ""),inlandWater:\(inlandWater), ocean:\(ocean)\n")

                    DispatchQueue.global(qos: .background).async {
                        // Create a private queue context.
                        let taskContext = DataController.getPrivateContext()
                                
                        // Add new location to CoreData store
                        let newLocation = LocationProperties(coordinate: location.coordinate,
                                                             radius: region.radius,
                                                             placeName: placeName, streetName: streetName)
                        self.importOneLocation(newLocation, taskContext: taskContext)
                    }
                } else {
                    // Did not return place names
                    print(String(format: "Geocoder: no place mark returned!\n=> %@", error?.localizedDescription ?? ""))
                }
                semaphore.signal()
            })

            _ = (semaphore.wait(timeout: DispatchTime.distantFuture) == .success ? 0 : -1)
        })

        queue.addOperation(operation)
//        print("===> fetchPlaceName operations:", queue.operationCount)
    }


    /**
     Imports one location, creating a managed object from the new data,
     and saving them to the persistent store, on a private queue. After saving,
     resets the context to clean up the cache and lower the memory footprint.
    */
    private func importOneLocation(_ locationData: LocationProperties, taskContext: NSManagedObjectContext) -> Void {
        
        // taskContext.performAndWait runs on the URLSession's delegate queue
        // so it won’t block the main thread.
        taskContext.performAndWait {
            
            // Create a Location managed object on the private queue context.
            guard let newLocation = NSEntityDescription.insertNewObject(forEntityName: "Location", into: taskContext) as? Location else {
                print(LocationError.creationError.localizedDescription)
                return
            }
            
            // Populate the Location's properties using the raw data.
            do {
                try newLocation.update(with: locationData)
            }
            catch LocationError.missingData {
                // Delete invalid Location from the private queue context.
                print(LocationError.missingData.localizedDescription)
                taskContext.delete(newLocation)
            }
            catch {
                print(error.localizedDescription)
            }
            
            // Save all insertions and deletions from the context to the store.
            if taskContext.hasChanges {
                do {
                    try taskContext.save()
                }
                catch {
                    print("Error: \(error)\nCould not save Core Data context.")
                    return
                }
                // Reset the taskContext to free the cache and lower the memory footprint.
                taskContext.reset()

                // Remove location from queue
                queuedLocations.removeAll { (item) -> Bool in
                    item.coordinate?.latitude == locationData.coordinate?.latitude &&
                        item.coordinate?.longitude == locationData.coordinate?.longitude &&
                        item.radius == locationData.radius
                }
            }
        }
    }
    

    // MARK: - Clear Locations
    /**
     Clear cached Core Data location entry
    */
    func clearLocations() {
        
        // Create a fetch request for the Tag entity
        let fetchRequest = NSFetchRequest<Location>(entityName: "Location")

        // Create batch delete request
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        // Execute batch delete request
        do {
            try managedObjectContext.execute(batchDeleteRequest)
        }
        catch {
            fatalError("Unresolved error \(error)")
        }
    }


    // MARK: - Get Place Names
    /**
     Routine returning the place name of a location
     This routine adds an operation fetching the place name if necessary
     */
    func getPlaceName(for location: CLLocation) -> [String : String]? {

        // Check coordinates
        if !CLLocationCoordinate2DIsValid(location.coordinate) {
            // Invalid location -> No place name
            return nil
        }

        // Create a fetch request for the location
        let fetchRequest = NSFetchRequest<Location>(entityName: "Location")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true),
                                        NSSortDescriptor(key: "longitude", ascending: true)]
        let deltaLatitude = getDeltaLatitude(for: location.coordinate.latitude, radius: location.horizontalAccuracy)
        let latitudeMinPredicate = NSPredicate(format: "latitude >= %lf", location.coordinate.latitude - deltaLatitude)
        let latitudeMaxPredicate = NSPredicate(format: "latitude <= %lf", location.coordinate.latitude + deltaLatitude)
        let deltaLongitude = getDeltaLongitude(for: location.coordinate.latitude, radius: location.horizontalAccuracy)
        let longitudeMinPredicate = NSPredicate(format: "longitude >= %lf", location.coordinate.longitude - deltaLongitude)
        let longitudeMaxPredicate = NSPredicate(format: "longitude <= %lf", location.coordinate.longitude + deltaLongitude)
        var compoundPredicate = NSCompoundPredicate()
        compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [latitudeMinPredicate,latitudeMaxPredicate,longitudeMinPredicate, longitudeMaxPredicate])
        fetchRequest.predicate = compoundPredicate
        
        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
        
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        let knownPlaceNames = controller.fetchedObjects ?? []
        
        // Loop over known places
        var placeNames: [String: String] = .init(minimumCapacity: 2)
        for knownPlace: Location in knownPlaceNames {
            // Known location
            let knownLatitude = knownPlace.latitude
            let knownLongitude = knownPlace.longitude
            let knownLocation = CLLocation(latitude: knownLatitude, longitude: knownLongitude)

            // Do we know the place of this location?
            if location.distance(from: knownLocation) <= knownPlace.radius {
                // Retrieve non-empty cached strings
                if knownPlace.placeName.count > 0 {
                    placeNames["placeLabel"] = knownPlace.placeName
                } else {
                    placeNames["placeLabel"] = ""
                }
                if knownPlace.streetName.count > 0 {
                    placeNames["dateLabel"] = knownPlace.streetName
                } else {
                    placeNames["dateLabel"] = ""
                }
                return placeNames
            }
        }
        
        // Place names unknown —> Prepare fetch
        let newLocation = LocationProperties(coordinate: location.coordinate,
                                             radius: location.horizontalAccuracy,
                                             placeName: "", streetName: "")
        
        // Place names not in cache, but may be in queue
        if queuedLocations.contains(where: { (item) -> Bool in
            item.coordinate?.latitude == newLocation.coordinate?.latitude &&
                item.coordinate?.longitude == newLocation.coordinate?.longitude &&
                item.radius == newLocation.radius
        }) {
            return placeNames
        }
        
        // Add operation to queue if possible
        if queue.operationCount < kPiwigoMaxNberOfLocationsToDecode {
            // Add location to queue
            queuedLocations.append(newLocation)
            
            // Fetch place names at location
            fetchPlaceName(at: newLocation) { (error) in
                if error == nil {
                    print("=> location could not be requested")
                }
            }
        }
        
        return placeNames
    }
    
    private func getDeltaLatitude(for latitude: CLLocationDegrees, radius: CLLocationDistance) -> CLLocationDegrees {
        // See https://en.wikipedia.org/wiki/Latitude
        var deltaLat: Double = radius as Double
        let num = a * (1.0 - e2)
        let den = pow(1.0 - e2 * pow(sin(latitude * Double.pi / 180.0),2), 1.5)
        deltaLat = deltaLat / num * den
        return (deltaLat * 180.0 / Double.pi) as CLLocationDegrees
    }

    private func getDeltaLongitude(for latitude: CLLocationDegrees, radius: CLLocationDistance) -> CLLocationDegrees {
        // See https://en.wikipedia.org/wiki/Latitude
        var deltaLong: Double = radius as Double
        let num = a * cos(latitude * Double.pi / 180.0)
        let den = pow(1.0 - e2 * pow(sin(latitude * Double.pi / 180.0),2), 0.5)
        deltaLong = deltaLong / num * den
        return (deltaLong * 180.0 / Double.pi) as CLLocationDegrees
    }

    /**
     A fetched results controller to fetch Location records sorted by name.
     */
    lazy var fetchedResultsController: NSFetchedResultsController<Location> = {
        
        // Create a fetch request for the Tag entity sorted by name.
        let fetchRequest = NSFetchRequest<Location>(entityName: "Location")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true),
                                        NSSortDescriptor(key: "longitude", ascending: true)]

        // Create a fetched results controller and set its fetch request, context, and delegate.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                            managedObjectContext: self.managedObjectContext,
                                              sectionNameKeyPath: nil, cacheName: nil)
        
        // Perform the fetch.
        do {
            try controller.performFetch()
        } catch {
            fatalError("Unresolved error \(error)")
        }
        
        return controller
    }()
}
