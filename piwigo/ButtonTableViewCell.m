//
//  ButtonTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ButtonTableViewCell.h"

@interface ButtonTableViewCell()

@end

@implementation ButtonTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		self.buttonLabel = [UILabel new];
		self.buttonLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.buttonLabel.font = [UIFont piwigoFontButton];
		self.buttonLabel.textColor = [UIColor piwigoOrange];
		[self.contentView addSubview:self.buttonLabel];
		
		[self setupConstraints];
	}
	return self;
}

-(void)setupConstraints
{
	[self.contentView addConstraints:[NSLayoutConstraint constraintCenterView:self.buttonLabel]];
}

-(void)setButtonText:(NSString *)buttonText
{
	_buttonText = buttonText;
	self.buttonLabel.text = _buttonText;
}

@end
