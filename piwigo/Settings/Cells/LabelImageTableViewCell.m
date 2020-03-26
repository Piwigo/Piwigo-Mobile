//
//  LabelImageTableViewCell.m
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 27/01/2019.
//  Copyright © 2019 Piwigo.org. All rights reserved.
//

#import "LabelImageTableViewCell.h"
#import "Model.h"

@interface LabelImageTableViewCell()

@end

@implementation LabelImageTableViewCell

-(void)setupWithActivityName:(NSString *)activityName andEditOption:(int)option
{
    // General settings
    self.backgroundColor = [UIColor piwigoColorCellBackground];
    self.tintColor = [UIColor piwigoColorOrange];
    self.textLabel.font = [UIFont piwigoFontNormal];
    
    // Activity name
    self.leftLabel.text = activityName;
    self.leftLabel.font = [UIFont piwigoFontNormal];
    self.leftLabel.textColor = [UIColor piwigoColorLeftLabel];

    // Change image according to state
    switch (option) {
        case kPiwigoActionCellEditNone:
            self.rightAddImage.hidden = YES;
            self.rightRemoveImage.hidden = YES;
            break;
            
        case kPiwigoActionCellEditAdd:
            self.rightAddImage.hidden = NO;
            self.rightRemoveImage.hidden = YES;
            break;
            
        case kPiwigoActionCellEditRemove:
            self.rightAddImage.hidden = YES;
            self.rightRemoveImage.hidden = NO;
            break;
            
        default:
            break;
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.leftLabel.text = @"";
}

@end
