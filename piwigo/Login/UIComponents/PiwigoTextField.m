//
//  PiwigoTextField.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoTextField.h"

@implementation PiwigoTextField

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.layer.cornerRadius = 10.0;
		self.font = [UIFont piwigoFontNormal];
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.clearButtonMode = YES;
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
	}
	return self;
}

-(CGRect)textRectForBounds:(CGRect)bounds
{
	return CGRectInset(bounds, 10, 0);
}

-(CGRect)editingRectForBounds:(CGRect)bounds
{
	return CGRectInset(bounds, 10, 0);
}

@end
