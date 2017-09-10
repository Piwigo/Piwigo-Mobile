//
//  EditImageTextFieldTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditImageTextFieldTableViewCell : UITableViewCell

-(void)setLabel:(NSString*)label andTextField:(NSString*)text withPlaceholder:(NSString*)placeholder;
-(NSString*)getTextFieldText;

@end
