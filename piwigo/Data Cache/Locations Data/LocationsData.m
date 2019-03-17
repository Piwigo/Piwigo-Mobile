//
//  LocationsData.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "LocationsData.h"
#import "PiwigoLocationData.h"

@implementation LocationsData

+(LocationsData*)sharedInstance
{
	static LocationsData *instance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
		instance.knownPlaceNames = [NSArray new];
	});
	return instance;
}

-(void)clearCache
{
    self.knownPlaceNames = [NSArray new];
}

-(void)getPlaceNameForLocation:(CLLocation *)location
                    completion:(void (^)(NSString *placeName))completion
{
    // Check location validity
    if (!CLLocationCoordinate2DIsValid(location.coordinate)) {
        // Invalid location
        return;
    }
    
    // Loop over known locations
    for (PiwigoLocationData *locationData in self.knownPlaceNames)
    {
        // Is this location known?
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(locationData.latitude, locationData.longitude);
        CLLocation *cachedLocation = [[CLLocation alloc] initWithCoordinate:coordinate
                                    altitude:locationData.altitude
                                    horizontalAccuracy:locationData.horizontalAccuracy
                                    verticalAccuracy:locationData.verticalAccuracy
                                    timestamp:locationData.timestamp];

        if ([location distanceFromLocation:cachedLocation] < 1.0)
        {
            // Is requested location
            if (completion) {
                completion(locationData.placeName);
            }
            return;
        }
    }

    // Location is not in cache
    [self addLocationInCache:location
                        completion:^(NSString *placeName) {
                            // Done
                            if (completion) {
                                completion(placeName);
                            }
                        }];
}

-(void)addLocationInCache:(CLLocation *)location
               completion:(void (^)(NSString *placeName))completion
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location
                   completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
                       
               // Extract existing data
               if (!error && placemarks && placemarks.count > 0)
               {
                   // Log placemarks[0]
                   CLPlacemark *placeMark = [placemarks objectAtIndex:0];
                   NSLog(@"%@", [NSString stringWithFormat:@"name:%@, country:%@, administrativeArea:%@, subAdministrativeArea:%@, locality:%@, subLocality:%@, thoroughfare:%@, subThoroughfare:%@, region:%@, areasOfInterest:%@",
                          [placeMark name],
                          [placeMark country],
                          [placeMark administrativeArea],
                          [placeMark subAdministrativeArea],
                          [placeMark locality],
                          [placeMark subLocality],
                          [placeMark thoroughfare],
                          [placeMark subThoroughfare],
                          [placeMark region],
                          [placeMark areasOfInterest]]);

                   // Define place name
                   NSString *placeName = [NSString stringWithFormat:@"%@", [placeMark locality]];
                   
                   // Add new placemarks to cache
                   NSMutableArray *cachedPlaces = [[NSMutableArray alloc] initWithArray:self.knownPlaceNames];
                   PiwigoLocationData *newPlace = [PiwigoLocationData new];
                   newPlace.latitude = location.coordinate.latitude;
                   newPlace.longitude = location.coordinate.longitude;
                   newPlace.altitude = location.altitude;
                   newPlace.horizontalAccuracy = location.horizontalAccuracy;
                   newPlace.verticalAccuracy = location.verticalAccuracy;
                   newPlace.timestamp = location.timestamp;
                   newPlace.placeName = placeName;
                   [cachedPlaces addObject:newPlace];
                   self.knownPlaceNames = cachedPlaces;
                   
                   // Done
                   if (completion) {
                       completion(placeName);
                   }
               } else {
                   // Done
                   if (completion) {
                       completion(nil);
                   }
               }
           }];
}

@end
