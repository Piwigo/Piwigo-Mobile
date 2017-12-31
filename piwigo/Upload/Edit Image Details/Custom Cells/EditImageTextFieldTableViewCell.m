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
    [super awakeFromNib];
    
    self.cellLabel.font = [UIFont piwigoFontNormal];
    self.cellLabel.textColor = [UIColor piwigoLeftLabelColor];

    self.cellTextField.font = [UIFont piwigoFontNormal];
    self.cellTextField.textColor = [UIColor piwigoRightLabelColor];
    self.cellTextField.backgroundColor = [UIColor piwigoCellBackgroundColor];
}

-(void)setLabel:(NSString*)label andTextField:(NSString*)text withPlaceholder:(NSString*)placeholder
{
	self.cellLabel.text = label;
	self.cellTextField.text = text;
	self.cellTextField.placeholder = placeholder;
}

-(NSString*)getTextFieldText
{
	return self.cellTextField.text;
}

@end
