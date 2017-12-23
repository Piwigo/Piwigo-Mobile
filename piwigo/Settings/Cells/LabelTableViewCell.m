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
//        self.rightLabel.textAlignment = NSTextAlignmentLeft;
		self.leftLabel.adjustsFontSizeToFitWidth = NO;
		[self.contentView addSubview:self.leftLabel];
		
		self.rightLabel = [UILabel new];
		self.rightLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightLabel.font = [UIFont piwigoFontNormal];
		self.rightLabel.textColor = [UIColor piwigoBrown];
//        self.rightLabel.textAlignment = NSTextAlignmentRight;
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
							@"left" : self.leftLabel,
							@"right" : self.rightLabel
							};
	
    [self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.leftLabel]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.rightLabel]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[left]-[right]-15-|"
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
