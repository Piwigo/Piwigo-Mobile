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

@property (weak, nonatomic) IBOutlet UILabel *leftLabel;
@property (weak, nonatomic) IBOutlet UILabel *rightLabel;

@end

@implementation EditImagePrivacyTableViewCell

- (void)awakeFromNib {

    // Initialization code
    [super awakeFromNib];
	
    self.leftLabel.font = [UIFont piwigoFontNormal];
    self.rightLabel.font = [UIFont piwigoFontNormal];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
	
}

-(void)setPrivacyLevel:(kPiwigoPrivacy)privacy
{
	self.rightLabel.text = [[Model sharedInstance] getNameForPrivacyLevel:privacy];
    self.rightLabel.textColor = [UIColor piwigoLeftLabelColor];
    self.rightLabel.backgroundColor = [UIColor piwigoCellBackgroundColor];
}

-(void)setLeftLabelText:(NSString*)text
{
	self.leftLabel.text = text;
    self.leftLabel.textColor = [UIColor piwigoLeftLabelColor];
}

@end
