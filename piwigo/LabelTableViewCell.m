//
//  LabelTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "LabelTableViewCell.h"

@interface LabelTableViewCell()

@property (nonatomic, strong) UILabel *rightLabel;

@property (nonatomic, strong) NSLayoutConstraint *leftLabelWidthConstraint;

@end

@implementation LabelTableViewCell

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
		self.leftLabel.textAlignment = NSTextAlignmentRight;
		self.leftLabel.adjustsFontSizeToFitWidth = YES;
		self.leftLabel.minimumScaleFactor = 0.5;
		[self.contentView addSubview:self.leftLabel];
		
		self.rightLabel = [UILabel new];
		self.rightLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightLabel.font = [UIFont piwigoFontNormal];
		self.rightLabel.textColor = [UIColor blackColor];
		self.rightLabel.adjustsFontSizeToFitWidth = YES;
		self.rightLabel.minimumScaleFactor = 0.5;
		[self.contentView addSubview:self.rightLabel];
		
		[self setupConstraints];
	}
	return self;
}

-(void)setupConstraints
{
	NSDictionary *views = @{
							@"label" : self.leftLabel,
							@"right" : self.rightLabel
							};
	
	[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.leftLabel]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.rightLabel]];
	
	self.leftLabelWidthConstraint = [NSLayoutConstraint constrainViewToWidth:self.leftLabel width:80];
	[self.contentView addConstraint:self.leftLabelWidthConstraint];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label]-[right]-10-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
}

-(void)setLeftText:(NSString *)labelText
{
	_leftText = labelText;
	
	self.leftLabel.text = _leftText;
}

-(void)setRightText:(NSString *)rightText
{
	_rightText = rightText;
	
	self.rightLabel.text = _rightText;
}

-(void)setLeftLabelWidth:(CGFloat)leftLabelWidth
{
	_leftLabelWidth = leftLabelWidth;
	
	self.leftLabelWidthConstraint.constant = leftLabelWidth;
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	self.rightLabel.text = @"";
	self.leftLabel.text = @"";
	self.accessoryType = UITableViewCellAccessoryNone;
}

@end
