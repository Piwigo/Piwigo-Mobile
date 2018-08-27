//
//  EditImageTextFieldTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextFieldTableViewCell.h"
#import "Model.h"

@interface EditImageTextFieldTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *cellLabel;
@property (weak, nonatomic) IBOutlet UITextField *cellTextField;

@end

@implementation EditImageTextFieldTableViewCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    
    self.cellLabel.font = [UIFont piwigoFontNormal];
    self.cellTextField.font = [UIFont piwigoFontNormal];
    self.cellTextField.keyboardType = UIKeyboardTypeDefault;
    self.cellTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.cellTextField.autocorrectionType = UITextAutocorrectionTypeYes;
    self.cellTextField.returnKeyType = UIReturnKeyDefault;
    [self paletteChanged];
}

-(void)paletteChanged
{
    self.cellLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.cellTextField.textColor = [UIColor piwigoRightLabelColor];
    self.cellTextField.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.cellTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
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
