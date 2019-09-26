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

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation EditImageTextViewTableViewCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    
    self.cellTextView.font = [UIFont piwigoFontNormal];
    self.cellTextView.keyboardType = UIKeyboardTypeDefault;
    self.cellTextView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.cellTextView.autocorrectionType = UITextAutocorrectionTypeYes;
    self.cellTextView.returnKeyType = UIReturnKeyDefault;
    self.cellTextView.layer.cornerRadius = 5.0;
}

-(void)setupWithImageDetail:(NSString *)imageDetail
{
    // Cell background
    self.backgroundColor = [UIColor piwigoBackgroundColor];

    // Cell text view
    if ((imageDetail == nil) || (imageDetail.length == 0)) {
        self.cellTextView.text = NSLocalizedString(@"editImageDetails_descriptionPlaceholder", @"Description");
        self.cellTextView.textColor = [UIColor piwigoRightLabelColor];
    } else {
        self.cellTextView.text = imageDetail;
        self.cellTextView.textColor = [UIColor piwigoLeftLabelColor];
    }
    self.cellTextView.backgroundColor = [UIColor piwigoBackgroundColor];
    self.cellTextView.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)prepareForReuse
{
    [super prepareForReuse];

    self.cellTextView.delegate = nil;
    self.cellTextView.text = @"";
}

@end
