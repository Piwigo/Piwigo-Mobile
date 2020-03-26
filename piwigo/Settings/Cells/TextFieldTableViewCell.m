//
//  ServerTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "TextFieldTableViewCell.h"
#import "Model.h"

@interface TextFieldTableViewCell()

@property (nonatomic, strong) UILabel *leftLabel;

@end

@implementation TextFieldTableViewCell

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.backgroundColor = [UIColor piwigoColorCellBackground];
		
		self.leftLabel = [UILabel new];
		self.leftLabel.translatesAutoresizingMaskIntoConstraints = NO;
		self.leftLabel.font = [UIFont piwigoFontNormal];
		self.leftLabel.textColor = [UIColor piwigoColorLeftLabel];
		self.leftLabel.adjustsFontSizeToFitWidth = NO;
		[self.contentView addSubview:self.leftLabel];
		
		self.rightTextField = [UITextField new];
		self.rightTextField.translatesAutoresizingMaskIntoConstraints = NO;
		self.rightTextField.font = [UIFont piwigoFontNormal];
		self.rightTextField.textColor = [UIColor piwigoColorRightLabel];
        self.rightTextField.keyboardType = UIKeyboardTypeDefault;
        self.rightTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
        self.rightTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.rightTextField.autocorrectionType = UITextAutocorrectionTypeYes;
        self.rightTextField.returnKeyType = UIReturnKeyGo;

        self.rightTextField.returnKeyType = UIReturnKeyDone;
        if ([Model sharedInstance].isAppLanguageRTL) {
            self.rightTextField.textAlignment = NSTextAlignmentLeft;
        } else {
            self.rightTextField.textAlignment = NSTextAlignmentRight;
        }
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
	
	[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.leftLabel]];
	[self.contentView addConstraint:[NSLayoutConstraint constraintCenterHorizontalView:self.rightTextField]];

    if (@available(iOS 11, *)) {
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-[label]-[field]-|"
																			 options:kNilOptions
																			 metrics:nil
																			   views:views]];
    } else {
        [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-15-[label]-[field]-15-|"
                                                                                 options:kNilOptions
                                                                                 metrics:nil
                                                                                   views:views]];
    }
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
	self.rightTextField.tag = -1;
	self.rightTextField.delegate = nil;
	self.labelText = @"";
}

@end






