//
//  LocationsData.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "LocationsData.h"
#import "PiwigoLocationData.h"

CGFloat const kDistanceOfIncertainty = 10.0;

@implementation LocationsData

+(LocationsData*)sharedInstance
{
	static LocationsData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		instance.knownPlaceNames = [NSArray new];
        instance.geocoder = [[CLGeocoder alloc] init];
	});
	return instance;
}

-(void)clearCache
{
    self.knownPlaceNames = [NSArray new];
}

-(void)addLocationsToCache:(NSMutableArray *)locations
                completion:(void (^)(void))completion
{
    // Remove invalid locations
    NSMutableArray *invalidLocations = [NSMutableArray new];
    for (PiwigoLocationData *location in locations) {
        
        // Check location validity
        if (!CLLocationCoordinate2DIsValid(location.coordinate))
        {
            // Invalid location => Will be removed
            [invalidLocations addObject:location];
        }
    }
    [locations removeObjectsInArray:invalidLocations];

    // Done if all locations already in cache
    if (locations.count == 0) {
//        NSLog(@"Locations are invalid ;-)");
        return;
    }
    
    // Loop over known locations
    for (PiwigoLocationData *locationData in self.knownPlaceNames)
    {
        // Known location
        CLLocationDegrees latitude = locationData.coordinate.latitude;
        CLLocationDegrees longitude = locationData.coordinate.longitude;
        CLLocation *cachedLocation = [[CLLocation alloc] initWithLatitude:latitude
                                                                longitude:longitude];
        
        // Compare known location to list of requested locations
        PiwigoLocationData *knownLocation;
        for (PiwigoLocationData *location in locations) {
            
            // Already in cache ?
            CLLocationDegrees latitude = location.coordinate.latitude;
            CLLocationDegrees longitude = location.coordinate.longitude;
            CLLocation *testedLocation = [[CLLocation alloc] initWithLatitude:latitude
                                                                 longitude:longitude];

            if ([testedLocation distanceFromLocation:cachedLocation] < MAX(locationData.radius, kDistanceOfIncertainty))
            {
                // Within 10 m or inside region => Will be removed
                knownLocation = location;
                break;
            }
        }
        if (knownLocation) [locations removeObject:knownLocation];
    }
    
    // Done if all locations already in cache
    if (locations.count == 0) {
//        NSLog(@"Locations already known ;-)");
        return;
    }
    
    // Prepare list of operations
    NSMutableArray *newLocations = [NSMutableArray array];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;   // Make it a serial queue
    
    NSOperation *completionOperation = [NSBlockOperation blockOperationWithBlock:^{
        self.knownPlaceNames = [self.knownPlaceNames arrayByAddingObjectsFromArray:newLocations];
        if (completion) {
            completion();
        }
    }];
    
    // Loop over remaining locations
    for (PiwigoLocationData *location in locations) {

        // Add Geocoder request
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            // Initialise
            CLLocationDegrees latitude = location.coordinate.latitude;
            CLLocationDegrees longitude = location.coordinate.longitude;
            CLLocation *newLocation = [[CLLocation alloc] initWithLatitude:latitude
                                                                    longitude:longitude];
            
            // Request place name
            [self.geocoder reverseGeocodeLocation:newLocation
                completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
                    
                    // Extract existing data
                    if (!error && placemarks && placemarks.count > 0)
                    {
                        // Extract data
                        CLPlacemark *placeMark = [placemarks objectAtIndex:0];
                        CLCircularRegion *region = (CLCircularRegion *)[placeMark region];
                        NSString *locality = [placeMark locality] ? [placeMark locality] : @"";
                        NSString *thoroughfare = [placeMark thoroughfare] ? [placeMark thoroughfare] : @"";
                        NSString *administrativeArea = [placeMark administrativeArea] ? [placeMark administrativeArea] : @"";
                        
                        // Define place name
                        NSString *placeName = @"", *streetName = @"";
                        if (locality && [locality length] > 0)
                        {
                            // Locality returned
                            if (region.radius > location.radius)
                            {
                                // Images of section are in the same region
                                if (locality.length && administrativeArea.length && thoroughfare.length) {
                                    placeName = [NSString stringWithFormat:@"%@, %@", locality, administrativeArea];
                                    streetName = [NSString stringWithFormat:@"%@", thoroughfare];
                                } else {
                                    placeName = [NSString stringWithFormat:@"%@", locality];
                                    streetName = [NSString stringWithFormat:@"%@", administrativeArea];
                                }
                            }
                            else {
                                // Images of section are in not in the same region
                                if (locality.length && administrativeArea.length) {
                                    placeName = [NSString stringWithFormat:@"%@, …", locality];
                                    streetName = [NSString stringWithFormat:@"%@, …", administrativeArea];
                                } else {
                                    placeName = [NSString stringWithFormat:@"%@, …", locality];
                                }
                            }

                        }
                        
                        // Log placemarks[0]
//                        NSLog(@"%@", [NSString stringWithFormat:@"name:%@, country:%@, administrativeArea:%@, subAdministrativeArea:%@, locality:%@, subLocality:%@, thoroughfare:%@, subThoroughfare:%@, region:%@, areasOfInterest:%@",
//                                      [placeMark name],
//                                      [placeMark country],
//                                      [placeMark administrativeArea],
//                                      [placeMark subAdministrativeArea],
//                                      [placeMark locality],
//                                      [placeMark subLocality],
//                                      [placeMark thoroughfare],
//                                      [placeMark subThoroughfare],
//                                      [placeMark region],
//                                      [placeMark areasOfInterest]]);
                        
                        // Add new placemarks to cache
                        PiwigoLocationData *newPlace = [PiwigoLocationData new];
                        newPlace.coordinate = location.coordinate;
                        newPlace.radius = region.radius;
                        newPlace.placeName = placeName;
                        newPlace.streetName = streetName;
                        [newLocations addObject:newPlace];
                    } else {
                        if (error) {
                            NSLog(@"Geocoder error %ld: %@", (long)error.code, [error localizedDescription]);
                        } else {
                            NSLog(@"Geocoder: no place mark returned!");
                        }
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }];
        
        [completionOperation addDependency:operation];
        [queue addOperation:operation];
    }
    
    [[NSOperationQueue mainQueue] addOperation:completionOperation];
}

-(NSDictionary *)getPlaceNameForLocation:(PiwigoLocationData *)location
{
    NSMutableDictionary *placeNames = [NSMutableDictionary new];
    
    // Check location validity
    if (!CLLocationCoordinate2DIsValid(location.coordinate)) {
        // Invalid location
        return placeNames;
    }
    
    // Initialise
    CLLocationDegrees latitude = location.coordinate.latitude;
    CLLocationDegrees longitude = location.coordinate.longitude;
    CLLocation *requestedLocation = [[CLLocation alloc] initWithLatitude:latitude
                                                            longitude:longitude];

    // Loop over known locations
    for (PiwigoLocationData *locationData in self.knownPlaceNames)
    {
        // Known location
        CLLocationDegrees latitude = locationData.coordinate.latitude;
        CLLocationDegrees longitude = locationData.coordinate.longitude;
        CLLocation *cachedLocation = [[CLLocation alloc] initWithLatitude:latitude
                                                                longitude:longitude];
        
        // Is this location known?
        if ([requestedLocation distanceFromLocation:cachedLocation] < MAX(locationData.radius, kDistanceOfIncertainty))
        {
            if (locationData.placeName) [placeNames setValue:locationData.placeName forKey:@"placeLabel"];
            if (locationData.streetName) [placeNames setValue:locationData.streetName forKey:@"dateLabel"];
            break;
        }
    }
    
    return placeNames;
}

@end
