//
//  PiwigoButton.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "Model.h"
#import "PiwigoButton.h"

@implementation PiwigoButton

-(instancetype)init
{
	self = [super init];
	if (self)
	{
		self.layer.cornerRadius = 10.0;
		self.titleLabel.font = [UIFont piwigoFontButton];
		[self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	return self;
}

-(void)setHighlighted:(BOOL)highlighted
{
	[super setHighlighted:highlighted];
    
    if (AppVars.shared.isDarkPaletteActive) {
        if (highlighted) {
            self.backgroundColor = [UIColor piwigoColorOrange];
        } else {
            self.backgroundColor = [UIColor piwigoColorOrangeSelected];
        }
    } else {
        if (highlighted) {
            self.backgroundColor = [UIColor piwigoColorOrangeSelected];
        } else {
            self.backgroundColor = [UIColor piwigoColorOrange];
        }
    }
}

@end
