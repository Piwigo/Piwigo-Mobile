//
//  PiwigoButton.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoButton.h"

@implementation PiwigoButton

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoOrange];
		self.layer.cornerRadius = 5.0;
		
		self.titleLabel.font = [UIFont piwigoFontButton];
		[self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	return self;
}

-(void)setHighlighted:(BOOL)highlighted
{
	[super setHighlighted:highlighted];
	if(highlighted) {
		self.backgroundColor = [UIColor piwigoOrangeSelected];
	} else {
		self.backgroundColor = [UIColor piwigoOrange];
	}
}

@end
