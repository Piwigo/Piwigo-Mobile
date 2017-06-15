//
//  SwitchTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 3/24/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^CellSwitchBlock)(BOOL switchState);

@interface SwitchTableViewCell : UITableViewCell

@property (nonatomic, strong) UILabel *leftLabel;
@property (nonatomic, strong) UISwitch *cellSwitch;
@property (nonatomic, copy) CellSwitchBlock cellSwitchBlock;

@end
