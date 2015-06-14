//
//  UIDevice+DeviceType.h
//  Piwigo
//
//  Created by Olaf Greck on 14.06.15
//  Copyright (c) 2015 Olaf Greck. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (DeviceType)
+(BOOL)isiPhone;
+(BOOL)isiPhoneFive;
+(BOOL)isiPad;

+(BOOL)isiOS7;
+(BOOL)isAtLeastiOSSeven;
+(BOOL)isAtLeastiOSEight;

@end
