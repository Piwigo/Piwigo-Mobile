//
//  UIColor+AppSpecificColors.m
//  missionprep
//
//  Created by Spencer Baker on 12/29/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "UIColor+AppSpecificColors.h"

@implementation UIColor (AppSpecificColors)

+(UIColor*)buttonColor
{
	return [UIColor colorWithRed:0.0/255.0 green:122.0/255.0 blue:255.0/255.0 alpha:1.0];
}


+(UIColor*)matrixCompleteColor
{
	return [UIColor colorWithRed:22/255.0 green:215/255.0 blue:32/255.0 alpha:1.0];
}

+(UIColor*)matrixInProgressColor
{
	return [UIColor colorWithRed:255/255.0 green:204/255.0 blue:0/255.0 alpha:1.0];
}


+(UIColor*)progressRedColor
{
	return [UIColor colorWithRed:255/255.0 green:81/255.0 blue:69/255.0 alpha:1.0];
}

+(UIColor*)progressBlueColor
{
	return [UIColor colorWithRed:28/255.0 green:168/255.0 blue:248/255.0 alpha:1.0];
}

+(UIColor*)progressOrangeColor
{
	return [UIColor colorWithRed:255/255.0 green:139/255.0 blue:10/255.0 alpha:1.0];
}

+(UIColor*)progressPurpleColor
{
	return [UIColor colorWithRed:233/255.0 green:76/255.0 blue:192/255.0 alpha:1.0];
}

@end
