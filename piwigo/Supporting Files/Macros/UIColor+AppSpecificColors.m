//
//  UIColor+AppSpecificColors.m
//  piwigo
//
//  Created by Spencer Baker on 12/29/14.
//  Copyright (c) 2014 BakerCrew. All rights reserved.
//

#import "UIColor+AppSpecificColors.h"
#import "Model.h"

@implementation UIColor (AppSpecificColors)

// Text Color
+(UIColor*)piwigoTextColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor lightTextColor];
    else
        return [UIColor darkTextColor];
}

// Background Color of Views (was piwigoGray)
+(UIColor*)piwigoBackgroundColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        if (@available(iOS 10, *))
            return [UIColor colorWithRed:23/255.0 green:23/255.0 blue:23/255.0 alpha:1.0];
        else
            return [UIColor colorWithRed:64/255.0 green:64/255.0 blue:64/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:239/255.0 green:239/255.0 blue:244/255.0 alpha:1.0];
}

// Piwigo Logo Colors
+(UIColor*)piwigoBrown
{
    return [UIColor colorWithRed:78/255.0 green:78/255.0 blue:78/255.0 alpha:1.0];
}
+(UIColor*)piwigoOrange
{
    return [UIColor colorWithRed:255/255.0 green:119/255.0 blue:1/255.0 alpha:1.0];
}
+(UIColor*)piwigoOrangeSelected
{
	return [UIColor colorWithRed:198/255.0 green:92/255.0 blue:0/255.0 alpha:1.0];
}

// HUD Views
+(UIColor*)piwigoHudContentColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        if (@available(iOS 10, *))
            return [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1];
        else
            return [UIColor colorWithRed:23/255.0 green:23/255.0 blue:23/255.0 alpha:1.0];
    else
        if (@available(iOS 10, *))
            return [UIColor colorWithRed:239/255.0 green:239/255.0 blue:244/255.0 alpha:1];
        else
            return [UIColor colorWithRed:23/255.0 green:23/255.0 blue:23/255.0 alpha:1.0];
}
+(UIColor*)piwigoHudBezelViewColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        if (@available(iOS 10, *))
            return [UIColor colorWithWhite:0.f alpha:1.0];
        else
            return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
    else
        if (@available(iOS 10, *))
            return [UIColor colorWithWhite:0.f alpha:1.0];
        else
            return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
}

// Color of TableView Headers (was piwigoGrayXXLight)
+(UIColor*)piwigoHeaderColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:128/255.0 green:128/255.0 blue:128/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:51/255.0 green:51/255.0 blue:53/255.0 alpha:1.0];
}

// Color of TableView Separators (was piwigoGrayXLight)
+(UIColor*)piwigoSeparatorColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:64/255.0 green:64/255.0 blue:64/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:128/255.0 green:128/255.0 blue:128/255.0 alpha:1.0];
}

// Background Color of TableView Cells (was piwigoGrayLight)
+(UIColor*)piwigoCellBackgroundColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        if (@available(iOS 10, *))
            return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
        else
            return [UIColor colorWithRed:46/255.0 green:46/255.0 blue:46/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1.0];
}

// Color of TableView Left Labels (was piwigoWhiteCream)
+(UIColor*)piwigoLeftLabelColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1];
    else
        return [UIColor darkTextColor];
}

// Color of TableView Right Labels (was piwigoGrayXXLight)
+(UIColor*)piwigoRightLabelColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:128/255.0 green:128/255.0 blue:128/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:128/255.0 green:128/255.0 blue:128/255.0 alpha:1.0];
}

// Color of Switch Thumbs
+(UIColor*)piwigoThumbColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1];
    else
        return [UIColor colorWithRed:239/255.0 green:239/255.0 blue:244/255.0 alpha:1.0];
}

// Color of lines under fields
+(UIColor*)piwigoUnderlineColor
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:51/255.0 green:51/255.0 blue:53/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1];
}


+(UIColor*)piwigoGray
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:23/255.0 green:23/255.0 blue:23/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:23/255.0 green:23/255.0 blue:23/255.0 alpha:1.0];
}
+(UIColor*)piwigoGrayLight
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0];
}
+(UIColor*)piwigoGrayXXLight
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:128/255.0 green:128/255.0 blue:128/255.0 alpha:1.0];
    else
        return [UIColor colorWithRed:51/255.0 green:51/255.0 blue:53/255.0 alpha:1.0];
}
+(UIColor*)piwigoWhiteCream
{
    if ([Model sharedInstance].isDarkPaletteActive)
        return [UIColor colorWithRed:200/255.0 green:200/255.0 blue:200/255.0 alpha:1];
    else
        return [UIColor colorWithRed:51/255.0 green:51/255.0 blue:53/255.0 alpha:1.0];
    //    return [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1];
}

@end
