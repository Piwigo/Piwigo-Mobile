//
//  DeletingView.m
//  piwigo
//
//  Created by Spencer Baker on 1/31/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "DeletingView.h"

@implementation DeletingView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
		
		UIView *center = [UIView new];
		center.translatesAutoresizingMaskIntoConstraints = NO;
		center.backgroundColor = [UIColor piwigoWhiteCream];
		center.layer.cornerRadius = 10;
		[self addSubview:center];
		[self addConstraints:[NSLayoutConstraint constrainViewToSize:center size:CGSizeMake(200, 200)]];
		[self addConstraints:[NSLayoutConstraint constraintViewToCenter:center]];
		
	}
	return self;
}

@end
