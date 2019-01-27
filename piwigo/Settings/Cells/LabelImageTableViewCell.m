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

-(void)setupWithActivityName:(NSString *)activityName sharingPrivateMetadata:(BOOL)isSharing
{
    // General settings
    self.backgroundColor = [UIColor piwigoCellBackgroundColor];
    self.tintColor = [UIColor piwigoOrange];
    self.textLabel.font = [UIFont piwigoFontNormal];
    
    // Activity name
    self.leftLabel.text = activityName;
    self.leftLabel.font = [UIFont piwigoFontNormal];
    self.leftLabel.textColor = [UIColor piwigoLeftLabelColor];

    // Change image according to state
    if (isSharing) {
        self.rightAddImage.hidden = YES;
        self.rightRemoveImage.hidden = NO;
    } else {
        self.rightAddImage.hidden = NO;
        self.rightRemoveImage.hidden = YES;
    }
}

-(void)prepareForReuse
{
    [super prepareForReuse];
    
    self.leftLabel.text = @"";
}

@end
