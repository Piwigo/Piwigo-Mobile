//
//  EditImageTextViewTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextViewTableViewCell.h"
#import "UIPlaceHolderTextView.h"
#import "Model.h"

@interface EditImageTextViewTableViewCell()

@property (weak, nonatomic) IBOutlet UIPlaceHolderTextView *textView;

@end

@implementation EditImageTextViewTableViewCell

-(void)awakeFromNib {

    // Initialization code
    [super awakeFromNib];

    self.textView.font = [UIFont piwigoFontNormal];
    self.textView.placeholder = NSLocalizedString(@"editImageDetails_descriptionPlaceholder", @"Description");
    [self paletteChanged];
}

-(void)paletteChanged
{
    self.textView.textColor = [UIColor piwigoLeftLabelColor];
    self.textView.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.textView.placeholderColor = [UIColor piwigoRightLabelColor];
    self.textView.keyboardAppearance = [Model sharedInstance].isDarkPaletteActive ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
}

-(void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
	if(selected)
	{
		[self.textView becomeFirstResponder];
		[self.textView scrollRangeToVisible:NSMakeRange([self.textView.text length], 0)];
	}
}

-(NSString*)getTextViewText
{
	return self.textView.text;
}

-(void)setTextForTextView:(NSString*)text
{
	self.textView.text = text;
}

-(BOOL)isEditingTextView
{
    return self.textView.isFirstResponder;
}

@end
