//
//  EditImageTextFieldTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/8/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "ImageUpload.h"

@interface EditImageTextFieldTableViewCell : UITableViewCell

@property (weak, nonatomic)     IBOutlet UILabel *cellLabel;
@property (weak, nonatomic)     IBOutlet UITextField *cellTextField;

-(void)setupWithLabel:(NSString *)label placeHolder:(NSString *)placeHolder andImageDetail:(NSString *)imageDetail;

@end
