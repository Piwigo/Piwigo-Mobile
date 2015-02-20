//
//  LabelTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/15/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LabelTableViewCell : UITableViewCell

@property (nonatomic, strong) UILabel *leftLabel;
@property (nonatomic, strong) NSString *leftText;
@property (nonatomic, strong) NSString *rightText;
@property (nonatomic, assign) CGFloat leftLabelWidth;

@end
