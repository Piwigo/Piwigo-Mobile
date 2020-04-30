//
//  EditImagePrivacyTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditImagePrivacyTableViewCell : UITableViewCell

-(void)setLeftLabelText:(NSString*)text;
-(void)setPrivacyLevel:(kPiwigoPrivacy)privacy inColor:(UIColor *)color;

@end
