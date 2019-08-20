//
//  EditImageTextFieldTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextFieldTableViewCell.h"
#import "Model.h"

@interface EditImageTextFieldTableViewCell() <UITextFieldDelegate>

@property (weak, nonatomic)     IBOutlet UILabel *cellLabel;
@property (weak, nonatomic)     IBOutlet UITextField *cellTextField;
@property (assign, nonatomic)   CGFloat textFieldHeight;

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
    self.cellTextField.clearButtonMode = UITextFieldViewModeUnlessEditing;
    self.cellTextField.delegate = self;
    [self paletteChanged];
}

-(void)paletteChanged
{
    self.cellLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.cellTextField.textColor = [UIColor piwigoLeftLabelColor];
    self.cellTextField.backgroundColor = [UIColor piwigoCellBackgroundColor];
    if ([[self.cellTextField.attributedPlaceholder string] length] > 0) {
        NSString *placeHolder = [self.cellTextField.attributedPlaceholder string];
        self.cellTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolder attributes:@{NSForegroundColorAttributeName: [UIColor piwigoRightLabelColor]}];
    }
    self.cellTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)setLabel:(NSString*)label andTextField:(NSString*)text withPlaceholder:(NSString*)placeholder
{
	self.cellLabel.text = label;
	self.cellTextField.text = text;
    self.cellTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: [UIColor piwigoRightLabelColor]}];
}

-(NSString*)getTextFieldText
{
	return self.cellTextField.text;
}

-(BOOL)isEditingTextField
{
    return self.cellTextField.isEditing;
}

-(CGFloat)getTextFieldHeight
{
    return self.textFieldHeight;
}


#pragma mark - UITextField Delegate Methods

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    self.textFieldHeight = self.frame.origin.y + self.frame.size.height;
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.textFieldHeight = 0.0;
}

@end
