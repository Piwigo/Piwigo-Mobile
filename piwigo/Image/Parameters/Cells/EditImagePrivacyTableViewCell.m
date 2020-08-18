//
//  EditImagePrivacyTableViewCell.m
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "EditImagePrivacyTableViewCell.h"
#import "Model.h"

@interface EditImagePrivacyTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UILabel *list;

@end

@implementation EditImagePrivacyTableViewCell

- (void)awakeFromNib {

    // Initialization code
    [super awakeFromNib];
	
    self.label.font = [UIFont piwigoFontNormal];
    self.list.font = [UIFont piwigoFontNormal];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
	
}

-(void)setLeftLabelText:(NSString*)text
{
    self.label.text = text;
    self.label.textColor = [UIColor piwigoColorLeftLabel];
}

-(void)setPrivacyLevel:(kPiwigoPrivacy)privacy inColor:(UIColor *)color
{
	self.list.text = [[Model sharedInstance] getNameForPrivacyLevel:privacy];
    self.list.textColor = color;
}

@end
