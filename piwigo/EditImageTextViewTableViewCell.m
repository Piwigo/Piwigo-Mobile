//
//  EditImageTextViewTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImageTextViewTableViewCell.h"
#import "UIPlaceHolderTextView.h"

@interface EditImageTextViewTableViewCell()

@property (weak, nonatomic) IBOutlet UIPlaceHolderTextView *textView;

@end

@implementation EditImageTextViewTableViewCell

- (void)awakeFromNib {
    // Initialization code
	self.textView.font = [UIFont piwigoFontNormal];
	self.textView.placeholder = @"Description";
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
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

@end
