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

@property (nonatomic, assign) CLLocation *location;
@property (nonatomic, strong) NSArray<CLPlacemark *> *placemarks;

@end
