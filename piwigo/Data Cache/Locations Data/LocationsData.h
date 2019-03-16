//
//  LocationsData.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class PiwigoLocationData;

@interface LocationsData : NSObject

+(LocationsData*)sharedInstance;

@property (nonatomic, strong) NSArray *knownPlaceNames;

-(void)getPlaceMarkForLocation:(CLLocation *)location
                    completion:(void (^)(NSArray<CLPlacemark *> *placemarks))completion;
-(void)clearCache;

@end
