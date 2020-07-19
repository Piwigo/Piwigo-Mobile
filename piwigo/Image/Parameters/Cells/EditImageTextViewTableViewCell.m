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

-(void)setComment:(NSString *)imageDetail inColor:(UIColor *)color
{
    // Cell background
    self.backgroundColor = [UIColor piwigoColorBackground];
    
    // Cell label
    self.label.textColor = [UIColor piwigoColorRightLabel];

    // Cell text view
    self.textView.text = imageDetail;
    self.textView.textColor = color;
    self.textView.backgroundColor = [UIColor piwigoColorBackground];
    self.textView.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)prepareForReuse
{
    [super prepareForReuse];

    self.textView.delegate = nil;
    self.textView.text = @"";
}

@end
