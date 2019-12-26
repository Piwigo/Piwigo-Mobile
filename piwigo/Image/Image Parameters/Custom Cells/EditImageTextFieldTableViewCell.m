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
    self.cellTextField.clearButtonMode = UITextFieldViewModeAlways;
}

-(void)setupWithLabel:(NSString *)label placeHolder:(NSString *)placeHolder andImageDetail:(NSString *)imageDetail
{
    // Cell background
    self.backgroundColor = [UIColor piwigoBackgroundColor];

    // Cell label
    self.cellLabel.text = label;
    self.cellLabel.textColor = [UIColor piwigoLeftLabelColor];
    
    // Cell text field
    if (imageDetail == nil) {
        self.cellTextField.text = @"";
    } else {
        self.cellTextField.text = imageDetail;
    }
    self.cellTextField.textColor = [UIColor piwigoLeftLabelColor];
    self.cellTextField.backgroundColor = [UIColor piwigoBackgroundColor];
    if ([placeHolder length] > 0) {
        self.cellTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeHolder attributes:@{NSForegroundColorAttributeName: [UIColor piwigoRightLabelColor]}];
    }
    self.cellTextField.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)prepareForReuse
{
    [super prepareForReuse];

    self.cellTextField.delegate = nil;
    self.cellTextField.text = @"";
}

@end
