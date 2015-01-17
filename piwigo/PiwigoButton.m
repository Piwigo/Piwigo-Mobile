//
//  PiwigoButton.m
//  piwigo
//
//  Created by Spencer Baker on 1/17/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "PiwigoButton.h"

@interface PiwigoButton()

//@property (nonatomic, strong) UILabel *buttonLabel;

@end

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
		
//		self.buttonLabel = [UILabel new];
//		self.buttonLabel.translatesAutoresizingMaskIntoConstraints = NO;
//		self.buttonLabel.font = [UIFont piwigoFontButton];
//		self.buttonLabel.textColor = [UIColor whiteColor];
//		[self addSubview:self.buttonLabel];
		
//		[self setupAutoLayout];
	}
	return self;
}

//-(void)setupAutoLayout
//{
//	[self addConstraints:[NSLayoutConstraint constraintViewToCenter:self.buttonLabel]];
//}

@end
