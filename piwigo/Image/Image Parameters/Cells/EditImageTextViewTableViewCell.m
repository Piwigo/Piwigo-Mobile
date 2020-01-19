//
//  EditImageTextViewTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextViewTableViewCell.h"
#import "Model.h"

@interface EditImageTextViewTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation EditImageTextViewTableViewCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    
    self.label.text = NSLocalizedString(@"editImageDetails_description", @"Description");
    self.label.font = [UIFont piwigoFontNormal];

    self.textView.font = [UIFont piwigoFontNormal];
    self.textView.keyboardType = UIKeyboardTypeDefault;
    self.textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.textView.autocorrectionType = UITextAutocorrectionTypeYes;
    self.textView.returnKeyType = UIReturnKeyDefault;
    self.textView.layer.cornerRadius = 5.0;
}

-(void)setupWithImageDetail:(NSString *)imageDetail
{
    // Cell background
    self.backgroundColor = [UIColor piwigoBackgroundColor];
    
    // Cell label
    self.label.textColor = [UIColor piwigoRightLabelColor];

    // Cell text view
    self.textView.text = imageDetail;
    self.textView.textColor = [UIColor piwigoLeftLabelColor];
    self.textView.backgroundColor = [UIColor piwigoBackgroundColor];
    self.textView.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)prepareForReuse
{
    [super prepareForReuse];

    self.textView.delegate = nil;
    self.textView.text = @"";
}

@end
