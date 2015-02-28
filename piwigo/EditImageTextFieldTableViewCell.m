//
//  EditImageTextFieldTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextFieldTableViewCell.h"

@interface EditImageTextFieldTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *cellLabel;
@property (weak, nonatomic) IBOutlet UITextField *cellTextField;

@end

@implementation EditImageTextFieldTableViewCell

- (void)awakeFromNib {
    // Initialization code
}

-(void)setLabel:(NSString*)label andTextField:(NSString*)text withPlaceholder:(NSString*)placeholder
{
	if(!text)
	{
		text = @"";
	}
	self.cellLabel.text = label;
	self.cellTextField.text = text;
	self.cellTextField.placeholder = placeholder;
}

-(NSString*)getTextFieldText
{
	return self.cellTextField.text;
}

@end
