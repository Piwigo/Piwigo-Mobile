//
//  PiwigoLocationData.h
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 10/03/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface PiwigoLocationData : NSObject

@property (nonatomic, assign) CLLocationDegrees latitude;
@property (nonatomic, assign) CLLocationDegrees longitude;
@property (nonatomic, assign) CLLocationDistance altitude;
@property (nonatomic, assign) CLLocationAccuracy horizontalAccuracy;
@property (nonatomic, assign) CLLocationAccuracy verticalAccuracy;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSString *placeName;
@property (nonatomic, strong) NSString *streetName;

@end
