//
//  ServerTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TextFieldTableViewCell.h"

@interface TextFieldTableViewCell()

@property (nonatomic, strong) UILabel *leftLabel;

@end

@implementation TextFieldTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoWhiteCream];
		
		self.leftLabel = [UILabel new];
		self.leftLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.leftLabel.font = [UIFont piwigoFontNormal];
		self.leftLabel.textColor = [UIColor piwigoGray];
		self.leftLabel.textAlignment = NSTextAlignmentRight;
		[self.contentView addSubview:self.leftLabel];
		
		self.rightTextField = [UITextField new];
		self.rightTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightTextField.font = [UIFont piwigoFontNormal];
		self.rightTextField.textColor = [UIColor blackColor];
		[self.contentView addSubview:self.rightTextField];
		
		[self setupConstraints];
	}
	return self;
}

-(void)setupConstraints
{
	NSDictionary *views = @{
							@"label" : self.leftLabel,
							@"field" : self.rightTextField
							};
	
	[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.leftLabel]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintVerticalCenterView:self.rightTextField]];
	
	[self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label(80)]-[field]-10-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
}

-(void)setLabelText:(NSString *)labelText
{
	_labelText = labelText;
	
	self.leftLabel.text = _labelText;
}

-(void)prepareForReuse
{
	[super prepareForReuse];
	self.rightTextField.userInteractionEnabled = YES;
	self.rightTextField.text = @"";
	self.labelText = @"";
}

@end






