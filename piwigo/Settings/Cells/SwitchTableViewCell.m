//
//  SwitchTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "SwitchTableViewCell.h"

@interface SwitchTableViewCell()

@end

@implementation SwitchTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor whiteColor];
		
		self.leftLabel = [UILabel new];
		self.leftLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.leftLabel.font = [UIFont piwigoFontNormal];
		self.leftLabel.textColor = [UIColor piwigoGray];
		self.leftLabel.textAlignment = NSTextAlignmentLeft;
		self.leftLabel.adjustsFontSizeToFitWidth = NO;
		self.leftLabel.numberOfLines = 2;
		self.leftLabel.preferredMaxLayoutWidth = 150;
		[self.contentView addSubview:self.leftLabel];
		
		self.cellSwitch = [UISwitch new];
		self.cellSwitch.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:self.cellSwitch];
		[self.cellSwitch addTarget:self action:@selector(switchChanged) forControlEvents:UIControlEventValueChanged];
		
		[self setupConstraints];
	}
	return self;
}

-(void)setupConstraints
{
	NSDictionary *views = @{
							@"label" : self.leftLabel,
							@"switch" : self.cellSwitch
							};
	
	[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.leftLabel]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.cellSwitch]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label]-[switch]-15-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
}

-(void)switchChanged
{
	if(self.cellSwitchBlock)
	{
		self.cellSwitchBlock(self.cellSwitch.isOn);
	}
}

@end
