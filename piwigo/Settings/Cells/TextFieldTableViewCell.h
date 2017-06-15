//
//  ServerTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/2/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TextFieldTableViewCell : UITableViewCell

@property (nonatomic, strong) NSString *labelText;
@property (nonatomic, strong) UITextField *rightTextField;

@end
