//
//  EditImageTagsTableViewCell.h
//  piwigo
//
//  Created by Spencer Baker on 2/18/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "TagsData.h"

@interface EditImageTagsTableViewCell : UITableViewCell

-(void)setTagList:(NSArray <PiwigoTagData *> *)tags inColor:(UIColor *)color;

@end
