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
    for (CLLocation *location in locations) {
        
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
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(locationData.latitude, locationData.longitude);
        CLLocation *cachedLocation = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                   altitude:locationData.altitude
                                                         horizontalAccuracy:locationData.horizontalAccuracy
                                                           verticalAccuracy:locationData.verticalAccuracy
                                                                  timestamp:locationData.timestamp];
        
        // Compare known location to list of requested locations
        CLLocation *knownLocation;
        for (CLLocation *location in locations) {
            
            // Already in cache ?
            if ([location distanceFromLocation:cachedLocation] < kDistanceOfIncertainty)
            {
                // Within 10 m => Will be removed
                knownLocation = location;
                break;
            }
        }
        [locations removeObject:knownLocation];
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
    for (CLLocation *location in locations) {

        // Add Geocoder request
        NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            [self.geocoder reverseGeocodeLocation:location
                completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
                    
                    // Extract existing data
                    NSString *placeName = @"";
                    if (!error && placemarks && placemarks.count > 0)
                    {
                        // Define place name
                        CLPlacemark *placeMark = [placemarks objectAtIndex:0];
                        placeName = [NSString stringWithFormat:@"%@", [placeMark locality]];
                        
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
                        newPlace.latitude = location.coordinate.latitude;
                        newPlace.longitude = location.coordinate.longitude;
                        newPlace.altitude = location.altitude;
                        newPlace.horizontalAccuracy = location.horizontalAccuracy;
                        newPlace.verticalAccuracy = location.verticalAccuracy;
                        newPlace.timestamp = location.timestamp;
                        newPlace.placeName = placeName;
                        [newLocations addObject:newPlace];
                    } else {
                        if (error) {
                            NSLog(@"Geocoder error %ld: %@", error.code, [error localizedDescription]);
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

-(NSString *)getPlaceNameForLocation:(CLLocation *)location
{
    NSString *placeName;
    
    // Check location validity
    if (!CLLocationCoordinate2DIsValid(location.coordinate)) {
        // Invalid location
        return placeName;
    }
    
    // Loop over known locations
    for (PiwigoLocationData *locationData in self.knownPlaceNames)
    {
        // Known location
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(locationData.latitude, locationData.longitude);
        CLLocation *cachedLocation = [[CLLocation alloc] initWithCoordinate:coordinate
                                                                   altitude:locationData.altitude
                                                         horizontalAccuracy:locationData.horizontalAccuracy
                                                           verticalAccuracy:locationData.verticalAccuracy
                                                                  timestamp:locationData.timestamp];
        
        // Is this location known?
        if ([location distanceFromLocation:cachedLocation] < kDistanceOfIncertainty)
        {
            placeName = locationData.placeName;
            break;
        }
    }
    
    return placeName;
}

@end
