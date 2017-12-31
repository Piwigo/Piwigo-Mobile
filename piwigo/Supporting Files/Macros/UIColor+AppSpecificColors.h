//
//  UIColor+AppSpecificColors.h
//  piwigo
//
//  Created by Spencer Baker on 12/29/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (AppSpecificColors)

+(UIColor*)piwigoTextColor;
+(UIColor*)piwigoBackgroundColor;

+(UIColor*)piwigoBrown;
+(UIColor*)piwigoOrange;
+(UIColor*)piwigoOrangeSelected;

+(UIColor*)piwigoHudContentColor;
+(UIColor*)piwigoHudBezelViewColor;

+(UIColor*)piwigoHeaderColor;
+(UIColor*)piwigoSeparatorColor;
+(UIColor*)piwigoCellBackgroundColor;
+(UIColor*)piwigoLeftLabelColor;
+(UIColor*)piwigoRightLabelColor;
+(UIColor*)piwigoThumbColor;

+(UIColor*)piwigoGray;
+(UIColor*)piwigoGrayLight;
+(UIColor*)piwigoGrayXXLight;
+(UIColor*)piwigoWhiteCream;

@end
