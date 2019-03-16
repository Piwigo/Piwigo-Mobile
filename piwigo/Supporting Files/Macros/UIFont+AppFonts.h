//
//  UIFont+AppFonts.h
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIFont (AppFonts)

+(UIFont*)piwigoFontLight;
+(UIFont*)piwigoFontNormal;
+(UIFont*)piwigoFontSemiBold;
+(UIFont*)piwigoFontBold;
+(UIFont*)piwigoFontExtraBold;
+(UIFont*)piwigoFontSmall;
+(UIFont*)piwigoFontSmallSemiBold;
+(UIFont*)piwigoFontTiny;
+(UIFont*)piwigoFontLarge;
+(UIFont*)piwigoFontLargeTitle;
+(UIFont*)piwigoFontButton;
+(UIFont*)piwigoFontDisclosure;
+(CGFloat)fontSizeForLabel:(UILabel *)label andNberOfLines:(NSInteger)nberLines;

@end
