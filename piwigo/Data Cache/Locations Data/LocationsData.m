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

-(void)getPlaceMarkForLocation:(CLLocation *)location
                    completion:(void (^)(NSArray<CLPlacemark *> *placemarks))completion
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
        if ([location distanceFromLocation:locationData.location] < 1.0)
        {
            // Done
            if (completion) {
                completion(locationData.placemarks);
            }
        }
    }

    // Location is not in cache
    [self addPlaceMarksForLocation:location
                        completion:^(NSArray<CLPlacemark *> *placemarks) {
                            // Done
                            if (completion) {
                                completion(placemarks);
                            }
                        }];
}

-(void)addPlaceMarksForLocation:(CLLocation *)location
                     completion:(void (^)(NSArray<CLPlacemark *> *placemarks))completion
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location
                   completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
                       
               // Extract existing data
               if (!error && placemarks && placemarks.count > 0)
               {
                   // Add new placemarks to cache
                   NSMutableArray *cachedPlaces = [[NSMutableArray alloc] initWithArray:self.knownPlaceNames];
                   PiwigoLocationData *newPlace = [PiwigoLocationData new];
                   newPlace.location = location;
                   newPlace.placemarks = placemarks;
                   [cachedPlaces addObject:newPlace];
                   self.knownPlaceNames = cachedPlaces;

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

                   // Done
                   if (completion) {
                       completion(placemarks);
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
