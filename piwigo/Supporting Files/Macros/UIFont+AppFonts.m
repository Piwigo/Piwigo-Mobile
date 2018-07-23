//
//  UIFont+AppFonts.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "UIFont+AppFonts.h"

@implementation UIFont (AppFonts)

+(UIFont*)piwigoFontLight
{
    return [UIFont fontWithName:@"OpenSans-Light" size:17.0];
}

+(UIFont*)piwigoFontNormal
{
	return [UIFont fontWithName:@"OpenSans" size:17.0];
}

+(UIFont*)piwigoFontBold
{
    return [UIFont fontWithName:@"OpenSans-Bold" size:17.0];
}

+(UIFont*)piwigoFontExtraBold
{
    return [UIFont fontWithName:@"OpenSans-Extrabold" size:17.0];
}

+(UIFont*)piwigoFontSmall
{
    return [UIFont fontWithName:@"OpenSans" size:13.0];
}

+(UIFont*)piwigoFontTiny
{
    return [UIFont fontWithName:@"OpenSans" size:10.0];
}

+(UIFont*)piwigoFontLarge
{
    return [UIFont fontWithName:@"OpenSans" size:28.0];
}

+(UIFont*)piwigoFontLargeTitle
{
    return [UIFont fontWithName:@"OpenSans-Extrabold" size:28.0];
}

+(UIFont*)piwigoFontButton
{
    return [UIFont fontWithName:@"OpenSans" size:21.0];
}

+(UIFont*)piwigoFontDisclosure
{
    return [UIFont fontWithName:@"LacunaRegular" size:21.0];
}

@end

// Code for determining font name, e.g. LacunaRegular, OpenSans

//for ( NSString *familyName in [UIFont familyNames] )
//{
//    NSLog(@"Family %@", familyName);
//    NSLog(@"Names = %@", [UIFont fontNamesForFamilyName:familyName]);
//}
