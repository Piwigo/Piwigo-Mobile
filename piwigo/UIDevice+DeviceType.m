//
//  UIDevice+DeviceType.m
//  Piwigo
//
//  Created by Olaf Greck on 14.06.15
//  Copyright (c) 2015 Olaf Greck. All rights reserved.
//

#import "UIDevice+DeviceType.h"

@implementation UIDevice (DeviceType)

+(BOOL)isiPhone {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
}

+(BOOL)isiPhoneFive {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)  {
        CGSize result = [[UIScreen mainScreen] bounds].size;
        if(result.height == 480) {
            // iPhone Classic
            return NO;
        }
        if(result.height == 568) {
            // iPhone 5
            return YES;
        }
    }
    return NO;
}

+(BOOL)isiPad {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}


#pragma - Chekc ios verison -

+(BOOL)isAtLeastiOSSeven {
    return ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
}


+(BOOL)isAtLeastiOSEight {
    return  [[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0;
}

+(BOOL)isiOS7 {
    return ([self isAtLeastiOSSeven] && (NO == [self isAtLeastiOSEight]));
}


@end
