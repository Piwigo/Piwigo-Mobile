//
//  EditImageLabelTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/16/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Model.h"

@interface EditImageLabelTableViewCell : UITableViewCell

-(void)paletteChanged;
-(void)setPrivacyLevel:(kPiwigoPrivacy)privacy;
-(void)setLeftLabelText:(NSString*)text;

@end
