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
		self.backgroundColor = [UIColor piwigoCellBackgroundColor];
		
		self.leftLabel = [UILabel new];
		self.leftLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.leftLabel.font = [UIFont piwigoFontNormal];
		self.leftLabel.textColor = [UIColor piwigoLeftLabelColor];
		self.leftLabel.adjustsFontSizeToFitWidth = NO;
		self.leftLabel.numberOfLines = 2;
		self.leftLabel.preferredMaxLayoutWidth = 150;
		[self.contentView addSubview:self.leftLabel];
		
		self.cellSwitch = [UISwitch new];
		self.cellSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        self.cellSwitch.thumbTintColor = [UIColor piwigoThumbColor];
        self.cellSwitch.tintColor = [UIColor piwigoRightLabelColor];
        self.cellSwitch.onTintColor = [UIColor piwigoOrange];
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
	
    if (@available(iOS 11, *)) {
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[switch]-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
    } else {
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label]-[switch]-15-|"
                                                                                 options:kNilOptions
                                                                                 metrics:nil
                                                                                   views:views]];
    }
}

-(void)switchChanged
{
	if(self.cellSwitchBlock)
	{
		self.cellSwitchBlock(self.cellSwitch.isOn);
	}
}

@end
