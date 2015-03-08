//
//  UIColor+AppSpecificColors.m
//  piwigo
//
//  Created by Spencer Baker on 12/29/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "UIColor+AppSpecificColors.h"

@implementation UIColor (AppSpecificColors)

+(UIColor*)piwigoOrange
{
	return [UIColor colorWithRed:255/255.0 green:119.5/255.0 blue:0/255.0 alpha:1.0];
}
+(UIColor*)piwigoOrangeSelected
{
	return [UIColor colorWithRed:198/255.0 green:92/255.0 blue:0/255.0 alpha:1.0];
}
+(UIColor*)piwigoGray
{
	return [UIColor colorWithRed:51/255.0 green:51/255.0 blue:51/255.0 alpha:1.0];
}
+(UIColor*)piwigoGrayLight
{
	return [UIColor colorWithRed:78/255.0 green:78/255.0 blue:78/255.0 alpha:1.0];
}
+(UIColor*)piwigoBrown
{
	return [UIColor colorWithRed:114/255.0 green:93/255.0 blue:49/255.0 alpha:1.0];
}
+(UIColor*)piwigoWhiteCream
{
	return [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1];
}

@end
